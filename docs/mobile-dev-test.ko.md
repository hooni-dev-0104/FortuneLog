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
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://gcddzpfzjcstypegmmnj.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<YOUR_ANON_KEY>
```

## 3. 앱에서 입력할 값

- `Engine Base URL`: `http://localhost:8080`
- `Supabase Email`, `Supabase Password`: 테스트 계정
- `Birth Date`, `Birth Time`, `Timezone`, `Location`, `Gender`

## 4. 테스트 순서

1. `A) Email Login`
2. `B) Sync Session` (token/user id 자동 반영)
3. `C) Create Birth Profile` (`birth_profile_id` 자동 생성)
4. `1) Calculate Chart`
5. `2) Generate Report`
6. `3) Daily Fortune`

각 결과는 화면 하단 JSON으로 표시됩니다.

## 참고

- 현재 `lunar`는 미지원이며 `solar` 기준 테스트가 정상 동작합니다.
