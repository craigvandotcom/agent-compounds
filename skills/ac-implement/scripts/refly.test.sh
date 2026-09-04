#!/usr/bin/env bash
#
# refly.test.sh — proof harness for refly.sh.
#
# ASSURANCE
#   PROBE:      this file IS the probe — bash skills/ac-implement/scripts/refly.test.sh
#   SCHEDULE:   every scripts/run-all-harnesses.sh run (repo-wide *.test.sh discovery),
#               which lint.sh Check 20 audits for scheduling.
#   MODE:       blocking
#   ON-FAILURE: closed
#
# Proves the three things refly.sh may and may not do: it STRIPS the stamp from a bead whose
# premises hold again, it LEAVES a bead whose premises still fail, and it TOUCHES NOTHING
# when it cannot verify (dry-run, or br absent). A hermetic br shim records every write.
#
# Exit 0  every case passed · Exit 1  at least one failed
#
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REFLY="$HERE/refly.sh"

PASS=0; FAIL=0
ok()  { PASS=$(( PASS + 1 )); echo "  ok   — $*"; }
bad() { FAIL=$(( FAIL + 1 )); echo "  FAIL — $*"; }

[ -x "$REFLY" ] || { echo "refly.test: refly.sh missing or not executable at $REFLY"; exit 1; }

WORK=$(mktemp -d "${TMPDIR:-/tmp}/ac-refly-test.XXXXXX") || { echo "refly.test: cannot create scratch dir"; exit 1; }
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/root" "$WORK/bin"
: >"$WORK/root/present-artifact.md"
WRITES="$WORK/br-writes.log"; : >"$WRITES"

# Two stamped beads on a fake board. `flies` consumes a closed blocker whose artifact is on
# the tree and names a probe that is RED. `stuck` names a probe that is already GREEN, so
# flight-check still refuses it. The shim logs every update/comment it receives.
cat >"$WORK/bin/br" <<'STUB'
#!/usr/bin/env bash
FLIES_BODY='## Acceptance Criteria\n- Something.\n  Probe: `test -e ./nope.md` — tier: none\n\n## Consumes\n- upstream -> ./present-artifact.md (landed)\n'
STUCK_BODY='## Acceptance Criteria\n- Something.\n  Probe: `test -e ./present-artifact.md` — tier: none\n\n## Consumes\n- none\n'
case "${1:-}" in
  list)
    printf '{"issues":[{"id":"flies","status":"open","title":"PREMISE-FAILED: fix(x): flies again"},{"id":"stuck","status":"open","title":"PREMISE-FAILED: fix(y): still green"},{"id":"upstream","status":"closed","title":"done"},{"id":"plain","status":"open","title":"fix(z): never stamped"}]}\n' ;;
  show)
    case "${2:-}" in
      flies)    printf '[{"id":"flies","status":"open","title":"PREMISE-FAILED: fix(x): flies again","description":"%s"}]\n' "$FLIES_BODY" ;;
      stuck)    printf '[{"id":"stuck","status":"open","title":"PREMISE-FAILED: fix(y): still green","description":"%s"}]\n' "$STUCK_BODY" ;;
      upstream) echo '[{"id":"upstream","status":"closed","title":"done"}]' ;;
      *) exit 3 ;;
    esac ;;
  update|comments) echo "$*" >>"$BR_WRITES" ;;
  *) echo '{}' ;;
esac
STUB
chmod +x "$WORK/bin/br"

run() {
  RUN_OUT=$(env BR_WRITES="$WRITES" PATH="$WORK/bin:$PATH" bash "$REFLY" --root "$WORK/root" "$@" 2>&1)
  RUN_RC=$?
}

# ---------------------------------------------------------------------------------------
echo "refly.test: case 1 — strip the flyable, leave the stuck, ignore the unstamped"
# ---------------------------------------------------------------------------------------
run
[ "$RUN_RC" -eq 0 ] && ok "refly exits 0 after re-checking" || bad "expected exit 0, got $RUN_RC: $RUN_OUT"
grep -q -- 'update flies --title fix(x): flies again' "$WRITES" \
  && ok "flyable bead: stamp stripped, title otherwise untouched" \
  || bad "flyable bead: no clean-title update recorded: $(cat "$WRITES")"
grep -q -- 'comments add flies' "$WRITES" && ok "flyable bead: repair comment recorded" \
  || bad "flyable bead: no repair comment"
grep -q -- 'update stuck' "$WRITES" && bad "stuck bead: its title was touched" \
  || ok "stuck bead: left stamped"
printf '%s' "$RUN_OUT" | grep -q 'stuck — still stamped: PREMISE-FAILED: RED' \
  && ok "stuck bead: the surviving refusal is reported by class" \
  || bad "stuck bead: refusal class not reported: $RUN_OUT"
grep -q -- 'plain' "$WRITES" && bad "an unstamped bead was written to" || ok "unstamped bead: never considered"
grep -qE -- '--status|--assignee' "$WRITES" && bad "refly unclaimed something — it must never" \
  || ok "refly never unclaims"

# ---------------------------------------------------------------------------------------
echo "refly.test: case 2 — --dry-run reports and writes nothing"
# ---------------------------------------------------------------------------------------
: >"$WRITES"
run --dry-run
[ "$RUN_RC" -eq 0 ] && ok "dry-run exits 0" || bad "dry-run: expected exit 0, got $RUN_RC"
printf '%s' "$RUN_OUT" | grep -q 'would strip the stamp' && ok "dry-run names what it would strip" \
  || bad "dry-run: no would-strip line: $RUN_OUT"
[ ! -s "$WRITES" ] && ok "dry-run wrote nothing to the board" || bad "dry-run wrote: $(cat "$WRITES")"

# ---------------------------------------------------------------------------------------
echo "refly.test: case 3 — cannot verify -> NOT-GATED, nothing touched"
# ---------------------------------------------------------------------------------------
: >"$WRITES"
NOBR="$WORK/nobr"; mkdir -p "$NOBR"
for t in bash jq git sed grep printf date mktemp dirname cat awk sh env; do
  p=$(command -v "$t" 2>/dev/null) && ln -sf "$p" "$NOBR/$t"
done
RUN_OUT=$(env BR_WRITES="$WRITES" PATH="$NOBR" bash "$REFLY" --root "$WORK/root" 2>&1); RUN_RC=$?
[ "$RUN_RC" -eq 2 ] && ok "no br on PATH exits 2" || bad "no br: expected exit 2, got $RUN_RC: $RUN_OUT"
printf '%s' "$RUN_OUT" | grep -q 'NOT-GATED' && ok "no br: says NOT-GATED" || bad "no br: silent: $RUN_OUT"
[ ! -s "$WRITES" ] && ok "no br: wrote nothing" || bad "no br: wrote: $(cat "$WRITES")"

# ---------------------------------------------------------------------------------------
echo ""
echo "refly.test: $PASS passed, $FAIL failed"
[ "$PASS" -gt 0 ] || { echo "refly.test: NOT-GATED — zero cases ran"; exit 1; }
[ "$FAIL" -eq 0 ]
