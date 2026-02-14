# Flutter 테스트 화면 실행 방법

## 1. 엔진 서버 실행

```bash
cd /Users/hooni/FortuneLog/services/engine-api
./gradlew bootRun
```

기본 포트: `8080`

## 2. Flutter 앱 실행

```bash
cd /Users/hooni/FortuneLog/apps/mobile
cp .env.example .env
# .env 파일에 SUPABASE_URL / SUPABASE_ANON_KEY / AUTH_REDIRECT_TO 입력
./scripts/run_ios_dev.sh
```

`AUTH_REDIRECT_TO` 기본값:

```text
io.supabase.flutter://login-callback/
```

Supabase Dashboard > Authentication > URL Configuration 의 Additional Redirect URLs에도 동일 값을 추가해야 합니다.

## 3. 앱에서 입력할 값

- `Engine Base URL`: `http://localhost:8080`
- `Supabase Email`, `Supabase Password`: 테스트 계정
- `Birth Date`, `Birth Time`, `Timezone`, `Location`, `Gender`

## 4. 테스트 순서

1. `A) Email Login`
2. `B) Sync Session` (token/user id 자동 반영)
3. `C) Create Birth Profile` (`birth_profile_id` 자동 생성)
4. `D) Fetch Birth Profiles` (기존 프로필 목록 조회/선택)
5. `1) Calculate Chart`
6. `2) Generate Report`
7. `3) Daily Fortune`
8. `4) Fetch Reports` (Supabase 저장 확인)
9. `5) Fetch Orders`
10. `6) Fetch Subscriptions`

각 결과는 화면 하단 JSON으로 표시됩니다.

## 참고

- `lunar` 입력도 지원되며 윤달 값 검증 실패 시 에러 메시지가 상세히 표시됩니다.
- 엔진 응답 및 에러에 `requestId`가 포함되며 상단 상태 영역에서 확인 가능합니다.
