#!/usr/bin/env bash
# Every check CI should run. Fails on the first broken step.
set -euo pipefail
cd "$(dirname "$0")/.."

step() { echo; echo "== $* =="; }

step "Dart format";            melos run format:check
step "Static analysis";        dart analyze --fatal-infos apps packages tool
step "Dependency rules";       dart run tool/check_dependencies.dart
step "Dart & Flutter tests";   melos run test

step "Go format";              test -z "$(cd backend && gofmt -l .)" || { (cd backend && gofmt -l .); exit 1; }
step "Go vet";                 (cd backend && go vet ./...)
step "Go tests (race)";        (cd backend && go test -race -count=1 ./...)
step "Go build";               (cd backend && go build ./cmd/api ./cmd/worker)

if command -v initdb >/dev/null; then
  step "Database migrations";  ./scripts/validate-migrations.sh
else
  echo "(skipping migration validation: initdb/pg_ctl not on PATH)"
fi

echo; echo "All checks passed."
