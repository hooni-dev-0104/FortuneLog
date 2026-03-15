#!/usr/bin/env bash
set -euo pipefail

DEFAULT_TERMS_URL="${POLICY_TERMS_URL:-https://fortunelog.app/terms}"
DEFAULT_PRIVACY_URL="${POLICY_PRIVACY_URL:-https://fortunelog.app/privacy}"
DEFAULT_REFUND_URL="${POLICY_REFUND_URL:-https://fortunelog.app/refund}"
CONNECT_TIMEOUT="${POLICY_LINK_CONNECT_TIMEOUT:-10}"
MAX_TIME="${POLICY_LINK_MAX_TIME:-30}"
USER_AGENT="${POLICY_LINK_USER_AGENT:-FortuneLogPolicyMonitor/1.0}"

usage() {
  cat <<USAGE
Usage: scripts/check-policy-links.sh [options]

Checks that policy URLs return a healthy HTTP status (2xx/3xx).

Options:
  --url <name>=<url>         Check a custom URL. Repeatable.
  --connect-timeout <sec>    Override curl connect timeout (default: ${CONNECT_TIMEOUT})
  --max-time <sec>           Override curl total timeout (default: ${MAX_TIME})
  -h, --help                 Show this help message

Environment overrides:
  POLICY_TERMS_URL
  POLICY_PRIVACY_URL
  POLICY_REFUND_URL
  POLICY_LINK_CONNECT_TIMEOUT
  POLICY_LINK_MAX_TIME
  POLICY_LINK_USER_AGENT

Examples:
  scripts/check-policy-links.sh
  scripts/check-policy-links.sh --url staging-terms=https://staging.fortunelog.app/terms
USAGE
}

parse_named_url() {
  local raw="$1"
  if [[ "$raw" != *=* ]]; then
    echo "Invalid --url value: $raw" >&2
    echo "Expected format: <name>=<url>" >&2
    exit 1
  fi

  local name="${raw%%=*}"
  local url="${raw#*=}"

  if [[ -z "$name" || -z "$url" ]]; then
    echo "Invalid --url value: $raw" >&2
    echo "Expected non-empty <name> and <url>" >&2
    exit 1
  fi

  printf '%s|%s\n' "$name" "$url"
}

check_url() {
  local name="$1"
  local url="$2"
  local output
  local curl_status=0

  output="$(curl \
    --silent \
    --show-error \
    --location \
    --output /dev/null \
    --connect-timeout "$CONNECT_TIMEOUT" \
    --max-time "$MAX_TIME" \
    --user-agent "$USER_AGENT" \
    --write-out '%{http_code}|%{url_effective}|%{num_redirects}' \
    "$url" 2>&1)" || curl_status=$?

  if [[ $curl_status -ne 0 ]]; then
    printf 'FAIL %-10s curl_exit=%s url=%s details=%s\n' "$name" "$curl_status" "$url" "$output"
    return 1
  fi

  local http_code effective_url redirects
  IFS='|' read -r http_code effective_url redirects <<< "$output"

  if [[ "$http_code" =~ ^[23][0-9][0-9]$ ]]; then
    printf 'PASS %-10s status=%s redirects=%s final=%s\n' "$name" "$http_code" "$redirects" "$effective_url"
    return 0
  fi

  printf 'FAIL %-10s status=%s redirects=%s final=%s\n' "$name" "$http_code" "$redirects" "$effective_url"
  return 1
}

main() {
  local -a links=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --url)
        if [[ $# -lt 2 ]]; then
          echo "Missing value for --url" >&2
          usage
          exit 1
        fi
        links+=("$(parse_named_url "$2")")
        shift 2
        ;;
      --connect-timeout)
        if [[ $# -lt 2 ]]; then
          echo "Missing value for --connect-timeout" >&2
          usage
          exit 1
        fi
        CONNECT_TIMEOUT="$2"
        shift 2
        ;;
      --max-time)
        if [[ $# -lt 2 ]]; then
          echo "Missing value for --max-time" >&2
          usage
          exit 1
        fi
        MAX_TIME="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $1" >&2
        usage
        exit 1
        ;;
    esac
  done

  if [[ ${#links[@]} -eq 0 ]]; then
    links=(
      "terms|$DEFAULT_TERMS_URL"
      "privacy|$DEFAULT_PRIVACY_URL"
      "refund|$DEFAULT_REFUND_URL"
    )
  fi

  printf 'Policy link check started at %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf 'Using connect_timeout=%ss max_time=%ss\n' "$CONNECT_TIMEOUT" "$MAX_TIME"

  local failed=0
  local pair name url
  for pair in "${links[@]}"; do
    IFS='|' read -r name url <<< "$pair"
    if ! check_url "$name" "$url"; then
      failed=1
    fi
  done

  if [[ $failed -ne 0 ]]; then
    echo 'Policy link check failed.' >&2
    exit 1
  fi

  echo 'Policy link check passed.'
}

main "$@"
