#!/usr/bin/env bash
# Copies a file into experiment/backup/ BEFORE its first modification and
# records it in MODIFIED.txt. Run from the repo root: docs/reels/experiment/backup.sh <path>...
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"; E="$ROOT/docs/reels/experiment"
cd "$ROOT"
for f in "$@"; do
  if grep -qxF "$f" "$E/MODIFIED.txt" 2>/dev/null; then continue; fi
  [ -f "$f" ] || { echo "not a file: $f" >&2; exit 1; }
  mkdir -p "$E/backup/$(dirname "$f")"
  cp -p "$f" "$E/backup/$f"
  echo "$f" >> "$E/MODIFIED.txt"
  echo "backed up $f"
done
