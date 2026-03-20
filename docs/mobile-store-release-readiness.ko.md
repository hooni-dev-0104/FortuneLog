# 모바일 스토어 출시 준비도 점검 (2026-03-21)

## 범위
- 대상: `apps/mobile` Flutter 앱
- 목적: App Store / Play Store 제출 전에 저장소 안에서 확인 가능한 릴리스 블로커와 남은 수동 작업을 분리해 기록

## 2026-03-21에 확인한 검증 결과
- `cd apps/mobile && flutter analyze` → **PASS** (`No issues found!`)
- `cd apps/mobile && flutter test` → **PASS** (7 tests passed)
- `scripts/check-mobile-release-readiness.sh` → **FAIL**
  - Android `applicationId` / `namespace`가 `com.example.fortune_log_mobile` placeholder 상태
  - Android release 빌드가 debug signing 사용
  - iOS/macOS bundle identifier가 `com.example.fortuneLogMobile` placeholder 상태
- `scripts/check-policy-links.sh` → **FAIL in this environment**
  - `https://fortunelog.app/terms`
  - `https://fortunelog.app/privacy`
  - `https://fortunelog.app/refund`
  - 위 세 URL 모두 현재 실행 환경에서 DNS resolve 실패 (`curl: (6) Could not resolve host`)로 확인됨

## 현재 확인된 출시 블로커

### 1. Android 패키지/서명 설정이 샘플 값 그대로 남아 있음
- `apps/mobile/android/app/build.gradle.kts:9` — `namespace = "com.example.fortune_log_mobile"`
- `apps/mobile/android/app/build.gradle.kts:25` — `applicationId = "com.example.fortune_log_mobile"`
- `apps/mobile/android/app/build.gradle.kts:37` — release build가 `signingConfigs.getByName("debug")` 사용
- `apps/mobile/android/app/src/main/kotlin/com/example/fortune_log_mobile/MainActivity.kt:1` — Kotlin package path도 placeholder namespace 기준

**의미**
- 실제 Play Store 업로드용 고유 패키지명이 아직 확정/반영되지 않았습니다.
- release keystore / Play App Signing 정리가 끝나기 전까지는 배포 아티팩트를 신뢰하기 어렵습니다.

### 2. iOS / macOS 번들 식별자가 샘플 값 그대로 남아 있음
- `apps/mobile/ios/Runner.xcodeproj/project.pbxproj:480`
- `apps/mobile/ios/Runner.xcodeproj/project.pbxproj:662`
- `apps/mobile/ios/Runner.xcodeproj/project.pbxproj:684`
- `apps/mobile/macos/Runner/Configs/AppInfo.xcconfig:11`

모두 `com.example.fortuneLogMobile` 계열 식별자를 사용 중입니다.

**의미**
- 실제 Apple Developer 식별자/프로비저닝 프로파일과 연결할 수 없습니다.
- App Store Connect 제출 전 bundle identifier 확정이 필요합니다.

### 3. 스토어용 공개 메타데이터가 저장소 기준으로 아직 미완성
- 저장소 내 문서에서는 정책/환불/탈퇴 흐름은 확인되지만, 스토어 등록용 **지원 URL / 지원 이메일 / 마케팅 카피 / 스크린샷 세트 / 연령 등급 응답 초안**은 아직 관리되지 않습니다.

**의미**
- 코드 품질과 별개로 스토어 입력 폼을 채울 운영 메타데이터가 부족합니다.
- 최소한 아래 항목은 별도 문서/비밀 저장소/스토어 콘솔에서 확정해야 합니다.
  - 지원 이메일 또는 지원 페이지 URL
  - 마케팅 설명문 / 키워드 / 프로모션 문구
  - 앱 아이콘/스크린샷/미리보기 영상
  - 연령 등급 / 데이터 수집 / 결제/구독 관련 제출 답변

### 4. 정책 링크는 코드에 연결되어 있지만 외부 가용성은 별도 확인 필요
- 앱 기본 정책 링크:
  - `apps/mobile/lib/main.dart:95`
  - `apps/mobile/lib/features/mypage/my_page.dart:25`
  - `apps/mobile/lib/features/mypage/my_page.dart:29`
  - `apps/mobile/lib/features/mypage/my_page.dart:33`
- 모니터링 스크립트/문서:
  - `scripts/check-policy-links.sh`
  - `docs/policy-link-monitoring.ko.md`

**의미**
- 정책/환불 링크를 앱에서 노출할 준비는 되어 있습니다.
- 다만 2026-03-21 현재 이 실행 환경에서는 `fortunelog.app` DNS 조회가 실패했으므로, 실제 배포 환경/CI/외부 네트워크에서 다시 검증해야 합니다.

## 이미 준비된 항목
- 정책 문서 화면(이용약관/개인정보/환불) 존재
  - `apps/mobile/lib/features/policy/policy_document_page.dart`
- 마이페이지에서 정책 화면 진입 및 회원 탈퇴 요청 진입 제공
  - `apps/mobile/lib/features/mypage/my_page.dart`
- 회원 탈퇴 운영 절차 문서 존재
  - `docs/account-deletion-runbook.ko.md`
- RevenueCat 베타 연동 문서 존재
  - `docs/revenuecat-beta-setup.ko.md`

## 권장 다음 단계
1. 실제 Android package name / iOS bundle identifier를 확정하고 플랫폼 설정 전체에 일괄 반영
2. Android release signing, Play App Signing, iOS signing/provisioning을 실제 배포 자격증명 기준으로 분리
3. 스토어 메타데이터 초안(지원 URL·이메일, 설명문, 스크린샷, 등급 답변)을 별도 문서로 고정
4. 외부 네트워크에서 `scripts/check-policy-links.sh`를 다시 실행해 공개 정책 URL 가용성 확인
5. 제출 직전 아래 명령으로 회귀 검증
   ```bash
   cd apps/mobile
   flutter analyze
   flutter test
   cd ../..
   scripts/check-mobile-release-readiness.sh --check-policy-links
   ```
