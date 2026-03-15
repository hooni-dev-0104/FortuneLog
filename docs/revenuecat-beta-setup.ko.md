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

## 5. 이벤트 매핑(베타 기준)

주요 RevenueCat 이벤트는 아래 내부 상태로 변환됩니다.

- `INITIAL_PURCHASE`, `RENEWAL` → `order_status=paid`, `subscription_status=active`
- `BILLING_ISSUE` → `subscription_status=grace`
- `EXPIRATION` → `subscription_status=expired`
- `CANCELLATION` → 만료시각이 미래면 `active/grace`, 과거면 `canceled`
- `TEST`, `SUBSCRIBER_ALIAS` 등 비과금성 이벤트 → no-op

### 탈퇴 계정 정책
- `profiles.is_deactivated=true` 계정은 웹훅이 수신되어도 결제/구독 상태를 재활성화하지 않습니다.
- 탈퇴 요청 이후 entitlement는 `false`로 유지되며, 유료 리포트 접근도 복구하지 않습니다.

## 6. 로컬 점검 순서

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
