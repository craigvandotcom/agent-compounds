#!/usr/bin/env bash
# 22-ledger-integrity.test.sh — the proof harness for lint/checks/22-ledger-integrity.sh.
#
#   PROBE: an entry citing a control the constitution does not define is RED; an entry
#          re-observed after its control landed is RED as a FAILED CONTROL; an entry with
#          no receipt, or no control and not tagged untreated, is RED naming the entry; a
#          well-formed treated entry, an explicitly untreated entry, and a legacy foreign
#          id (the seed rule) are GREEN; an entry with an unscorable ordinal is RED as a
#          named NOT-SCORABLE finding; an absent or empty ledger, an invariant with no
#          Prevents:, and a calibration with no retires-when all fail CLOSED naming
#          NOT-GATED; a checkout shipping no ledger at all (the default path, no --ledger
#          given) SKIPS (exit 77), never claiming the contract holds; a missing shared
#          parser is NOT-GATED (exit 2); the real registry is GREEN or SKIPs (ledgers are
#          adopter-local and gitignored, so CI may carry none).
#
# ASSURANCE
#   PROBE:    bash lint/checks/22-ledger-integrity.test.sh
#   SCHEDULE: scripts/run-all-proofs.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/22-ledger-integrity.sh"
ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

# A minimal, CONFORMING constitution: one invariant, one calibration, both complete.
CONSTITUTION="$WORK/SKILL.md"
cat >"$CONSTITUTION" <<'EOF'
# ac-pipeline — the constitution

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
  printf '## %s\n- skills: [ac-pipeline]\n- impact: M\n- frequency: frequent\n' "$id"
  printf -- '- perceptibility: silent\n- recurrence: 2\n- related: []\n'
  printf -- '- first_seen: 2026-08-01\n- last_seen: 2026-08-10\n- stage: ac2\n- status: open\n'
  for line in "$@"; do printf -- '%s\n' "$line"; done
  printf -- '- proposed_fix: fix it.\n- narrative: it broke.\n\n'
}

ledger() {  # ledger <file> <entry-blocks...>
  local f="$1"; shift
  {
    printf -- '---\nskill: ac-pipeline\ncreated: 2026-08-27\nlast_pass: 2026-08-27\n---\n\n'
    printf '# ac-pipeline — friction log\n\n'
    printf '%s' "$@"
  } >"$f"
}

run_check() {  # run_check <ledger path> -> sets OUT/RC (flag-override, real ROOT for the parser)
  OUT=$(bash "$CHECK" --ledger "$1" --constitution "$CONSTITUTION" "$ROOT" 2>&1); RC=$?
}

# --- Case 1: an explicitly named ABSENT ledger fails CLOSED with NOT-GATED -----------
run_check "$WORK/does-not-exist.md"
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "NOT-GATED"; then
  ok "Case 1: an explicitly named absent ledger fails closed carrying NOT-GATED (rc=$RC)"
else
  bad "Case 1: expected non-zero + NOT-GATED, got $RC. Output: $OUT"
fi

# --- Case 2: an EMPTY ledger (header, zero entries) also fails NOT-GATED -------------
ledger "$WORK/empty.md" ""
run_check "$WORK/empty.md"
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "NOT-GATED"; then
  ok "Case 2: a ledger with zero entries fails closed carrying NOT-GATED"
else
  bad "Case 2: expected non-zero + NOT-GATED, got $RC. Output: $OUT"
fi

# --- Case 3: a well-formed entry (receipt + resolvable control) PASSES ---------------
ledger "$WORK/good.md" "$(entry good-one '- receipt: commit 47593f3' '- control: I1' '- control_landed: 2026-08-27')"
run_check "$WORK/good.md"
if [ "$RC" -eq 0 ]; then
  ok "Case 3: an entry citing a receipt and a resolvable control PASSES"
else
  bad "Case 3: expected exit 0, got $RC. Output: $OUT"
fi

# --- Case 4: no control and not untreated is REJECTED --------------------------------
ledger "$WORK/nocontrol.md" "$(entry orphan-one '- receipt: commit 47593f3')"
run_check "$WORK/nocontrol.md"
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "orphan-one"; then
  ok "Case 4: an entry naming no control and not tagged untreated is REJECTED"
else
  bad "Case 4: expected non-zero naming the entry, got $RC. Output: $OUT"
fi

# --- Case 5: an entry explicitly tagged 'control: untreated' PASSES ------------------
ledger "$WORK/untreated.md" "$(entry untreated-one '- receipt: bead ac-cfn4' '- control: untreated')"
run_check "$WORK/untreated.md"
if [ "$RC" -eq 0 ]; then
  ok "Case 5: an entry tagged 'control: untreated' PASSES"
else
  bad "Case 5: expected exit 0, got $RC. Output: $OUT"
fi

# --- Case 6: no receipt is REJECTED (evidence is the point of the entry) ------------
ledger "$WORK/noreceipt.md" "$(entry unevidenced-one '- control: I1' '- control_landed: 2026-08-27')"
run_check "$WORK/noreceipt.md"
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "unevidenced-one"; then
  ok "Case 6: an entry citing no receipt is REJECTED"
else
  bad "Case 6: expected non-zero naming the entry, got $RC. Output: $OUT"
fi

# --- Case 7: a LEGACY id inherited from an old ledger is ACCEPTED (the seed rule) ----
# During construction, controls cite ids minted in older ledgers and the family ledger
# inherits them, so a foreign id is legal INPUT, not a violation.
ledger "$WORK/legacy.md" "$(entry br-d-body-is-shell-expanded '- receipt: skills/beads-standards/FRICTIONS.md' '- control: C-receipt-formats' '- control_landed: 2026-08-27')"
run_check "$WORK/legacy.md"
if [ "$RC" -eq 0 ]; then
  ok "Case 7: an entry inheriting a legacy friction id from an old ledger PASSES"
else
  bad "Case 7: expected exit 0 for an inherited id, got $RC. Output: $OUT"
fi

# --- Case 8: cites a control the constitution does not define is REJECTED -----------
ledger "$WORK/ghost.md" "$(entry ghost-one '- receipt: commit 47593f3' '- control: I9' '- control_landed: 2026-08-27')"
run_check "$WORK/ghost.md"
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "I9"; then
  ok "Case 8: an entry citing a nonexistent control is REJECTED (referential integrity)"
else
  bad "Case 8: expected non-zero naming I9, got $RC. Output: $OUT"
fi

# --- Case 9: recurrence re-observed AFTER its control landed is a FAILED CONTROL -----
ledger "$WORK/recur.md" "$(entry regressed-one '- receipt: commit 47593f3' '- control: I1' '- control_landed: 2026-08-05')"
run_check "$WORK/recur.md"
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "FAILED CONTROL"; then
  ok "Case 9: an entry re-observed after its control landed is FLAGGED as a failed control"
else
  bad "Case 9: expected non-zero naming FAILED CONTROL, got $RC. Output: $OUT"
fi

# --- Case 10: control direction — an invariant with no Prevents: is REJECTED --------
BADC="$WORK/bad-constitution.md"
sed 's/Prevents: perishable tree-state/it is good practice, generally,/' "$CONSTITUTION" >"$BADC"
OUT=$(bash "$CHECK" --ledger "$WORK/good.md" --constitution "$BADC" "$ROOT" 2>&1); RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -qi "names no failure"; then
  ok "Case 10: an invariant naming no failure it prevents is REJECTED"
else
  bad "Case 10: expected non-zero naming the control gap, got $RC. Output: $OUT"
fi

# --- Case 11: control direction — a calibration with no retires-when is REJECTED ----
BADC2="$WORK/bad-constitution-2.md"
sed 's/\*retires when:\* the receipt tools take/it stays forever because/' "$CONSTITUTION" >"$BADC2"
OUT=$(bash "$CHECK" --ledger "$WORK/good.md" --constitution "$BADC2" "$ROOT" 2>&1); RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -qi "retires"; then
  ok "Case 11: a calibration naming no retiring measurement is REJECTED"
else
  bad "Case 11: expected non-zero naming the missing retire clause, got $RC. Output: $OUT"
fi

# --- Case 12: ONE parser — the check reads the shared computation, never a second ---
if grep -q "friction-rollup.py" "$CHECK"; then
  ok "Case 12: the check consumes friction-rollup.py (the shared parse), not a second parser"
else
  bad "Case 12: the check no longer references friction-rollup.py — a second parser has appeared"
fi

# --- default-path resolution (no --ledger/--constitution given): an isolated root ----
# build_tree <root> <ledger-text|EMPTY> <with-rollup:yes|no> — a real SKILL.md + an
# optional FRICTIONS.md, exercising the check's DEFAULT ledger/constitution resolution
# rather than the --ledger/--constitution override used above.
build_tree() {
  local w="$1" ledger="$2" rollup="$3"
  mkdir -p "$w/skills/skill-builder/scripts" "$w/skills/ac-pipeline"
  [ "$rollup" = yes ] && cp "$ROOT/skills/skill-builder/scripts/friction-rollup.py" "$w/skills/skill-builder/scripts/"
  cp "$ROOT/skills/ac-pipeline/SKILL.md" "$w/skills/ac-pipeline/"
  if [ "$ledger" != EMPTY ]; then printf '%s' "$ledger" > "$w/skills/ac-pipeline/FRICTIONS.md"; fi
}

LEDGER_OK='---
skill: ac-pipeline
created: 2026-09-07
last_pass: never
---

# fixture ledger

## fixture-friction
- skills: [ac-pipeline]
- impact: M
- frequency: every-run
- perceptibility: silent
- recurrence: 3
- first_seen: 2026-09-01
- last_seen: 2026-08-01
- status: closed
- receipt: somewhere (fixture)
- control: I1
- control_landed: 2026-08-27
'

# --- Case 13: SKIP — a checkout that ships no ledger at all (default path) ----------
w="$(mktemp -d)"
build_tree "$w" EMPTY yes
out="$(bash "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 77 ] && printf '%s' "$out" | grep -q "skipped"; then
  ok "Case 13: no ledger in the checkout (default path) -> exit 77, reported as a skip"
else
  bad "Case 13: expected 77 carrying 'skipped', got $rc"; printf '%s\n' "$out"
fi
if printf '%s' "$out" | grep -q "contract holds both directions"; then
  bad "Case 13: claimed the contract holds while gating nothing"
fi
rm -rf "$w"

# --- Case 14: GREEN via default path; entry count is read at parse time, never from
# a hand-kept header (the ledgers carry no 'entries:' field) --------------------------
w="$(mktemp -d)"
build_tree "$w" "$LEDGER_OK" yes
out="$(bash "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q "1 entr(y|ies)"; then
  ok "Case 14: default-path GREEN, entry count derived from the parsed ledger"
else
  bad "Case 14: expected 0 naming '1 entr(y|ies)', got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- Case 15: RED via default path — an unscorable ordinal is a named finding -------
# The folded-in --strict class: an ordinal outside the schema's canonical set is a
# REPORT ROW, never a mutation; the frictions docket consumes it.
w="$(mktemp -d)"
build_tree "$w" "$(printf '%s' "$LEDGER_OK" | sed 's/^- frequency: every-run$/- frequency: sometimes/')" yes
out="$(bash "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "NOT-SCORABLE: fixture-friction" \
   && ! printf '%s' "$out" | grep -q "FAILED CONTROL"; then
  ok "Case 15: default-path unscorable ordinal -> exit 1 naming NOT-SCORABLE only"
else
  bad "Case 15: expected 1 naming NOT-SCORABLE only, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- Case 16: NOT-GATED — the shared parser is missing from the audited tree --------
w="$(mktemp -d)"
build_tree "$w" "$LEDGER_OK" no
out="$(bash "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q "NOT-GATED"; then
  ok "Case 16: missing shared parser -> exit 2, verified nothing"
else
  bad "Case 16: expected 2, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- Case 17: the real registry is GREEN, or SKIPs (ledgers are adopter-local and
# gitignored, so this checkout may carry none) ---------------------------------------
out="$(bash "$CHECK" "$ROOT" 2>&1)"; rc=$?
if [ "$rc" = 77 ]; then
  ok "Case 17: no friction ledger in this checkout (adopter-local) -> 77, never ok"
elif [ "$rc" = 0 ] && ! printf '%s' "$out" | grep -q "NOT-SCORABLE"; then
  ok "Case 17: the real registry's ledger is scorable"
else
  bad "Case 17: expected 0 with no NOT-SCORABLE (or 77 with no ledger), got $rc"; printf '%s\n' "$out"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "22-ledger-integrity.test.sh: all fixture tests passed."
  exit 0
else
  echo "22-ledger-integrity.test.sh: ${fails} failure(s)."
  exit 1
fi
