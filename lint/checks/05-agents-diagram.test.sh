#!/usr/bin/env bash
# 05-agents-diagram.test.sh — the fixture proving Check 5's contract.
#
#   PROBE: the committed static fixture (skills/ + agents/ only) is RED
#           naming the three missing diagram paths; the real registry is
#           GREEN; a nonexistent root is NOT-GATED (2).
#
# ASSURANCE
#   PROBE:    bash lint/checks/05-agents-diagram.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/05-agents-diagram.py"
ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

# --- RED: the committed static fixture ------------------------------------------
# _plans is skipped as a gitignored local-only path (the fixture lives inside
# this repo, so the enclosing .gitignore governs — same as the legacy block).
out="$(python3 "$CHECK" "$ROOT/lint/fixtures/05-agents-diagram" 2>&1)"; rc=$?
if [ "$rc" = 1 ] \
   && printf '%s' "$out" | grep -q "diagram path missing: deploy.sh" \
   && printf '%s' "$out" | grep -q "diagram path missing: templates" \
   && printf '%s' "$out" | grep -q "NOTICE: diagram path '_plans' is gitignored"; then
  ok "RED: static fixture -> exit 1 naming deploy.sh and templates; _plans skipped as gitignored"
else
  bad "RED case: expected 1 naming two paths + the _plans NOTICE, got $rc"; printf '%s\n' "$out"
fi

# --- GREEN: the real registry ----------------------------------------------------
out="$(python3 "$CHECK" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  ok "GREEN: every real diagram path exists"
else
  bad "real-tree case: expected 0, got $rc"; printf '%s\n' "$out"
fi

# --- NOT-GATED: a nonexistent root -----------------------------------------------
out="$(python3 "$CHECK" /tmp/05ad-void-root-does-not-exist 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q "NOT-CHECKED"; then
  ok "NOT-GATED: nonexistent root -> exit 2, verified nothing"
else
  bad "NOT-GATED case: expected 2, got $rc"; printf '%s\n' "$out"
fi

echo "05-agents-diagram.test.sh: ${fails} failure(s)"
[ "$fails" -eq 0 ]
