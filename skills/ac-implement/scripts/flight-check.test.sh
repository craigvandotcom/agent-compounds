#!/usr/bin/env bash
#
# flight-check.test.sh — the RED/GREEN proof harness for flight-check.sh (ac-k25c.2).
#
# ASSURANCE
#   PROBE:      this file IS the probe — bash skills/ac-implement/scripts/flight-check.test.sh
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

WORK=$(mktemp -d "${TMPDIR:-/tmp}/ac-flight-test.XXXXXX") || { echo "flight-check.test: cannot create scratch dir"; exit 1; }
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/root" "$WORK/receipts" "$WORK/bodies" "$WORK/bin"
: >"$WORK/root/present-artifact.md"
printf 'assert one\nassert two\n' >"$WORK/root/existing-harness.test.sh"

# Hermetic br shim: every Consumes blocker resolves CLOSED, list answers prefix
# queries — the suite must never depend on a developer's real beads DB, and the
# CONSUMES leg must be reachable (a machine with real br on PATH must not leak
# live board state into these cases).
cat >"$WORK/bin/br" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  show)
    case "${2:-}" in
      upstream|bd-epic-kb-seams-573x7.1|bd-epic-ing-ownership-k2mpd.1)
        echo '[{"id":"resolved","status":"closed"}]' ;;
      *) exit 3 ;;  # exact-id miss: not on the board under that spelling
    esac ;;
  list) echo '{"issues":[{"id":"upstream","status":"closed"},{"id":"bd-epic-kb-seams-573x7.1","status":"closed"},{"id":"bd-epic-ing-ownership-k2mpd.1","status":"closed"}],"total":3,"has_more":false,"limit":5000,"offset":0}' ;;
  *) echo '{}' ;;
esac
STUB
chmod +x "$WORK/bin/br"

# run <body-file> [extra env assignments…] -> stdout+stderr in RUN_OUT, status in RUN_RC
RUN_OUT=""
RUN_RC=0
run() {
  local body="$1"; shift
  RUN_OUT=$(env AC2_DRY_RUN=1 AC2_FLIGHT_DIR="$WORK/receipts" PATH="$WORK/bin:$PATH" "$@" \
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

# 2a'' multi-hyphen blocker ids parse whole, and unique id prefixes resolve —
# the extractor once truncated bd-epic-kb-seams-573x7.3 to 'bd-epic' and refused
# the whole bd-epic-* family at claim (five beads burned, one BCA run).
cat >"$WORK/bodies/consumes-hyphen.md" <<'BODY'
## Acceptance Criteria
- Something.
  Probe: `test -e ./nope.md` — tier: none

## Consumes
- bd-epic-kb-seams-573x7.1 -> ./present-artifact.md (the landed blocker)
BODY
run "$WORK/bodies/consumes-hyphen.md"
[ "$RUN_RC" -eq 0 ] && ok "CONSUMES parses multi-hyphen blocker ids whole" \
  || bad "CONSUMES(hyphen): expected exit 0, got $RUN_RC: $RUN_OUT"

cat >"$WORK/bodies/consumes-prefix.md" <<'BODY'
## Acceptance Criteria
- Something.
  Probe: `test -e ./nope.md` — tier: none

## Consumes
- bd-epic-kb-seams-573x7 -> ./present-artifact.md (prefix of a closed blocker)
BODY
run "$WORK/bodies/consumes-prefix.md"
[ "$RUN_RC" -eq 0 ] && ok "CONSUMES resolves a unique blocker id prefix" \
  || bad "CONSUMES(prefix): expected exit 0, got $RUN_RC: $RUN_OUT"

cat >"$WORK/bodies/consumes-ambiguous.md" <<'BODY'
## Acceptance Criteria
- Something.
  Probe: `test -e ./nope.md` — tier: none

## Consumes
- bd-epic -> ./present-artifact.md (matches more than one id — must refuse)
BODY
run "$WORK/bodies/consumes-ambiguous.md"
printf '%s' "$RUN_OUT" | grep -q "blocker 'bd-epic' is not on the board" \
  && ok "CONSUMES refuses an ambiguous prefix (fail closed)" \
  || bad "CONSUMES(ambiguous): expected refusal, got rc=$RUN_RC: $RUN_OUT"

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
  Probe: `ac-definitely-not-installed --check` — tier: none

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
echo "flight-check.test: case 3 — one writer, one receipt format, receipts APPEND"
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

# (b) re-invocation, once the harness IS written and BEFORE any fix.
cat >"$WORK/bodies/ownharness-written.md" <<'BODY'
## Acceptance Criteria
- The harness now exists and is honestly red against the unfixed tree.
  Probe: `test -f ./existing-harness.test.sh && grep -q FIXED ./existing-harness.test.sh` — tier: none

## Consumes
- none
BODY
run "$WORK/bodies/ownharness-written.md"
[ "$(grep -c '^FLIGHT-RECEIPT v1' "$RECEIPT")" -ge 2 ] \
  && ok "receipts APPEND, so close-gate reads the last-observed RED" \
  || bad "receipts did not append — the re-invocation lost the earlier moment"

# ---------------------------------------------------------------------------------------
echo "flight-check.test: case 4 — a post-fix receipt is STRUCTURALLY unreachable"
# ---------------------------------------------------------------------------------------
# The same bead, after the fix: the probe is now GREEN, so the only writer of the receipt
# refuses. There is no path that banks a RED after the diff — which is what makes the receipt
# a temporal anchor rather than a formality.
printf 'FIXED\n' >>"$WORK/root/existing-harness.test.sh"
RECEIPTS_BEFORE=$(grep -c '^FLIGHT-RECEIPT v1' "$RECEIPT")
run "$WORK/bodies/ownharness-written.md"
[ "$RUN_RC" -eq 1 ] && printf '%s' "$RUN_OUT" | grep -q 'PREMISE-FAILED: RED' \
  && ok "after the fix the writer refuses — a RED cannot be banked post-diff" \
  || bad "post-fix re-invocation did not refuse (rc=$RUN_RC): $RUN_OUT"
[ "$(grep -c '^FLIGHT-RECEIPT v1' "$RECEIPT")" -eq "$RECEIPTS_BEFORE" ] \
  && ok "the refused run appended NO receipt — the anchor is unchanged" \
  || bad "the post-fix run appended a receipt anyway"

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
echo "flight-check.test: case 7 — --check-only answers the question and writes nothing"
# ---------------------------------------------------------------------------------------
# refly.sh re-asks every stamped bead through this flag; a check that routed or wrote a
# receipt on the way would re-stamp or pre-certify — either is a write with no observer.
CO_DIR="$WORK/receipts-check-only"; mkdir -p "$CO_DIR"
RUN_OUT=$(env AC2_FLIGHT_DIR="$CO_DIR" PATH="$WORK/bin:$PATH" \
  bash "$GATE" ac-test-0001 --body-file "$WORK/bodies/perish.md" --root "$WORK/root" --check-only 2>&1)
RUN_RC=$?
[ "$RUN_RC" -eq 1 ] && ok "check-only: a failing premise exits 1" \
  || bad "check-only(fail): expected exit 1, got $RUN_RC: $RUN_OUT"
printf '%s' "$RUN_OUT" | grep -q 'PREMISE-FAILED: PERISHABLE' && ok "check-only: the refusal still names its class" \
  || bad "check-only(fail): class not named: $RUN_OUT"
printf '%s' "$RUN_OUT" | grep -qE 'ROUTE|br comments add|br update' \
  && bad "check-only(fail): routed a premise failure it was told not to write: $RUN_OUT" \
  || ok "check-only: nothing is routed on failure"

RUN_OUT=$(env AC2_FLIGHT_DIR="$CO_DIR" PATH="$WORK/bin:$PATH" \
  bash "$GATE" ac-test-0001 --body-file "$WORK/bodies/clear.md" --root "$WORK/root" --check-only 2>&1)
RUN_RC=$?
[ "$RUN_RC" -eq 0 ] && ok "check-only: a flyable bead exits 0" \
  || bad "check-only(pass): expected exit 0, got $RUN_RC: $RUN_OUT"
[ ! -e "$CO_DIR/ac-test-0001.flight-receipt" ] && ok "check-only: no receipt is written on pass" \
  || bad "check-only(pass): a receipt was written — a re-check must not pre-certify a RED"

# ---------------------------------------------------------------------------------------
echo ""
echo "flight-check.test: $PASS passed, $FAIL failed"
if [ "$PASS" -eq 0 ]; then
  echo "flight-check.test: NOT-GATED — zero cases ran; a harness that asserted nothing is not a pass"
  exit 1
fi
[ "$FAIL" -eq 0 ]
