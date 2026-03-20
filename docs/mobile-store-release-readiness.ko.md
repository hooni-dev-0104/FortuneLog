# 모바일 스토어 출시 준비도 점검 (2026-03-21 KST)

## 범위
- 대상: `apps/mobile` Flutter 앱
- 목적: App Store / Play Store 제출 전에 저장소 안에서 확인 가능한 릴리스 블로커와 남은 수동 작업을 분리해 기록

## 2026-03-21에 확인한 검증 결과
- `cd apps/mobile && flutter analyze` → **PASS** (`No issues found!`)
- `cd apps/mobile && flutter test` → **PASS** (**8 tests passed**)
- `scripts/check-mobile-release-readiness.sh` → **PASS with warnings**
  - Android / iOS / macOS placeholder 식별자 점검 통과
  - 정책 문서/회원 탈퇴 진입점 존재 확인
  - 단, Android release signing은 `android/key.properties`가 없으면 기본적으로 실패하도록 설계되어 있고
  - 로컬 검증에서만 `ALLOW_DEBUG_SIGNED_RELEASE=true` opt-in 시 debug-signed release를 허용하며
  - iOS `DEVELOPMENT_TEAM`은 아직 Runner.xcodeproj에 설정되지 않음
- `cd apps/mobile && ./scripts/check_store_readiness.sh` → **PASS with warnings**
  - 스토어 식별자/기본 릴리스 식별자 점검 통과
  - Android keystore 부재, iOS `DEVELOPMENT_TEAM` 미설정은 경고로 남아 있음
- `cd apps/mobile && dart run tool/release_readiness_audit.dart --strict` → **FAIL**
  - blocker: `ios_development_team_missing`
  - warning: `support_contact_missing`
  - pass: `policy_urls_present`, `store_icons_present`
- `scripts/check-policy-links.sh` → **FAIL in this environment**
  - `https://fortunelog.app/terms`
  - `https://fortunelog.app/privacy`
  - `https://fortunelog.app/refund`
  - 위 세 URL 모두 현재 실행 환경에서 DNS resolve 실패 (`curl: (6) Could not resolve host`)로 확인됨

## 현재 확인된 출시 블로커

### 1. iOS App Store 제출용 `DEVELOPMENT_TEAM`이 아직 설정되지 않음
- `apps/mobile/ios/Runner.xcodeproj/project.pbxproj`
- `cd apps/mobile && dart run tool/release_readiness_audit.dart --strict`가 `ios_development_team_missing` blocker를 계속 보고함

**의미**
- 실제 Apple Developer Team / signing 설정이 완료되기 전에는 App Store Connect용 archive/code signing을 신뢰할 수 없습니다.

**현재 운영 판단**
- 2026-03-21 기준 Apple Developer 등록이 아직 완료되지 않았으므로, 이 항목은 **즉시 해결해야 하는 개발 이슈가 아니라 추후 등록 완료 후 처리할 운영 이슈**로 기록합니다.
- 즉, 현재 단계에서는 known issue로 추적하되 **논이슈(non-issue for now)** 로 간주합니다.

### 2. Android release signing 자격증명이 저장소 밖에서 주입되어야 함
- `apps/mobile/android/app/build.gradle.kts`
- `apps/mobile/scripts/check_store_readiness.sh`
- `scripts/check-mobile-release-readiness.sh`

**의미**
- 현재 리포지토리 기준 식별자 자체는 `com.fortunelog.mobile`로 정리되었지만,
- `apps/mobile/android/key.properties`가 없으면 release build는 기본적으로 실패합니다.
- 예외적으로 로컬 검증에서만 `ALLOW_DEBUG_SIGNED_RELEASE=true` 를 준 경우 debug 서명 release가 허용됩니다.
- 즉, Play 업로드 전에는 실제 keystore / Play App Signing 연결이 별도로 필요합니다.

### 3. 스토어용 공개 메타데이터가 저장소 기준으로 아직 미완성
- 저장소 내 문서에서는 정책/환불/탈퇴 흐름은 확인되지만, 스토어 등록용 **지원 URL / 지원 이메일 / 마케팅 카피 / 스크린샷 세트 / 연령 등급 응답 초안**은 아직 관리되지 않습니다.
- 특히 `dart run tool/release_readiness_audit.dart --strict`는 `support_contact_missing` warning을 계속 보고합니다.

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

## 이번에 정리된 항목
- Android package / namespace는 `com.fortunelog.mobile`로 이미 정리되어 있음
- iOS Runner bundle identifier는 `com.fortunelog.mobile`로 정리되어 있음
- macOS AppInfo / RunnerTests bundle identifier placeholder를 `com.fortunelog.mobile` 기준으로 정리함
- 루트 릴리스 체크 스크립트가 현재 구조(Android Kotlin path, macOS RunnerTests, signing/team warnings)를 기준으로 동작하도록 정리됨

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
1. Apple Developer Team ID를 Runner target에 설정하고 `dart run tool/release_readiness_audit.dart --strict` blocker를 해소
2. Android release keystore / Play App Signing 입력을 완료해 debug-signing fallback 의존성을 제거
3. 지원 이메일 또는 지원 URL을 앱/스토어 메타데이터에 반영해 `support_contact_missing` warning을 해소
4. 외부 네트워크에서 `scripts/check-policy-links.sh`를 다시 실행해 공개 정책 URL 가용성 확인
5. 제출 직전 아래 명령으로 회귀 검증
   ```bash
   cd apps/mobile
   flutter analyze
   flutter test
   ./scripts/check_store_readiness.sh
   dart run tool/release_readiness_audit.dart --strict
   cd ../..
   scripts/check-mobile-release-readiness.sh --check-policy-links
   ```
