#!/usr/bin/env bash
# Restores dashuri_mvp to the state recorded in BASELINE.md (before the
# Reels experiment). Does NOT use git (no checkout/reset/stash/clean).
#
#   docs/reels/experiment/restore.sh            # dry run: show what would change
#   docs/reels/experiment/restore.sh --apply    # restore files, then verify by SHA-256
#   docs/reels/experiment/restore.sh --apply --purge-docs   # also delete docs/reels
#
# 1. Copies every file listed in MODIFIED.txt back from backup/.
# 2. Deletes every path listed in CREATED.txt (files and directories the
#    experiment added).
# 3. Verifies every tracked file against tracked_files_at_baseline.sha256
#    and the pre-existing docs/finance files against BASELINE.md.
# Database: run drop_reels_schema.sql only on a database where you applied
# the Reels migration yourself (never production).
set -euo pipefail
E="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$E/../../.." && pwd)"
APPLY=0; PURGE=0
for a in "$@"; do case "$a" in --apply) APPLY=1;; --purge-docs) PURGE=1;; *) echo "unknown option $a"; exit 2;; esac; done
cd "$ROOT"
[ -f "$E/CREATED.txt" ] || { echo "CREATED.txt missing"; exit 1; }

echo "== Files restored from backup (modified by the experiment)"
while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ -f "$E/backup/$f" ] || { echo "MISSING BACKUP for $f"; exit 1; }
  if cmp -s "$E/backup/$f" "$f" 2>/dev/null; then echo "  unchanged  $f"; else echo "  restore    $f"; fi
  [ $APPLY = 1 ] && cp -p "$E/backup/$f" "$f"
done < "$E/MODIFIED.txt"

echo "== Paths removed (created by the experiment)"
while IFS= read -r p; do
  [ -n "$p" ] || continue
  case "$p" in /*|*..*|docs/finance*|"") echo "refusing unsafe path: $p"; exit 1;; esac
  if [ -e "$p" ]; then echo "  remove     $p"; [ $APPLY = 1 ] && rm -rf -- "$p"; else echo "  absent     $p"; fi
done < "$E/CREATED.txt"

if [ $APPLY = 0 ]; then echo; echo "Dry run only. Re-run with --apply."; exit 0; fi

echo "== Verifying tracked files (SHA-256 vs baseline)"
bad=0
while IFS= read -r line; do
  sum="${line%%  *}"; f="${line#*  }"
  if [ ! -f "$f" ]; then echo "  MISSING  $f"; bad=1; continue; fi
  now="$(shasum -a 256 "$f" | cut -d' ' -f1)"
  [ "$now" = "$sum" ] || { echo "  DIFFERS  $f"; bad=1; }
done < "$E/tracked_files_at_baseline.sha256"
echo "== Verifying pre-existing docs/finance work"
sed -n '/^## Pre-existing untracked work/,$p' "$E/BASELINE.md" | grep -E '^[0-9a-f]{64}  ' | while IFS= read -r line; do
  sum="${line%%  *}"; f="${line#*  }"
  now="$(shasum -a 256 "$f" 2>/dev/null | cut -d' ' -f1)"
  [ "$now" = "$sum" ] || { echo "  DIFFERS  $f"; exit 3; }
done || bad=1
if [ $bad = 0 ]; then echo "RESTORE VERIFIED: every tracked file and docs/finance file matches the baseline."; else echo "RESTORE INCOMPLETE — see above."; exit 1; fi
if [ $PURGE = 1 ]; then rm -rf -- "$ROOT/docs/reels"; echo "docs/reels removed."; fi
echo "Next: run 'flutter pub get' at the repo root to refresh .dart_tool (feature_reels is gone)."
