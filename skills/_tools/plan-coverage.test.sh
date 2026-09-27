#!/usr/bin/env bash
# plan-coverage.test.sh — fixture tests for plan-coverage.sh, both polarities.
# A fake br (AC2_BR_CMD) serves the epic's children; no live board is read.
# Run directly:  bash skills/_tools/plan-coverage.test.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$DIR/plan-coverage.sh"

FAILURES=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

# Fake br: `show` answers from $WORK/show.json, `list` from $WORK/list.json; FAKE_BR_FAIL=1
# returns the error envelope br emits on a dead read.
cat >"$WORK/br" <<'SH'
#!/usr/bin/env bash
[ "${FAKE_BR_FAIL:-0}" = 1 ] && { echo '{"error":{"message":"db locked"}}'; exit 3; }
case "$1" in show) cat "$FAKE_DIR/show.json" ;; list) cat "$FAKE_DIR/list.json" ;; esac
SH
chmod +x "$WORK/br"
export AC2_BR_CMD="$WORK/br" FAKE_DIR="$WORK"

# Epic ep with a dotted child ep.1 and a non-dotted child ac-x (parent-child edge only).
echo '{"id":"ep","dependents":[
  {"id":"ep.1","dependency_type":"parent-child"},
  {"id":"ac-x","dependency_type":"parent-child"},
  {"id":"ac-y","dependency_type":"blocks"}]}' >"$WORK/show.json"
beads() {  # $1 = ep.1 AC text, $2 = ac-x AC text
  jq -n --arg a "$1" --arg b "$2" '{issues:[
    {id:"ep",   description:"## Success Criteria\nvision"},
    {id:"ep.1", description:("## Acceptance Criteria\n- " + $a + " Probe: `true`")},
    {id:"ac-x", description:("## Acceptance Criteria\n- " + $b + " Probe: `true`")},
    {id:"ac-y", description:"Done when: the cache is warm"}]}' >"$WORK/list.json"
}
cat >"$WORK/plan.md" <<'MD'
## Deliverables
- `a.sh` — does A.
  Done when: `a.sh` prints OK for input 1
  and exits 0.
- `b.sh` — does B.
  Done when: the cache is warm
MD
run() { OUT=$(bash "$CHECK" "$WORK/plan.md" ep 2>&1); RC=$?; }

beads 'Done when: `a.sh` prints OK for input 1 and exits 0.' 'Done when: the cache is warm'
run
[ "$RC" -eq 0 ] && [ "$OUT" = "COVERED 2" ] \
  && pass "every line quoted (wrapped line, non-dotted child) -> COVERED 2" \
  || fail "covered plan: expected rc 0 COVERED 2, got $RC: $OUT"

beads 'Done when: `a.sh` prints OK for input 1 and exits 0.' 'something else'
run
[ "$RC" -eq 1 ] && echo "$OUT" | grep -qx 'COVERAGE GAP: the cache is warm' \
  && pass "dropped deliverable -> COVERAGE GAP (a blocks-only bead does not count)" \
  || fail "dropped deliverable: expected rc 1 naming the line, got $RC: $OUT"

beads 'Done when: `a.sh` prints OK for input 1.' 'Done when: the cache is warm'
run
[ "$RC" -eq 1 ] && echo "$OUT" | grep -q '^COVERAGE GAP: `a.sh` prints OK for input 1 and exits 0.$' \
  && pass "reworded quote -> COVERAGE GAP" \
  || fail "reworded quote: expected rc 1, got $RC: $OUT"

beads 'Done when: `a.sh` prints OK for input 1 and exits 0.' 'something else'
jq '.issues[0].description = "## Success Criteria\nDone when: the cache is warm"' "$WORK/list.json" \
  >"$WORK/l.tmp" && mv "$WORK/l.tmp" "$WORK/list.json"
run
[ "$RC" -eq 1 ] && echo "$OUT" | grep -qx 'COVERAGE GAP: the cache is warm' \
  && pass "line quoted only by the epic -> COVERAGE GAP (the epic never covers)" \
  || fail "epic-only quote: expected rc 1 naming the line, got $RC: $OUT"

printf '## Deliverables\n- `a.sh` — does A.\n' >"$WORK/plan.md"
run
[ "$RC" -eq 1 ] && echo "$OUT" | grep -q '^REFUSED no-done-when' \
  && pass "plan with no Done when -> REFUSED" \
  || fail "no Done when: expected rc 1 REFUSED, got $RC: $OUT"

OUT=$(FAKE_BR_FAIL=1 bash "$CHECK" "$WORK/plan.md" ep 2>/dev/null); RC=$?
[ "$RC" -eq 2 ] && echo "$OUT" | grep -q '^NOT-GATED' \
  && pass "br refusal -> NOT-GATED, never COVERED" \
  || fail "br refusal: expected rc 2 NOT-GATED, got $RC: $OUT"

[ "$FAILURES" -eq 0 ] && { echo "plan-coverage.test.sh: all passed"; exit 0; }
echo "plan-coverage.test.sh: $FAILURES failed"; exit 1
