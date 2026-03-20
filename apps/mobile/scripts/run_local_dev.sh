#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env.local"

if ! command -v flutter >/dev/null 2>&1; then
  if [[ -x "${HOME}/sdk/flutter/bin/flutter" ]]; then
    export PATH="${HOME}/sdk/flutter/bin:${PATH}"
  else
    echo "[error] flutter not found in PATH or ~/sdk/flutter/bin."
    exit 1
  fi
fi

boot_ios_simulator_if_needed() {
  local device_name="$1"

  if [[ "${device_name}" == "ios" ]]; then
    return 0
  fi
  if [[ "${device_name}" =~ ^[0-9A-Fa-f-]{36}$ ]]; then
    xcrun simctl boot "${device_name}" >/dev/null 2>&1 || true
    xcrun simctl bootstatus "${device_name}" -b >/dev/null 2>&1 || true
    return 0
  fi
  if [[ "${device_name}" != iPhone* && "${device_name}" != iPad* ]]; then
    return 0
  fi

  local udid
  udid="$(
    xcrun simctl list devices available 2>/dev/null \
      | grep -F "    ${device_name} (" \
      | head -n 1 \
      | sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/'
  )"

  if [[ -z "${udid}" ]]; then
    echo "[warn] Could not find an available iOS simulator named '${device_name}'."
    xcrun simctl list devices available | sed -n '1,120p'
    return 0
  fi

  xcrun simctl boot "${udid}" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "${udid}" -b >/dev/null 2>&1 || true
}

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "[error] ${ENV_FILE} not found."
  echo "Create apps/mobile/.env.local with local-only SUPABASE_URL and SUPABASE_ANON_KEY."
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

: "${SUPABASE_URL:?SUPABASE_URL is required in .env.local}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY is required in .env.local}"

ENGINE_BASE_URL="${ENGINE_BASE_URL:-http://127.0.0.1:8080}"
DEVICE="${1:-chrome}"

cd "${ROOT_DIR}"
flutter pub get

boot_ios_simulator_if_needed "${DEVICE}"

flutter run \
  -d "${DEVICE}" \
  --device-timeout 120 \
  --dart-define-from-file="${ENV_FILE}" \
  --dart-define=ENGINE_BASE_URL="${ENGINE_BASE_URL}"
