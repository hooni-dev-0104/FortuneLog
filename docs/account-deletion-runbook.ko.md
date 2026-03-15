# 회원 탈퇴(비식별화/파기) Runbook (Beta v1)

## 개요
- 모바일 앱은 `POST /engine/v1/accounts:deletion-request`로 탈퇴 요청을 생성합니다.
- 백엔드는 `account_deletion_requests` 테이블에 요청을 적재합니다.
- Beta v1에서는 요청 접수/접근 차단(로그아웃)까지를 우선 구현하고, 실제 파기 자동화는 후속 배치 작업으로 처리합니다.

## 스키마
- 마이그레이션: `202603150001_account_deletion_requests.sql`
- 마이그레이션: `202603150002_profiles_deactivation_flag.sql`
- 핵심 컬럼:
  - `user_id`: 대상 사용자
  - `status`: `requested | processing | completed | rejected | canceled`
  - `requested_reason`: 사용자 사유(옵션)
  - `requested_at`: 요청 시각
  - `processed_at`, `anonymized_at`: 운영 처리 시각
- 활성 요청 중복 방지:
  - `uq_account_deletion_requests_user_active`
  - 조건: `status in ('requested', 'processing')`

## 접근 차단(즉시)
- 탈퇴 요청 접수 시 `profiles.is_deactivated=true`, `profiles.deactivated_at=now()`로 즉시 전환됩니다.
- Engine API는 비활성 계정에 대해 `ACCOUNT_DELETION_LOCKED (403)`을 반환합니다.

## 운영 처리 절차 (수동 v1)
1. `status='requested'` 요청을 오래된 순으로 조회
2. 대상 사용자의 유료 접근 상태/구독 상태 확인
3. 필요 시 `status='processing'`으로 전환
4. 비식별화/파기 정책 수행
5. 완료 시 `status='completed'`, `processed_at`, `anonymized_at` 기록

## 비동기 워커(v1)
- Engine API 내 스케줄러가 `requested -> processing -> completed/rejected` 전이를 처리합니다.
- 기본 주기: 30초 (`ACCOUNT_DELETION_WORKER_FIXED_DELAY_MS`)
- 배치 크기: 20 (`ACCOUNT_DELETION_WORKER_BATCH_SIZE`)
- 처리 내용:
  - `reports`, `saju_charts`, `birth_profiles`, `orders`, `subscriptions` 사용자 데이터 삭제
  - `profiles.nickname` 비식별화
  - 요청 상태 `completed` 및 시각(`processed_at`, `anonymized_at`) 기록

## 결제/구독 웹훅 정합성 정책
- `profiles.is_deactivated=true` 계정은 RevenueCat/결제 웹훅 수신 시에도 재활성화하지 않습니다.
- 해당 계정의 `orders/subscriptions` 상태 갱신 및 entitlement 재계산을 건너뜁니다.
- 유료 리포트 공개 상태는 항상 `false` 방향으로 보정해, 탈퇴 요청 이후 접근이 다시 열리지 않도록 유지합니다.

## 점검 쿼리 예시
```sql
select id, user_id, status, requested_at
from public.account_deletion_requests
order by requested_at asc
limit 50;
```

```sql
select id, user_id, status, requested_at
from public.account_deletion_requests
where status in ('requested', 'processing')
order by requested_at asc;
```
