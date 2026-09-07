#!/usr/bin/env bash
# 6-portability.test.sh — the fixture proving Check 6's contract.
#
#   RED: the committed static fixture (all five patterns in one file) exits 1
#        naming every pattern; a fresh single hit in skills/ exits 1.
#   GREEN: the real registry exits 0.
#   NOT-GATED: a root with no skills/ exits 2.
#
# ASSURANCE
#   PROBE:    bash lint/checks/6-portability.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/6-portability.py"
ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
pass() { echo "  PASS $1"; }
fail() { echo "  FAIL $1"; fails=$((fails + 1)); }

# --- RED: the committed static fixture -------------------------------------------
out="$(python3 "$CHECK" "$ROOT/lint/fixtures/6-portability" 2>&1)"; rc=$?
n_hits="$(printf '%s' "$out" | grep -c 'portability violation' || true)"
if [ "$rc" = 1 ] && [ "$n_hits" = 5 ] \
   && printf '%s' "$out" | grep -q "portability violation 'canonical_ingredients'" \
   && printf '%s' "$out" | grep -q "portability violation 'For Body Compass'" \
   && printf '%s' "$out" | grep -q "portability violation '127.0.0.1:54321'" \
   && printf '%s' "$out" | grep -q "portability violation 'bd-8nse'" \
   && printf '%s' "$out" | grep -q "portability violation 'bd-9veq'"; then
  pass "RED: all five patterns named -> exit 1"
else
  fail "RED fixture: expected 1 with 5 hits, got $rc with $n_hits"; printf '%s\n' "$out"
fi

# --- RED: one fresh hit in a scratch tree ------------------------------------------
w="$(mktemp -d)"
mkdir -p "$w/skills/some-skill"
printf 'reads canonical_ingredients\n' > "$w/skills/some-skill/SKILL.md"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "portability violation 'canonical_ingredients' found in skills/some-skill/SKILL.md"; then
  pass "RED: fresh skills hit -> exit 1 with relative path"
else
  fail "fresh-hit case: expected 1, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- GREEN: the real registry --------------------------------------------------------
out="$(python3 "$CHECK" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  pass "GREEN: no portability violation in the real registry"
else
  fail "real-tree case: expected 0, got $rc"; printf '%s\n' "$out"
fi

# --- NOT-GATED: no skills/ -------------------------------------------------------------
w="$(mktemp -d)"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q "NOT-CHECKED"; then
  pass "NOT-GATED: no skills/ dir -> exit 2"
else
  fail "NOT-GATED case: expected 2, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

echo "6-portability.test.sh: $((4 - fails)) passed, $fails failed"
[ "$fails" -eq 0 ]
