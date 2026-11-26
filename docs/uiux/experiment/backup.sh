#!/usr/bin/env bash
# Copies files into docs/uiux/experiment/backup/ BEFORE their first change in
# the UI/UX pass and records them in MODIFIED.txt (or DELETED.txt with --delete).
# Run from anywhere: docs/uiux/experiment/backup.sh [--delete] <repo-relative path>...
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"; K="$ROOT/docs/uiux/experiment"; cd "$ROOT"
LIST="$K/MODIFIED.txt"; if [ "${1:-}" = "--delete" ]; then LIST="$K/DELETED.txt"; shift; fi
for f in "$@"; do
  grep -qxF "$f" "$K/MODIFIED.txt" "$K/DELETED.txt" 2>/dev/null && continue
  grep -qxF "$f" "$K/CREATED.txt" 2>/dev/null && continue   # created in this pass: nothing to back up
  [ -f "$f" ] || { echo "not a file: $f" >&2; exit 1; }
  mkdir -p "$K/backup/$(dirname "$f")"; cp -p "$f" "$K/backup/$f"; echo "$f" >> "$LIST"; echo "backed up $f"
done
