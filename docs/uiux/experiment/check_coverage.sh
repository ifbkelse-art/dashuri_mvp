#!/usr/bin/env bash
# Verifies the recovery kit is complete: every baseline file that changed is
# backed up (MODIFIED.txt), and every new file lies under a CREATED.txt path.
set -uo pipefail
K="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$K/../../.." && pwd)"; cd "$ROOT"
bad=0
while IFS= read -r line; do s="${line%%  *}"; f="${line#*  }"
  if [ ! -f "$f" ]; then grep -qxF "$f" "$K/DELETED.txt" || { echo "DELETED, NOT RECORDED $f"; bad=1; }; continue; fi
  [ "$(shasum -a 256 "$f" | cut -d' ' -f1)" = "$s" ] && continue
  grep -qxF "$f" "$K/MODIFIED.txt" || { echo "CHANGED, NOT BACKED UP $f"; bad=1; }
done < "$K/baseline_files.sha256"
find . -type f -not -path './.git/*' -not -path '*/build/*' -not -path '*/.dart_tool/*' -not -path '*/node_modules/*' \
  -not -path './docs/uiux/*' -not -name '.DS_Store' -not -path '*/.idea/*' -not -path '*/ios/Pods/*' -not -path '*/.gradle/*' \
  -not -path './design/Dashuri_Design.zip' | sed 's#^\./##' | while IFS= read -r f; do
  grep -qF "  $f" "$K/baseline_files.sha256" && continue
  ok=0; while IFS= read -r c; do [ -n "$c" ] && { [ "$f" = "$c" ] || [[ "$f" == "$c"/* ]]; } && ok=1; done < "$K/CREATED.txt"
  [ $ok = 1 ] || echo "NEW, NOT RECORDED $f"
done
[ $bad = 0 ] && echo "coverage check done"
