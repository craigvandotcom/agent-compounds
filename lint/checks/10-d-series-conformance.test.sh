#!/usr/bin/env bash
# 10-d-series-conformance.test.sh — the contract harness for lint/checks/10-d-series-conformance.py.
#
#   PROBE: a canon file missing its load-bearing marker is FAILED with the
#           D-tag named; a fully conforming tree PASSES; a tree with no
#           skills/ is NOT-GATED (exit 2). The stale-pattern row (D9b) fires
#           in reverse — its presence is the violation.
#
# ASSURANCE
#   PROBE:    bash lint/checks/10-d-series-conformance.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/10-d-series-conformance.py"
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

# --- 1 RED: canon file without its marker -> exit 1, tag named ---------------
t="$work/red"
mkdir -p "$t/skills/ac-plan-lab"
printf '%s\n' 'no write-back section here' > "$t/skills/ac-plan-lab/SKILL.md"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "^FAIL 10-d-series-conformance: D5: " "$OUT"; then
  ok "RED: missing write-back section failed, D5 named"
else
  bad "RED: expected exit 1 naming D5, got $rc"; cat "$OUT"
fi

# --- 2 RED-ABSENT: stale wave/ pattern present -> exit 1, D9b named -----------
t="$work/stale"
mkdir -p "$t/skills/ac-plan-lab" "$t/skills/ac-publish/references" \
  "$t/skills/ac-distribute" "$t/skills/ac-loop" "$t/skills/ac-human-session"
printf '%s\n' 'Write Back section' > "$t/skills/ac-plan-lab/SKILL.md"
printf '%s\n' 'the sole owner of version bumps' > "$t/skills/ac-publish/references/version-bump.md"
printf '%s\n' 'defer to the version-bump owner' > "$t/skills/ac-distribute/SKILL.md"
printf '%s\n' 'startswith("wave/")' > "$t/skills/ac-loop/SKILL.md"
printf '%s\n' 'oldest-within-tier' > "$t/skills/ac-human-session/SKILL.md"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "^FAIL 10-d-series-conformance: D9b: " "$OUT"; then
  ok "RED-ABSENT: stale wave/ pattern failed, D9b named"
else
  bad "RED-ABSENT: expected exit 1 naming D9b, got $rc"; cat "$OUT"
fi

# --- 3 GREEN: fully conforming tree -> exit 0 ---------------------------------
t="$work/green"
mkdir -p "$t/skills/ac-plan-lab" "$t/skills/ac-publish/references" \
  "$t/skills/ac-distribute" "$t/skills/ac-loop" "$t/skills/ac-human-session"
printf '%s\n' 'Write Back section' > "$t/skills/ac-plan-lab/SKILL.md"
printf '%s\n' 'the sole owner of version bumps' > "$t/skills/ac-publish/references/version-bump.md"
printf '%s\n' 'defer to the version-bump owner' > "$t/skills/ac-distribute/SKILL.md"
printf '%s\n' 'clean loop skill' > "$t/skills/ac-loop/SKILL.md"
printf '%s\n' 'oldest-within-tier' > "$t/skills/ac-human-session/SKILL.md"
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
  echo "All 10-d-series-conformance contract cases passed."
  exit 0
fi
echo "$fails case(s) FAILED."
exit 1
