# FortuneLog 기술 스펙 (Supabase + Spring Boot)

- 문서 버전: v0.1
- 작성일: 2026-02-13
- 기준 문서: `docs/functional-spec.ko.md`
- 목표: MVP를 빠르게 출시하면서 확장 가능한 구조 확보

## 1. 기술 스택

### 1.1 클라이언트
- Flutter (iOS/Android 단일 코드베이스)
- Supabase Flutter SDK (Auth, PostgREST, Realtime 선택적 사용)
- FCM (푸시)

### 1.2 백엔드/데이터
- Supabase:
  - Auth (이메일 + 소셜 OAuth)
  - Postgres (주 데이터 저장소)
  - Storage (공유 이미지/정적 자원)
  - Edge Functions (웹훅, 간단 오케스트레이션)
- Spring Boot (Java 21):
  - 사주 계산 엔진 API
  - 해석 조합/리포트 생성
  - 엔진 버전 관리 및 계산 로그

### 1.3 운영/품질
- 관측: Sentry(앱/서버), 구조화 로그(JSON)
- 분석: Amplitude
- 배포: Spring Boot 컨테이너 (ECS 또는 Fly/Render 등)

## 2. 아키텍처

## 2.1 책임 분리
- Supabase 책임:
  - 사용자 인증/권한
  - 사용자 데이터 영속화
  - 결제 상태/구독 상태 저장
  - RLS를 통한 사용자 데이터 격리
- Spring 엔진 책임:
  - 출생정보 기반 사주 원국 계산
  - 오행/십성 계산
  - 리포트 문장 생성(템플릿 규칙)

## 2.2 요청 흐름
1. 앱이 Supabase Auth로 로그인 후 `access token(JWT)` 획득
2. 앱이 Supabase DB에 출생정보 저장
3. 앱이 Spring 엔진 API 호출 시 JWT 전달
4. Spring 서버가 JWT 검증 후 계산 수행
5. 계산 결과를 Supabase DB에 저장(서비스 롤 또는 보안 RPC 경유)
6. 앱은 Supabase에서 리포트 조회

## 2.3 네트워크 경계
- Public:
  - Supabase API/Auth endpoint
  - Spring API gateway endpoint
- Private/Protected:
  - Spring -> Supabase DB 쓰기 권한(서비스 키는 서버에만 저장)

## 3. 저장소/프로젝트 구조(권장)

```text
FortuneLog/
  apps/
    mobile/                 # Flutter 앱
  services/
    engine-api/             # Spring Boot 엔진
  infra/
    supabase/
      migrations/           # SQL migration
      seeds/
  docs/
    functional-spec.ko.md
    tech-spec.ko.md
```

## 4. 데이터베이스 설계 (Supabase Postgres)

## 4.1 핵심 테이블
- `profiles`
  - `id uuid pk` (auth.users.id 참조)
  - `nickname text`
  - `created_at timestamptz`
- `birth_profiles`
  - `id uuid pk`
  - `user_id uuid fk -> profiles.id`
  - `birth_datetime_local timestamp`
  - `birth_timezone text`
  - `birth_location text`
  - `calendar_type text check (solar|lunar)`
  - `is_leap_month boolean`
  - `gender text`
  - `unknown_birth_time boolean`
  - `created_at timestamptz`
- `saju_charts`
  - `id uuid pk`
  - `user_id uuid fk`
  - `birth_profile_id uuid fk`
  - `chart_json jsonb`
  - `five_elements_json jsonb`
  - `engine_version text`
  - `created_at timestamptz`
- `reports`
  - `id uuid pk`
  - `user_id uuid fk`
  - `chart_id uuid fk`
  - `report_type text` (`summary|personality|relationship|career|daily`)
  - `content_json jsonb`
  - `is_paid_content boolean`
  - `visible boolean`
  - `created_at timestamptz`
- `products`
  - `id uuid pk`
  - `code text unique`
  - `name text`
  - `price int`
  - `currency text`
  - `product_type text` (`one_time|subscription`)
- `orders`
  - `id uuid pk`
  - `user_id uuid fk`
  - `product_id uuid fk`
  - `status text` (`pending|paid|failed|canceled`)
  - `provider text`
  - `provider_order_id text`
  - `created_at timestamptz`
- `subscriptions`
  - `id uuid pk`
  - `user_id uuid fk`
  - `plan_code text`
  - `status text` (`active|grace|expired|canceled`)
  - `started_at timestamptz`
  - `expires_at timestamptz`

## 4.2 인덱스
- `birth_profiles(user_id, created_at desc)`
- `saju_charts(user_id, created_at desc)`
- `reports(user_id, report_type, created_at desc)`
- `orders(user_id, created_at desc)`
- `subscriptions(user_id, status)`

## 4.3 RLS 정책 원칙
- 공통 원칙: `auth.uid() = user_id` 인 데이터만 `select/update/delete` 허용
- `products`는 전 사용자 읽기 허용
- 결제/구독 상태 갱신은 서버(서비스 키)만 허용

## 5. Spring Boot 엔진 설계

## 5.1 모듈
- `api`: REST controller, validation
- `application`: use-case orchestration
- `domain`: 간지/오행/십성 계산 규칙
- `infra`: Supabase 연동, 캐시, 외부 연계

## 5.2 필수 API
- `POST /engine/v1/charts:calculate`
  - 입력: 출생 정보
  - 출력: `chart_json`, `five_elements_json`, `engine_version`
- `POST /engine/v1/reports:generate`
  - 입력: `chart_id`, `report_type`
  - 출력: 리포트 JSON
- `POST /engine/v1/fortunes:daily`
  - 입력: `user_id`, `date`
  - 출력: 오늘 운세 JSON
- `GET /engine/v1/health`

## 5.3 인증/권한
- 앱 -> 엔진 호출 시 Supabase JWT 전달 (`Authorization: Bearer`)
- 엔진에서 Supabase JWT 공개키(JWKS) 검증
- 내부 쓰기 작업은 서버 보관 `SUPABASE_SERVICE_ROLE_KEY` 사용

## 5.4 성능
- 계산 API P95 2초 이하 목표
- 동일 입력(동일 birth_profile + engine_version)은 캐시 우선 조회

## 6. API 계약 (앱 관점)

## 6.1 앱 -> Supabase
- 인증, 프로필 CRUD, 리포트 조회, 결제 상태 조회

## 6.2 앱 -> Spring 엔진
- 계산/생성 트리거성 API만 호출
- 엔진 완료 후 앱은 Supabase에서 결과 재조회

## 6.3 에러 표준
- 예시:
```json
{
  "requestId": "2db5d6f4-0bf1-4ac8-b00d-6f6a6a0d9f12",
  "code": "BIRTH_INFO_INVALID",
  "message": "invalid lunar/leap month combination"
}
```

## 7. 결제/구독 처리

## 7.1 처리 흐름
1. 앱에서 스토어 결제 수행
2. 결제 provider webhook -> Supabase Edge Function
3. Edge Function이 `orders`, `subscriptions` 갱신
4. 유료 리포트 가시성(`reports.visible`) 업데이트

## 7.2 보안
- 웹훅 서명 검증 필수
- 중복 이벤트 idempotency key 처리

## 8. 배치/스케줄

- 매일 06:00(사용자 로컬 시간 기준) 오늘 운세 사전 생성
- Supabase Cron -> Edge Function -> Spring `/fortunes:daily` 호출
- 실패 시 재시도 3회, 이후 DLQ 테이블 기록

## 9. 환경 변수

## 9.1 Flutter
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `ENGINE_API_BASE_URL`

## 9.2 Spring
- `SUPABASE_URL`
- `SUPABASE_JWKS_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `ENGINE_CACHE_TTL_SECONDS`
- `SENTRY_DSN`

## 10. 로깅/모니터링

- 공통 로그 필드:
  - `timestamp`, `level`, `requestId`, `userId`, `path`, `latencyMs`, `errorCode`
- 알람:
  - 계산 API 에러율 > 2%
  - P95 지연 > 2초
  - 웹훅 실패율 > 1%

## 11. 보안 체크리스트

- 서비스 롤 키는 앱/클라이언트에 절대 노출 금지
- 모든 테이블 RLS 활성화 확인
- PII 최소 저장 (출생정보 외 민감 데이터 미수집)
- 탈퇴 시 비식별화/파기 정책 적용

## 12. 단계별 구현 계획

1. Supabase 스키마 + RLS + Auth 연결
2. Spring 엔진 기본 API(차트 계산) 구현
3. 리포트 생성/저장 플로우 연결
4. 결제 웹훅 + 구독 반영
5. 오늘 운세 배치 + 푸시
6. Sentry/Amplitude 연결 및 성능 튜닝

## 13. 오픈 이슈

- 출생시간 미상 케이스 해석 정책 확정 필요
- 리포트 템플릿 버전 관리 방식(`report_template_version`) 확정 필요
- 결제 공급자(RevenueCat 직접 연동 vs 스토어 웹훅 직접) 확정 필요
