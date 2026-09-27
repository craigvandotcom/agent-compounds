#!/usr/bin/env bash
# citation-grammar.test.sh — fixture tests for skills/_tools/citation-grammar.sh.
#
# Both polarities, always: a checker that refuses everything satisfies the violation cases
# alone, and one that refuses nothing satisfies the conforming cases alone. Every violation
# class is asserted BY NAME on the bead it came from, so a case cannot pass on the wrong
# defect. The four classes measured on real boards (label prefix, two artifacts, prose,
# placeholder) each have a Delivers case; the wrapped continuation line gets its own case,
# because an unfolded reader sees only the first line and passes it.
#
# Run directly:  bash skills/_tools/citation-grammar.test.sh
# Discovered automatically by scripts/run-all-proofs.sh (glob over *.test.sh).
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="$DIR/citation-grammar.sh"

FAILURES=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }

[ -f "$TOOL" ] || { echo "HARNESS FAIL: missing $TOOL"; exit 1; }
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

# desc <name> <delivers-lines> [<consumes-lines>] — a four-section description on disk.
desc() {
  printf '## Intent\nA synthetic bead; prose here — like skills/x/y.sh and z — is never graded.\n\n## Acceptance Criteria\n- it works\n  Probe: `true` — tier: none\n\n## Delivers\n%s\n\n## Consumes\n%s\n' \
    "$2" "${3:-- none}" >"$WORK/$1.md"
  printf '%s' "$WORK/$1.md"
}
run() { OUT=$(bash "$TOOL" "$@" 2>&1); RC=$?; }

expect_ok() { # <label> <file>
  run check "$2" fx
  if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q '^citations: OK fx' && ! echo "$OUT" | grep -q VIOLATION; then
    pass "$1 (citations: OK, exit 0)"
  else
    fail "$1: expected exit 0 + OK, got $RC. Output: $OUT"
  fi
}
expect_class() { # <label> <class> <section> <file>
  run check "$4" fx
  if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "^citations: VIOLATION fx \[$2\] $3:" \
     && echo "$OUT" | grep -q '^citations: REFUSED fx'; then
    pass "$1 ([$2] on $3, exit 1)"
  else
    fail "$1: expected exit 1 + [$2] on $3, got $RC. Output: $OUT"
  fi
}

# --- Conforming forms ---------------------------------------------------------------------
expect_ok "Case 1: one bare path per Delivers bullet" \
  "$(desc c1 '- skills/_tools/citation-grammar.sh
- skills/_tools/citation-grammar.test.sh')"
expect_ok "Case 2: a trailing parenthetical gloss that names no second path" \
  "$(desc c2 '- skills/ac-polish/scripts/bead-artifact.py (the base_digest() function under investigation)')"
expect_ok "Case 3: '- none' at both ends, bare 'none' too" \
  "$(desc c3 '- none' 'none')"
expect_ok "Case 4: a top-level name.ext and a route-group path with parentheses in it" \
  "$(desc c4 '- lint.sh
- apps/web/app/(auth)/page.tsx')"
expect_ok "Case 5: a touchers: line beneath the bullet is structure, not prose" \
  "$(desc c5 "- skills/_tools/touchers.sh
  touchers: \`rg -l -F \"_tools/touchers\" . -g '!skills/_tools/touchers.sh'\` → 4 · owned by: bd-x")"
expect_ok "Case 6: Consumes '<id> -> <path> (gloss)', with either arrow" \
  "$(desc c6 '- none' '- bd-a.1 -> skills/ac-pipeline/SKILL.md (the MODE declaration)
- bd-a.2 → lint.sh')"

# --- The four measured violation classes, Delivers end ------------------------------------
expect_class "Case 7: a label prefix" LABEL-PREFIX Delivers \
  "$(desc v7 '- gate: skills/ac-implement/scripts/close-gate.sh')"
expect_class "Case 8: two artifacts on one entry" TWO-ARTIFACTS Delivers \
  "$(desc v8 '- skills/a/one.sh and skills/b/two.md')"
expect_class "Case 9: a second artifact hidden in the gloss" TWO-ARTIFACTS Delivers \
  "$(desc v9 '- skills/a/one.sh (replaces skills/a/old.sh)')"
expect_class "Case 10: trailing prose after the path" PROSE Delivers \
  "$(desc v10 '- skills/a/one.sh — the gate every round runs')"
expect_class "Case 11: a prose entry with no path at the head" PROSE Delivers \
  "$(desc v11 '- a ruling recorded in the close comment')"
expect_class "Case 12: a placeholder path" PLACEHOLDER Delivers \
  "$(desc v12 '- skills/<name>/SKILL.md')"
expect_class "Case 13: a TBD placeholder" PLACEHOLDER Delivers \
  "$(desc v13 '- TBD')"

# --- The wrapped continuation line --------------------------------------------------------
# Unfolded, the head is a clean path with no remainder and this entry would PASS while
# promising two artifacts.
expect_class "Case 14: a second artifact past a line break" TWO-ARTIFACTS Delivers \
  "$(desc v14 '- skills/a/one.sh and, on the next line,
  skills/b/two.md')"
expect_class "Case 15: prose past a line break" PROSE Delivers \
  "$(desc v15 '- skills/a/one.sh
  which the gate reads every round')"

# --- The remaining classes, and the Consumes end ------------------------------------------
expect_class "Case 16: a backticked path is not bare" NOT-BARE Delivers \
  "$(desc v16 '- `skills/a/one.sh`')"
expect_class "Case 17: an empty bullet" EMPTY Delivers \
  "$(desc v17 '- ')"
expect_class "Case 18: a label prefix after the Consumes arrow" LABEL-PREFIX Consumes \
  "$(desc v18 '- none' '- bd-a.1 -> gate: skills/a/one.sh')"
expect_class "Case 19: prose after the Consumes arrow" PROSE Consumes \
  "$(desc v19 '- none' '- bd-a.1 -> the inventory baseline, in its close comment')"
expect_class "Case 20: a Consumes line with no arrow" NO-ARROW Consumes \
  "$(desc v20 '- none' '- skills/a/one.sh')"

# Every violation on a bead is reported, not just the first: a reader fixing one per round
# pays a round per defect.
run check "$(desc v21 '- gate: skills/a/one.sh
- skills/b/two.md and skills/c/three.md')" fx
N=$(echo "$OUT" | grep -c '^citations: VIOLATION fx')
if [ "$RC" -eq 1 ] && [ "$N" -eq 2 ]; then
  pass "Case 21: every violating entry is reported (2 of 2)"
else
  fail "Case 21: expected 2 VIOLATION lines, got $N (rc $RC). Output: $OUT"
fi

# --- Artifact mode: the shape the polish VALIDATE leg runs over ---------------------------
{
  printf '<!-- BEAD:bd-ok -->\n# bd-ok — clean\ntype: task · priority: 2 · labels: none · base: x\n\n'
  cat "$WORK/c1.md"
  printf '\n<!-- /BEAD:bd-ok -->\n\n<!-- BEAD:bd-bad -->\n# bd-bad — dirty\ntype: task · priority: 2 · labels: none · base: x\n\n'
  cat "$WORK/v7.md"
  printf '\n<!-- /BEAD:bd-bad -->\n'
} >"$WORK/artifact.md"
run artifact "$WORK/artifact.md"
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q '^citations: OK bd-ok' \
   && echo "$OUT" | grep -q '^citations: VIOLATION bd-bad \[LABEL-PREFIX\]' \
   && ! echo "$OUT" | grep -q 'VIOLATION bd-ok'; then
  pass "Case 22: artifact mode grades each BEAD block under its own id (exit 1, only bd-bad named)"
else
  fail "Case 22: artifact mode, got $RC. Output: $OUT"
fi

# --- The worked example shipped in bead-schema.md obeys the rule it sits beside -----------
# The registry's own example once TAUGHT the label prefix (`- gate: <path>`), and 15 of 20
# open beads on this board copied it. A schema whose example fails its own checker teaches
# the defect faster than the prose forbids it.
SCHEMA="$DIR/../ac-beadify/references/bead-schema.md"
sed -n '/ac-example-bead:start/,/ac-example-bead:end/p' "$SCHEMA" >"$WORK/schema-example.md"
if [ ! -s "$WORK/schema-example.md" ]; then
  fail "Case 25: no ac-example-bead block could be read out of $SCHEMA"
else
  run check "$WORK/schema-example.md" bead-schema-example
  [ "$RC" -eq 0 ] \
    && pass "Case 25: the worked example in bead-schema.md conforms (exit 0)" \
    || fail "Case 25: the shipped example breaks the citation rule, got $RC. Output: $OUT"
fi

# --- NOT-GATED: a sweep over nothing is never a pass --------------------------------------
run check "$WORK/does-not-exist.md" fx
[ "$RC" -eq 2 ] && echo "$OUT" | grep -q 'citations: NOT-GATED' \
  && pass "Case 23: an unreadable description is NOT-GATED (exit 2)" \
  || fail "Case 23: expected exit 2 + NOT-GATED, got $RC. Output: $OUT"
printf 'no blocks here\n' >"$WORK/empty-artifact.md"
run artifact "$WORK/empty-artifact.md"
[ "$RC" -eq 2 ] && echo "$OUT" | grep -q 'citations: NOT-GATED' \
  && pass "Case 24: an artifact with no BEAD block is NOT-GATED (exit 2)" \
  || fail "Case 24: expected exit 2 + NOT-GATED, got $RC. Output: $OUT"

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "citation-grammar.test.sh: all cases passed"
  exit 0
fi
echo "citation-grammar.test.sh: $FAILURES case(s) FAILED"
exit 1
