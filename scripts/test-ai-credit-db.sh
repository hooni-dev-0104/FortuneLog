#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Uses a disposable PostgreSQL container, no published ports, no credentials,
# and no Supabase project or production connection.
python3 infra/supabase/tests/ai_credit_transactions.py
