#!/usr/bin/env bash
# Restores dashuri_mvp to the state recorded in BASELINE.md (before the UI/UX
# pass), INCLUDING the uncommitted Reels experiment and docs/finance as they
# were. Uses no git.   restore.sh            dry run
#                      restore.sh --apply    restore, then verify every file by SHA-256
set -euo pipefail
K="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$K/../../.." && pwd)"; cd "$ROOT"
APPLY=0; [ "${1:-}" = "--apply" ] && APPLY=1
echo "== restore modified/deleted files from backup"
cat "$K/MODIFIED.txt" "$K/DELETED.txt" | while IFS= read -r f; do
  [ -n "$f" ] || continue; [ -f "$K/backup/$f" ] || { echo "MISSING BACKUP $f"; exit 1; }
  cmp -s "$K/backup/$f" "$f" 2>/dev/null && echo "  unchanged $f" || echo "  restore   $f"
  if [ $APPLY = 1 ]; then mkdir -p "$(dirname "$f")"; cp -p "$K/backup/$f" "$f"; fi
done
echo "== remove files created by the pass"
while IFS= read -r p; do
  [ -n "$p" ] || continue
  case "$p" in /*|*..*|docs/finance*|docs/uiux*) echo "refusing $p"; exit 1;; esac
  if [ -e "$p" ]; then echo "  remove    $p"; [ $APPLY = 1 ] && rm -rf -- "$p"; fi
done < "$K/CREATED.txt"
[ $APPLY = 1 ] || { echo "Dry run. Re-run with --apply."; exit 0; }
echo "== verify every baseline file"
bad=0
while IFS= read -r line; do s="${line%%  *}"; f="${line#*  }"
  [ -f "$f" ] || { echo "  MISSING $f"; bad=1; continue; }
  [ "$(shasum -a 256 "$f" | cut -d' ' -f1)" = "$s" ] || { echo "  DIFFERS $f"; bad=1; }
done < "$K/baseline_files.sha256"
[ $bad = 0 ] && echo "RESTORE VERIFIED: every file matches the UI/UX-pass baseline." || { echo "RESTORE INCOMPLETE"; exit 1; }
