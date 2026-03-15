# 회원 탈퇴(비식별화/파기) Runbook (Beta v1)

## 개요
- 모바일 앱은 `POST /engine/v1/accounts:deletion-request`로 탈퇴 요청을 생성합니다.
- 백엔드는 `account_deletion_requests` 테이블에 요청을 적재합니다.
- Beta v1에서는 요청 접수/접근 차단(로그아웃)까지를 우선 구현하고, 실제 파기 자동화는 후속 배치 작업으로 처리합니다.

## 스키마
- 마이그레이션: `202603150001_account_deletion_requests.sql`
- 핵심 컬럼:
  - `user_id`: 대상 사용자
  - `status`: `requested | processing | completed | rejected | canceled`
  - `requested_reason`: 사용자 사유(옵션)
  - `requested_at`: 요청 시각
  - `processed_at`, `anonymized_at`: 운영 처리 시각
- 활성 요청 중복 방지:
  - `uq_account_deletion_requests_user_active`
  - 조건: `status in ('requested', 'processing')`

## 운영 처리 절차 (수동 v1)
1. `status='requested'` 요청을 오래된 순으로 조회
2. 대상 사용자의 유료 접근 상태/구독 상태 확인
3. 필요 시 `status='processing'`으로 전환
4. 비식별화/파기 정책 수행
5. 완료 시 `status='completed'`, `processed_at`, `anonymized_at` 기록

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
