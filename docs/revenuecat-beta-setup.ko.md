# RevenueCat 베타 연동 가이드

## 1. 개요

베타 단계에서는 아래 구조로 결제/구독 상태를 동기화합니다.

1. 모바일 앱에서 RevenueCat SDK 초기화
2. RevenueCat Webhook 이벤트를 엔진 API가 수신
3. 엔진 API가 `orders` / `subscriptions` / 유료 리포트 가시성을 갱신

Webhook 엔드포인트:

- `POST /engine/v1/payments:webhook`

## 2. 모바일 설정

`apps/mobile/.env`에 RevenueCat 공개 SDK 키를 설정합니다.

```env
REVENUECAT_API_KEY_IOS=appl_xxxxx
REVENUECAT_API_KEY_ANDROID=goog_xxxxx
REVENUECAT_ENTITLEMENT_ID=premium
```

참고:

- iOS/Android 키는 RevenueCat Project의 플랫폼별 Public SDK Key를 사용합니다.
- `REVENUECAT_ENTITLEMENT_ID`는 선택값이며, 비우면 active entitlement가 하나라도 있으면 활성으로 판단합니다.

## 3. 서버 설정

`services/engine-api/.env`에 webhook 인증값을 설정합니다.

```env
# Legacy generic webhook HMAC (선택, 기존 호환용)
PAYMENT_WEBHOOK_SECRET=

# RevenueCat webhook Authorization header 값
REVENUECAT_WEBHOOK_AUTH=rc_live_xxxxx
```

## 4. RevenueCat Webhook 설정

RevenueCat dashboard에서 webhook URL을 아래처럼 지정합니다.

- URL: `https://<engine-domain>/engine/v1/payments:webhook`

Authorization header 값은 `REVENUECAT_WEBHOOK_AUTH`와 동일하게 맞춥니다.

예시:

- Header: `Authorization: Bearer rc_live_xxxxx`

서버는 `Bearer` prefix가 있거나 없어도 같은 값으로 비교합니다.

## 5. 프리미엄 사주풀이 이용권(Phase 1)

Phase 1에서는 iOS/Android 네이티브 RevenueCat 1회성 상품으로만 실제 구매를 지원합니다.
Flutter web 화면은 가격/잔액/안내를 보여주되 실제 web checkout은 제공하지 않습니다.

| RevenueCat product_id | 지급 credit | fallback 표시가 |
| --- | ---: | ---: |
| `fortunelog_ai_credit_1` | 1회 | 1,500원 |
| `fortunelog_ai_credit_5` | 5회 | 5,500원 |
| `fortunelog_ai_credit_10` | 10회 | 10,000원 |

- `product_id`와 credit 수량은 repo/server 계약이 기준입니다.
- 앱에 표시되는 실결제 가격은 RevenueCat/App Store/Google Play 가격을 우선합니다.
- Supabase `products.price`는 fallback/문서용 가격이며 store 설정과 출시 전 대조해야 합니다.
- AI 사주풀이는 생성 성공 후 report 저장과 credit 차감이 완료된 경우에만 사용자에게 반환됩니다.

## 6. 이벤트 매핑(베타 기준)

주요 RevenueCat 이벤트는 아래 내부 상태로 변환됩니다.

- `INITIAL_PURCHASE`, `RENEWAL` → `order_status=paid`, `subscription_status=active`
- `NON_RENEWING_PURCHASE` + `fortunelog_ai_credit_*` → `order_status=paid`, `ai_interpretation` credit 지급
  - 크레딧 팩은 consumable 이용권이므로 `subscriptions`/유료 리포트 가시성 entitlement를 갱신하지 않습니다.
  - 동일 실제 구매의 중복 지급은 `credit_ledger.source_provider + source_order_id + reason + credit_type` unique index로 방지합니다.
- `BILLING_ISSUE` → `subscription_status=grace`
- `EXPIRATION` → `subscription_status=expired`
- `CANCELLATION` → 만료시각이 미래면 `active/grace`, 과거면 `canceled`
- `REFUND` 등 Phase 1에서 명시 처리하지 않는 consumable 환불 이벤트 → 자동 차감하지 않고 운영 대응 정책으로 처리합니다.
- `TEST`, `SUBSCRIBER_ALIAS` 등 비과금성 이벤트 → no-op

### 탈퇴 계정 정책
- `profiles.is_deactivated=true` 계정은 웹훅이 수신되어도 결제/구독 상태를 재활성화하지 않습니다.
- 탈퇴 요청 이후 entitlement는 `false`로 유지되며, 유료 리포트 접근도 복구하지 않습니다.

## 7. 출시 전 검증 체크리스트

- RevenueCat/App Store/Google Play의 product ID가 위 표와 정확히 일치하는지 확인합니다.
- 1회/5회/10회권의 store 가격이 각각 1,500원/5,500원/10,000원 정책과 일치하는지 확인합니다.
- 각 상품의 sandbox 구매 webhook에서 `event.id`, `product_id`, `transaction_id`, `original_transaction_id`를 캡처합니다.
- 동일 webhook 재전송이 credit을 중복 지급하지 않는지 확인합니다.
- 구매 직후 앱의 `GET /engine/v1/credits` 잔액이 갱신되는지 확인합니다.
- Flutter web에서는 구매 버튼이 실제 결제를 시도하지 않고 앱 구매 안내를 보여주는지 확인합니다.

## 8. 로컬 점검 순서

1. 엔진 실행

```bash
cd services/engine-api
./gradlew bootRun
```

2. 모바일 실행

```bash
cd apps/mobile
./scripts/run_ios_dev.sh "iPhone 14"
```

3. RevenueCat dashboard에서 test webhook 발송
4. 앱 `내정보 > 주문 / 결제 · 구독`에서 상태 반영 확인
