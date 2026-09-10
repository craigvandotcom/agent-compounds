#!/usr/bin/env bash
# 11-g-series-conformance.test.sh — the contract harness for lint/checks/11-g-series-conformance.py.
#
#   PROBE: a canon file missing its marker is FAILED with the G-tag named;
#           the retired UI Validation Suite block surviving is FAILED (G7a);
#           a fully conforming tree PASSES; a tree with no skills/ is
#           NOT-GATED (exit 2).
#
# ASSURANCE
#   PROBE:    bash lint/checks/11-g-series-conformance.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/11-g-series-conformance.py"
ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

OUT="$(mktemp)"
run_check() {
  python3 "$CHECK" "$1" >"$OUT" 2>&1
  echo $?
}

work="$(mktemp -d)"
trap 'rm -rf "$work" "$OUT"' EXIT

build_green() { # <root>
  mkdir -p "$1/skills/ac-pipeline/references" "$1/skills/ac-backlog" "$1/skills/ac-distribute" "$1/skills/ac-land"
  printf '%s\n' '23:00 cross-cadence sweep' > "$1/skills/ac-pipeline/references/schedule.md"
  printf '%s\n' 'Route by shape: small + clear goes to a bead' > "$1/skills/ac-backlog/SKILL.md"
  printf '%s\n' 'fast-forward-equivalent QA counts as fresh' > "$1/skills/ac-distribute/SKILL.md"
  printf '%s\n' 'emit a skill-hotfix: commit' > "$1/skills/ac-land/SKILL.md"
}

# --- 1 RED: canon file without its marker -> exit 1, tag named ---------------
t="$work/red"
mkdir -p "$t/skills/ac-pipeline/references"
printf '%s\n' 'no schedule table here' > "$t/skills/ac-pipeline/references/schedule.md"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "^FAIL 11-g-series-conformance: G1: " "$OUT"; then
  ok "RED: missing schedule table failed, G1 named"
else
  bad "RED: expected exit 1 naming G1, got $rc"; cat "$OUT"
fi

# --- 2 RED-ABSENT: retired block survives -> exit 1, G7a named ----------------
t="$work/stale"
build_green "$t"
printf '%s\n' '1c. UI Validation Suite' >> "$t/skills/ac-land/SKILL.md"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "^FAIL 11-g-series-conformance: G7a: " "$OUT"; then
  ok "RED-ABSENT: retired UI suite block failed, G7a named"
else
  bad "RED-ABSENT: expected exit 1 naming G7a, got $rc"; cat "$OUT"
fi

# --- 3 GREEN: fully conforming tree -> exit 0 ---------------------------------
t="$work/green"
build_green "$t"
rc=$(run_check "$t")
if [ "$rc" = 0 ]; then
  ok "GREEN: conforming tree passes"
else
  bad "GREEN: expected exit 0, got $rc"; cat "$OUT"
fi

# --- 4 NOT-GATED: no skills/ -> exit 2 ----------------------------------------
t="$work/empty"
rc=$(run_check "$t")
if [ "$rc" = 2 ] && grep -qi "NOT-CHECKED" "$OUT"; then
  ok "EMPTY: no skills/ -> NOT-GATED exit 2"
else
  bad "EMPTY: expected exit 2 NOT-CHECKED, got $rc"; cat "$OUT"
fi

# --- 5 LIVE: the real registry is green ---------------------------------------
rc=$(run_check "$ROOT")
if [ "$rc" = 0 ]; then
  ok "LIVE: registry tree passes"
else
  bad "LIVE: expected exit 0 on the real registry, got $rc"; cat "$OUT"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "All 11-g-series-conformance contract cases passed."
  exit 0
fi
echo "$fails case(s) FAILED."
exit 1
