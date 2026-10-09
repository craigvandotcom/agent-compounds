#!/usr/bin/env bash
# stamp-refined-check.test.sh — proof for stamp-refined.sh's `--check` mode: the ONE
# read-only entry point that must run every CONTENT leg the restamp itself runs, so
# VALIDATE (ac-polish's bead-mode gate) and the restamp gate can never drift apart again.
#
# THE MOTIVATING DEFECT (org-uv40/org-gv6, 2026-09-28): VALIDATE ran `bead.py check <file>`
# alone. `bead.py check` carried no PROBE-PRESENCE leg at all (it lived only in
# stamp-refined.sh's own inline copy), so a bead whose only probe was a bare `test -f`
# existence read on a code Delivers passed VALIDATE — the restamp gate's inline copy of the
# SAME rule then refused it. Case 2 below is that exact fixture, now caught by --check.
#
# Run directly: bash skills/_tools/stamp-refined-check.test.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$DIR/stamp-refined.sh"

FAILURES=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

write_fx() { printf '%s' "$2" >"$WORK/$1"; }

# --- Case 1: usage — no file given -------------------------------------------------------
OUT=$(bash "$STAMP" --check 2>&1); RC=$?
if [ "$RC" -eq 2 ] && echo "$OUT" | grep -q 'usage:'; then
  pass "Case 1: --check with no file is NOT-GATED (exit 2), naming usage"
else
  fail "Case 1: expected exit 2 naming usage, got $RC. Output: $OUT"
fi

# --- Case 2: THE MOTIVATING DEFECT — a code Delivers whose only probe is a bare `test -f`
# existence read is REFUSED, naming probe-presence. This is the exact shape the old
# `bead.py check <file>` (VALIDATE's whole rule set, pre-move) let through and the restamp
# gate's own inline copy then refused (org-uv40/org-gv6).
CODE_NO_RUN='## Intent
something.

## Acceptance Criteria
- x.
  Probe: `test -f lib/parser.sh`

## Delivers
- lib/parser.sh

## Consumes
- none
'
write_fx no-run.md "$CODE_NO_RUN"
OUT=$(bash "$STAMP" --check "$WORK/no-run.md" --type task --labels origin:ac-beadify 2>&1); RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q 'probe-presence'; then
  pass "Case 2: a code Delivers with only a bare 'test -f' probe is REFUSED, naming probe-presence — the org-uv40/org-gv6 shape"
else
  fail "Case 2: expected exit 1 naming probe-presence, got $RC. Output: $OUT"
fi

# --- Case 3: the SAME content, but the probe actually runs something ('test -x p && bash p')
# — a clean fixture passes end to end (element4 + bead.py check both clean).
CODE_RUNS='## Intent
something.

## Acceptance Criteria
- x.
  Probe: `test -x lib/parser.sh && bash lib/parser.sh`

## Delivers
- lib/parser.sh

## Consumes
- none
'
write_fx runs.md "$CODE_RUNS"
OUT=$(bash "$STAMP" --check "$WORK/runs.md" --type task --labels origin:ac-beadify 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'OK .*every content leg the stamp runs is clean'; then
  pass "Case 3: a code Delivers whose probe runs something passes clean end to end"
else
  fail "Case 3: expected exit 0 and a clean OK line, got $RC. Output: $OUT"
fi

# --- Case 4: --type threads through to bead.py's origin_violation leg (via the meta-header
# line) — labels: none with a task type is refused for carrying no origin:<skill> label.
NO_ORIGIN='## Intent
something.

## Acceptance Criteria
- x.
  Probe: `test -x lib/parser.sh && bash lib/parser.sh`

## Delivers
- lib/parser.sh

## Consumes
- none
'
write_fx no-origin.md "$NO_ORIGIN"
OUT=$(bash "$STAMP" --check "$WORK/no-origin.md" --type task 2>&1); RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q 'no origin:'; then
  pass "Case 4: --type with no --labels (defaulting to none) is refused for no origin: label — --type threads through bead.py's meta-header parser"
else
  fail "Case 4: expected exit 1 naming 'no origin:', got $RC. Output: $OUT"
fi

# --- Case 5: --labels given without --type cannot form a meta-header line (bead.py's own
# parser demands both on one line) — a note is printed and the label/type legs are skipped,
# never silently dropped.
write_fx labels-only.md "$CODE_RUNS"
OUT=$(bash "$STAMP" --check "$WORK/labels-only.md" --labels origin:ac-beadify 2>&1); RC=$?
if echo "$OUT" | grep -q -- '--labels given without --type'; then
  pass "Case 5: --labels with no --type prints a note rather than silently dropping it"
else
  fail "Case 5: expected a note about --labels without --type. Output: $OUT"
fi

# --- Case 6: element4 is wired — a body with no AC section at all is refused by that leg,
# never silently passed through to bead.py check alone.
NO_AC='## Intent
nothing declared.
'
write_fx no-ac.md "$NO_AC"
OUT=$(bash "$STAMP" --check "$WORK/no-ac.md" 2>&1); RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -qi 'element4-check'; then
  pass "Case 6: a body with no Acceptance Criteria section is refused by the element4 leg"
else
  fail "Case 6: expected exit 1 naming element4-check, got $RC. Output: $OUT"
fi

# --- Case 7: the board-only skip line is always printed, naming every leg --check cannot
# run without a live id — never silent, the same contract bead.py check's own file-mode
# skip line already keeps.
OUT=$(bash "$STAMP" --check "$WORK/runs.md" --type task --labels origin:ac-beadify 2>&1)
if echo "$OUT" | grep -q 'board-only legs skipped' \
   && echo "$OUT" | grep -q 'sensitive-prod' \
   && echo "$OUT" | grep -q 'prod-write-tripwire' \
   && echo "$OUT" | grep -q 'ruling-staleness' \
   && echo "$OUT" | grep -q 'fixpoint-receipt'; then
  pass "Case 7: every board-only leg --check cannot run is named on one line, never silent"
else
  fail "Case 7: expected the board-only skip line naming every leg. Output: $OUT"
fi

# --- Case 8: a nonexistent file is NOT-GATED (exit 2), never a pass ---------------------
OUT=$(bash "$STAMP" --check "$WORK/does-not-exist.md" 2>&1); RC=$?
if [ "$RC" -eq 2 ]; then
  pass "Case 8: a nonexistent file is NOT-GATED (exit 2)"
else
  fail "Case 8: expected exit 2 for a missing file, got $RC. Output: $OUT"
fi

# --- Case 9: THE VACUOUS --check HOLE (bd-1fse3/bd-qer3r sibling gap, 2026-09-28) — a task
# bead with NO 'Probe:' line at all used to pass --check (bead.py check carried no zero-probe
# leg) even though the full stamp's own inline copy of the same rule would refuse it as "no
# executable Probe: line". --check must refuse it too, for an implementable type. Delivers
# names a NON-code path (docs/spec.md) so the pre-existing probe-presence leg (a CODE
# Delivers needs a probe that runs something) stays clean and cannot mask which leg fired.
NO_PROBE='## Intent
something.

## Acceptance Criteria
- x exists, verified by hand.

## Delivers
- docs/spec.md

## Consumes
- none
'
# The grep target is 'no-probe:' (with the trailing colon — the exact violation-line
# prefix `cmd_check` writes, `refused.append(f"no-probe: {npv}")`), never the bare
# 'no-probe' substring: a fixture FILENAME containing that substring (as an earlier
# revision of this case did: no-probe-decision.md) would false-match on its own path
# echoed back in an unrelated OK/skip line.
write_fx zprobeless.md "$NO_PROBE"
OUT=$(bash "$STAMP" --check "$WORK/zprobeless.md" --type task --labels origin:ac-beadify 2>&1); RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q 'no-probe:'; then
  pass "Case 9: a task bead with zero 'Probe:' lines is REFUSED by --check, naming no-probe — the vacuous sibling gap is closed"
else
  fail "Case 9: expected exit 1 naming no-probe:, got $RC. Output: $OUT"
fi

# --- Case 10: the type/label exemption — decision/epic/investigation and human-gate keep
# today's exemption (bead-schema.md § Required axes): zero 'Probe:' lines never refuses
# those. A decision-typed bead with the same probe-less body as Case 9 passes the no-probe
# leg clean (it may still be refused elsewhere, e.g. element4 or origin, but never by
# no-probe).
write_fx zprobeless-decision.md "$NO_PROBE"
OUT=$(bash "$STAMP" --check "$WORK/zprobeless-decision.md" --type decision --labels origin:ac-beadify 2>&1); RC=$?
if [ "$RC" -eq 0 ] && ! echo "$OUT" | grep -q 'no-probe:'; then
  pass "Case 10: a decision-typed bead with zero 'Probe:' lines is never refused by no-probe — type exemption preserved"
else
  fail "Case 10: a decision-typed bead was refused by no-probe; the type exemption regressed. rc=$RC Output: $OUT"
fi

# --- Case 11: the human-gate label exemption — a task-typed, human-gate-labelled bead with
# zero 'Probe:' lines is never refused by no-probe either, regardless of its type.
# (element4-check does not thread --labels through --check today — out of scope here — so
# this case only asserts the no-probe leg itself, via bead.py's own meta-header read, not
# the overall exit code.)
write_fx zprobeless-human-gate.md "$NO_PROBE"
OUT=$(bash "$STAMP" --check "$WORK/zprobeless-human-gate.md" --type task --labels origin:ac-beadify,human-gate 2>&1); RC=$?
if ! echo "$OUT" | grep -q 'no-probe:'; then
  pass "Case 11: a human-gate-labelled task bead with zero 'Probe:' lines is never refused by no-probe — label exemption preserved"
else
  fail "Case 11: a human-gate-labelled bead was refused by no-probe; the label exemption regressed. Output: $OUT"
fi

# --- Case 12: a plan-less bead (origin:ac-triage) with a Delivers path and no ## Seams is
# REFUSED by --check, naming seams-missing — the same bead.py check leg the stamp runs.
write_fx plan-less.md "$CODE_RUNS"
OUT=$(bash "$STAMP" --check "$WORK/plan-less.md" --type task --labels origin:ac-triage 2>&1); RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q 'seams-missing'; then
  pass "Case 12: a plan-less task with a Delivers path and no Seams is REFUSED, naming seams-missing"
else
  fail "Case 12: expected exit 1 naming seams-missing, got $RC. Output: $OUT"
fi

# --- Case 13: the same bead with a non-empty ## Seams section passes clean.
write_fx plan-less-seams.md "$CODE_RUNS
## Seams
- lib/parser.sh · new — no touchers
"
OUT=$(bash "$STAMP" --check "$WORK/plan-less-seams.md" --type task --labels origin:ac-triage 2>&1); RC=$?
if [ "$RC" -eq 0 ] && ! echo "$OUT" | grep -q 'seams-missing'; then
  pass "Case 13: the same bead with a Seams section passes clean"
else
  fail "Case 13: expected exit 0 with no seams-missing, got $RC. Output: $OUT"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "stamp-refined-check.test.sh: all cases passed"
  exit 0
else
  echo "stamp-refined-check.test.sh: $FAILURES case(s) FAILED"
  exit 1
fi
