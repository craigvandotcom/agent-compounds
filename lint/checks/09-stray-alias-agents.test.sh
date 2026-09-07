#!/usr/bin/env bash
# 09-stray-alias-agents.test.sh — the fixture proving Check 9's contract.
#
#   PROBE: the committed static fixture (agents/engineer.md present) is RED;
#           a reviewer.md copy is RED; the real registry is GREEN; a root
#           with no agents/ dir is NOT-GATED (2).
#
# ASSURANCE
#   PROBE:    bash lint/checks/09-stray-alias-agents.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/09-stray-alias-agents.py"
ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

# --- RED: the committed static fixture (engineer.md) -----------------------------
out="$(python3 "$CHECK" "$ROOT/lint/fixtures/09-stray-alias-agents" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "agents/engineer.md exists"; then
  ok "RED: stray engineer.md -> exit 1"
else
  bad "RED case: expected 1, got $rc"; printf '%s\n' "$out"
fi

# --- RED: a stray reviewer.md ----------------------------------------------------
w="$(mktemp -d)"
mkdir -p "$w/agents"
printf 'x\n' > "$w/agents/reviewer.md"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "agents/reviewer.md exists"; then
  ok "RED: stray reviewer.md -> exit 1"
else
  bad "reviewer case: expected 1, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- GREEN: the real registry ----------------------------------------------------
out="$(python3 "$CHECK" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  ok "GREEN: no retired alias in the real registry"
else
  bad "real-tree case: expected 0, got $rc"; printf '%s\n' "$out"
fi

# --- NOT-GATED: no agents/ directory ---------------------------------------------
w="$(mktemp -d)"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q "NOT-CHECKED"; then
  ok "NOT-GATED: no agents/ dir -> exit 2, verified nothing"
else
  bad "NOT-GATED case: expected 2, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

echo "09-stray-alias-agents.test.sh: ${fails} failure(s)"
[ "$fails" -eq 0 ]
