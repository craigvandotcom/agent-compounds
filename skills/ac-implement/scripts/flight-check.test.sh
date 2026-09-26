#!/usr/bin/env bash
#
# flight-check.test.sh — the RED/GREEN proof harness for flight-check.sh (ac-k25c.2).
#
# ASSURANCE
#   PROBE:      this file IS the probe — bash skills/ac-implement/scripts/flight-check.test.sh
#   SCHEDULE:   every scripts/run-all-proofs.sh run (repo-wide *.test.sh discovery),
#               scheduled by CI's `proofs` job.
#   MODE:       blocking
#   ON-FAILURE: closed
#
# It proves the named refusals FIRE and NAME THEMSELVES, that the flight receipt
# carries the RED assertion fingerprint close-gate hash-locks against, that the fingerprint
# has the two declared scopes from ONE writer, and — the load-bearing one — that a post-fix
# re-fingerprint is STRUCTURALLY unreachable rather than merely discouraged.
#
# Every case drives the real script against a synthetic bead body in a scratch root, with
# AC2_DRY_RUN=1 so the premise-failure routing is asserted without touching a board.
#
# Exit 0  every case passed
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
# AC_TEST_SHOW_FAIL=1 makes show exit 3. The exact-id miss is already the
# prefix-resolution signal; the switch is for the resolved-id re-read, whose
# refusal must be NOT-GATED rather than a fabricated "not on the board".
cat >"$WORK/bin/br" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  show)
    [ "${AC_TEST_SHOW_FAIL:-}" = "1" ] && exit 3
    case "${2:-}" in
      upstream|bd-epic-kb-seams-573x7.1|bd-epic-ing-ownership-k2mpd.1)
        echo '[{"id":"resolved","status":"closed"}]' ;;
      ac-test-0001)
        if [ -n "${AC_TEST_PARENT:-}" ]; then
          printf '[{"id":"ac-test-0001","parent":"%s","labels":[]}]\n' "$AC_TEST_PARENT"
        else
          echo '[{"id":"ac-test-0001","labels":[]}]'  # the SUT holds no refined — the stamp leg correctly skips
        fi ;;
      ac-parent-epic) echo '[{"id":"ac-parent-epic","status":"open"}]' ;;
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
echo "flight-check.test: case 2 — the named refusals fire and each NAMES itself"
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

# A parent-child citation is containment, not a closure premise. The schema forbids the
# citation, but flight-check must not deadlock a legacy/malformed child if one survives.
cat >"$WORK/bodies/consumes-parent.md" <<'BODY'
## Acceptance Criteria
- Something.
  Probe: `test -e ./nope.md` — tier: none

## Consumes
- ac-parent-epic -> ./present-artifact.md (the containing epic)
BODY
run "$WORK/bodies/consumes-parent.md" AC_TEST_PARENT=ac-parent-epic
[ "$RUN_RC" -eq 0 ] && ok "CONSUMES exempts a direct parent-child containment edge" \
  || bad "CONSUMES(parent): expected exit 0, got $RUN_RC: $RUN_OUT"
printf '%s' "$RUN_OUT" | grep -q "CONSUMES parent 'ac-parent-epic' exempted" \
  && ok "parent-child exemption names the relation it honored" \
  || bad "parent-child exemption was not named: $RUN_OUT"
run "$WORK/bodies/consumes-parent.md" AC_TEST_PARENT=some-other-epic
[ "$RUN_RC" -eq 1 ] && ok "CONSUMES still refuses an ordinary open blocker" \
  || bad "CONSUMES(non-parent): expected exit 1, got $RUN_RC: $RUN_OUT"
printf '%s' "$RUN_OUT" | grep -q "blocker 'ac-parent-epic' is 'open'" \
  && ok "the non-parent open blocker is named" \
  || bad "non-parent blocker was not named: $RUN_OUT"

# 2a'' multi-hyphen blocker ids parse whole, and unique id prefixes resolve —
# the extractor once truncated bd-epic-kb-seams-573x7.3 to 'bd-epic' and refused
# the whole bd-epic-* family at claim (five beads burned, one consumer-app run).
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
Perishable: the legacy_schema.entries column still exists :: false

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
printf '%s' "$RUN_OUT" | grep -q 'legacy_schema.entries column' \
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

# 2e HANG — a probe that never exits refuses as ENVIRONMENT, so the bead is stamped, not re-picked.
cat >"$WORK/bodies/hang.md" <<'BODY'
## Acceptance Criteria
- Watches instead of exiting.
  Probe: `sleep 30` — tier: none

## Consumes
- none
BODY
run "$WORK/bodies/hang.md" AC2_PROBE_TIMEOUT=1
[ "$RUN_RC" -eq 1 ] && printf '%s' "$RUN_OUT" | grep -q 'PREMISE-FAILED: ENVIRONMENT — probe .sleep 30. did not exit' \
  && ok "a hanging probe refuses as ENVIRONMENT within the timeout" \
  || bad "HANG: expected exit 1 + ENVIRONMENT timeout, got $RUN_RC: $RUN_OUT"

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
echo "flight-check.test: case 8 — a stale \`refined\` stamp is re-gated at claim (ac-l7xt)"
# ---------------------------------------------------------------------------------------
# A stamp written under an older contract survives every later pass unless something
# re-checks it where it is spent. The fixture: a scratch repo whose bead delivers an
# EXISTING, REFERENCED path with no touchers line — stamped `refined` under the
# pre-touchers contract. flight-check must refuse it with stale-stamp, the stamp gate must
# strip the label, and after the line is added flight-check must clear the bead.
R2="$WORK/root2"; mkdir -p "$R2"
mkdir -p "$R2/fix"
printf 'the re-gate fixture deliverable\n' >"$R2/fix/fixture-deliverable.md"
printf 'references fix/fixture-deliverable\n' >"$R2/fix/referrer.txt"
git -C "$R2" init -q
git -C "$R2" -c user.email=f@f -c user.name=f add -A
git -C "$R2" -c user.email=f@f -c user.name=f commit -qm fixture

B2="$WORK/bin2"; mkdir -p "$B2"
cat >"$B2/br" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  show)   shift; id=""; json=""
          while [ $# -gt 0 ]; do case "$1" in --json) json=1 ;; *) id="$1" ;; esac; shift; done
          [ "$id" = ac-l7xt-fix ] && cat "${AC_FIXTURE_JSON:?}" || exit 3 ;;
  label)  printf '%s\n' "$*" >> "${AC_LABEL_LOG:?}"
          # MUTATE the fixture so stamp-refined's READ-BACK (ac-heyt.7) sees the write:
          # the downgrade leg asserts refined is gone and unrefined present on re-read.
          op="${2:-}"; id="${3:-}"; name="${4:-}"
          [ "$op" = add ] || [ "$op" = remove ] || exit 0
          [ -n "${AC_FIXTURE_JSON:-}" ] && [ -f "$AC_FIXTURE_JSON" ] || exit 0
          tmp="${AC_FIXTURE_JSON}.tmp"
          jq --arg op "$op" --arg name "$name" \
            'if $op == "add" then .labels = ((.labels // []) + [$name] | unique) else .labels = ((.labels // []) - [$name]) end' \
            "$AC_FIXTURE_JSON" >"$tmp" && mv "$tmp" "$AC_FIXTURE_JSON"
          exit 0 ;;
  comments) exit 0 ;;
  update) exit 0 ;;
  *) exit 3 ;;
esac
STUB
chmod +x "$B2/br"

cat >"$WORK/fix-desc1.md" <<'BODY'
## Intent
Re-gate fixture: a deliverable that exists and is referenced owes a touchers line.

## Acceptance Criteria
- The deliverable is present.
  Probe: `test -f fix/fixture-deliverable.md` — tier: none
- The referrer is present.
  Probe: `test -f fix/referrer.txt` — tier: none
- The absent artifact is still absent.
  Probe: `test -f fixture-absent.md` — tier: none

## Delivers
- `fix/fixture-deliverable.md` — the re-gate fixture deliverable

## Consumes
- none
BODY
cat >"$WORK/fix-desc2.md" <<'BODY'
## Intent
Re-gate fixture: a deliverable that exists and is referenced owes a touchers line.

## Acceptance Criteria
- The deliverable is present.
  Probe: `test -f fix/fixture-deliverable.md` — tier: none
- The referrer is present.
  Probe: `test -f fix/referrer.txt` — tier: none
- The absent artifact is still absent.
  Probe: `test -f fixture-absent.md` — tier: none

## Delivers
- `fix/fixture-deliverable.md` — the re-gate fixture deliverable
  touchers: `rg -l -F "fix/fixture-deliverable" .` → 1 · owned by: ac-l7xt-fix | out-of-scope: fixture

## Consumes
- none
BODY
mk_json() { jq -n --arg d "$(cat "$1")" \
  '{id:"ac-l7xt-fix",issue_type:"task",labels:["origin:ac-triage","refined","refine-full"],description:$d,comments:[]}'; }

: >"$WORK/labels1.log"
mk_json "$WORK/fix-desc1.md" >"$WORK/fix1.json"
RUN_OUT=$(env AC2_DRY_RUN=1 AC2_FLIGHT_DIR="$WORK/receipts2" PATH="$B2:$PATH" \
  AC_FIXTURE_JSON="$WORK/fix1.json" AC_LABEL_LOG="$WORK/labels1.log" \
  bash "$GATE" ac-l7xt-fix --body-file "$WORK/fix-desc1.md" --root "$R2" 2>&1)
RUN_RC=$?
[ "$RUN_RC" -eq 1 ] && ok "stale stamp: flight-check refuses with exit 1" \
  || bad "stale stamp: expected exit 1, got $RUN_RC: $RUN_OUT"
printf '%s' "$RUN_OUT" | grep -q 'STALE-STAMP' && ok "stale stamp: the refusal names its class" \
  || bad "stale stamp: class not named: $RUN_OUT"
printf '%s' "$RUN_OUT" | grep -q 'unowned-touchers' && ok "stale stamp: the stamp gate's own refusal surfaced" \
  || bad "stale stamp: stamp-gate refusal missing: $RUN_OUT"
grep -q 'remove ac-l7xt-fix refined' "$WORK/labels1.log" && grep -q 'add ac-l7xt-fix unrefined' "$WORK/labels1.log" \
  && ok "stale stamp: the downgrade leg stripped refined and added unrefined" \
  || bad "stale stamp: downgrade did not run: $(cat "$WORK/labels1.log")"
printf '%s' "$RUN_OUT" | grep -q 'ROUTE (dry-run)' && ok "stale stamp: routed as a premise failure" \
  || bad "stale stamp: not routed: $RUN_OUT"

# ...and after the touchers line is added, the same bead clears for flight.
: >"$WORK/labels2.log"
mk_json "$WORK/fix-desc2.md" >"$WORK/fix2.json"
RUN_OUT=$(env AC2_DRY_RUN=1 AC2_FLIGHT_DIR="$WORK/receipts2" PATH="$B2:$PATH" \
  AC_FIXTURE_JSON="$WORK/fix2.json" AC_LABEL_LOG="$WORK/labels2.log" \
  bash "$GATE" ac-l7xt-fix --body-file "$WORK/fix-desc2.md" --root "$R2" 2>&1)
RUN_RC=$?
[ "$RUN_RC" -eq 0 ] && ok "stale stamp: with the touchers line, flight-check clears the bead" \
  || bad "stale stamp: expected exit 0, got $RUN_RC: $RUN_OUT"
[ -e "$WORK/receipts2/ac-l7xt-fix.flight-receipt" ] && ok "stale stamp: cleared bead wrote its RED receipt" \
  || bad "stale stamp: no receipt after clearing"
grep -q 'add ac-l7xt-fix refined' "$WORK/labels2.log" && ok "stale stamp: the re-gate re-stamped on the way through" \
  || bad "stale stamp: re-gate did not stamp: $(cat "$WORK/labels2.log")"

# ---------------------------------------------------------------------------------------
echo "flight-check.test: case 8b — the refined stamp is re-gated at CLAIM time, not on every re-run"
# ---------------------------------------------------------------------------------------
# Reuses case 8's stub br (B2), root (R2) and the stale-contract body (fix-desc1.md, no
# touchers line — the body that made the stamp gate downgrade in case 8). Each sub-case
# adds a `comments` array to the fixture JSON and pre-seeds a flight receipt directly, so
# the skip decision can be driven without a prior flight-check run writing it.
mk_json_c() { jq -n --arg d "$(cat "$1")" --argjson c "$2" \
  '{id:"ac-l7xt-fix",issue_type:"task",labels:["origin:ac-triage","refined","refine-full"],description:$d,comments:$c}'; }
write_receipt() { mkdir -p "$(dirname "$1")"; cat >"$1" <<EOF
FLIGHT-RECEIPT v1
bead: ac-l7xt-fix
at: $2
tree: $(git -C "$R2" rev-parse HEAD)
premise: PASS consumes=0 environment=0 perishable=0
freshness-key: tree=$(git -C "$R2" rev-parse HEAD);tracked=clean
red-probe: test -f fixture-absent.md
red-exit: 1
red-green-siblings: 2 of 3 probe(s) already green

EOF
}

# 8b(a) — CLAIM before the receipt: the prior run in THIS claim already re-gated it. A
# stale-contract body must NOT bounce; the stamp leg is skipped, not re-run.
: >"$WORK/labels8b-a.log"
write_receipt "$WORK/receipts8b-a/ac-l7xt-fix.flight-receipt" "2024-01-02T00:00:00Z"
mk_json_c "$WORK/fix-desc1.md" '[{"text":"CLAIM: someone","created_at":"2024-01-01T00:00:00Z"}]' >"$WORK/fix8b-a.json"
RUN_OUT=$(env AC2_DRY_RUN=1 AC2_FLIGHT_DIR="$WORK/receipts8b-a" PATH="$B2:$PATH" \
  AC_FIXTURE_JSON="$WORK/fix8b-a.json" AC_LABEL_LOG="$WORK/labels8b-a.log" \
  bash "$GATE" ac-l7xt-fix --body-file "$WORK/fix-desc1.md" --root "$R2" 2>&1)
RUN_RC=$?
[ "$RUN_RC" -eq 0 ] && ok "8b(a): receipt after claim -> a stale-contract body does not bounce" \
  || bad "8b(a): expected exit 0, got $RUN_RC: $RUN_OUT"
printf '%s' "$RUN_OUT" | grep -q 'STAMP skipped' && ok "8b(a): output names the skip" \
  || bad "8b(a): no STAMP skipped line: $RUN_OUT"
printf '%s' "$RUN_OUT" | grep -q 'STAMP ok' && bad "8b(a): STAMP ok printed after a skip: $RUN_OUT" \
  || ok "8b(a): STAMP ok does not print after a skip"
grep -q 'remove ac-l7xt-fix refined' "$WORK/labels8b-a.log" \
  && bad "8b(a): the stamp gate ran anyway (label log): $(cat "$WORK/labels8b-a.log")" \
  || ok "8b(a): the stamp gate never ran — no downgrade in the label log"

# 8b(b) — receipt OLDER than a newer CLAIM: the receipt predates this claim, so it is not
# evidence of a re-gate within it. STALE-STAMP must fire and the stamp must downgrade.
: >"$WORK/labels8b-b.log"
write_receipt "$WORK/receipts8b-b/ac-l7xt-fix.flight-receipt" "2024-01-01T00:00:00Z"
mk_json_c "$WORK/fix-desc1.md" '[{"text":"CLAIM: someone","created_at":"2024-01-02T00:00:00Z"}]' >"$WORK/fix8b-b.json"
RUN_OUT=$(env AC2_DRY_RUN=1 AC2_FLIGHT_DIR="$WORK/receipts8b-b" PATH="$B2:$PATH" \
  AC_FIXTURE_JSON="$WORK/fix8b-b.json" AC_LABEL_LOG="$WORK/labels8b-b.log" \
  bash "$GATE" ac-l7xt-fix --body-file "$WORK/fix-desc1.md" --root "$R2" 2>&1)
RUN_RC=$?
[ "$RUN_RC" -eq 1 ] && ok "8b(b): receipt older than the claim -> STALE-STAMP fires" \
  || bad "8b(b): expected exit 1, got $RUN_RC: $RUN_OUT"
printf '%s' "$RUN_OUT" | grep -q 'STALE-STAMP' && ok "8b(b): the refusal names its class" \
  || bad "8b(b): STALE-STAMP not named: $RUN_OUT"
grep -q 'remove ac-l7xt-fix refined' "$WORK/labels8b-b.log" \
  && ok "8b(b): the stamp downgraded refined" \
  || bad "8b(b): no downgrade in the label log: $(cat "$WORK/labels8b-b.log")"

# 8b(c) — a receipt is present but there is no CLAIM comment at all: the skip's other key
# is empty, so the gate runs exactly as it does today (fail closed on the stale contract).
: >"$WORK/labels8b-c.log"
write_receipt "$WORK/receipts8b-c/ac-l7xt-fix.flight-receipt" "2024-01-01T00:00:00Z"
mk_json_c "$WORK/fix-desc1.md" '[]' >"$WORK/fix8b-c.json"
RUN_OUT=$(env AC2_DRY_RUN=1 AC2_FLIGHT_DIR="$WORK/receipts8b-c" PATH="$B2:$PATH" \
  AC_FIXTURE_JSON="$WORK/fix8b-c.json" AC_LABEL_LOG="$WORK/labels8b-c.log" \
  bash "$GATE" ac-l7xt-fix --body-file "$WORK/fix-desc1.md" --root "$R2" 2>&1)
RUN_RC=$?
[ "$RUN_RC" -eq 1 ] && ok "8b(c): no CLAIM comment -> the gate runs" \
  || bad "8b(c): expected exit 1, got $RUN_RC: $RUN_OUT"
printf '%s' "$RUN_OUT" | grep -q 'STALE-STAMP' && ok "8b(c): the refusal names its class" \
  || bad "8b(c): STALE-STAMP not named: $RUN_OUT"
grep -q 'remove ac-l7xt-fix refined' "$WORK/labels8b-c.log" \
  && ok "8b(c): the stamp gate ran and downgraded refined" \
  || bad "8b(c): no downgrade in the label log: $(cat "$WORK/labels8b-c.log")"

# ---------------------------------------------------------------------------------------
echo "flight-check.test: case 8c — a stale touchers count is re-derived after a tree change"
# ---------------------------------------------------------------------------------------
# This is the measured failure shape: a predecessor commits a new referrer after a receipt
# was written.  The old receipt is not a cache of the new tree.  The first check-only pass
# re-derives the count and refuses; after the count is re-derived at the new tree, the same
# claim can fly and the receipt carries the new freshness key.
R3="$WORK/root3"; mkdir -p "$R3/fix"
printf 'the count fixture deliverable\n' >"$R3/fix/fixture-deliverable.md"
printf 'references fix/fixture-deliverable\n' >"$R3/fix/referrer.txt"
git -C "$R3" init -q
git -C "$R3" -c user.email=f@f -c user.name=f add -A
git -C "$R3" -c user.email=f@f -c user.name=f commit -qm initial

cat >"$WORK/count-desc-old.md" <<'BODY'
## Intent
A touchers count that changes when a predecessor lands.

## Acceptance Criteria
- The delivered artifact is present.
  Probe: `test -f fix/fixture-deliverable.md` — tier: none
- The absent artifact is still absent.
  Probe: `test -f fix/fixture-absent.md` — tier: none

## Delivers
- `fix/fixture-deliverable.md` — count fixture
  touchers: `rg -l -F "fix/fixture-deliverable" . -g '!fix/fixture-deliverable.md'` → 1 · owned by: ac-l7xt-fix

## Consumes
- none
BODY
cat >"$WORK/count-desc-new.md" <<'BODY'
## Intent
A touchers count that changes when a predecessor lands.

## Acceptance Criteria
- The delivered artifact is present.
  Probe: `test -f fix/fixture-deliverable.md` — tier: none
- The absent artifact is still absent.
  Probe: `test -f fix/fixture-absent.md` — tier: none

## Delivers
- `fix/fixture-deliverable.md` — count fixture
  touchers: `rg -l -F "fix/fixture-deliverable" . -g '!fix/fixture-deliverable.md'` → 2 · owned by: ac-l7xt-fix

## Consumes
- none
BODY

OLD_TREE3=$(git -C "$R3" rev-parse HEAD)
printf 'references fix/fixture-deliverable from the predecessor\n' >"$R3/fix/predecessor.txt"
git -C "$R3" -c user.email=f@f -c user.name=f add -A
git -C "$R3" -c user.email=f@f -c user.name=f commit -qm predecessor
NEW_TREE3=$(git -C "$R3" rev-parse HEAD)
COUNT_RECEIPTS="$WORK/receipts8c"; mkdir -p "$COUNT_RECEIPTS"
cat >"$COUNT_RECEIPTS/ac-l7xt-fix.flight-receipt" <<EOF
FLIGHT-RECEIPT v1
bead: ac-l7xt-fix
at: 2024-01-02T00:00:00Z
tree: $OLD_TREE3
premise: PASS consumes=0 environment=0 perishable=0
freshness-key: tree=$OLD_TREE3;tracked=clean
red-probe: test -f fix/fixture-absent.md
red-exit: 1
red-green-siblings: 1 of 2 probe(s) already green

EOF
: >"$WORK/labels8c-check.log"
mk_json_c "$WORK/count-desc-old.md" '[{"text":"CLAIM: someone","created_at":"2024-01-01T00:00:00Z"}]' >"$WORK/count8c.json"
RUN_OUT=$(env AC2_DRY_RUN=1 AC2_FLIGHT_DIR="$COUNT_RECEIPTS" PATH="$B2:$PATH" \
  AC_FIXTURE_JSON="$WORK/count8c.json" AC_LABEL_LOG="$WORK/labels8c-check.log" \
  bash "$GATE" ac-l7xt-fix --body-file "$WORK/count-desc-old.md" --root "$R3" --check-only 2>&1)
RUN_RC=$?
[ "$RUN_RC" -eq 1 ] && printf '%s' "$RUN_OUT" | grep -q 'touchers count was re-derived at use' \
  && ok "8c: check-only re-derives the stale touchers count at the new tree" \
  || bad "8c: expected a re-derived count refusal, got rc=$RUN_RC: $RUN_OUT"
printf '%s' "$RUN_OUT" | grep -q "freshness key: tree=$NEW_TREE3;tracked=clean" \
  && ok "8c: the refusal carries the current tree freshness key" \
  || bad "8c: current freshness key missing: $RUN_OUT"

: >"$WORK/labels8c-gate.log"
mk_json_c "$WORK/count-desc-old.md" '[{"text":"CLAIM: someone","created_at":"2024-01-01T00:00:00Z"}]' >"$WORK/count8c-gate.json"
RUN_OUT=$(env AC2_DRY_RUN=1 AC2_FLIGHT_DIR="$COUNT_RECEIPTS" PATH="$B2:$PATH" \
  AC_FIXTURE_JSON="$WORK/count8c-gate.json" AC_LABEL_LOG="$WORK/labels8c-gate.log" \
  bash "$GATE" ac-l7xt-fix --body-file "$WORK/count-desc-old.md" --root "$R3" 2>&1)
RUN_RC=$?
[ "$RUN_RC" -eq 1 ] && printf '%s' "$RUN_OUT" | grep -q 'STAMP re-derived' \
  && printf '%s' "$RUN_OUT" | grep -q 'STALE-STAMP' \
  && ok "8c: claim-time gate re-derives instead of replaying the old receipt" \
  || bad "8c: expected a freshness-key re-derivation refusal, got rc=$RUN_RC: $RUN_OUT"

: >"$WORK/labels8c-pass.log"
mk_json_c "$WORK/count-desc-new.md" '[{"text":"CLAIM: someone","created_at":"2024-01-03T00:00:00Z"}]' >"$WORK/count8c-pass.json"
RUN_OUT=$(env AC2_DRY_RUN=1 AC2_FLIGHT_DIR="$COUNT_RECEIPTS" PATH="$B2:$PATH" \
  AC_FIXTURE_JSON="$WORK/count8c-pass.json" AC_LABEL_LOG="$WORK/labels8c-pass.log" \
  bash "$GATE" ac-l7xt-fix --body-file "$WORK/count-desc-new.md" --root "$R3" 2>&1)
RUN_RC=$?
[ "$RUN_RC" -eq 0 ] && grep -q "freshness-key: tree=$NEW_TREE3;tracked=clean" "$COUNT_RECEIPTS/ac-l7xt-fix.flight-receipt" \
  && ok "8c: the re-derived count lets the next claim fly and records the new key" \
  || bad "8c: expected a fresh green claim, got rc=$RUN_RC: $RUN_OUT"

# ---------------------------------------------------------------------------------------
echo "flight-check.test: case 9 — a refused resolved-blocker show is NOT-GATED, never a fabricated status"
# ---------------------------------------------------------------------------------------
# consumes-prefix.md already proves list resolves the prefix to exactly one id and
# the re-read succeeds. The same body with AC_TEST_SHOW_FAIL=1 fails that re-read:
# list still succeeds, so the gate is past prefix-resolution when show refuses.
run "$WORK/bodies/consumes-prefix.md" AC_TEST_SHOW_FAIL=1
[ "$RUN_RC" -eq 2 ] && ok "resolved-blocker show refusal exits 2 (NOT-GATED, not a fabricated status)" \
  || bad "resolved-blocker refusal: expected exit 2, got $RUN_RC: $RUN_OUT"
printf '%s' "$RUN_OUT" | grep -q 'NOT-GATED' \
  && ok "resolved-blocker refusal carries NOT-GATED" || bad "no NOT-GATED token: $RUN_OUT"
printf '%s' "$RUN_OUT" | grep -q 'refused for resolved blocker' \
  && ok "resolved-blocker refusal names the read that refused" || bad "did not name the read: $RUN_OUT"
printf '%s' "$RUN_OUT" | grep -q 'closure unverifiable' \
  && ok "resolved-blocker refusal says closure is unverifiable" || bad "did not say unverifiable: $RUN_OUT"
printf '%s' "$RUN_OUT" | grep -q 'not on the board' \
  && bad "resolved-blocker refusal fabricated a not-on-the-board status: $RUN_OUT" \
  || ok "resolved-blocker refusal did not fabricate a not-on-the-board status"

# ---------------------------------------------------------------------------------------
echo ""
echo "flight-check.test: $PASS passed, $FAIL failed"
if [ "$PASS" -eq 0 ]; then
  echo "flight-check.test: NOT-GATED — zero cases ran; a harness that asserted nothing is not a pass"
  exit 1
fi
[ "$FAIL" -eq 0 ]
