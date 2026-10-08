#!/usr/bin/env bash
# claim.test.sh — proof harness for claim.sh: the CLAIM comment is gated on the claim's exit.
#
# ASSURANCE
#   PROBE:      this file IS the probe — bash skills/ac-implement/scripts/claim.test.sh
#   SCHEDULE:   every scripts/run-all-proofs.sh run (repo-wide *.test.sh discovery)
#   MODE:       blocking
#   ON-FAILURE: closed
#
# Drives the real script against a hermetic br stub that records every `comments add`.
#
# Exit 0  every case passed
# Exit 1  at least one case failed
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SUT="$HERE/claim.sh"
PASS=0; FAIL=0
ok()  { PASS=$(( PASS + 1 )); echo "  ok   — $*"; }
bad() { FAIL=$(( FAIL + 1 )); echo "  FAIL — $*"; }
[ -x "$SUT" ] || { echo "claim.test: claim.sh missing or not executable at $SUT"; exit 1; }

WORK=$(mktemp -d "${TMPDIR:-/tmp}/ac-claim-test.XXXXXX") || exit 1
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
cat >"$WORK/bin/br" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  update)
    case "${AC_TEST_CLAIM:-ok}" in
      ok) echo '[{"id":"x","status":"in_progress"}]'; exit 0 ;;
      exit) echo 'already claimed' >&2; exit 4 ;;
      validation) echo '{"error":{"code":"VALIDATION_FAILED"}}'; exit 0 ;;
    esac ;;
  comments)
    # args: comments add <id> -f <file>
    cat "$5" >> "$AC_TEST_LOG" ;;
esac
STUB
chmod +x "$WORK/bin/br"

run() { # <claim-mode> -> RUN_RC; comments recorded in $WORK/log
  : >"$WORK/log"
  env PATH="$WORK/bin:$PATH" AC_TEST_LOG="$WORK/log" AC_TEST_CLAIM="$1" AC2_FLIGHT_DIR="$WORK/flight" \
    bash "$SUT" ac-test-1 --actor DustyCastle >/dev/null 2>&1
  RUN_RC=$?
}

echo "claim.test: refused claim (non-zero exit)"
run exit
[ "$RUN_RC" -eq 3 ] && ok "claim.sh: refused claim exits non-zero (3)" || bad "refused claim: expected rc 3, got $RUN_RC"
[ ! -s "$WORK/log" ] && ok "claim.sh: refused claim writes no CLAIM comment" || bad "refused claim wrote: $(cat "$WORK/log")"

echo "claim.test: refused claim (VALIDATION_FAILED at exit 0)"
run validation
{ [ "$RUN_RC" -eq 3 ] && [ ! -s "$WORK/log" ]; } && ok "claim.sh: VALIDATION_FAILED is a refusal, no comment" \
  || bad "validation: rc=$RUN_RC log=$(cat "$WORK/log")"

echo "claim.test: successful claim"
run ok
[ "$RUN_RC" -eq 0 ] && [ "$(grep -c '^CLAIM: DustyCastle$' "$WORK/log")" -eq 1 ] \
  && [ "$(wc -l <"$WORK/log" | tr -d ' ')" -eq 1 ] \
  && ok "claim.sh: successful claim writes exactly one CLAIM comment" \
  || bad "success: rc=$RUN_RC log=$(cat "$WORK/log")"

echo "claim.test: unminted actor"
: >"$WORK/log"
env PATH="$WORK/bin:$PATH" AC_TEST_LOG="$WORK/log" AC2_FLIGHT_DIR="$WORK/flight" bash "$SUT" ac-test-1 --actor FoggyCreek >/dev/null 2>&1
rc=$?
{ [ "$rc" -eq 1 ] && [ ! -s "$WORK/log" ]; } && ok "claim.sh: unminted actor exits 1, claims nothing" || bad "unminted: rc=$rc"

echo ""
echo "claim.test: $PASS passed, $FAIL failed"
[ "$PASS" -gt 0 ] || { echo "claim.test: NOT-GATED — zero cases ran"; exit 1; }
[ "$FAIL" -eq 0 ]
