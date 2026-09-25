#!/usr/bin/env bash
# prod-write-tripwire.test.sh — the signal classifier in isolation.
#
# The escaped data-fix fixture is the load-bearing case: it names neither a production
# mechanism nor SQL, so a mechanism-only tripwire would wave it through. This harness pins
# every signal class, both recorded passes, and the missing-gate-pair refusal.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="$DIR/prod-write-tripwire.sh"
FIXTURE="$DIR/fixtures/prod-write/escaped-data-fix.md"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASSES=0
FAILURES=0
pass() { echo "  PASS: $1"; PASSES=$((PASSES + 1)); }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }

run_case() { # <name> <expected-rc> <expected-output> <description> [labels] [decision-count]
  local name="$1" want_rc="$2" want="$3" desc="$4" labels="${5:-}" decisions="${6:-0}"
  local out rc
  out=$(bash "$TOOL" "$desc" "$labels" "$decisions" "$name" 2>&1); rc=$?
  if [ "$rc" -eq "$want_rc" ] && printf '%s\n' "$out" | grep -qF "$want"; then
    pass "$name"
  else
    fail "$name (rc=$rc, wanted $want_rc + '$want')" "$out"
  fi
}

cat >"$WORK/plain.md" <<'EOF'
## Intent
Refactor the local parser and add unit coverage.

## Acceptance Criteria
- The parser remains deterministic.
  Probe: `bash skills/_tools/prod-write-tripwire.test.sh` — tier: standing-harness
EOF

cat >"$WORK/negative.md" <<'EOF'
## Intent
Refactor the local parser and add unit coverage.

prod-write: none — this changes only local test fixtures and no runtime data path.
EOF

if [ ! -x "$TOOL" ]; then
  fail "tripwire harness is executable" "$TOOL missing or not executable"
else
  pass "tripwire harness is executable"
fi

run_case "escaped data fix is refused as data-state with the matched text" 1 \
  "[data-state]" "$FIXTURE" "refined" 0
run_case "a plain code-only description passes" 0 "no prod-write signal" "$WORK/plain.md" "refined" 0
run_case "a non-empty negative verdict passes" 0 "recorded negative verdict" "$WORK/negative.md" "refined" 0
# The negative verdict must be in the fixture itself, so append it to a disposable copy.
cp "$FIXTURE" "$WORK/negative-fixture.md"
printf '%s\n' 'prod-write: none — the sanitized fixture is classifier input only.' >>"$WORK/negative-fixture.md"
run_case "the escaped fixture passes with its own negative verdict" 0 "recorded negative verdict" \
  "$WORK/negative-fixture.md" "refined" 0
run_case "sensitive-prod plus a DECISION blocks edge passes" 0 "gate pair" \
  "$FIXTURE" "refined,sensitive-prod" 1
run_case "sensitive-prod without the DECISION edge is refused" 1 "missing recorded gate pair" \
  "$FIXTURE" "refined,sensitive-prod" 0

for case_spec in \
  "mechanism|--execute a local command" \
  "mechanism|supabase db push" \
  "mechanism|--linked" \
  "mechanism|--project-ref" \
  "mechanism|api.supabase.co" \
  "mechanism|psql" \
  "SQL write|UPDATE catalog SET name = 'x'" \
  "SQL write|INSERT INTO catalog (id) VALUES (1)" \
  "SQL write|DELETE FROM catalog" \
  "SQL write|TRUNCATE catalog" \
  "data-state|backfill the reference values" \
  "data-state|a data-fix migration" \
  "data-state|a one-off update script" \
  "data-state|production database rows"
do
  expected=${case_spec%%|*}
  signal=${case_spec#*|}
  printf '## Intent\n%s\n' "$signal" >"$WORK/signal.md"
  run_case "$expected signal: $signal" 1 "[$expected]" "$WORK/signal.md" "" 0
done

cat >"$WORK/empty-reason.md" <<'EOF'
## Intent
Run a one-off update script against the service.
prod-write: none —
EOF
run_case "an empty negative reason does not count" 1 "missing recorded gate pair" \
  "$WORK/empty-reason.md" "" 0

out=$(bash "$TOOL" "$WORK/plain.md" "refined" "not-a-count" 2>&1); rc=$?
if [ "$rc" -eq 2 ] && printf '%s\n' "$out" | grep -q "NOT-GATED"; then
  pass "a malformed decision-edge count is NOT-GATED, never read as zero"
else
  fail "malformed decision count" "rc=$rc: $out"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "$PASSES passed, $FAILURES failed — all prod-write tripwire tests passed."
  exit 0
fi
echo "$FAILURES prod-write tripwire test(s) FAILED."
exit 1
