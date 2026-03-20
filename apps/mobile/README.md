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

## 릴리스 식별자

- Android application ID / namespace: `com.fortunelog.mobile`
- iOS bundle identifier: `com.fortunelog.mobile`
- macOS bundle identifier: `com.fortunelog.mobile`

## Android release signing

Android 베타/릴리스 빌드는 로컬 비밀값을 커밋하지 않는 방식으로 서명합니다.

1. 업로드용 keystore를 준비합니다.
2. keystore 파일을 `apps/mobile/android/` 아래에 둡니다. 예: `upload-keystore.jks`
3. `apps/mobile/android/key.properties.example` 를 `apps/mobile/android/key.properties` 로 복사합니다.
4. 아래 값을 실제 값으로 채웁니다.
   - `storePassword`
   - `keyPassword`
   - `keyAlias`
   - `storeFile`
5. 서명된 아티팩트를 빌드합니다.
   - `flutter build appbundle --release --dart-define-from-file=.env.local`
   - 또는 `flutter build apk --release --dart-define-from-file=.env.local`
6. 실제 keystore 없이 로컬 검증만 필요하면 명시적으로 opt-in 합니다.
   - `ALLOW_DEBUG_SIGNED_RELEASE=true flutter build apk --release --dart-define-from-file=.env.local`

참고:
- `android/key.properties`, `*.jks`, `*.keystore` 는 git에 커밋하지 않습니다.
- `storeFile` 은 `apps/mobile/android/` 기준 경로입니다.
- release build는 기본적으로 signing 정보가 없으면 실패합니다.
- debug 서명 fallback은 `ALLOW_DEBUG_SIGNED_RELEASE=true` 를 명시한 로컬 검증에서만 허용하며, 이 결과물은 Play Console 업로드용으로 쓰면 안 됩니다.

## 검증

```bash
cd apps/mobile
flutter analyze
flutter test
dart run tool/release_readiness_audit.dart
```

`tool/release_readiness_audit.dart` 는 스토어 제출 전 점검이 필요한 항목을 빠르게 스캔합니다.
기본 실행은 리포트만 출력하고, `--strict` 를 붙이면 blocker 발견 시 종료 코드 1로 실패합니다.

## CI release gate

PR에서는 `.github/workflows/mobile-ci.yml` 이 아래를 수행합니다.

1. `flutter analyze --no-fatal-infos`
2. `flutter test --reporter expanded`
3. debug APK 빌드
4. 임시 Android keystore + `android/key.properties` 생성
5. release APK 빌드

실제 비밀값을 저장소에 넣지 않고도 release signing 경로가 깨지지 않았는지 CI에서 확인하기 위한 구성입니다.
