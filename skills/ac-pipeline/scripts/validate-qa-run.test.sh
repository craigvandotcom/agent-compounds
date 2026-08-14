#!/usr/bin/env bash
# validate-qa-run.test.sh — hermetic fixtures for validate-qa-run.sh
#
# Declared RED (bd-qa-verdict-writeback-gap-26ww1): a manifest with
# proves:["bd-example"] and no writeback.json must fail.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$SCRIPT_DIR/validate-qa-run.sh"
FAILURES=0
CASES=0

expect_exit() {
  CASES=$((CASES + 1))
  local dir="$1" want="$2" label="$3"
  set +e
  out=$(bash "$TARGET" "$dir" --skip-teardown-check 2>&1)
  got=$?
  set -e
  if [ "$got" -eq "$want" ]; then
    printf '  PASS  %s (exit %s)\n' "$label" "$got"
  else
    printf '  FAIL  %s — exit %s want %s\n%s\n' "$label" "$got" "$want" "$out"
    FAILURES=$((FAILURES + 1))
  fi
}

mkfix() {
  local d="$1"
  mkdir -p "$d"
  cat > "$d/journeys-manifest.json" <<'JSON'
{"run_id":"t","app":"bca","depth":"smoke","session_prefix":"qa-t","dispatched":[{"journey":"login","lane":"sequential","worker":"w1"}],"skipped":{},"proves":["bd-example"]}
JSON
  cat > "$d/verdict-login.json" <<'JSON'
{"journey":"login","lane":"sequential","session":"s","started_at":"2026-01-01T00:00:00Z","ended_at":"2026-01-01T00:01:00Z","status":"PASS","assertions":[],"covered":[],"console_errors":"none","findings":[]}
JSON
}

echo "--- proves writeback ---"
RED=$(mktemp -d /tmp/qa-proves-red-XXXXXX)
mkfix "$RED"
expect_exit "$RED" 1 "fails when proves[] beads have no writeback record"
# the script must name the missing id
if bash "$TARGET" "$RED" --skip-teardown-check 2>&1 | grep -q 'no writeback record for bd-example'; then
  CASES=$((CASES + 1)); printf '  PASS  red output names bd-example\n'
else
  CASES=$((CASES + 1)); printf '  FAIL  red output names bd-example\n'; FAILURES=$((FAILURES + 1))
fi
rm -rf "$RED"

GREEN=$(mktemp -d /tmp/qa-proves-green-XXXXXX)
mkfix "$GREEN"
printf '%s\n' '[{"id":"bd-example","verdict":"passed"}]' > "$GREEN/writeback.json"
expect_exit "$GREEN" 0 "same fixture with writeback covering bd-example exits 0"
rm -rf "$GREEN"

echo "--- pending finding still fails (bd-xx9yv, no regression) ---"
PEND=$(mktemp -d /tmp/qa-pending-XXXXXX)
mkdir -p "$PEND"
cat > "$PEND/journeys-manifest.json" <<'JSON'
{"run_id":"t","app":"bca","depth":"smoke","session_prefix":"qa-t","dispatched":[{"journey":"login","lane":"sequential","worker":"w1"}],"skipped":{}}
JSON
cat > "$PEND/verdict-login.json" <<'JSON'
{"journey":"login","lane":"sequential","session":"s","started_at":"2026-01-01T00:00:00Z","ended_at":"2026-01-01T00:01:00Z","status":"FAIL","assertions":[],"covered":[],"console_errors":"none","findings":[{"title":"x","severity":"qa-finding","repro":"","bead":"pending"}]}
JSON
expect_exit "$PEND" 1 "pending finding still fails"
rm -rf "$PEND"

echo ""
echo "validate-qa-run.test: ${CASES} cases, ${FAILURES} failures"
[ "$FAILURES" -eq 0 ]
