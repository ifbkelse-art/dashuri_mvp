#!/usr/bin/env bash
# Runs Go integration tests (build tag `integration`) against a throwaway
# Postgres with every migration applied. The API code connects as the
# least-privilege `api_service` role, exactly as in production, so missing
# grants or RLS policies fail the tests.
#
# Env exported to `go test`:
#   DASHURI_TEST_DATABASE_URL  api_service connection (what the code under test uses)
#   DASHURI_TEST_ADMIN_URL     superuser connection (fixtures only: auth.users, roles)
#
# Usage: ./scripts/test-backend-integration.sh [go test args...]   (default: ./...)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
PORT="${DASHURI_TEST_PG_PORT:-55433}"
trap 'pg_ctl -D "$TMP/data" stop -m fast >/dev/null 2>&1 || true; rm -rf "$TMP"' EXIT

initdb -D "$TMP/data" -U postgres -A trust >/dev/null
pg_ctl -D "$TMP/data" -o "-p $PORT -k $TMP -c listen_addresses=127.0.0.1 -c max_connections=200" -l "$TMP/log" start >/dev/null
for _ in $(seq 1 50); do pg_isready -h 127.0.0.1 -p "$PORT" >/dev/null 2>&1 && break; sleep 0.2; done

PSQL=(psql -h 127.0.0.1 -p "$PORT" -U postgres -d postgres -v ON_ERROR_STOP=1 -q -X)
"${PSQL[@]}" -f "$ROOT/supabase/tests/stubs.sql"
for f in "$ROOT"/supabase/migrations/*.sql; do "${PSQL[@]}" -f "$f"; done
"${PSQL[@]}" -c "alter role api_service login password 'test'; alter role worker_service login password 'test';"

export DASHURI_TEST_DATABASE_URL="postgres://api_service:test@127.0.0.1:$PORT/postgres?sslmode=disable"
export DASHURI_TEST_ADMIN_URL="postgres://postgres@127.0.0.1:$PORT/postgres?sslmode=disable"
cd "$ROOT/backend"
if [ $# -eq 0 ]; then set -- ./...; fi
go test -tags integration -count=1 -p 1 "$@"
