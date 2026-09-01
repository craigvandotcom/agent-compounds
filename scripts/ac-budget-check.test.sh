#!/usr/bin/env bash
# ac-budget-check.test.sh — fixture tests for ac-budget-check.sh (lint Check 23).
#
# Every cap gets BOTH sides of its boundary, and every fail-closed rule gets an empty
# fixture: the plan's biggest named risk is cultural (the ac2 files staying small) and the
# only countermeasure that has ever held in this registry is a check with fixtures either
# side of the line. A cap proven only by a passing tree is a cap nobody has tested.
#
# Run directly:  bash scripts/ac-budget-check.test.sh
# Discovered automatically by scripts/run-all-harnesses.sh (glob over *.test.sh).
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
CHECK="$DIR/ac-budget-check.sh"

FAILURES=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

# lines <n> — n lines of filler, so a fixture can sit exactly either side of a cap.
lines() { seq 1 "$1" | sed 's/^/line /'; }

# fix <name> — a MINIMAL conforming fixture root; callers mutate it per case.
#   ac-pipeline (the constitution, no subdirs) + ac-polish (points at one reference)
#   + one declared script. Everything under the caps.
fix() {
  local r="$WORK/$1"
  mkdir -p "$r/skills/ac-pipeline" "$r/skills/ac-polish/references" "$r/skills/ac-polish/scripts"
  lines 60 >"$r/skills/ac-pipeline/SKILL.md"
  { echo "Checklist: references/plan-checklist.md (mandatory load)"; lines 59; } \
    >"$r/skills/ac-polish/SKILL.md"
  lines 40 >"$r/skills/ac-polish/references/plan-checklist.md"
  cat >"$r/skills/ac-polish/scripts/demo.sh" <<'EOF'
#!/usr/bin/env bash
# PROBE:      demo.test.sh
# SCHEDULE:   every polish round
# MODE:       blocking
# ON-FAILURE: closed
EOF
  printf '%s' "$r"
}

run_on() { OUT=$(bash "$CHECK" "$1" 2>&1); RC=$?; }

# --- Case 1: NO ac2 skills at all -> NOT-GATED, never a silent pass -------------------
mkdir -p "$WORK/empty/skills"
run_on "$WORK/empty"
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "NOT-GATED"; then
  pass "Case 1: zero discovered ac2 skills fails closed with NOT-GATED"
else
  fail "Case 1: expected non-zero + NOT-GATED, got $RC. Output: $OUT"
fi

# --- Case 2: the minimal conforming fixture PASSES ------------------------------------
R=$(fix ok)
run_on "$R"
if [ "$RC" -eq 0 ]; then
  pass "Case 2: a conforming ac2 family PASSES"
else
  fail "Case 2: expected exit 0, got $RC. Output: $OUT"
fi

# --- Case 3: family SKILL.md cap — 800 passes, 801 fails ------------------------------
R=$(fix at800); lines 740 >"$R/skills/ac-pipeline/SKILL.md"   # 740 + 60 (polish) = 800
run_on "$R"
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "800/800"; then
  pass "Case 3a: a family of exactly 800 SKILL.md lines PASSES"
else
  fail "Case 3a: expected exit 0 at the boundary, got $RC. Output: $OUT"
fi
R=$(fix over800); lines 741 >"$R/skills/ac-pipeline/SKILL.md"
run_on "$R"
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "801/800"; then
  pass "Case 3b: 801 SKILL.md lines FAILS the family cap"
else
  fail "Case 3b: expected non-zero over the cap, got $RC. Output: $OUT"
fi

# --- Case 4: loaded-path cap — the reference counts toward 1,200 ----------------------
R=$(fix at1200); lines 400 >"$R/skills/ac-polish/references/plan-checklist.md"
lines 620 >"$R/skills/ac-pipeline/SKILL.md"          # 620 + 60 + 400 = 1080
run_on "$R"
if [ "$RC" -eq 0 ]; then
  pass "Case 4a: a worst path under the 1,200 target passes quietly"
else
  fail "Case 4a: expected exit 0, got $RC. Output: $OUT"
fi
R=$(fix over1200); lines 600 >"$R/skills/ac-polish/references/plan-checklist.md"
lines 620 >"$R/skills/ac-pipeline/SKILL.md"          # 620 + 60 + 600 = 1280
run_on "$R"
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "WARN worst path 1280 is over the 1200 target by 80"; then
  pass "Case 4b: a worst path over the 1,200 target WARNS with the overage named — and does NOT fail (a target, not a cap)"
else
  fail "Case 4b: expected exit 0 with a WARN naming 80 over, got $RC. Output: $OUT"
fi

# --- Case 5: the mandatory-load set is DERIVED from the pointers, not hardcoded -------
# A hardcoded list is exactly how per-file caps "held" while references/ grew ~11x.
R=$(fix derived)
lines 30 >"$R/skills/ac-polish/references/new.md"
{ echo "Also loads references/new.md at every invocation."; cat "$R/skills/ac-polish/SKILL.md"; } \
  >"$R/skills/ac-polish/SKILL.md.tmp" && mv "$R/skills/ac-polish/SKILL.md.tmp" "$R/skills/ac-polish/SKILL.md"
run_on "$R"
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "references/new.md"; then
  pass "Case 5: a newly pointed-at reference is COUNTED without touching the checker"
else
  fail "Case 5: the new reference was not counted, rc=$RC. Output: $OUT"
fi

# --- Case 6: a references file NOBODY points at is uncounted fat -> NOT-GATED --------
R=$(fix orphanref); lines 30 >"$R/skills/ac-polish/references/unpointed.md"
run_on "$R"
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "unpointed.md"; then
  pass "Case 6: a references file no SKILL.md points at is REJECTED as uncounted"
else
  fail "Case 6: expected non-zero naming the uncounted file, got $RC. Output: $OUT"
fi

# --- Case 7: a pointer to a reference that does not exist -> FAIL --------------------
R=$(fix dangling)
{ echo "Loads references/ghost.md every run."; cat "$R/skills/ac-polish/SKILL.md"; } \
  >"$R/x" && mv "$R/x" "$R/skills/ac-polish/SKILL.md"
run_on "$R"
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "ghost.md"; then
  pass "Case 7: a pointer to a missing reference FAILS (a pointer nobody kept)"
else
  fail "Case 7: expected non-zero naming the missing reference, got $RC. Output: $OUT"
fi

# --- Case 9: assurance declarations for ac2 scripts (Check 21 cannot see these) ------
R=$(fix undeclared); printf '#!/usr/bin/env bash\necho hi\n' >"$R/skills/ac-polish/scripts/demo.sh"
run_on "$R"
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "demo.sh"; then
  pass "Case 9a: an ac2 script with no assurance declarations FAILS"
else
  fail "Case 9a: expected non-zero naming the script, got $RC. Output: $OUT"
fi
R=$(fix noscripts); rm -rf "$R/skills/ac-polish/scripts"
run_on "$R"
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "NOT-GATED"; then
  pass "Case 9b: a discovery set resolving to ZERO scripts is NOT-GATED, not a pass"
else
  fail "Case 9b: expected non-zero + NOT-GATED, got $RC. Output: $OUT"
fi

# --- Case 11: pointed-at canon is REPORTED, never capped ----------------------------
R=$(fix canon); mkdir -p "$R/skills/beads-standards/reference"
lines 5000 >"$R/skills/beads-standards/reference/bead-conventions.md"
{ echo "Bead canon by pointer: skills/beads-standards/reference/bead-conventions.md"; cat "$R/skills/ac-polish/SKILL.md"; } \
  >"$R/x" && mv "$R/x" "$R/skills/ac-polish/SKILL.md"
run_on "$R"
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "pointed-at canon 5000"; then
  pass "Case 11: 5,000 lines of pointed-at canon are REPORTED and do not fail the check"
else
  fail "Case 11: expected exit 0 with the canon line count reported, got $RC. Output: $OUT"
fi

# --- Case 13: a relative pointer at a SIBLING's reference resolves family-wide -------
# ac-plan names ac-polish's checklist as its bar. That is a real pointer, not a dangling
# one — but an AMBIGUOUS basename must still fail, or the counted file is a coin toss.
R=$(fix sibling)
mkdir -p "$R/skills/ac-plan"
{ echo "Its references/plan-checklist.md is the bar."; lines 20; } >"$R/skills/ac-plan/SKILL.md"
run_on "$R"
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "ac-polish/references/plan-checklist.md"; then
  pass "Case 13a: a sibling's reference resolves family-wide and is counted ONCE"
else
  fail "Case 13a: expected exit 0 counting the sibling reference, got $RC. Output: $OUT"
fi
mkdir -p "$R/skills/ac-plan/references"; lines 10 >"$R/skills/ac-plan/references/plan-checklist.md"
run_on "$R"
if [ "$RC" -eq 0 ]; then
  pass "Case 13b: with its own copy present, the citing skill's own file wins (no ambiguity)"
else
  fail "Case 13b: expected exit 0, got $RC. Output: $OUT"
fi

# --- Case 14: workflows/ is MANDATORY LOAD and is COUNTED ------------------------------
# It was counted as zero for 145 lines in the heaviest skill while the header said "fat
# cannot hide either way". This case is the sensor that stops it hiding again.
R=$(fix wf-counted)
mkdir -p "$R/skills/ac-polish/workflows"; lines 25 >"$R/skills/ac-polish/workflows/plan.md"
{ cat "$R/skills/ac-polish/SKILL.md"; printf '\n| mode | workflow | checklist |\n| --- | --- | --- |\n| `plan` | `workflows/plan.md` | `references/plan-checklist.md` |\n'; } \
  >"$R/skills/ac-polish/SKILL.md.tmp" && mv "$R/skills/ac-polish/SKILL.md.tmp" "$R/skills/ac-polish/SKILL.md"
run_on "$R"
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "workflows/plan.md (25 lines, mode plan"; then
  pass "Case 14: a workflows/ file is COUNTED, and attributed to its mode"
else
  fail "Case 14: workflows/ not counted or not scoped, rc=$RC. Output: $OUT"
fi

# --- Case 15: mode-scoped files count ONLY the heaviest mode -----------------------------
# Three modes: 20, 60 and 40 lines. Worst path must add 60, not 120. Anything else charges
# the skill for loads that never happen together.
R=$(fix heaviest)
mkdir -p "$R/skills/ac-polish/workflows"
lines 20 >"$R/skills/ac-polish/references/a.md"; lines 60 >"$R/skills/ac-polish/references/b.md"; lines 40 >"$R/skills/ac-polish/references/c.md"
lines 40 >"$R/skills/ac-polish/references/plan-checklist.md"   # keep the fixture's own pointer valid
{ printf 'Checklist: references/plan-checklist.md (mandatory load)\n'; lines 59
  printf '\n| mode | checklist |\n| --- | --- |\n| `a` | `references/a.md` |\n| `b` | `references/b.md` |\n| `c` | `references/c.md` |\n'; } \
  >"$R/skills/ac-polish/SKILL.md"
run_on "$R"
# The claim is STRUCTURAL, not a magic number: total counts all three modes, worst counts only
# the heaviest, so total - worst must equal exactly the two modes left out (a=20 + c=40 = 60).
W=$(echo "$OUT" | sed -nE 's/.*worst path ([0-9]+)\/.*/\1/p'); T=$(echo "$OUT" | sed -nE 's/.*total inventory ([0-9]+) .*/\1/p')
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "heaviest mode is b (60 lines)" \
   && [ -n "$W" ] && [ -n "$T" ] && [ $(( T - W )) -eq 60 ]; then
  pass "Case 15: worst path adds the HEAVIEST mode only — total exceeds it by exactly the two modes left out (60)"
else
  fail "Case 15: expected total - worst = 60 with heaviest=b, got worst=$W total=$T rc=$RC. Output: $OUT"
fi

# --- Case 16: workflows/ with NO mode table is NOT-GATED ----------------------------------
# Workflows are mode-bound by construction. If the table cannot be read, the worst path is a
# guess, and a guess is not claimed.
R=$(fix wf-notable)
mkdir -p "$R/skills/ac-polish/workflows"; lines 10 >"$R/skills/ac-polish/workflows/x.md"
{ cat "$R/skills/ac-polish/SKILL.md"; echo "See workflows/x.md."; } \
  >"$R/skills/ac-polish/SKILL.md.tmp" && mv "$R/skills/ac-polish/SKILL.md.tmp" "$R/skills/ac-polish/SKILL.md"
run_on "$R"
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "NOT-GATED.*no mode table"; then
  pass "Case 16: workflows/ without a mode table is NOT-GATED — the worst path is not claimed"
else
  fail "Case 16: expected NOT-GATED on an unscoped workflows/, rc=$RC. Output: $OUT"
fi

# --- Case 17: a mode row naming a missing file FAILS ----------------------------------------
R=$(fix mode-dangling)
{ cat "$R/skills/ac-polish/SKILL.md"; printf '\n| mode | checklist |\n| --- | --- |\n| `ghost` | `references/ghost.md` |\n'; } \
  >"$R/skills/ac-polish/SKILL.md.tmp" && mv "$R/skills/ac-polish/SKILL.md.tmp" "$R/skills/ac-polish/SKILL.md"
run_on "$R"
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "mode 'ghost' names 'references/ghost.md', which does not exist"; then
  pass "Case 17: a mode row pointing at nothing FAILS, naming the mode and the file"
else
  fail "Case 17: dangling mode row not refused, rc=$RC. Output: $OUT"
fi

# --- Case 18: a workflows/ file nobody points at is UNCOUNTED FAT ---------------------------
R=$(fix wf-orphan)
mkdir -p "$R/skills/ac-polish/workflows"; lines 10 >"$R/skills/ac-polish/workflows/orphan.md"
run_on "$R"
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "workflows/orphan.md exists but no lean SKILL.md points at it"; then
  pass "Case 18: an unpointed workflows/ file is rejected as uncounted fat, same as references/"
else
  fail "Case 18: orphan workflow not rejected, rc=$RC. Output: $OUT"
fi

# --- Case 19: a FOREIGN-skill reference path is a citation, not a family load ------------
# `skill-builder/references/x.md` is shared canon cited by pointer. Its bare tail
# `references/x.md` used to match and resolve against the citing skill, failing on a file
# that exists. (ac-check23-leg2-cross-family-citation-gy75 — both swarm workers hit it.)
R=$(fix foreign-cite)
{ cat "$R/skills/ac-polish/SKILL.md"; echo "Litmus: skill-builder/references/structure-standard.md § shape."; } \
  >"$R/skills/ac-polish/SKILL.md.tmp" && mv "$R/skills/ac-polish/SKILL.md.tmp" "$R/skills/ac-polish/SKILL.md"
run_on "$R"
if [ "$RC" -eq 0 ] && ! echo "$OUT" | grep -q "structure-standard"; then
  pass "Case 19: a foreign-skill references/ path is NOT resolved against the citing skill"
else
  fail "Case 19: foreign citation still misread as a dangling family pointer, rc=$RC. Output: $OUT"
fi
# ...while a genuinely dangling FAMILY-LOCAL pointer must still fail — do not fix this by widening.
R=$(fix local-dangling)
{ cat "$R/skills/ac-polish/SKILL.md"; echo "See references/does-not-exist.md."; } \
  >"$R/skills/ac-polish/SKILL.md.tmp" && mv "$R/skills/ac-polish/SKILL.md.tmp" "$R/skills/ac-polish/SKILL.md"
run_on "$R"
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "does-not-exist.md', which does not exist"; then
  pass "Case 19b: a dangling FAMILY-LOCAL pointer still FAILS — the fix did not widen the check into uselessness"
else
  fail "Case 19b: local dangling pointer no longer refused, rc=$RC. Output: $OUT"
fi

# --- Case 12: the REAL registry passes its own check --------------------------------
run_on "$ROOT"
if [ "$RC" -eq 0 ]; then
  pass "Case 12: the shipped ac2 family satisfies every leg"
else
  fail "Case 12: the real repo does not satisfy the check, rc=$RC. Output: $OUT"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All ac-budget-check fixture tests passed."
  exit 0
else
  echo "$FAILURES fixture test(s) FAILED."
  exit 1
fi
