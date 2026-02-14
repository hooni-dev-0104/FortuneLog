#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "[error] ${ENV_FILE} not found."
  echo "Copy .env.example to .env and fill SUPABASE_URL/SUPABASE_ANON_KEY/AUTH_REDIRECT_TO first."
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

: "${SUPABASE_URL:?SUPABASE_URL is required in .env}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY is required in .env}"
: "${AUTH_REDIRECT_TO:?AUTH_REDIRECT_TO is required in .env}"
: "${ENGINE_BASE_URL:?ENGINE_BASE_URL is required in .env}"

cd "${ROOT_DIR}"
flutter pub get
flutter run \
  -d "${1:-ios}" \
  --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}" \
  --dart-define=AUTH_REDIRECT_TO="${AUTH_REDIRECT_TO}" \
  --dart-define=ENGINE_BASE_URL="${ENGINE_BASE_URL}"
