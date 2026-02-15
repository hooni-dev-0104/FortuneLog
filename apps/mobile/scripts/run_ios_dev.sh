#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

boot_ios_simulator_if_needed() {
  local device_name="$1"

  # Only handle iOS simulators when the user passed a human-friendly name.
  # If they pass an explicit UDID or "ios", Flutter can resolve it.
  if [[ "${device_name}" == "ios" ]]; then
    return 0
  fi
  if [[ "${device_name}" =~ ^[0-9A-Fa-f-]{36}$ ]]; then
    # Looks like a UDID.
    xcrun simctl boot "${device_name}" >/dev/null 2>&1 || true
    xcrun simctl bootstatus "${device_name}" -b >/dev/null 2>&1 || true
    return 0
  fi
  if [[ "${device_name}" != iPhone* && "${device_name}" != iPad* ]]; then
    return 0
  fi

  # Resolve the name to a UDID from available devices.
  local udid
  udid="$(
    xcrun simctl list devices available 2>/dev/null \
      | grep -F "    ${device_name} (" \
      | head -n 1 \
      | sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/'
  )"

  if [[ -z "${udid}" ]]; then
    echo "[warn] Could not find an available iOS simulator named '${device_name}'."
    echo "[info] Available devices:"
    xcrun simctl list devices available | sed -n '1,120p'
    return 0
  fi

  # Boot is idempotent.
  xcrun simctl boot "${udid}" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "${udid}" -b >/dev/null 2>&1 || true
}

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "[error] ${ENV_FILE} not found."
  echo "Copy .env.example to .env and fill SUPABASE_URL/SUPABASE_ANON_KEY/AUTH_REDIRECT_TO first."
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

# Validate required keys exist in the file (for dev ergonomics).
: "${SUPABASE_URL:?SUPABASE_URL is required in .env}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY is required in .env}"
: "${AUTH_REDIRECT_TO:?AUTH_REDIRECT_TO is required in .env}"

# Default to local engine-api for dev convenience.
ENGINE_BASE_URL="${ENGINE_BASE_URL:-http://127.0.0.1:8080}"

START_ENGINE=0
if [[ "${2:-}" == "--start-engine" ]]; then
  START_ENGINE=1
fi

if [[ "${START_ENGINE}" == "1" ]]; then
  # Start engine-api if it's not already responding.
  if ! curl -fsS "${ENGINE_BASE_URL}/engine/v1/health" >/dev/null 2>&1; then
    echo "[info] engine-api not reachable at ${ENGINE_BASE_URL}. Starting locally..."
    ENGINE_DIR="${ROOT_DIR}/../../services/engine-api"
    pushd "${ENGINE_DIR}" >/dev/null

    # Load engine-api env if present (needed for SUPABASE_JWKS_URL, etc).
    if [[ -f "${ENGINE_DIR}/.env" ]]; then
      set -a
      source "${ENGINE_DIR}/.env"
      set +a
    fi

    # Prefer Homebrew JDK 21 if available.
    if [[ -x "/opt/homebrew/opt/openjdk@21/bin/java" ]]; then
      export JAVA_HOME="/opt/homebrew/opt/openjdk@21"
    fi

    ./gradlew bootRun >/tmp/fortunelog_engine_api_bootrun.log 2>&1 &
    ENGINE_PID=$!
    popd >/dev/null

    # Ensure we don't leave it running when this script exits.
    trap 'kill ${ENGINE_PID} >/dev/null 2>&1 || true' EXIT

    # Wait up to ~30s for health endpoint.
    for _ in {1..30}; do
      if curl -fsS "${ENGINE_BASE_URL}/engine/v1/health" >/dev/null 2>&1; then
        echo "[info] engine-api is up."
        break
      fi
      sleep 1
    done
  fi
fi

cd "${ROOT_DIR}"
flutter pub get

DEVICE="${1:-ios}"
boot_ios_simulator_if_needed "${DEVICE}"

flutter run \
  -d "${DEVICE}" \
  --device-timeout 120 \
  --dart-define-from-file="${ENV_FILE}" \
  --dart-define=ENGINE_BASE_URL="${ENGINE_BASE_URL}"
