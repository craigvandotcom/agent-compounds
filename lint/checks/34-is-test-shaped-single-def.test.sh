#!/usr/bin/env bash
# 34-is-test-shaped-single-def.test.sh — the fixture proving Check 34's contract.
#
#   PROBE: the committed static fixture (flight-check.sh mentions is_test_shaped)
#           is RED; a second is_test_shaped() definition site is RED, naming
#           both sites; a sole definition site living outside close-gate.sh is
#           RED; the real registry is GREEN; a root with no
#           skills/ac-implement/scripts/ is NOT-GATED (2).
#
# ASSURANCE
#   PROBE:    bash lint/checks/34-is-test-shaped-single-def.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/34-is-test-shaped-single-def.py"
ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

# --- RED: the committed static fixture (flight-check.sh mentions it) ------------
out="$(python3 "$CHECK" "$ROOT/lint/fixtures/34-is-test-shaped-single-def" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "flight-check.sh mentions is_test_shaped"; then
  ok "RED: static fixture -> exit 1 naming the flight-check.sh mention"
else
  bad "RED case: expected 1 naming flight-check.sh, got $rc"; printf '%s\n' "$out"
fi

# --- RED: a second definition site -----------------------------------------------
w="$(mktemp -d)"
mkdir -p "$w/skills/ac-implement/scripts"
printf 'is_test_shaped() { return 0; }\n' > "$w/skills/ac-implement/scripts/close-gate.sh"
printf 'is_test_shaped() { return 1; }\n' > "$w/skills/ac-implement/scripts/other.sh"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "has 2 definition site(s)"; then
  ok "RED: second definition site -> exit 1 naming both sites"
else
  bad "second-site case: expected 1 naming 2 sites, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- RED: the sole definition site is NOT close-gate.sh --------------------------
w="$(mktemp -d)"
mkdir -p "$w/skills/ac-implement/scripts"
printf 'is_test_shaped() { return 0; }\n' > "$w/skills/ac-implement/scripts/wrong-owner.sh"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "has 1 definition site(s) (skills/ac-implement/scripts/wrong-owner.sh)"; then
  ok "RED: sole site not close-gate.sh -> exit 1 naming it"
else
  bad "wrong-owner case: expected 1 naming wrong-owner.sh, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- GREEN: single site in close-gate.sh, flight-check.sh clean ------------------
w="$(mktemp -d)"
mkdir -p "$w/skills/ac-implement/scripts"
printf 'is_test_shaped() { return 0; }\n' > "$w/skills/ac-implement/scripts/close-gate.sh"
printf '#!/usr/bin/env bash\necho hi\n' > "$w/skills/ac-implement/scripts/flight-check.sh"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  ok "GREEN: single close-gate.sh definition, flight-check.sh clean"
else
  bad "GREEN case: expected 0, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- GREEN: the real registry ----------------------------------------------------
out="$(python3 "$CHECK" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  ok "GREEN: the real registry's contract holds"
else
  bad "real-tree case: expected 0, got $rc"; printf '%s\n' "$out"
fi

# --- NOT-GATED: no skills/ac-implement/scripts/ -----------------------------------
w="$(mktemp -d)"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q "NOT-CHECKED"; then
  ok "NOT-GATED: no skills/ac-implement/scripts/ -> exit 2, verified nothing"
else
  bad "NOT-GATED case: expected 2, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

echo "34-is-test-shaped-single-def.test.sh: ${fails} failure(s)"
[ "$fails" -eq 0 ]
