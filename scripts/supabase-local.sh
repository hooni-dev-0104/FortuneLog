#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC_MIGRATIONS="$ROOT_DIR/infra/supabase/migrations"
DST_MIGRATIONS="$ROOT_DIR/supabase/migrations"

sync_migrations() {
  mkdir -p "$DST_MIGRATIONS"
  if compgen -G "$SRC_MIGRATIONS/*.sql" > /dev/null; then
    cp "$SRC_MIGRATIONS"/*.sql "$DST_MIGRATIONS"/
  fi
}

require_supabase_cli() {
  if command -v supabase >/dev/null 2>&1; then
    SUPABASE_BIN="supabase"
    return
  fi

  if [[ -x "$ROOT_DIR/.tools/bin/supabase" ]]; then
    SUPABASE_BIN="$ROOT_DIR/.tools/bin/supabase"
    return
  fi

  echo "supabase CLI is not installed."
  echo "Install: brew install supabase/tap/supabase"
  echo "Or install local binary at .tools/bin/supabase"
  exit 1
}

usage() {
  cat <<USAGE
Usage: scripts/supabase-local.sh <command>

Commands:
  start   Start local Supabase stack
  stop    Stop local Supabase stack
  reset   Reset local DB and re-apply migrations
  push    Push local migrations to linked project
  status  Show stack status
USAGE
}

main() {
  local SUPABASE_BIN=""
  local command="${1:-}"
  if [[ -z "$command" ]]; then
    usage
    exit 1
  fi

  require_supabase_cli
  sync_migrations

  cd "$ROOT_DIR"

  case "$command" in
    start)
      "$SUPABASE_BIN" start
      ;;
    stop)
      "$SUPABASE_BIN" stop
      ;;
    reset)
      "$SUPABASE_BIN" db reset
      ;;
    push)
      "$SUPABASE_BIN" db push
      ;;
    status)
      "$SUPABASE_BIN" status
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
