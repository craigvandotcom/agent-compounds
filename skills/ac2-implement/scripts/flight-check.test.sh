#!/usr/bin/env bash
#
# flight-check.test.sh — the RED/GREEN proof harness for flight-check.sh (ac-k25c.2).
#
# ASSURANCE
#   PROBE:      this file IS the probe — bash skills/ac2-implement/scripts/flight-check.test.sh
#   SCHEDULE:   every scripts/run-all-harnesses.sh run (repo-wide *.test.sh discovery),
#               which lint.sh Check 20 audits for scheduling.
#   MODE:       blocking
#   ON-FAILURE: closed
#
# It proves the four named refusals FIRE and NAME THEMSELVES, that the flight receipt
# carries the RED assertion fingerprint close-gate hash-locks against, that the fingerprint
# has the two declared scopes from ONE writer, and — the load-bearing one — that a post-fix
# re-fingerprint is STRUCTURALLY unreachable rather than merely discouraged.
#
# Every case drives the real script against a synthetic bead body in a scratch root, with
# AC2_DRY_RUN=1 so the premise-failure routing is asserted without touching a board.
#
# Exit 0  every case passed · 77 self-skip (precondition this harness cannot provision)
# Exit 1  at least one case failed
#
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
GATE="$HERE/flight-check.sh"

PASS=0
FAIL=0
ok()   { PASS=$(( PASS + 1 )); echo "  ok   — $*"; }
bad()  { FAIL=$(( FAIL + 1 )); echo "  FAIL — $*"; }

if [ ! -x "$GATE" ]; then
  echo "flight-check.test: flight-check.sh missing or not executable at $GATE"
  exit 1
fi
if ! command -v shasum >/dev/null 2>&1 && ! command -v sha256sum >/dev/null 2>&1; then
  echo "flight-check.test: SKIP — no sha256 tool on this box; the fingerprint leg cannot run"
  exit 77
fi

WORK=$(mktemp -d -t ac2-flight-test) || { echo "flight-check.test: cannot create scratch dir"; exit 1; }
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/root" "$WORK/receipts" "$WORK/bodies"
: >"$WORK/root/present-artifact.md"
printf 'assert one\nassert two\n' >"$WORK/root/existing-harness.test.sh"

# run <body-file> [extra env assignments…] -> stdout+stderr in RUN_OUT, status in RUN_RC
RUN_OUT=""
RUN_RC=0
run() {
  local body="$1"; shift
  RUN_OUT=$(env AC2_DRY_RUN=1 AC2_FLIGHT_DIR="$WORK/receipts" "$@" \
    bash "$GATE" ac-test-0001 --body-file "$body" --root "$WORK/root" 2>&1)
  RUN_RC=$?
}

# ---------------------------------------------------------------------------------------
echo "flight-check.test: case 1 — premises hold and a RED is observed -> cleared, receipt written"
# ---------------------------------------------------------------------------------------
cat >"$WORK/bodies/clear.md" <<'BODY'
## Intent
A bead whose premises hold and whose second probe is honestly red.

## Acceptance Criteria
- The thing that already holds.
  Probe: `true` — tier: none
- The thing this bead has yet to build.
  Probe: `test -e ./not-built-yet.md` — tier: none

## Consumes
- none
BODY
run "$WORK/bodies/clear.md"
[ "$RUN_RC" -eq 0 ] && ok "exit 0 when premises hold" || bad "expected exit 0, got $RUN_RC: $RUN_OUT"
RECEIPT="$WORK/receipts/ac-test-0001.flight-receipt"
if [ -f "$RECEIPT" ]; then
  ok "the flight receipt was written"
  grep -q '^FLIGHT-RECEIPT v1' "$RECEIPT" && ok "receipt carries its format marker" \
    || bad "receipt has no FLIGHT-RECEIPT version marker"
  grep -qE '^red-fingerprint: sha256:[0-9a-f]{64}$' "$RECEIPT" \
    && ok "receipt RECORDS the RED assertion fingerprint close-gate hash-locks against" \
    || bad "receipt carries no sha256 red-fingerprint — close-gate cannot lock against an absent field"
  grep -q "^red-probe: test -e ./not-built-yet.md$" "$RECEIPT" \
    && ok "the recorded RED is the probe that actually failed, not the green one" \
    || bad "receipt names the wrong RED probe: $(grep '^red-probe:' "$RECEIPT")"
  grep -q '^premise: PASS' "$RECEIPT" && ok "receipt records the premise pass it rests on" \
    || bad "receipt does not record the premise pass"
else
  bad "no receipt at $RECEIPT"
fi

# ---------------------------------------------------------------------------------------
echo "flight-check.test: case 2 — the four refusals fire and each NAMES itself"
# ---------------------------------------------------------------------------------------

# 2a CONSUMES — the artifact is not on the tree.
cat >"$WORK/bodies/consumes.md" <<'BODY'
## Acceptance Criteria
- Something.
  Probe: `test -e ./nope.md` — tier: none

## Consumes
- ac-blocker.1 -> skills/never-built/absent-artifact.md (the thing this bead builds on)
BODY
run "$WORK/bodies/consumes.md"
[ "$RUN_RC" -eq 1 ] && ok "CONSUMES refusal exits 1 (routing decision, not an error)" \
  || bad "CONSUMES: expected exit 1, got $RUN_RC"
printf '%s' "$RUN_OUT" | grep -q 'PREMISE-FAILED: CONSUMES' \
  && ok "CONSUMES refusal names its class" || bad "CONSUMES class not named: $RUN_OUT"
printf '%s' "$RUN_OUT" | grep -q 'absent-artifact.md' \
  && ok "CONSUMES refusal names WHICH artifact is absent" || bad "CONSUMES did not name the artifact"

# 2a' CONSUMES passes when the artifact IS on the tree (no blocker id -> no br dependency).
cat >"$WORK/bodies/consumes-ok.md" <<'BODY'
## Acceptance Criteria
- Something.
  Probe: `test -e ./nope.md` — tier: none

## Consumes
- upstream -> ./present-artifact.md
BODY
run "$WORK/bodies/consumes-ok.md"
[ "$RUN_RC" -eq 0 ] && ok "CONSUMES clears when the artifact is present" \
  || bad "CONSUMES(ok): expected exit 0, got $RUN_RC: $RUN_OUT"

# 2b ENVIRONMENT — a declared env precondition, not mere artifact existence.
cat >"$WORK/bodies/env.md" <<'BODY'
## Intent
Requires-env: AC2_FLIGHT_TEST_PROD_ONLY

## Acceptance Criteria
- A live-DB criterion that only holds in the prod-shaped environment.
  Probe: `test -e ./nope.md` — tier: none

## Consumes
- none
BODY
run "$WORK/bodies/env.md"
[ "$RUN_RC" -eq 1 ] && ok "ENVIRONMENT refusal exits 1" || bad "ENVIRONMENT: expected exit 1, got $RUN_RC"
printf '%s' "$RUN_OUT" | grep -q 'PREMISE-FAILED: ENVIRONMENT' \
  && ok "ENVIRONMENT refusal names its class" || bad "ENVIRONMENT class not named: $RUN_OUT"
printf '%s' "$RUN_OUT" | grep -q 'AC2_FLIGHT_TEST_PROD_ONLY' \
  && ok "ENVIRONMENT refusal names WHICH precondition failed" || bad "ENVIRONMENT did not name the variable"
run "$WORK/bodies/env.md" AC2_FLIGHT_TEST_PROD_ONLY=1
[ "$RUN_RC" -eq 0 ] && ok "ENVIRONMENT clears once the precondition actually holds" \
  || bad "ENVIRONMENT(ok): expected exit 0, got $RUN_RC: $RUN_OUT"

# 2b' ENVIRONMENT — a probe whose interpreter is missing would report a FALSE red.
cat >"$WORK/bodies/env-cmd.md" <<'BODY'
## Acceptance Criteria
- A criterion probed by a tool this box does not have.
  Probe: `ac2-definitely-not-installed --check` — tier: none

## Consumes
- none
BODY
run "$WORK/bodies/env-cmd.md"
printf '%s' "$RUN_OUT" | grep -q 'PREMISE-FAILED: ENVIRONMENT' \
  && ok "a missing probe interpreter is caught as ENVIRONMENT, not banked as a false RED" \
  || bad "missing interpreter was not caught: $RUN_OUT"

# 2c PERISHABLE — external state re-asserted at claim, because refine-time answers decay.
cat >"$WORK/bodies/perish.md" <<'BODY'
## Intent
Perishable: the bca.entries column still exists :: false

## Acceptance Criteria
- Something.
  Probe: `test -e ./nope.md` — tier: none

## Consumes
- none
BODY
run "$WORK/bodies/perish.md"
[ "$RUN_RC" -eq 1 ] && ok "PERISHABLE refusal exits 1" || bad "PERISHABLE: expected exit 1, got $RUN_RC"
printf '%s' "$RUN_OUT" | grep -q 'PREMISE-FAILED: PERISHABLE' \
  && ok "PERISHABLE refusal names its class" || bad "PERISHABLE class not named: $RUN_OUT"
printf '%s' "$RUN_OUT" | grep -q 'bca.entries column' \
  && ok "PERISHABLE refusal quotes the claim that stopped holding" || bad "PERISHABLE did not quote the claim"

# 2d RED — every named probe is already green, so there is no RED to record.
cat >"$WORK/bodies/nored.md" <<'BODY'
## Acceptance Criteria
- Already true at HEAD.
  Probe: `true` — tier: none
- Also already true at HEAD.
  Probe: `test -e ./present-artifact.md` — tier: none

## Consumes
- none
BODY
run "$WORK/bodies/nored.md"
[ "$RUN_RC" -eq 1 ] && ok "no-RED refusal exits 1" || bad "RED: expected exit 1, got $RUN_RC"
printf '%s' "$RUN_OUT" | grep -q 'PREMISE-FAILED: RED' \
  && ok "no-RED refusal names its class" || bad "RED class not named: $RUN_OUT"

# All four, distinctly named — the AC is "names WHICH of the four fired".
CLASSES=$(for b in consumes env perish nored; do
  run "$WORK/bodies/$b.md"
  printf '%s\n' "$RUN_OUT" | grep -o 'PREMISE-FAILED: [A-Z]*'
done | sort -u | wc -l | awk '{print $1}')
[ "$CLASSES" -eq 4 ] && ok "all four refusal classes are distinct and self-naming" \
  || bad "expected 4 distinct refusal classes, saw $CLASSES"

# ---------------------------------------------------------------------------------------
echo "flight-check.test: case 3 — one writer, one receipt format, two fingerprint moments"
# ---------------------------------------------------------------------------------------
rm -f "$WORK/receipts/ac-test-0001.flight-receipt"
# (b') at claim, for a bead that delivers its own harness: the harness does not exist yet.
cat >"$WORK/bodies/ownharness-claim.md" <<'BODY'
## Acceptance Criteria
- The bead delivers its own harness, which does not exist at claim.
  Probe: `test -x ./own.test.sh && bash ./own.test.sh` — tier: none

## Consumes
- none
BODY
run "$WORK/bodies/ownharness-claim.md"
grep -q '^red-fingerprint-scope: probe$' "$RECEIPT" \
  && ok "at claim with no harness on the tree, the fingerprint scope is 'probe'" \
  || bad "expected scope 'probe', got: $(grep '^red-fingerprint-scope:' "$RECEIPT" | tail -1)"
printf '%s' "$RUN_OUT" | grep -q 'RE-RUN this' \
  && ok "the scope-'probe' receipt tells the worker to re-run once the harness is written" \
  || bad "no re-invocation instruction on a scope-'probe' receipt"

# (b) re-invocation, once the harness IS written and BEFORE any fix.
cat >"$WORK/bodies/ownharness-written.md" <<'BODY'
## Acceptance Criteria
- The harness now exists and is honestly red against the unfixed tree.
  Probe: `test -f ./existing-harness.test.sh && grep -q FIXED ./existing-harness.test.sh` — tier: none

## Consumes
- none
BODY
run "$WORK/bodies/ownharness-written.md"
grep -q '^red-fingerprint-scope: probe+harness$' "$RECEIPT" \
  && ok "once the harness exists, the SAME writer records scope 'probe+harness'" \
  || bad "expected scope 'probe+harness', got: $(grep '^red-fingerprint-scope:' "$RECEIPT" | tail -1)"
grep -q 'existing-harness.test.sh' "$RECEIPT" \
  && ok "the receipt names the harness file the fingerprint was taken over" \
  || bad "receipt does not name its fingerprint inputs"
[ "$(grep -c '^FLIGHT-RECEIPT v1' "$RECEIPT")" -ge 2 ] \
  && ok "receipts APPEND, so close-gate reads the last-observed RED" \
  || bad "receipts did not append — the re-invocation lost the earlier moment"

# The fingerprint is over the ASSERTIONS, so editing the harness moves it.
FP_BEFORE=$(grep '^red-fingerprint:' "$RECEIPT" | tail -1)
printf 'assert three\n' >>"$WORK/root/existing-harness.test.sh"
run "$WORK/bodies/ownharness-written.md"
FP_AFTER=$(grep '^red-fingerprint:' "$RECEIPT" | tail -1)
[ "$FP_BEFORE" != "$FP_AFTER" ] \
  && ok "the fingerprint tracks the harness content — an edited test cannot pass as unchanged" \
  || bad "fingerprint did not move when the harness assertions changed"

# ---------------------------------------------------------------------------------------
echo "flight-check.test: case 4 — a post-fix re-fingerprint is STRUCTURALLY unreachable"
# ---------------------------------------------------------------------------------------
# The same bead, after the fix: the probe is now GREEN, so the only writer of the
# fingerprint refuses. There is no path that records a RED fingerprint after the diff.
printf 'FIXED\n' >>"$WORK/root/existing-harness.test.sh"
FP_LOCKED=$(grep '^red-fingerprint:' "$RECEIPT" | tail -1)
run "$WORK/bodies/ownharness-written.md"
[ "$RUN_RC" -eq 1 ] && printf '%s' "$RUN_OUT" | grep -q 'PREMISE-FAILED: RED' \
  && ok "after the fix the writer refuses — the fingerprint cannot be re-taken post-diff" \
  || bad "post-fix re-invocation did not refuse (rc=$RUN_RC): $RUN_OUT"
[ "$(grep '^red-fingerprint:' "$RECEIPT" | tail -1)" = "$FP_LOCKED" ] \
  && ok "the locked fingerprint is unchanged by the post-fix attempt" \
  || bad "the post-fix run rewrote the fingerprint"

# ---------------------------------------------------------------------------------------
echo "flight-check.test: case 5 — a gate that cannot verify says so and FAILS"
# ---------------------------------------------------------------------------------------
cat >"$WORK/bodies/noprobe.md" <<'BODY'
## Intent
A bead with no extractable probe at all.

## Acceptance Criteria
- Diff the file and eyeball it.

## Consumes
- none
BODY
run "$WORK/bodies/noprobe.md"
[ "$RUN_RC" -eq 2 ] && ok "zero extractable probes exits 2, not 0 — scanned-nothing is not a pass" \
  || bad "no-probe body: expected exit 2, got $RUN_RC"
printf '%s' "$RUN_OUT" | grep -q 'NOT-GATED' \
  && ok "the unverifiable case carries the NOT-GATED token" || bad "no NOT-GATED token: $RUN_OUT"

RUN_OUT=$(env AC2_DRY_RUN=1 AC2_FLIGHT_DIR="$WORK/receipts" bash "$GATE" ac-test-0001 \
  --body-file "$WORK/bodies/does-not-exist.md" --root "$WORK/root" 2>&1); RUN_RC=$?
[ "$RUN_RC" -eq 2 ] && ok "an unreadable bead body exits 2 (fail closed)" \
  || bad "unreadable body: expected exit 2, got $RUN_RC"

RUN_OUT=$(env AC2_DRY_RUN=1 bash "$GATE" 2>&1); RUN_RC=$?
[ "$RUN_RC" -eq 2 ] && ok "no bead id exits 2" || bad "missing bead id: expected exit 2, got $RUN_RC"

# ---------------------------------------------------------------------------------------
echo "flight-check.test: case 6 — the routing decision, and the birth declaration"
# ---------------------------------------------------------------------------------------
run "$WORK/bodies/perish.md"
for want in 'br comments add' 'PREMISE-FAILED-prefixed title' "--status open --assignee"; do
  printf '%s' "$RUN_OUT" | grep -q -- "$want" \
    && ok "premise failure routes: $want" || bad "routing step missing: $want"
done

DECL_MISSING=""
for field in 'PROBE:' 'SCHEDULE:' 'MODE:' 'ON-FAILURE:'; do
  grep -q "$field" "$GATE" || DECL_MISSING="$DECL_MISSING $field"
done
[ -z "$DECL_MISSING" ] && ok "flight-check.sh carries its 4-field assurance declaration at birth" \
  || bad "flight-check.sh declares no$DECL_MISSING"

# ---------------------------------------------------------------------------------------
echo ""
echo "flight-check.test: $PASS passed, $FAIL failed"
if [ "$PASS" -eq 0 ]; then
  echo "flight-check.test: NOT-GATED — zero cases ran; a harness that asserted nothing is not a pass"
  exit 1
fi
[ "$FAIL" -eq 0 ]
