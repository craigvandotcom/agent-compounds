#!/usr/bin/env bash
# br-call.test.sh — fixture tests for skills/_tools/br-call.sh (ac-heyt.3).
#
# The mock `br` stands in for the real binary and drives BOTH failure shapes the helper
# must refuse — (a) a non-zero exit, (b) rc 0 with a `.error` envelope on stdout — plus
# the happy path. A real br invocation is never made: the helper's contract is shape-only.
#
# Run directly:  bash skills/_tools/br-call.test.sh
# Discovered automatically by scripts/run-all-harnesses.sh (glob over *.test.sh).
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
TOOL="$DIR/br-call.sh"
MOCK="$DIR/fixtures/br-call/mock-br"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

FAILURES=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }

# Precondition: the helper under test must exist — a missing helper makes every case
# below vacuous (this harness exists precisely to prove the helper refuses).
[ -f "$TOOL" ] || { echo "HARNESS FAIL: missing $TOOL"; exit 1; }

# The helper is SOURCED — that is its contract (a sourced helper exposing br_call); a
# harness that invoked it without sourcing would test nothing.
# shellcheck disable=SC1090
. "$TOOL"

# The mock br, on PATH for the duration: the three shapes its callers see in the wild.
mkdir -p "$WORK/bin"
cat > "$WORK/bin/br" <<'MOCK'
#!/usr/bin/env bash
# mock br — mirrors the measured shapes of the real binary with --json:
#   env BR_MOCK=err-exit  -> non-zero exit with an error envelope on stdout
#   env BR_MOCK=err-zero  -> rc 0 with a .error envelope on stdout (the measured trap)
#   env BR_MOCK=ok        -> rc 0 with a payload array on stdout (happy path)
if [ "${BR_MOCK:-ok}" = "err-exit" ]; then
  printf '%s' '{"error":{"code":"BR_CRASH","message":"mock non-zero failure","retryable":false}}'
  exit 7
elif [ "${BR_MOCK:-ok}" = "err-zero" ]; then
  printf '%s' '{"error":{"code":"ISSUE_NOT_FOUND","message":"Issue not found: ac-missing","hint":"Run br list","retryable":false}}'
  exit 0
else
  printf '%s' '[{"id":"ac-demo","title":"mock happy path","labels":["refined"]}]'
  exit 0
fi
MOCK
chmod +x "$WORK/bin/br"
PATH="$WORK/bin:$PATH" export PATH

# Happy path: the payload must pass through unchanged, so a caller's jq pipeline works.
OUT="$(BR_MOCK=ok br_call show ac-demo --json)"
RC=$?
[ "$RC" -eq 0 ] || { fail "happy path returns $RC, expected 0"; }
[ "$OUT" = '[{"id":"ac-demo","title":"mock happy path","labels":["refined"]}]' ] \
  && pass "happy path passes the payload through unchanged" \
  || fail "happy path payload changed: $OUT"

# Failure shape (a): non-zero exit -> return 2, message on stderr.
ERR_OUT="$(BR_MOCK=err-exit br_call show ac-x --json 2>"$WORK/err-a")"
RC=$?
[ "$RC" -eq 2 ] || { fail "non-zero exit returns $RC, expected 2"; }
grep -q 'mock non-zero failure' "$WORK/err-a" \
  && pass "non-zero exit: envelope message surfaced on stderr" \
  || fail "non-zero exit: message missing from stderr ($(cat "$WORK/err-a"))"
[ -z "$ERR_OUT" ] || fail "non-zero exit: stdout not silent, got $ERR_OUT"

# Failure shape (b): rc 0 with a .error envelope -> return 2, message on stderr. This is
# the exact shape that made the old `_show_json` read labels null at rc 0 and proceed.
ERR_ZERO="$(BR_MOCK=err-zero br_call show ac-missing --json 2>"$WORK/err-b")"
RC=$?
[ "$RC" -eq 2 ] || { fail "rc-0 envelope returns $RC, expected 2"; }
grep -q 'Issue not found: ac-missing' "$WORK/err-b" \
  && pass "rc-0 envelope: error message surfaced on stderr" \
  || fail "rc-0 envelope: message missing from stderr ($(cat "$WORK/err-b"))"
[ -z "$ERR_ZERO" ] || fail "rc-0 envelope: stdout not silent, got $ERR_ZERO"

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "OK: every br-call case passed ($(basename "$0"))"
  exit 0
else
  echo "FAILURES: $FAILURES — br-call behaves outside its contract ($(basename "$0"))"
  exit 1
fi