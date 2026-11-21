#!/usr/bin/env bash
# One-time setup after cloning. Safe to re-run.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v flutter >/dev/null || { echo "Install Flutter (stable)"; exit 1; }
command -v go >/dev/null || { echo "Install Go 1.25+"; exit 1; }
command -v melos >/dev/null || dart pub global activate melos

echo "== Dart/Flutter workspace =="
dart pub get
melos bootstrap

echo "== Go backend =="
(cd backend && go mod download)

echo "== App config =="
for env in development staging production; do
  f="apps/mobile/config/$env.json"
  [ -f "$f" ] || cp "apps/mobile/config/$env.example.json" "$f"
done
[ -f backend/.env ] || cp backend/.env.example backend/.env

echo "Done. Next: ./scripts/validate.sh"
