# FortuneLog Mobile

Flutter client for FortuneLog.

## Local development

1. Install dependencies: `flutter pub get`
2. Add app configuration to `.env`
3. Run the app: `flutter run --dart-define-from-file=.env`
4. Validate changes locally:
   - `flutter analyze --no-fatal-infos`
   - `flutter test --reporter expanded`

## Release identifiers

- Android application ID / namespace: `com.fortunelog.mobile`
- iOS bundle identifier: `com.fortunelog.mobile`
- macOS bundle identifier: `com.fortunelog.mobile`

## Android release signing

FortuneLog now supports a local, non-secret release signing setup for Android.

1. Generate or obtain the upload keystore that will be used for beta/release builds.
2. Save the keystore file under `apps/mobile/android/` (for example `upload-keystore.jks`).
3. Copy `apps/mobile/android/key.properties.example` to `apps/mobile/android/key.properties`.
4. Fill in the real values for:
   - `storePassword`
   - `keyPassword`
   - `keyAlias`
   - `storeFile`
5. Build a signed artifact:
   - `flutter build appbundle --release --dart-define-from-file=.env`
   - or `flutter build apk --release --dart-define-from-file=.env`
6. If you only need a local verification build without the real upload keystore, opt in explicitly:
   - `ALLOW_DEBUG_SIGNED_RELEASE=true flutter build apk --release --dart-define-from-file=.env`

Notes:
- `android/key.properties`, `*.jks`, and `*.keystore` are already gitignored.
- `storeFile` is resolved from `apps/mobile/android/`, so `storeFile=upload-keystore.jks` expects `apps/mobile/android/upload-keystore.jks`.
- Release builds fail by default when signing secrets are absent. The debug-signing fallback is available only when `ALLOW_DEBUG_SIGNED_RELEASE=true` is set for explicit local verification, and that output must not be used for Play Console beta/release uploads.

## CI release gate

Pull requests run `.github/workflows/mobile-ci.yml`, which:

1. installs Flutter dependencies,
2. runs `flutter analyze --no-fatal-infos`,
3. runs `flutter test --reporter expanded`,
4. builds a debug APK, and
5. creates an ephemeral Android keystore plus `android/key.properties` before building a release APK.

This keeps the release-signing path enforced in CI without committing real signing secrets to the repository.
