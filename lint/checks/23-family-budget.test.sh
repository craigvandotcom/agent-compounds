#!/usr/bin/env bash
# 23-family-budget.test.sh — the fixture proving Check 23's contract.
#
#   PROBE: the committed static fixture (an 813-line family SKILL.md) is RED
#           naming the family cap; a synthetic minimal family (small SKILL.md
#           + one pointed-at reference + one triad-declaring lean script) is
#           GREEN; the real registry is GREEN; a root missing the judge is
#           NOT-GATED (2).
#
# ASSURANCE
#   PROBE:    bash lint/checks/23-family-budget.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/23-family-budget.py"
ROOT="$(cd "$HERE/../.." && pwd)"
JUDGE="$ROOT/scripts/ac-budget-check.sh"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

# --- RED: the committed static fixture (family cap breached) ---------------------
out="$(python3 "$CHECK" "$ROOT/lint/fixtures/23-family-budget" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "lean family SKILL.md total 813/800"; then
  ok "RED: family over cap -> exit 1 naming the total"
else
  bad "RED case: expected 1 naming the cap, got $rc"; printf '%s\n' "$out"
fi

# --- GREEN: a synthetic minimal family -------------------------------------------
w="$(mktemp -d)"
mkdir -p "$w/scripts" "$w/skills/ac-plan/references" "$w/skills/_tools"
cp "$JUDGE" "$w/scripts/"; chmod +x "$w/scripts/"*.sh
printf -- '---\nname: ac-plan\ndescription: "small family member"\n---\n\nReads skills/ac-plan/references/deep.md for the deep form.\n' > "$w/skills/ac-plan/SKILL.md"
printf '# deep form\n\nDetails.\n' > "$w/skills/ac-plan/references/deep.md"
cat > "$w/skills/_tools/polish-fixpoint.sh" <<'EOF'
#!/usr/bin/env bash
# PROBE: run the stamp tool
# SCHEDULE: polish fixpoint runs
# MODE: blocking
# ON-FAILURE: closed
exit 0
EOF
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q "family budget and anti-drift legs hold"; then
  ok "GREEN: synthetic minimal family -> exit 0"
else
  bad "GREEN case: expected 0, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- GREEN: the real registry ----------------------------------------------------
out="$(python3 "$CHECK" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  ok "GREEN: the real family is inside its caps"
else
  bad "real-tree case: expected 0, got $rc"; printf '%s\n' "$out"
fi

# --- NOT-GATED: the judge script is missing --------------------------------------
w="$(mktemp -d)"
mkdir -p "$w/skills/ac-plan"
printf -- '---\nname: ac-plan\ndescription: "x"\n---\n\nbody\n' > "$w/skills/ac-plan/SKILL.md"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q "NOT-CHECKED"; then
  ok "NOT-GATED: missing judge -> exit 2, verified nothing"
else
  bad "NOT-GATED case: expected 2, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

echo "23-family-budget.test.sh: ${fails} failure(s)"
[ "$fails" -eq 0 ]
