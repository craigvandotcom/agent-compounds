#!/usr/bin/env bash
# dcg pack probe for neometa.localdbguard (tools/dcg/packs/neometa-local-db.yaml).
# A custom pack dcg cannot load is ignored silently, so this harness is the only proof the
# pack is live. It checks BOTH layers — the PreToolUse hook (the protection) and `dcg test`
# (the rule) — and both halves: resets are blocked, everyday Supabase commands are not.
# Fixtures go through a payload FILE, never the scanned command line.
#
# usage: bash local-db-pack-probe.sh [path-to-config.toml]
CFG="${1:-}"
DCG="$HOME/.local/bin/dcg"
[ -x "$DCG" ] || DCG="$(command -v dcg)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
# name|expect_hook|expect_test|command
CASES='
reset|BLOCK|BLOCK|supabase db reset
reset-npx|BLOCK|BLOCK|npx supabase db reset
reset-linked|BLOCK|BLOCK|npx supabase db reset --linked
reset-flag-first|BLOCK|BLOCK|supabase --workdir . db reset
pnpm-reset|BLOCK|BLOCK|pnpm db:reset
pnpm-verify|BLOCK|BLOCK|pnpm db:verify
npm-run-reset|BLOCK|BLOCK|npm run db:reset
migration-up|ALLOW|ALLOW|supabase migration up
migration-list|ALLOW|ALLOW|supabase migration list --linked
status|ALLOW|ALLOW|supabase status
integration|ALLOW|ALLOW|pnpm test:integration:local
db-types|ALLOW|ALLOW|pnpm db:types
'
pass=0; fail=0
printf '%-18s %-11s %-11s %s\n' NAME "HOOK(e/a)" "TEST(e/a)" RESULT
while IFS='|' read -r name expect_hook expect_test cmd; do
  [ -n "$name" ] || continue
  f="$TMP/$name.json"
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
    res=ok; pass=$((pass+1))
  else
    res=FAIL; fail=$((fail+1))
  fi
  printf '%-18s %-11s %-11s %s\n' "$name" "$expect_hook/$actual_hook" "$expect_test/$actual_test" "$res"
done <<< "$CASES"
printf 'denominator: %d cases · %d ok · %d FAIL\n' "$((pass+fail))" "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
