#!/usr/bin/env bash
# 2-ac-cross-references.test.sh — the fixture proving Check 2's contract.
#
#   RED: the committed static fixture exits 1 naming the unresolvable /ac-*.
#   GREEN: the real registry exits 0 with the full token census.
#   NOT-GATED: a root with no skills/ exits 2.
#
# ASSURANCE
#   PROBE:    bash lint/checks/2-ac-cross-references.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/2-ac-cross-references.py"
ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
pass() { echo "  PASS $1"; }
fail() { echo "  FAIL $1"; fails=$((fails + 1)); }

# --- RED: the committed static fixture -------------------------------------------
out="$(python3 "$CHECK" "$ROOT/lint/fixtures/2-ac-cross-references" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "/ac-ghost-skill referenced in skills"; then
  pass "RED: unresolvable /ac-ghost-skill -> exit 1"
else
  fail "RED fixture: expected 1, got $rc"; printf '%s\n' "$out"
fi

# --- GREEN: path segments, globs and sed addresses do NOT fire --------------------
w="$(mktemp -d)"
mkdir -p "$w/skills/clean"
printf 'See /tmp/ac-claim.txt, scripts/ac-thing.sh, /ac-example-bead:start, /ac-never-made-*.\n' \
  > "$w/skills/clean/SKILL.md"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  pass "GREEN: only path segments / glob shorthand / sed address -> exit 0"
else
  fail "false-positive case: expected 0, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- GREEN: the real registry ------------------------------------------------------
out="$(python3 "$CHECK" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  pass "GREEN: every /ac-* invocation resolves in the real registry"
else
  fail "real-tree case: expected 0, got $rc"; printf '%s\n' "$out"
fi

# --- NOT-GATED: no skills/ ----------------------------------------------------------
w="$(mktemp -d)"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q "NOT-CHECKED"; then
  pass "NOT-GATED: no skills/ dir -> exit 2"
else
  fail "NOT-GATED case: expected 2, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

echo "2-ac-cross-references.test.sh: $((4 - fails)) passed, $fails failed"
[ "$fails" -eq 0 ]
