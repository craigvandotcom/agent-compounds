#!/usr/bin/env bash
# 15-line-ceilings.test.sh — the contract harness for lint/checks/15-line-ceilings.py.
#
#   PROBE: a SKILL.md over its tier ceiling is FAILED with the skill named;
#           a raised constant that outruns its measured tier is FAILED by the
#           one-way ratchet; a fully conforming tree PASSES; a tree with no
#           skills is NOT-GATED (exit 2).
#
# ASSURANCE
#   PROBE:    bash lint/checks/15-line-ceilings.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/15-line-ceilings.py"
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

write_config() { # <root> <conductor_ceiling> <standard_ceiling>
  mkdir -p "$1/lint"
  printf '{\n  "conductor_ceiling": %s,\n  "standard_ceiling": %s,\n  "conductor_skills": ["cond-lead"]\n}\n' \
    "$2" "$3" > "$1/lint/config.json"
}

# --- 1 RED: standard skill over the ceiling -> exit 1, skill named ------------
t="$work/red"
mkdir -p "$t/skills/big" "$t/skills/cond-lead"
write_config "$t" 1110 730
python3 - "$t" <<'PYEOF'
import sys
t = sys.argv[1]
open(t + "/skills/cond-lead/SKILL.md", "w").write("# c\n" + "".join("l\n" for _ in range(1000)))
open(t + "/skills/big/SKILL.md", "w").write("# b\n" + "".join("l\n" for _ in range(900)))
PYEOF
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "standard skill 'big' SKILL.md is 901 lines > 730 ceiling" "$OUT"; then
  ok "RED: oversized standard skill failed, named"
else
  bad "RED: expected exit 1 naming 'big', got $rc"; cat "$OUT"
fi

# --- 2 RATCHET: constant raised beyond its measured tier -> exit 1 ------------
t="$work/ratchet"
mkdir -p "$t/skills/cond-lead" "$t/skills/small"
write_config "$t" 1300 730
python3 - "$t" <<'PYEOF'
import sys
t = sys.argv[1]
open(t + "/skills/cond-lead/SKILL.md", "w").write("# c\n" + "".join("l\n" for _ in range(1000)))
open(t + "/skills/small/SKILL.md", "w").write("# s\nl\n")
PYEOF
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "ratchet violated — CONDUCTOR_CEILING (1300) exceeds derived ceiling (1160" "$OUT"; then
  ok "RATCHET: raised constant refused, derived value named"
else
  bad "RATCHET: expected exit 1 naming the ratchet violation, got $rc"; cat "$OUT"
fi

# --- 3 GREEN: everything under the ceilings -> exit 0 -------------------------
# The one-way ratchet demands a plausible tier: a standard tier max below
# ceil(730 / 1.10) would itself fail the ratchet leg (faithful legacy behavior),
# so the green tree's standard tier max is 700 lines.
t="$work/green"
mkdir -p "$t/skills/cond-lead" "$t/skills/small"
write_config "$t" 1110 730
python3 - "$t" <<'PYEOF'
import sys
t = sys.argv[1]
open(t + "/skills/cond-lead/SKILL.md", "w").write("# c\n" + "".join("l\n" for _ in range(1000)))
open(t + "/skills/small/SKILL.md", "w").write("# s\n" + "".join("l\n" for _ in range(699)))
PYEOF
rc=$(run_check "$t")
if [ "$rc" = 0 ]; then
  ok "GREEN: conforming tree passes"
else
  bad "GREEN: expected exit 0, got $rc"; cat "$OUT"
fi

# --- 4 NOT-GATED: no skills -> exit 2 -----------------------------------------
t="$work/empty"
write_config "$t" 1110 730
rc=$(run_check "$t")
if [ "$rc" = 2 ] && grep -qi "NOT-CHECKED" "$OUT"; then
  ok "EMPTY: no skills -> NOT-GATED exit 2"
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
  echo "All 15-line-ceilings contract cases passed."
  exit 0
fi
echo "$fails case(s) FAILED."
exit 1
