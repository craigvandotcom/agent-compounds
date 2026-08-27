#!/usr/bin/env bash
# ac2-ledger-integrity.test.sh — fixture tests for ac2-ledger-integrity.sh (lint Check 22).
#
# Both polarities on every rule: a violating fixture AND a conforming one. The first case
# is the one the whole check exists for — an ABSENT ledger must fail CLOSED carrying the
# literal token NOT-GATED, because a check that green-passes over an empty set is the
# failure mode this pipeline was built to stop believing.
#
# Run directly:  bash scripts/ac2-ledger-integrity.test.sh
# Discovered automatically by scripts/run-all-harnesses.sh (glob over *.test.sh).
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
CHECK="$DIR/ac2-ledger-integrity.sh"

FAILURES=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

# A minimal, CONFORMING constitution: one invariant, one calibration, both complete.
CONSTITUTION="$WORK/SKILL.md"
cat >"$CONSTITUTION" <<'EOF'
# ac2-pipeline — the constitution

## Invariants

1. **Beads are memory, never a cache of the tree.** (L3) Prevents: perishable tree-state
   decaying at a measured 100% base rate.

## Calibrations

- **Receipt formats.** (L2) Bodies via `-f <file>`. *retires when:* the receipt tools take
  one uniform body flag.
EOF

# entry <id> <extra field lines...>
entry() {
  local id="$1"; shift
  printf '## %s\n- skills: [ac2-pipeline]\n- impact: M\n- frequency: frequent\n' "$id"
  printf -- '- perceptibility: silent\n- recurrence: 2\n- related: []\n'
  printf -- '- first_seen: 2026-08-01\n- last_seen: 2026-08-10\n- stage: ac2\n- status: open\n'
  for line in "$@"; do printf -- '%s\n' "$line"; done
  printf -- '- proposed_fix: fix it.\n- narrative: it broke.\n\n'
}

ledger() {  # ledger <file> <entry-blocks...>
  local f="$1"; shift
  {
    printf -- '---\nskill: ac2-pipeline\ncreated: 2026-08-27\nlast_pass: 2026-08-27\nentries: 1\n---\n\n'
    printf '# ac2-pipeline — friction log\n\n'
    printf '%s' "$@"
  } >"$f"
}

run_check() {  # run_check <ledger path> -> sets OUT/RC
  OUT=$(bash "$CHECK" --ledger "$1" --constitution "$CONSTITUTION" "$ROOT" 2>&1); RC=$?
}

# --- Case 1: ABSENT ledger -> fails CLOSED with the literal NOT-GATED token ------------
run_check "$WORK/does-not-exist.md"
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "NOT-GATED"; then
  pass "Case 1: an absent ledger fails closed carrying NOT-GATED (rc=$RC)"
else
  fail "Case 1: expected non-zero + NOT-GATED, got $RC. Output: $OUT"
fi

# --- Case 2: EMPTY ledger (header, zero entries) -> also NOT-GATED --------------------
ledger "$WORK/empty.md" ""
run_check "$WORK/empty.md"
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "NOT-GATED"; then
  pass "Case 2: a ledger with zero entries fails closed carrying NOT-GATED"
else
  fail "Case 2: expected non-zero + NOT-GATED, got $RC. Output: $OUT"
fi

# --- Case 3: a well-formed entry (receipt + resolvable control) -> PASS ---------------
ledger "$WORK/good.md" "$(entry good-one '- receipt: commit 47593f3' '- control: I1' '- control_landed: 2026-08-27')"
run_check "$WORK/good.md"
if [ "$RC" -eq 0 ]; then
  pass "Case 3: an entry citing a receipt and a resolvable control PASSES"
else
  fail "Case 3: expected exit 0, got $RC. Output: $OUT"
fi

# --- Case 4: no control and not untreated -> FAIL -------------------------------------
ledger "$WORK/nocontrol.md" "$(entry orphan-one '- receipt: commit 47593f3')"
run_check "$WORK/nocontrol.md"
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "orphan-one"; then
  pass "Case 4: an entry naming no control and not tagged untreated is REJECTED"
else
  fail "Case 4: expected non-zero naming the entry, got $RC. Output: $OUT"
fi

# --- Case 5: explicitly untreated -> PASS (the sanctioned escape) ---------------------
ledger "$WORK/untreated.md" "$(entry untreated-one '- receipt: bead ac-cfn4' '- control: untreated')"
run_check "$WORK/untreated.md"
if [ "$RC" -eq 0 ]; then
  pass "Case 5: an entry tagged 'control: untreated' PASSES"
else
  fail "Case 5: expected exit 0, got $RC. Output: $OUT"
fi

# --- Case 6: no receipt -> FAIL (evidence is the point of the entry) ------------------
ledger "$WORK/noreceipt.md" "$(entry unevidenced-one '- control: I1' '- control_landed: 2026-08-27')"
run_check "$WORK/noreceipt.md"
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "unevidenced-one"; then
  pass "Case 6: an entry citing no receipt is REJECTED"
else
  fail "Case 6: expected non-zero naming the entry, got $RC. Output: $OUT"
fi

# --- Case 7: a LEGACY id inherited from an old ledger -> ACCEPTED (the seed rule) -----
# During construction ac2 controls cite ids minted in the ac-* ledgers; the family ledger
# inherits them, so a foreign id is legal INPUT, not a violation.
ledger "$WORK/legacy.md" "$(entry br-d-body-is-shell-expanded '- receipt: skills/beads-standards/FRICTIONS.md' '- control: C-receipt-formats' '- control_landed: 2026-08-27')"
run_check "$WORK/legacy.md"
if [ "$RC" -eq 0 ]; then
  pass "Case 7: an entry inheriting a legacy friction id from an old ledger PASSES"
else
  fail "Case 7: expected exit 0 for an inherited id, got $RC. Output: $OUT"
fi

# --- Case 8: cites a control the constitution does not define -> FAIL ----------------
ledger "$WORK/ghost.md" "$(entry ghost-one '- receipt: commit 47593f3' '- control: I9' '- control_landed: 2026-08-27')"
run_check "$WORK/ghost.md"
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "I9"; then
  pass "Case 8: an entry citing a nonexistent control is REJECTED (referential integrity)"
else
  fail "Case 8: expected non-zero naming I9, got $RC. Output: $OUT"
fi

# --- Case 9: recurrence re-observed AFTER its control landed -> FAILED CONTROL --------
# The whole reason the ledger records control_landed: a friction that keeps biting after
# its fix shipped is a failed control, and silence about it is the recurrence-26 class.
ledger "$WORK/recur.md" "$(entry regressed-one '- receipt: commit 47593f3' '- control: I1' '- control_landed: 2026-08-05')"
run_check "$WORK/recur.md"
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "FAILED CONTROL"; then
  pass "Case 9: an entry re-observed after its control landed is FLAGGED as a failed control"
else
  fail "Case 9: expected non-zero naming FAILED CONTROL, got $RC. Output: $OUT"
fi

# --- Case 10: control direction — an invariant with no Prevents: -> FAIL -------------
BADC="$WORK/bad-constitution.md"
sed 's/Prevents: perishable tree-state/it is good practice, generally,/' "$CONSTITUTION" >"$BADC"
OUT=$(bash "$CHECK" --ledger "$WORK/good.md" --constitution "$BADC" "$ROOT" 2>&1); RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -qi "names no failure"; then
  pass "Case 10: an ac2 invariant naming no failure it prevents is REJECTED"
else
  fail "Case 10: expected non-zero naming the control gap, got $RC. Output: $OUT"
fi

# --- Case 11: control direction — a calibration with no retires-when -> FAIL ---------
BADC2="$WORK/bad-constitution-2.md"
sed 's/\*retires when:\* the receipt tools take/it stays forever because/' "$CONSTITUTION" >"$BADC2"
OUT=$(bash "$CHECK" --ledger "$WORK/good.md" --constitution "$BADC2" "$ROOT" 2>&1); RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -qi "retires"; then
  pass "Case 11: a Calibration naming no retiring measurement is REJECTED"
else
  fail "Case 11: expected non-zero naming the missing retire clause, got $RC. Output: $OUT"
fi

# --- Case 12: the REAL seeded ledger + the REAL constitution -> PASS -----------------
# The fixtures are not the only subject: the shipped ledger must satisfy its own check.
OUT=$(bash "$CHECK" "$ROOT" 2>&1); RC=$?
if [ "$RC" -eq 0 ]; then
  pass "Case 12: the shipped ac2 ledger and constitution PASS the check"
else
  fail "Case 12: the real repo does not satisfy the check, rc=$RC. Output: $OUT"
fi

# --- Case 13: ONE parser — the check reads the shared computation, never its own -----
# ac-on0y.3 delivers the single parse over skills/*/FRICTIONS.md. If this check ever grows
# its own field parser, the two drift; this case pins the dependency.
if grep -q "friction-rollup.py" "$CHECK"; then
  pass "Case 13: the check consumes friction-rollup.py (the shared parse), not a second parser"
else
  fail "Case 13: the check no longer references friction-rollup.py — a second parser has appeared"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All ac2-ledger-integrity fixture tests passed."
  exit 0
else
  echo "$FAILURES fixture test(s) FAILED."
  exit 1
fi
