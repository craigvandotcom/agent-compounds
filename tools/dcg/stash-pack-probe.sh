#!/usr/bin/env bash
# dcg pack probe for neometa.stashguard — BOTH its rules, despite the historical
# filename: unscoped-stash-save and whole-tree-add (bd-ctlqg). Fixtures live in
# this FILE, never on the dcg-scanned command line — the matcher is string-based
# and fires on its own test payloads.
#
# This harness is the ONLY proof the pack is LIVE. dcg silently ignores a custom
# pack it cannot load, `dcg packs` does not list custom packs at all, and
# `dcg pack validate` passing says nothing about loading — an unloaded guard is
# indistinguishable from a passing one except through a real blocked/allowed probe.
# Both halves matter: the guard must bite on the dangerous forms AND must not
# over-block the safe ones (a solo agent staging its own full tree with an
# explicit pathspec must still work).
#
# TWO LAYERS, MEASURED SEPARATELY (bd-ctlqg, 2026-08-08). `dcg test` and the
# PreToolUse HOOK do not agree, and only the hook actually protects anything:
#
#   git rebase main   hook=BLOCK  test=BLOCK
#   git stash         hook=BLOCK  test=BLOCK
#   git add -A        hook=ALLOW  test=BLOCK   <-- UPSTREAM DEFECT, dcg 0.6.7
#
# The divergence is not ours and not a pack-loading failure: dcg's OWN built-in
# strict_git:add-all-flag rule behaves identically, while strict_git:rebase from
# the same pack blocks at the hook. On dcg 0.6.7 the hook path does not evaluate
# the `git add` verb at all, from any pack. So the whole-tree-add rule below is
# correct and inert — it starts protecting the moment upstream is fixed.
#
# Every case therefore pins BOTH columns to the CURRENTLY MEASURED truth. A case
# whose hook expectation is ALLOW-by-defect is marked `defect`. When upstream
# fixes it this harness goes RED on those rows — which is the point: that red is
# the signal to flip the expectation and finish bd-ctlqg's rung 3.
#
# usage: bash probe.sh [path-to-config.toml]
CFG="${1:-}"
DCG="$HOME/.local/bin/dcg"
TMP="$(dirname "$0")/fixtures"
mkdir -p "$TMP"

# name|expect_hook(BLOCK/ALLOW)|expect_test(BLOCK/ALLOW)|command
#   expect_hook — what the PreToolUse hook does. THIS is the protection.
#   expect_test — what `dcg test` reports. This is the rule's correctness.
CASES='
bare-stash|BLOCK|BLOCK|git stash
stash-u|BLOCK|BLOCK|git stash -u
stash-push|BLOCK|BLOCK|git stash push
stash-push-u|BLOCK|BLOCK|git stash push -u
stash-save|BLOCK|BLOCK|git stash save wip
scoped-push|ALLOW|ALLOW|git stash push -- lib/foo.ts
scoped-push-u|ALLOW|ALLOW|git stash push -u -- lib/foo.ts
stash-list|ALLOW|ALLOW|git stash list
stash-show|ALLOW|ALLOW|git stash show -p
stash-pop|ALLOW|ALLOW|git stash pop
stash-apply|ALLOW|ALLOW|git stash apply
control-status|ALLOW|ALLOW|git status
add-A|ALLOW|BLOCK|git add -A
add-all-long|ALLOW|BLOCK|git add --all
add-dot|ALLOW|BLOCK|git add .
add-u|ALLOW|BLOCK|git add -u
add-update-long|ALLOW|BLOCK|git add --update
add-A-with-C|ALLOW|BLOCK|git -C /repo add -A
add-v-then-A|ALLOW|BLOCK|git add -v -A
add-A-scoped|ALLOW|ALLOW|git add -A -- .
add-scoped-paths|ALLOW|ALLOW|git add -- lib/foo.ts lib/bar.ts
add-named-file|ALLOW|ALLOW|git add lib/foo.ts
add-relative-path|ALLOW|ALLOW|git add ./lib/foo.ts
add-patch|ALLOW|ALLOW|git add -p lib/foo.ts
control-commit|ALLOW|ALLOW|git commit -m wip
'

pass=0; fail=0; defect=0
printf '%-18s %-11s %-11s %s\n' NAME "HOOK(e/a)" "TEST(e/a)" RESULT
printf '%s\n' "----------------------------------------------------------------"
while IFS='|' read -r name expect_hook expect_test cmd; do
  [ -n "$name" ] || continue
  f="$TMP/$name.json"
  # build the payload with printf so the literal never hits a scanned cmdline
  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$cmd" > "$f"
  if [ -n "$CFG" ]; then
    hook_out="$(DCG_CONFIG="$CFG" "$DCG" < "$f" 2>&1)"
    test_out="$(DCG_CONFIG="$CFG" "$DCG" test "$cmd" 2>&1)"
  else
    hook_out="$("$DCG" < "$f" 2>&1)"
    test_out="$("$DCG" test "$cmd" 2>&1)"
  fi
  if printf '%s' "$hook_out" | grep -q "BLOCKED"; then actual_hook=BLOCK; else actual_hook=ALLOW; fi
  if printf '%s' "$test_out" | grep -q "Result: BLOCKED"; then actual_test=BLOCK; else actual_test=ALLOW; fi

  if [ "$actual_hook" = "$expect_hook" ] && [ "$actual_test" = "$expect_test" ]; then
    if [ "$expect_hook" != "$expect_test" ]; then res="ok(defect)"; defect=$((defect+1)); else res=ok; fi
    pass=$((pass+1))
  else
    res=FAIL; fail=$((fail+1))
  fi
  printf '%-18s %-11s %-11s %s\n' "$name" "$expect_hook/$actual_hook" "$expect_test/$actual_test" "$res"
done <<< "$CASES"

printf '%s\n' "----------------------------------------------------------------"
printf 'denominator: %d cases · %d ok · %d FAIL · %d pinned to the upstream hook defect\n' \
  "$((pass+fail))" "$pass" "$fail" "$defect"
if [ "$defect" -gt 0 ]; then
  printf '\n!! %d rule(s) are CORRECT under `dcg test` but INERT at the hook (dcg %s).\n' \
    "$defect" "$("$DCG" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  printf '   The whole-tree-add guard does NOT protect the shared checkout today.\n'
  printf '   Doctrine is the only live control: delegation-contract.md preamble + commit-discipline.md.\n'
fi
[ "$fail" -eq 0 ] || exit 1
