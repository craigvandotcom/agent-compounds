#!/usr/bin/env bash
# 15-line-ceilings.test.sh — the contract harness for lint/checks/15-line-ceilings.py.
#
#   PROBE: a SKILL.md over its tier ceiling is FAILED with the skill named; a
#           config.json ceiling RAISED beyond HEAD's committed value AND
#           beyond its measured tier is FAILED by the one-way ratchet; an
#           UNCHANGED constant left stranded above the derived ceiling by a
#           tier-max skill SHRINKING is a NOTICE, never a fail (2026-09-12
#           fix — the person who shrinks the biggest file must not go red);
#           the same shrink with no git history at all (base unresolvable)
#           still degrades to NOTICE, never a false fail; a fully conforming
#           tree PASSES; a tree with no skills is NOT-GATED (exit 2).
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

# --- 2 RATCHET: config.json ceiling RAISED beyond HEAD's committed value -----
# HEAD commits conductor_ceiling: 1110; the working tree raises it to 1300,
# beyond the derived ceiling too -> a real raise, refused.
t="$work/ratchet"
mkdir -p "$t/skills/cond-lead" "$t/skills/small"
write_config "$t" 1110 730
python3 - "$t" <<'PYEOF'
import sys
t = sys.argv[1]
open(t + "/skills/cond-lead/SKILL.md", "w").write("# c\n" + "".join("l\n" for _ in range(1000)))
open(t + "/skills/small/SKILL.md", "w").write("# s\nl\n")
PYEOF
git -C "$t" init -q -b main
git -C "$t" config user.email t@t.t; git -C "$t" config user.name t
git -C "$t" add -A && git -C "$t" commit -qm base
write_config "$t" 1300 730
git -C "$t" add lint/config.json
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "ratchet violated — CONDUCTOR_CEILING raised from 1110 (HEAD) to 1300" "$OUT"; then
  ok "RATCHET: raised-beyond-HEAD constant refused, derived value named"
else
  bad "RATCHET: expected exit 1 naming the HEAD-raise, got $rc"; cat "$OUT"
fi

# --- 2b NOTICE: constant UNCHANGED, tier-max skill SHRANK (git history present) --
# HEAD and the working tree agree on standard_ceiling: 730 — nobody raised
# anything. The tier-max standard skill shrinks from 900 to 100 lines between
# the base commit and the working tree, so the derived ceiling drops well
# below 730. This must NOT fail: it is exactly the shrink the 2026-09-12 fix
# protects.
t="$work/notice-shrink"
mkdir -p "$t/skills/cond-lead" "$t/skills/big"
write_config "$t" 1110 730
python3 - "$t" <<'PYEOF'
import sys
t = sys.argv[1]
open(t + "/skills/cond-lead/SKILL.md", "w").write("# c\n" + "".join("l\n" for _ in range(1000)))
open(t + "/skills/big/SKILL.md", "w").write("# b\n" + "".join("l\n" for _ in range(900)))
PYEOF
git -C "$t" init -q -b main
git -C "$t" config user.email t@t.t; git -C "$t" config user.name t
git -C "$t" add -A && git -C "$t" commit -qm base
python3 - "$t" <<'PYEOF'
import sys
t = sys.argv[1]
open(t + "/skills/big/SKILL.md", "w").write("# b\n" + "".join("l\n" for _ in range(100)))
PYEOF
rc=$(run_check "$t")
if [ "$rc" = 0 ] && grep -q "NOTICE ratchet        STANDARD_CEILING 730 exceeds derived" "$OUT" \
   && ! grep -q "^FAIL " "$OUT"; then
  ok "NOTICE: unraised constant stranded by a shrink -> exit 0, not a failure"
else
  bad "NOTICE case: expected exit 0 with a NOTICE line, got $rc"; cat "$OUT"
fi

# --- 2c NOTICE: same shrink with NO git history at all (base unresolvable) ------
# A raise this check cannot prove (no HEAD to compare against) must never be
# reported as one — degrade to NOTICE, not a fail.
t="$work/notice-no-git"
mkdir -p "$t/skills/cond-lead" "$t/skills/small"
write_config "$t" 1110 730
python3 - "$t" <<'PYEOF'
import sys
t = sys.argv[1]
open(t + "/skills/cond-lead/SKILL.md", "w").write("# c\n" + "".join("l\n" for _ in range(1000)))
open(t + "/skills/small/SKILL.md", "w").write("# s\n" + "".join("l\n" for _ in range(100)))
PYEOF
rc=$(run_check "$t")
if [ "$rc" = 0 ] && grep -q "NOTICE ratchet        STANDARD_CEILING 730 exceeds derived" "$OUT"; then
  ok "NOTICE: no-git tree, base unresolvable -> exit 0, not a false fail"
else
  bad "no-git NOTICE case: expected exit 0 with a NOTICE line, got $rc"; cat "$OUT"
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
