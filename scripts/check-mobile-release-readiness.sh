#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK_POLICY_LINKS=0

usage() {
  cat <<USAGE
Usage: scripts/check-mobile-release-readiness.sh [--check-policy-links]

Runs repo-local release readiness checks for apps/mobile.

Checks:
  - placeholder Android/iOS/macOS package identifiers
  - Android release signing still bound to debug config
  - placeholder Android package path / pubspec description
  - required public-policy/account-deletion documentation presence
  - in-app policy / account deletion entrypoints presence

Options:
  --check-policy-links   Also run scripts/check-policy-links.sh (network-dependent)
  -h, --help             Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-policy-links)
      CHECK_POLICY_LINKS=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

failures=0

pass() {
  printf 'PASS %s\n' "$1"
}

fail() {
  printf 'FAIL %s\n' "$1"
  failures=1
}

contains() {
  local file="$1"
  local pattern="$2"
  rg -n --fixed-strings --quiet "$pattern" "$file"
}

check_absent() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if contains "$file" "$pattern"; then
    fail "$label"
  else
    pass "$label"
  fi
}

check_present() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if contains "$file" "$pattern"; then
    pass "$label"
  else
    fail "$label"
  fi
}

cd "$ROOT_DIR"

echo "Mobile release readiness check started at $(date -u '+%Y-%m-%dT%H:%M:%SZ')"

check_absent "apps/mobile/android/app/build.gradle.kts" 'namespace = "com.example.fortune_log_mobile"' 'android namespace is not left on com.example placeholder'
check_absent "apps/mobile/android/app/build.gradle.kts" 'applicationId = "com.example.fortune_log_mobile"' 'android applicationId is not left on com.example placeholder'
check_absent "apps/mobile/android/app/build.gradle.kts" 'signingConfig = signingConfigs.getByName("debug")' 'android release build is not signed with debug config'
check_absent "apps/mobile/android/app/src/main/kotlin/com/example/fortune_log_mobile/MainActivity.kt" 'package com.example.fortune_log_mobile' 'android MainActivity package is not left on com.example placeholder'
check_absent "apps/mobile/ios/Runner.xcodeproj/project.pbxproj" 'PRODUCT_BUNDLE_IDENTIFIER = com.example.fortuneLogMobile;' 'ios Runner bundle identifier is not left on com.example placeholder'
check_absent "apps/mobile/macos/Runner/Configs/AppInfo.xcconfig" 'PRODUCT_BUNDLE_IDENTIFIER = com.example.fortuneLogMobile' 'macOS bundle identifier is not left on com.example placeholder'
check_absent "apps/mobile/pubspec.yaml" 'description: FortuneLog mobile app (dev test shell)' 'pubspec description no longer uses dev test shell placeholder'
check_present "apps/mobile/lib/features/policy/policy_document_page.dart" 'case PolicyDocumentType.terms:' 'in-app terms document exists'
check_present "apps/mobile/lib/features/policy/policy_document_page.dart" 'case PolicyDocumentType.privacy:' 'in-app privacy document exists'
check_present "apps/mobile/lib/features/policy/policy_document_page.dart" 'case PolicyDocumentType.refund:' 'in-app refund document exists'
check_present "apps/mobile/lib/features/mypage/my_page.dart" '회원 탈퇴 요청' 'account deletion entry point exists in app UI'
check_present "docs/policy-link-monitoring.ko.md" 'https://fortunelog.app/privacy' 'policy link monitoring doc exists'
check_present "docs/account-deletion-runbook.ko.md" 'POST /engine/v1/accounts:deletion-request' 'account deletion runbook exists'

if [[ $CHECK_POLICY_LINKS -eq 1 ]]; then
  if scripts/check-policy-links.sh; then
    pass 'public policy URLs responded successfully'
  else
    fail 'public policy URLs responded successfully'
  fi
else
  echo 'INFO skipped network policy link check (pass --check-policy-links to enable)'
fi

if [[ $failures -ne 0 ]]; then
  echo 'Mobile release readiness check failed.' >&2
  exit 1
fi

echo 'Mobile release readiness check passed.'
