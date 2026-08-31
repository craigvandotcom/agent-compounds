#!/usr/bin/env bash
# element4-check.test.sh — fixture tests for element4-check.sh and stamp-refined.sh.
#
# Both polarities, always: a check that always FAILS satisfies a one-sided test, and a
# header-presence grep satisfies a test that never feeds it an empty section.
# Run directly:  bash skills/_tools/element4-check.test.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
CHECK="$DIR/element4-check.sh"
STAMP="$DIR/stamp-refined.sh"

FAILURES=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

# A well-formed body minus element 4 — the shape bd-qxp8l shipped in.
BODY_COMMON='## Anchors
- `lib/x.ts` :: unique string `foo`

## Baselines
    $ grep -c foo lib/x.ts
    1

## Territory
- lib/x.ts

## Acceptance Criteria
- [ ] foo is bar.
'

write_fx() { printf '%s' "$2" >"$WORK/$1"; }

# --- Case 1: NO `## Declared RED` header -> non-zero -------------------------
write_fx missing.md "$BODY_COMMON"
OUT=$(bash "$CHECK" --file "$WORK/missing.md" 2>&1); RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "no '## Declared RED' header"; then
  pass "Case 1: description with no '## Declared RED' header is REJECTED (exit 1)"
else
  fail "Case 1: expected exit 1 naming the missing header, got $RC. Output: $OUT"
fi

# --- Case 2: a real Declared RED -> exit 0 -----------------------------------
write_fx present.md "$BODY_COMMON
## Declared RED
Test \`nng > already-pushed growth is still scored\` must FAIL before the fix, with
approximately: assert \`violations\` equals 1; today it returns 0.
"
OUT=$(bash "$CHECK" --file "$WORK/present.md" 2>&1); RC=$?
if [ "$RC" -eq 0 ]; then
  pass "Case 2: description WITH a populated '## Declared RED' is ACCEPTED (exit 0)"
else
  fail "Case 2: expected exit 0, got $RC. Output: $OUT"
fi

# --- Case 3: sanctioned `RED: n/a — <why>` -> exit 0 -------------------------
# Blocking this would push authors to fabricate REDs, which is worse than omitting one.
write_fx na.md "$BODY_COMMON
## Declared RED
RED: n/a — comment-only delivery; no executable assertion can change state.
"
OUT=$(bash "$CHECK" --file "$WORK/na.md" 2>&1); RC=$?
if [ "$RC" -eq 0 ]; then
  pass "Case 3: 'RED: n/a — <why>' is ACCEPTED (exit 0)"
else
  fail "Case 3: expected exit 0, got $RC. Output: $OUT"
fi

# --- Case 4: header present, section EMPTY -> non-zero -----------------------
# This is what separates the check from a header-presence grep.
write_fx empty.md "## Declared RED

## Sequence + risk
1 of 1.
"
OUT=$(bash "$CHECK" --file "$WORK/empty.md" 2>&1); RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "is EMPTY"; then
  pass "Case 4: '## Declared RED' header with an EMPTY section is REJECTED (exit 1)"
else
  fail "Case 4: expected exit 1 naming the empty section, got $RC. Output: $OUT"
fi

# --- Case 5: bare `RED: n/a` with no reason -> non-zero ----------------------
write_fx nabare.md "## Declared RED
RED: n/a
"
OUT=$(bash "$CHECK" --file "$WORK/nabare.md" 2>&1); RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "no reason"; then
  pass "Case 5: 'RED: n/a' with no stated reason is REJECTED (exit 1)"
else
  fail "Case 5: expected exit 1, got $RC. Output: $OUT"
fi

# --- Case 6: exempt issue types skip the check ------------------------------
write_fx exempt.md "$BODY_COMMON"
OUT=$(bash "$CHECK" --file "$WORK/exempt.md" --type epic 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "SKIP"; then
  pass "Case 6: an exempt issue_type (epic) skips the check (exit 0)"
else
  fail "Case 6: expected exit 0 with SKIP, got $RC. Output: $OUT"
fi

# ============================================================================
# Cases 7-8: the GUARDED STAMP PATH. The label write lives inside stamp_refined
# and cannot run without the check running first.
# ============================================================================
MOCK="$WORK/bin"; mkdir -p "$MOCK"
BR_LOG="$WORK/br.log"
FIXTURE_BEADS="$WORK/beads.json"; export FIXTURE_BEADS BR_LOG
cat >"$MOCK/br" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$BR_LOG"
if [ "$1" = "show" ]; then
  shift
  ids=()
  while [ $# -gt 0 ]; do case "$1" in --json) shift ;; *) ids+=("$1"); shift ;; esac; done
  want=$(printf '%s\n' "${ids[@]}" | jq -R . | jq -s .)
  out=$(jq --argjson want "$want" '[ .[] | select(.id as $i | $want | index($i)) ]' "$FIXTURE_BEADS")
  [ "$(printf '%s' "$out" | jq 'length')" -gt 0 ] && { printf '%s\n' "$out"; exit 0; }
  echo '{"error":{"code":"ISSUE_NOT_FOUND"}}'
fi
exit 0
EOF
chmod +x "$MOCK/br"

RED_OK='## Declared RED\nTest `x` must FAIL before the fix; assert exit 1.\n'
RED_PROBED='## Declared RED\nTest `x` must FAIL before the fix; assert exit 1.\n\n## Acceptance Criteria\n- The fix lands.\n  Probe: `grep -q "the fix" src/x.ts` — tier: none\n'
jq -n --arg red "$(printf "$RED_OK")" --arg redp "$(printf "$RED_PROBED")" '[
  {id:"bd-good", issue_type:"bug", description:$red},
  {id:"bd-good-probed", issue_type:"bug", description:$redp},
  {id:"bd-bad",  issue_type:"bug", description:"## Anchors\nnone\n"}
]' >"$FIXTURE_BEADS"

# --- Case 7: stamp_refined REFUSES a bead with no Declared RED, writes NO label ---
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-bad 2>&1); RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "REFUSED bd-bad" \
   && ! grep -q 'label add bd-bad refined' "$BR_LOG"; then
  pass "Case 7: stamp_refined REFUSES bd-bad and writes NO 'refined' label"
else
  fail "Case 7: expected refusal with no label write, got $RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

# --- Case 8: a Declared RED WITHOUT a probe is refused — the 2026-08-29 floor --------
# (updated from "full stamp": since ac53c1c a refined bead must be probe-bearing, and a
# prose Declared RED alone is exactly the legacy dialect that stamped zero-probe beads)
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" REFINE_PATH=refine-full bash "$STAMP" bd-good 2>&1); RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -qi "probe" \
   && ! grep -q 'label add bd-good refined' "$BR_LOG"; then
  pass "Case 8: a Declared RED with no Probe: line is REFUSED (probe floor) — no label written"
else
  fail "Case 8: expected probe-floor refusal with no label write, got $RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

# --- Case 8b: a probed Declared-RED bead stamps (element 4 via legacy shape + floor) --
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" REFINE_PATH=refine-full bash "$STAMP" bd-good-probed 2>&1); RC=$?
if [ "$RC" -eq 0 ] && grep -q 'label add bd-good-probed refined' "$BR_LOG" \
   && grep -q 'label add bd-good-probed refine-full' "$BR_LOG"; then
  pass "Case 8b: a probed Declared-RED bead STAMPS (remove unrefined + add refined + path label)"
else
  fail "Case 8b: expected a full stamp, got $RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

# ============================================================================
# Cases 9-10: stamp-refined.sh under ZSH — the fleet's default shell.
# zsh populates no BASH_SOURCE. A bash-only self-read resolves against $PWD, which
# refuses every bead when sourced and exits 0 writing nothing when executed.
# Both cases run both polarities: the fixed script AND a mutant forced onto the
# bash-only branch, which must fail. A case that only ever passes is not evidence.
# ============================================================================
if ! command -v zsh >/dev/null 2>&1; then
  fail "Cases 9-10: zsh not installed — the zsh contract is UNPROVEN on this host"
else
  FIXED="$WORK/fixed"; MUTANT="$WORK/mutant"; mkdir -p "$FIXED" "$MUTANT"
  cp "$STAMP" "$FIXED/stamp-refined.sh"; cp "$CHECK" "$FIXED/element4-check.sh"
  cp "$CHECK" "$MUTANT/element4-check.sh"
  # The mutation: force the ZSH_VERSION sentinel false so both self-reads fall back to
  # the bash-only branch — exactly the pre-fix script.
  sed 's/\[ -n "${ZSH_VERSION:-}" \]/false/g' "$STAMP" >"$MUTANT/stamp-refined.sh"

  # The mutation must actually bite, or the negative controls below are vacuous.
  if [ "$(grep -c '^if false; then' "$MUTANT/stamp-refined.sh")" -eq 2 ]; then
    pass "Case 9a: the negative-control mutation applied (both zsh branches disabled)"
  else
    fail "Case 9a: mutation did not apply — the ZSH_VERSION sentinel moved; Cases 9b-10b are vacuous"
  fi

  # --- Case 9: SOURCED under zsh from a foreign cwd resolves its OWN sibling ---
  ask_sourced() {  # $1 = dir holding the script; echoes the resolved ELEMENT4_CHECK
    zsh -f -c "cd /; unset ELEMENT4_CHECK; . '$1/stamp-refined.sh'; printf '%s' \"\$ELEMENT4_CHECK\""
  }
  GOT=$(ask_sourced "$FIXED")
  if [ "$GOT" = "$FIXED/element4-check.sh" ]; then
    pass "Case 9b: zsh-sourced from a foreign cwd resolves ELEMENT4_CHECK to its own sibling"
  else
    fail "Case 9b: expected '$FIXED/element4-check.sh', got '$GOT'"
  fi

  GOT=$(ask_sourced "$MUTANT")
  if [ "$GOT" != "$MUTANT/element4-check.sh" ]; then
    pass "Case 9c: NEGATIVE CONTROL — the bash-only read misresolves under zsh (got '$GOT')"
  else
    fail "Case 9c: negative control did not go RED — the mutant resolved correctly"
  fi

  # --- Case 10: EXECUTED under zsh refuses loudly instead of exiting 0 silently ---
  : >"$BR_LOG"
  OUT=$(cd / && PATH="$MOCK:$PATH" zsh -f "$FIXED/stamp-refined.sh" bd-bad 2>&1); RC=$?
  if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "REFUSED bd-bad" \
     && ! grep -q 'label add bd-bad refined' "$BR_LOG"; then
    pass "Case 10a: 'zsh <script> bd-bad' REFUSES like bash does, writing no label"
  else
    fail "Case 10a: expected a loud refusal, got rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
  fi

  : >"$BR_LOG"
  OUT=$(cd / && PATH="$MOCK:$PATH" zsh -f "$MUTANT/stamp-refined.sh" bd-bad 2>&1); RC=$?
  if [ "$RC" -eq 0 ] && [ -z "$OUT" ]; then
    pass "Case 10b: NEGATIVE CONTROL — the bash-only guard exits 0 silently under zsh"
  else
    fail "Case 10b: negative control did not go RED — mutant rc=$RC, output: $OUT"
  fi

  # --- Case 10c: sourcing must still NOT run the argument loop, under either shell ---
  : >"$BR_LOG"
  for SH in bash zsh; do
    OUT=$($SH -f -c "cd /; PATH='$MOCK:\$PATH'; . '$FIXED/stamp-refined.sh' bd-bad" 2>&1 || true)
    if echo "$OUT" | grep -q "REFUSED bd-bad"; then
      fail "Case 10c ($SH): sourcing ran the argument loop — the direct-invocation guard is inverted"
    else
      pass "Case 10c ($SH): sourcing defines the function without consuming its arguments"
    fi
  done
fi

# --- RED-vs-Territory (friction: declared-red-not-reconciled-against-territory...) -----
# Both polarities: a check that always FAILS would satisfy Case 11 alone.

TERR_BODY='## Anchors
- `lib/x.ts` :: unique string `foo`

## Baselines
    $ grep -c foo lib/x.ts
    1

## Territory
- lib/x.ts
- features/a/a.test.ts

## Acceptance Criteria
- [ ] foo is bar.
'

# --- Case 11: RED names a TEST file absent from Territory -> REJECTED (bd-9uszd shape) --
write_fx red-terr-bad.md "$TERR_BODY
## Declared RED
Test in \`features/b/b.test.ts\` must FAIL before the fix, with approximately: assert
\`violations\` equals 1.
"
OUT=$(bash "$CHECK" --file "$WORK/red-terr-bad.md" 2>&1); RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "features/b/b.test.ts"; then
  pass "Case 11: RED naming a test file OUTSIDE ## Territory is REJECTED (exit 1)"
else
  fail "Case 11: expected exit 1 naming the out-of-territory test file, got $RC. Output: $OUT"
fi

# --- Case 12: RED names a test file that IS in Territory -> ACCEPTED -------------------
write_fx red-terr-ok.md "$TERR_BODY
## Declared RED
Test in \`features/a/a.test.ts\` must FAIL before the fix, with approximately: assert
\`violations\` equals 1.
"
OUT=$(bash "$CHECK" --file "$WORK/red-terr-ok.md" 2>&1); RC=$?
if [ "$RC" -eq 0 ]; then
  pass "Case 12: RED naming a test file INSIDE ## Territory is ACCEPTED (exit 0)"
else
  fail "Case 12: expected exit 0, got $RC. Output: $OUT"
fi

# --- Case 13: RED cites a NON-test source file outside Territory -> WARN, not FAIL -----
# A RED legitimately asserts ABOUT a file it never edits. Narrow the FAIL or it over-rejects.
write_fx red-terr-src.md "$TERR_BODY
## Declared RED
Test in \`features/a/a.test.ts\` must FAIL, asserting the exit code of \`scripts/ci/gate.mjs\`
is 1; today it returns 0.
"
OUT=$(bash "$CHECK" --file "$WORK/red-terr-src.md" 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "WARN.*scripts/ci/gate.mjs"; then
  pass "Case 13: RED citing a non-test file outside Territory WARNS but is ACCEPTED (exit 0)"
else
  fail "Case 13: expected exit 0 with a WARN naming the source file, got $RC. Output: $OUT"
fi

# --- Case 14: legacy bead with NO ## Territory section -> never bounced ----------------
write_fx red-terr-legacy.md "## Acceptance Criteria
- [ ] foo is bar.

## Declared RED
Test in \`features/b/b.test.ts\` must FAIL before the fix, with approximately: assert
\`violations\` equals 1.
"
OUT=$(bash "$CHECK" --file "$WORK/red-terr-legacy.md" 2>&1); RC=$?
if [ "$RC" -eq 0 ]; then
  pass "Case 14: bead with no ## Territory (legacy) is ACCEPTED, not bounced (exit 0)"
else
  fail "Case 14: expected exit 0 for a legacy bead, got $RC. Output: $OUT"
fi

# ============================================================================
# Cases 15-21: the lean schema (four sections, no `## Declared RED`). Element 4's
# ASSERTION is carried by the ACs, each naming its executable probe. The widening
# must accept that shape WITHOUT becoming a blanket exemption for "has ACs" —
# hence the vacuous, probe-less and partial-coverage refusals below.
# Which shape accepted a description is an EXPLICIT rule, asserted in Case 20:
# a `## Declared RED` header, when present, decides — never grep order.
# ============================================================================

AC2_BODY='## Intent
The gate is reachable from any shell, so "the probe ran" is a habit, not a property.
Boundary: no change to `br` itself. Line numbers are banned in this section.

## Acceptance Criteria
- The gate ships as an executable script the worker loop can invoke.
  Probe: `test -x skills/ac-implement/scripts/close-gate.sh` — tier: none
- A close with no probe receipt is refused, and the refusal names the missing receipt.
  Probe: `grep -q '"'"'refusing: no probe receipt'"'"' skills/ac-implement/scripts/close-gate.sh` — tier: none

## Delivers
- gate: skills/ac-implement/scripts/close-gate.sh

## Consumes
- none
'

# --- Case 15: lean schema, every AC probe-carrying, NO Declared RED -> ACCEPTED --------
write_fx ac-good.md "$AC2_BODY"
OUT=$(bash "$CHECK" --file "$WORK/ac-good.md" 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "via probe-carrying"; then
  pass "Case 15: ac-schema description with probe-carrying ACs is ACCEPTED (exit 0)"
else
  fail "Case 15: expected exit 0 naming the probe-carrying branch, got $RC. Output: $OUT"
fi

# --- Case 16: the example bead SHIPPED in bead-schema.md passes the gate ---------------
# The contract this widening accepts is a real file, not a fixture invented here: if the
# shipped example stops passing, the schema and its gate have diverged.
SCHEMA="$ROOT/skills/ac-beadify/references/bead-schema.md"
if [ ! -f "$SCHEMA" ]; then
  fail "Case 16: $SCHEMA is missing — the lean schema this widening accepts does not exist"
else
  sed -n '/ac-example-bead:start/,/ac-example-bead:end/p' "$SCHEMA" >"$WORK/schema-example.md"
  OUT=$(bash "$CHECK" --file "$WORK/schema-example.md" 2>&1); RC=$?
  if [ "$RC" -eq 0 ]; then
    pass "Case 16: the example bead shipped in bead-schema.md is ACCEPTED (exit 0)"
  else
    fail "Case 16: the shipped example bead was REJECTED, got $RC. Output: $OUT"
  fi
fi

# --- Case 17: lean shape whose ACs name NO probe -> REJECTED ---------------------------
# The widening must not become a blanket exemption for "has an AC section".
write_fx ac-noprobe.md '## Intent
Why this matters.

## Acceptance Criteria
- The gate refuses a close with no receipt.
- The refusal is loud.

## Delivers
- gate: skills/ac-implement/scripts/close-gate.sh

## Consumes
- none
'
OUT=$(bash "$CHECK" --file "$WORK/ac-noprobe.md" 2>&1); RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "no executable probe"; then
  pass "Case 17: ac-shape ACs naming no executable probe are REJECTED (exit 1)"
else
  fail "Case 17: expected exit 1 naming the missing probes, got $RC. Output: $OUT"
fi

# --- Case 18: AC section present but BULLETLESS -> REJECTED, not vacuously accepted ----
# "every bullet names a probe" is trivially true of zero bullets. This is the false-green
# the widening itself introduces; no other case covers it.
write_fx ac-vacuous.md '## Intent
Why this matters.

## Acceptance Criteria
The gate should refuse closes that have no receipt, and generally behave well.

## Delivers
- gate: skills/ac-implement/scripts/close-gate.sh

## Consumes
- none
'
OUT=$(bash "$CHECK" --file "$WORK/ac-vacuous.md" 2>&1); RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "no AC bullets"; then
  pass "Case 18: a bulletless '## Acceptance Criteria' section is REJECTED (exit 1)"
else
  fail "Case 18: expected exit 1 naming the empty AC list, got $RC. Output: $OUT"
fi

# --- Case 19: PARTIAL coverage (1 of 5 ACs carries a probe) -> REJECTED ---------------
write_fx ac-partial.md '## Intent
Why this matters.

## Acceptance Criteria
- The gate ships as an executable script.
  Probe: `test -x skills/ac-implement/scripts/close-gate.sh` — tier: none
- A close with no receipt is refused.
- The refusal names the missing receipt.
- The gate is wired into the close step.
- The harness runs in CI.

## Delivers
- gate: skills/ac-implement/scripts/close-gate.sh

## Consumes
- none
'
OUT=$(bash "$CHECK" --file "$WORK/ac-partial.md" 2>&1); RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "4 of 5"; then
  pass "Case 19: PARTIAL probe coverage (1 of 5 ACs) is REJECTED (exit 1)"
else
  fail "Case 19: expected exit 1 counting the probe-less ACs, got $RC. Output: $OUT"
fi

# --- Case 20: BOTH shapes present -> accepted, and the RED branch is the one that did --
# The rule is explicit: a '## Declared RED' header decides. Assert WHICH branch accepted.
write_fx ac-both.md "$AC2_BODY
## Declared RED
Test \`close-gate refuses a receiptless close\` must FAIL before the fix, with
approximately: assert exit 1; today it returns 0.
"
OUT=$(bash "$CHECK" --file "$WORK/ac-both.md" 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "via ## Declared RED" \
   && ! echo "$OUT" | grep -q "via probe-carrying"; then
  pass "Case 20: with BOTH shapes present, '## Declared RED' is the branch that accepts"
else
  fail "Case 20: expected exit 0 via the Declared RED branch only, got $RC. Output: $OUT"
fi

# --- Case 21: NEITHER shape -> still REJECTED (the pre-widening contract holds) --------
write_fx ac-neither.md '## Intent
Why this matters.

## Delivers
- gate: skills/ac-implement/scripts/close-gate.sh

## Consumes
- none
'
OUT=$(bash "$CHECK" --file "$WORK/ac-neither.md" 2>&1); RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "no '## Declared RED' header"; then
  pass "Case 21: neither Declared RED nor an AC section is still REJECTED (exit 1)"
else
  fail "Case 21: expected exit 1, got $RC. Output: $OUT"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All element4-check fixture tests passed."
  exit 0
else
  echo "$FAILURES fixture test(s) FAILED."
  exit 1
fi
