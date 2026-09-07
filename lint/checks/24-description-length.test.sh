#!/usr/bin/env bash
# 24-description-length.test.sh — the fixture proving Check 24's contract.
#
#   PROBE: the committed static fixture is RED (a 1310-char description) and
#           carries a WARN line (960 chars) that is reported, never a
#           finding; the real registry is GREEN with its WARN band printed;
#           a root with no skills/ dir is NOT-GATED (2).
#
# ASSURANCE
#   PROBE:    bash lint/checks/24-description-length.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/24-description-length.py"
ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

# --- RED + WARN: the committed static fixture ------------------------------------
out="$(python3 "$CHECK" "$ROOT/lint/fixtures/24-description-length" 2>&1)"; rc=$?
if [ "$rc" = 1 ] \
   && printf '%s' "$out" | grep -q "overcap: description .* over the 1024 cap" \
   && printf '%s' "$out" | grep -q "WARN nearcap" \
   && printf '%s' "$out" | grep -q "1 skill description(s) over the 1024-char"; then
  ok "RED: over-cap description -> exit 1; the 960-char WARN is a report, not a finding"
else
  bad "RED case: expected 1 with WARN line, got $rc"; printf '%s\n' "$out"
fi

# --- GREEN: the real registry ----------------------------------------------------
out="$(python3 "$CHECK" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  ok "GREEN: every real description inside the cap"
else
  bad "real-tree case: expected 0, got $rc"; printf '%s\n' "$out"
fi

# --- NOT-GATED: no skills directory ----------------------------------------------
w="$(mktemp -d)"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q "NOT-CHECKED"; then
  ok "NOT-GATED: no skills/ dir -> exit 2, verified nothing"
else
  bad "NOT-GATED case: expected 2, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

echo "24-description-length.test.sh: ${fails} failure(s)"
[ "$fails" -eq 0 ]
