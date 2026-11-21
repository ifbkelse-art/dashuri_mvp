#!/usr/bin/env bash
# Applies supabase/migrations to a throwaway local Postgres (with stubs for
# Supabase-managed schemas) and runs the ledger invariant tests.
# Requires: initdb, pg_ctl, psql on PATH. Uses port 55432 and a temp dir.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
PORT=55432
trap 'pg_ctl -D "$TMP/data" stop -m fast >/dev/null 2>&1 || true; rm -rf "$TMP"' EXIT

initdb -D "$TMP/data" -U postgres -A trust >/dev/null
pg_ctl -D "$TMP/data" -o "-p $PORT -k $TMP" -l "$TMP/log" start >/dev/null
for _ in $(seq 1 30); do pg_isready -h "$TMP" -p $PORT >/dev/null 2>&1 && break; sleep 0.2; done

PSQL=(psql -h "$TMP" -p $PORT -U postgres -d postgres -v ON_ERROR_STOP=1 -q -X)
"${PSQL[@]}" -f "$ROOT/supabase/tests/stubs.sql"
for f in "$ROOT"/supabase/migrations/*.sql; do
  echo "apply $(basename "$f")"
  "${PSQL[@]}" -f "$f"
done
echo "--- invariants ---"
OUT="$("${PSQL[@]}" -t -A -f "$ROOT/supabase/tests/ledger_invariants.sql")"
echo "$OUT" | grep -E '^(PASS|FAIL)'
if echo "$OUT" | grep -q '^FAIL'; then echo "Some invariants FAILED"; exit 1; fi
echo "All migration invariants passed."
