# fortune_log_mobile

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

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

Notes:
- `android/key.properties`, `*.jks`, and `*.keystore` are already gitignored.
- If `android/key.properties` is absent, release builds fall back to the debug signing key so local verification can still run, but that output should not be used for Play Console beta/release uploads.
