# FortuneLog Mobile

FortuneLog의 Flutter 앱입니다.

## 로컬 실행

### 1) 로컬 환경 파일 준비

`apps/mobile/.env.local` 파일을 만들고 아래 값을 채웁니다.

```env
SUPABASE_URL=
SUPABASE_ANON_KEY=
AUTH_REDIRECT_TO=io.supabase.flutter://login-callback/
ENGINE_BASE_URL=http://127.0.0.1:8080
REVENUECAT_API_KEY_IOS=
REVENUECAT_API_KEY_ANDROID=
REVENUECAT_ENTITLEMENT_ID=
```

` .env.local ` 은 git에 커밋하지 않습니다.

### 2) 일반 로컬 실행

저장소 루트에서:

```bash
apps/mobile/scripts/run_local_dev.sh
```

기본 타깃은 `chrome` 입니다.

다른 타깃 예시:

```bash
apps/mobile/scripts/run_local_dev.sh chrome
apps/mobile/scripts/run_local_dev.sh "iPhone 16 Pro"
```

### 3) iOS 중심 실행

```bash
apps/mobile/scripts/run_ios_dev.sh
```

특정 시뮬레이터를 지정할 수도 있습니다.

```bash
apps/mobile/scripts/run_ios_dev.sh "iPhone 16 Pro"
```

`--start-engine` 를 붙이면 로컬 `engine-api` 부팅도 시도합니다.

```bash
apps/mobile/scripts/run_ios_dev.sh "iPhone 16 Pro" --start-engine
```

## 수동 실행

직접 실행하려면:

```bash
cd apps/mobile
flutter pub get
flutter run \
  --dart-define-from-file=.env.local \
  --dart-define=ENGINE_BASE_URL=http://127.0.0.1:8080
```

## 검증

```bash
cd apps/mobile
flutter analyze
flutter test
```
