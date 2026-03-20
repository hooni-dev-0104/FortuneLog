#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_BUILD="$ROOT_DIR/android/app/build.gradle.kts"
ANDROID_ACTIVITY="$ROOT_DIR/android/app/src/main/kotlin/com/fortunelog/mobile/MainActivity.kt"
IOS_PROJECT="$ROOT_DIR/ios/Runner.xcodeproj/project.pbxproj"
EXPECTED_ID="com.fortunelog.mobile"

failures=0
warnings=0

pass() {
  printf 'PASS %s\n' "$1"
}

warn() {
  warnings=$((warnings + 1))
  printf 'WARN %s\n' "$1"
}

fail() {
  failures=$((failures + 1))
  printf 'FAIL %s\n' "$1"
}

check_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"

  if grep -Fq "$needle" "$file"; then
    pass "$label"
  else
    fail "$label (missing: $needle in ${file#$ROOT_DIR/})"
  fi
}

check_absent() {
  local file="$1"
  local needle="$2"
  local label="$3"

  if grep -Fq "$needle" "$file"; then
    fail "$label (found forbidden value: $needle in ${file#$ROOT_DIR/})"
  else
    pass "$label"
  fi
}

check_contains "$ANDROID_BUILD" 'namespace = "com.fortunelog.mobile"' 'Android namespace uses release identifier'
check_contains "$ANDROID_BUILD" 'applicationId = "com.fortunelog.mobile"' 'Android applicationId uses release identifier'
check_absent "$ANDROID_BUILD" 'com.example' 'Android config no longer uses example identifiers'
check_contains "$ANDROID_ACTIVITY" 'package com.fortunelog.mobile' 'Android MainActivity package matches namespace'
check_contains "$IOS_PROJECT" 'PRODUCT_BUNDLE_IDENTIFIER = com.fortunelog.mobile;' 'iOS Runner bundle identifier uses release identifier'
check_contains "$IOS_PROJECT" 'PRODUCT_BUNDLE_IDENTIFIER = com.fortunelog.mobile.RunnerTests;' 'iOS RunnerTests bundle identifier uses release identifier'
check_absent "$IOS_PROJECT" 'com.example.fortuneLogMobile' 'iOS project no longer uses example identifiers'

if grep -Fq 'create("release")' "$ANDROID_BUILD"; then
  pass 'Android release signing hook is wired for key.properties'
else
  fail 'Android release signing hook missing from build.gradle.kts'
fi

if [[ -f "$ROOT_DIR/android/key.properties" ]]; then
  pass 'android/key.properties is present for release signing'
else
  warn 'android/key.properties is missing; release builds will keep using debug signing until the keystore is supplied'
fi

if grep -Fq 'DEVELOPMENT_TEAM =' "$IOS_PROJECT"; then
  pass 'iOS DEVELOPMENT_TEAM is configured'
else
  warn 'iOS DEVELOPMENT_TEAM is not configured in Runner.xcodeproj; Apple signing must be set before App Store upload'
fi

if [[ -x "$ROOT_DIR/../scripts/check-policy-links.sh" ]]; then
  :
fi

printf 'SUMMARY failures=%s warnings=%s expected_id=%s\n' "$failures" "$warnings" "$EXPECTED_ID"

if (( failures > 0 )); then
  exit 1
fi
