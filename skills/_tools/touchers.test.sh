#!/usr/bin/env bash
# touchers.test.sh — fixture tests for skills/_tools/touchers.sh.
#
# The tree the counts come from is a FIXTURE, not the live registry: three small files under
# skills/_tools/fixtures/touchers/ make "exists in the tree" and "is referenced by another
# file" true and stable, and every DECLARED command in a fixture description is scoped to
# that directory. A harness whose expected counts move whenever an unrelated file mentions a
# path is a flake, and a flake is not evidence.
#
# Both polarities, always: a check that refuses everything satisfies the REFUSED cases alone,
# and a check that refuses nothing satisfies the OK cases alone. The three defects measured
# 2026-09-06 each get their own case — the phantom obligation (Case 4), the per-bullet
# scoping the flat read lost (Cases 5 and 9), plus the NOT-GATED control (Case 10).
#
# Run directly:  bash skills/_tools/touchers.test.sh
# Discovered automatically by scripts/run-all-harnesses.sh (glob over *.test.sh).
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
TOOL="$DIR/touchers.sh"
FIXDIR_REL="skills/_tools/fixtures/touchers"
TARGET="$FIXDIR_REL/tchr-target.md"
REFONE="$FIXDIR_REL/ref-one.md"
REFTWO="$FIXDIR_REL/ref-two.md"

FAILURES=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }

cd "$ROOT" || { echo "HARNESS FAIL: cannot enter $ROOT"; exit 1; }
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

# Preconditions. A missing fixture would make every case below vacuously green.
for f in "$TOOL" "$TARGET" "$REFONE" "$REFTWO"; do
  [ -f "$ROOT/$f" ] || [ -f "$f" ] || { echo "HARNESS FAIL: missing $f"; exit 1; }
done

# The declared commands, scoped to the fixture dir so their counts cannot drift with the
# registry: the target is referenced by both siblings (2), ref-one by ref-two alone (1).
CMD_TARGET="rg -l -F \"touchers/tchr-target\" $FIXDIR_REL -g \"!$TARGET\""
CMD_REFONE="rg -l -F \"touchers/ref-one\" $FIXDIR_REL -g \"!$REFONE\""

write_desc() { printf '%s' "$2" >"$WORK/$1"; printf '%s' "$WORK/$1"; }
run_check() { OUT=$(bash "$TOOL" check "$1" "${2:-fx}" 2>&1); RC=$?; }

# --- Case 1: a well-formed line whose command reproduces its count -> OK ----------------
D=$(write_desc ok.md "## Delivers
- \`$TARGET\` — the fixture artifact
  touchers: \`$CMD_TARGET\` → 2 · owned by: bd-fixture-refs
")
run_check "$D" ok
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "touchers: OK"; then
  pass "Case 1: a touchers line whose command reproduces its count is accepted (touchers: OK, exit 0)"
else
  fail "Case 1: expected exit 0 + 'touchers: OK', got $RC. Output: $OUT"
fi

# --- Case 2: an existing, referenced path with NO line -> REFUSED ----------------------
D=$(write_desc missing.md "## Delivers
- \`$TARGET\` — the fixture artifact
")
run_check "$D" missing
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "touchers: REFUSED" \
   && echo "$OUT" | grep -q "unowned-touchers" && echo "$OUT" | grep -q "referenced by"; then
  pass "Case 2: a referenced Delivers path with no touchers line is REFUSED [unowned-touchers] (exit 1)"
else
  fail "Case 2: expected exit 1 + unowned-touchers, got $RC. Output: $OUT"
fi

# --- Case 3: a STALE count -> REFUSED, naming both numbers ------------------------------
# The list being stale WHEN USED is the defect this gate exists for, so a count that no
# longer reproduces is refused exactly like a missing line.
D=$(write_desc stale.md "## Delivers
- \`$TARGET\` — the fixture artifact
  touchers: \`$CMD_TARGET\` → 7 · owned by: bd-fixture-refs
")
run_check "$D" stale
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "declare → 7 but the command reproduces 2"; then
  pass "Case 3: a stale touchers count is REFUSED, naming the declared and the reproduced count"
else
  fail "Case 3: expected exit 1 naming both counts, got $RC. Output: $OUT"
fi

# --- Case 4: a path that appears ONLY inside a touchers disposition owes NOTHING --------
# The measured defect (2026-09-06): the path regex ran over the whole Delivers section,
# touchers lines included, so a path named inside a command's -g glob or inside the reason
# grew a phantom obligation that no bullet could ever satisfy.
D=$(write_desc phantom.md "## Delivers
- \`$TARGET\` — the fixture artifact
  touchers: \`$CMD_TARGET\` → 2 · owned by: bd-fixture-refs (which also owns $REFONE)
")
run_check "$D" phantom
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "touchers: OK"; then
  pass "Case 4: a path named only inside a touchers disposition creates NO obligation (exit 0)"
else
  fail "Case 4: expected exit 0 — the disposition's own text is not a delivery, got $RC. Output: $OUT"
fi

# --- Case 5: TWO existing paths under one bullet -> REFUSED (one path per bullet) -------
# One touchers line cannot own two paths: the old reader answered for the second path with
# the FIRST line's count, so the second went silently unchecked. Refuse the shape instead.
D=$(write_desc multi.md "## Delivers
- \`$TARGET\` and \`$REFONE\` — two artifacts under one bullet
  touchers: \`$CMD_TARGET\` → 2 · owned by: bd-fixture-refs
")
run_check "$D" multi
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "one path per Delivers bullet"; then
  pass "Case 5: a bullet naming two existing paths is REFUSED by the one-path-per-bullet rule"
else
  fail "Case 5: expected exit 1 naming the one-path rule, got $RC. Output: $OUT"
fi

# --- Case 6: a path that does not exist yet owes nothing --------------------------------
D=$(write_desc new.md "## Delivers
- \`$FIXDIR_REL/not-yet-written.md\` — an artifact this bead creates
")
run_check "$D" new
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "touchers: OK"; then
  pass "Case 6: a Delivers path absent from the tree is a NEW artifact and owes no line (exit 0)"
else
  fail "Case 6: expected exit 0 for a new artifact, got $RC. Output: $OUT"
fi

# --- Case 7: derive prints the stem, the count, and a command that reproduces it --------
DER=$(bash "$TOOL" derive "$TARGET" 2>&1); RC=$?
D_STEM=$(printf '%s' "$DER" | cut -f1)
D_N=$(printf '%s' "$DER" | cut -f2)
D_CMD=$(printf '%s' "$DER" | cut -f3-)
D_REPRO=$(bash -c "$D_CMD" 2>/dev/null | grep -c .)
D_HITS=$(bash -c "$D_CMD" 2>/dev/null)
if [ "$RC" -eq 0 ] && [ "$D_STEM" = "touchers/tchr-target" ] && [ "${D_N:-0}" -ge 2 ] \
   && [ "$D_REPRO" = "$D_N" ] \
   && printf '%s\n' "$D_HITS" | grep -q "$REFONE" && printf '%s\n' "$D_HITS" | grep -q "$REFTWO"; then
  pass "Case 7: derive on an existing referenced path prints stem/N/command, and the command reproduces N ($D_N, including both fixture referrers)"
else
  fail "Case 7: expected a self-reproducing derivation, rc=$RC stem='$D_STEM' n='$D_N' reproduced='$D_REPRO'. Output: $DER"
fi

# --- Case 8: derive on a path that does not exist prints `new` --------------------------
DER=$(bash "$TOOL" derive "$FIXDIR_REL/not-yet-written.md" 2>&1); RC=$?
if [ "$RC" -eq 0 ] && [ "$DER" = "new" ]; then
  pass "Case 8: derive on a not-yet-existing path prints 'new' (exit 0) — a new artifact owes nothing"
else
  fail "Case 8: expected 'new' with exit 0, got rc=$RC output '$DER'"
fi

# --- Case 9: the SECOND bullet's obligation is judged against its OWN line --------------
# The per-bullet scoping, stated as a test: bullet 1 carries a valid line, bullet 2 carries
# none. A reader that searches the whole section finds bullet 1's line for bullet 2 and
# passes this description — which is exactly the silent hole.
D=$(write_desc second.md "## Delivers
- \`$TARGET\` — the fixture artifact
  touchers: \`$CMD_TARGET\` → 2 · owned by: bd-fixture-refs
- \`$REFONE\` — a second delivered file, referenced by its sibling
")
run_check "$D" second
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "unowned-touchers" && echo "$OUT" | grep -Fq "$REFONE"; then
  pass "Case 9: a second bullet with no line of its own is REFUSED — the line is read per bullet, not per section"
else
  fail "Case 9: expected exit 1 naming $REFONE, got $RC. Output: $OUT"
fi

# --- Case 9b: the same two bullets, each with its own line -> OK ------------------------
# The negative pole of Case 9: per-bullet reading must still ACCEPT a fully-owned pair, or
# Case 9 would be satisfied by a checker that refuses every multi-bullet Delivers.
D=$(write_desc secondok.md "## Delivers
- \`$TARGET\` — the fixture artifact
  touchers: \`$CMD_TARGET\` → 2 · owned by: bd-fixture-refs
- \`$REFONE\` — a second delivered file, referenced by its sibling
  touchers: \`$CMD_REFONE\` → 1 · out-of-scope: ref-two is a fixture and is rewritten wholesale
")
run_check "$D" secondok
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "touchers: OK"; then
  pass "Case 9b: two bullets, each with its own reproducing line, are ACCEPTED (exit 0)"
else
  fail "Case 9b: expected exit 0, got $RC. Output: $OUT"
fi

# --- Case 10: NOT-GATED — when rg cannot run, nothing is read as zero -------------------
# A missing or broken rg reads as "zero references" only if the tool ignores its exit code.
# That is the silent pass this case pins shut; the shim lives in its own dir so every other
# case keeps the real rg.
NORG="$WORK/norg"; mkdir -p "$NORG"
printf '#!/usr/bin/env bash\nexit 127\n' >"$NORG/rg"; chmod +x "$NORG/rg"
D=$(write_desc notgated.md "## Delivers
- \`$TARGET\` — the fixture artifact
  touchers: \`$CMD_TARGET\` → 2 · owned by: bd-fixture-refs
")
OUT=$(PATH="$NORG:$PATH" bash "$TOOL" check "$D" notgated 2>&1); RC=$?
if [ "$RC" -eq 2 ] && echo "$OUT" | grep -q "NOT-GATED" && echo "$OUT" | grep -q "rg exited 127"; then
  pass "Case 10: NOT-GATED (exit 2) when rg cannot run — the count is unknown, never zero"
else
  fail "Case 10: expected exit 2 + NOT-GATED naming rg's exit code, got $RC. Output: $OUT"
fi

# --- Case 11: a malformed line (no owned-by / out-of-scope) -> REFUSED ------------------
D=$(write_desc malformed.md "## Delivers
- \`$TARGET\` — the fixture artifact
  touchers: \`$CMD_TARGET\` → 2
")
run_check "$D" malformed
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "malformed"; then
  pass "Case 11: a touchers line naming no owner and no out-of-scope reason is REFUSED as malformed"
else
  fail "Case 11: expected exit 1 + malformed, got $RC. Output: $OUT"
fi

# --- Case 12: the worked example shipped in bead-schema.md is VALID under this gate -----
# The contract ac-beadify compiles to is a real file, not a fixture invented here: if the
# shipped example stops passing, the schema teaches a shape its own gate refuses.
SCHEMA="$ROOT/skills/ac-beadify/references/bead-schema.md"
if [ ! -f "$SCHEMA" ]; then
  fail "Case 12: $SCHEMA is missing — the schema whose example this gate judges does not exist"
else
  sed -n '/ac-example-bead:start/,/ac-example-bead:end/p' "$SCHEMA" >"$WORK/schema-example.md"
  run_check "$WORK/schema-example.md" bead-schema-example
  if [ "$RC" -eq 0 ]; then
    pass "Case 12: the worked example in bead-schema.md passes touchers_check (exit 0)"
  else
    fail "Case 12: the shipped example bead was REFUSED, got $RC. Output: $OUT"
  fi
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All touchers fixture tests passed."
  exit 0
else
  echo "$FAILURES fixture test(s) FAILED."
  exit 1
fi
