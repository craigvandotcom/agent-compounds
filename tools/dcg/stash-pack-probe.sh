#!/usr/bin/env bash
# dcg pack probe. Fixtures live in this FILE, never on the dcg-scanned command
# line — the matcher is string-based and fires on its own test payloads.
#
# usage: bash probe.sh [path-to-config.toml]
CFG="${1:-}"
DCG="$HOME/.local/bin/dcg"
TMP="$(dirname "$0")/fixtures"
mkdir -p "$TMP"

# name|expected(BLOCK/ALLOW)|command
CASES='
bare-stash|BLOCK|git stash
stash-u|BLOCK|git stash -u
stash-push|BLOCK|git stash push
stash-push-u|BLOCK|git stash push -u
stash-save|BLOCK|git stash save wip
scoped-push|ALLOW|git stash push -- lib/foo.ts
scoped-push-u|ALLOW|git stash push -u -- lib/foo.ts
stash-list|ALLOW|git stash list
stash-show|ALLOW|git stash show -p
stash-pop|ALLOW|git stash pop
stash-apply|ALLOW|git stash apply
control-status|ALLOW|git status
'

pass=0; fail=0
printf '%-16s %-7s %-7s %s\n' NAME EXPECT ACTUAL RESULT
printf '%s\n' "------------------------------------------------------"
while IFS='|' read -r name expect cmd; do
  [ -n "$name" ] || continue
  f="$TMP/$name.json"
  # build the payload with printf so the literal never hits a scanned cmdline
  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$cmd" > "$f"
  if [ -n "$CFG" ]; then
    out="$(DCG_CONFIG="$CFG" "$DCG" < "$f" 2>&1)"
  else
    out="$("$DCG" < "$f" 2>&1)"
  fi
  if printf '%s' "$out" | grep -q "BLOCKED"; then actual=BLOCK; else actual=ALLOW; fi
  if [ "$actual" = "$expect" ]; then res=ok; pass=$((pass+1)); else res=FAIL; fail=$((fail+1)); fi
  printf '%-16s %-7s %-7s %s\n' "$name" "$expect" "$actual" "$res"
done <<< "$CASES"

printf '%s\n' "------------------------------------------------------"
printf 'denominator: %d cases · %d ok · %d FAIL\n' "$((pass+fail))" "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
