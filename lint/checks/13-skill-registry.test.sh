#!/usr/bin/env bash
# 13-skill-registry.test.sh — the fixture proving Check 13's contract.
#
#   PROBE: an over-1024-char description is RED (the fixture's run.sh);
#           the real registry is GREEN; a tree missing the judge is
#           NOT-GATED (2).
#
# ASSURANCE
#   PROBE:    bash lint/checks/13-skill-registry.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/13-skill-registry.py"
ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

# --- RED: the run.sh fixture demonstrates the over-cap case ----------------------
if bash "$ROOT/lint/fixtures/13-skill-registry/run.sh" >/tmp/13fx.out 2>&1; then
  ok "RED: over-cap description -> judge fails, check exits 1"
else
  bad "RED case: run.sh did not demonstrate the RED"; cat /tmp/13fx.out
fi

# --- GREEN: the real registry ----------------------------------------------------
out="$(python3 "$CHECK" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  ok "GREEN: the real registry is inside budget, cap and graph"
else
  bad "real-tree case: expected 0, got $rc"; printf '%s\n' "$out"
fi

# --- NOT-GATED: the judge script is missing from the audited root ----------------
w="$(mktemp -d)"
mkdir -p "$w/skills"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q "NOT-CHECKED"; then
  ok "NOT-GATED: missing judge -> exit 2, verified nothing"
else
  bad "NOT-GATED case: expected 2, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

echo "13-skill-registry.test.sh: ${fails} failure(s)"
[ "$fails" -eq 0 ]
