#!/usr/bin/env bash
# 1-dead-patterns.test.sh — the fixture proving Check 1's contract.
#
#   RED: the committed static fixture (four dead patterns across skills/ and
#        agents/) exits 1 naming every pattern; a single-pattern RED exits 1.
#   GREEN: the real registry (no dead pattern) exits 0.
#   NOT-GATED: a root with no *.md under skills/ or agents/ exits 2.
#
# ASSURANCE
#   PROBE:    bash lint/checks/1-dead-patterns.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/1-dead-patterns.py"
ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
pass() { echo "  PASS $1"; }
fail() { echo "  FAIL $1"; fails=$((fails + 1)); }

# --- RED: the committed static fixture -------------------------------------------
out="$(python3 "$CHECK" "$ROOT/lint/fixtures/1-dead-patterns" 2>&1)"; rc=$?
if [ "$rc" = 1 ] \
   && printf '%s' "$out" | grep -q "dead pattern 'persona-catalog'" \
   && printf '%s' "$out" | grep -q "dead pattern 'craigs-setup'" \
   && printf '%s' "$out" | grep -q "dead pattern 'browser-qa-agent'" \
   && printf '%s' "$out" | grep -q "dead pattern 'agent-compounds/commands/'"; then
  pass "RED: all four dead patterns named -> exit 1"
else
  fail "RED fixture: expected 1 naming all four patterns, got $rc"; printf '%s\n' "$out"
fi

# --- RED: one fresh pattern hit in a scratch tree ---------------------------------
w="$(mktemp -d)"
mkdir -p "$w/skills/some-skill"
printf 'spawns the browser-qa-agent\n' > "$w/skills/some-skill/SKILL.md"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "dead pattern 'browser-qa-agent' found in skills/some-skill/SKILL.md"; then
  pass "RED: fresh skills hit -> exit 1 with relative path"
else
  fail "fresh-hit case: expected 1, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- GREEN: the real registry ------------------------------------------------------
out="$(python3 "$CHECK" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  pass "GREEN: no dead pattern in the real registry"
else
  fail "real-tree case: expected 0, got $rc"; printf '%s\n' "$out"
fi

# --- NOT-GATED: nothing to scan ------------------------------------------------------
w="$(mktemp -d)"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q "NOT-CHECKED"; then
  pass "NOT-GATED: no *.md under skills/ or agents/ -> exit 2"
else
  fail "NOT-GATED case: expected 2, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

echo "1-dead-patterns.test.sh: $((4 - fails)) passed, $fails failed"
[ "$fails" -eq 0 ]
