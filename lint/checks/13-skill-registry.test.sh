#!/usr/bin/env bash
# 13-skill-registry.test.sh — the fixture proving Check 13's contract.
#
#   PROBE: an over-1024-char description is RED (the fixture's run.sh);
#           the real registry is GREEN; a tree missing the judge is
#           NOT-GATED (2).
#
# ASSURANCE
#   PROBE:    bash lint/checks/13-skill-registry.test.sh
#   SCHEDULE: scripts/run-all-proofs.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/13-skill-registry.py"
ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT

# --- RED: the run.sh fixture demonstrates the over-cap case ----------------------
if bash "$ROOT/lint/fixtures/13-skill-registry/run.sh" >"$OUT" 2>&1; then
  ok "RED: over-cap description -> judge fails, check exits 1"
else
  bad "RED case: run.sh did not demonstrate the RED"; cat "$OUT"
fi

# --- RED: description-budget breach (registry-description-budget: BREACH) -------
w="$(mktemp -d)"
mkdir -p "$w/skills/skill-builder/scripts"
cp "$ROOT/skills/skill-builder/scripts/validate-skill.sh" "$w/skills/skill-builder/scripts/"
chmod +x "$w/skills/skill-builder/scripts/"*.sh
DESC="$(python3 -c 'print("trigger word " * 70)' | cut -c1-900)"
for i in $(seq 1 40); do
  mkdir -p "$w/skills/budget-$i"
  printf -- '---\nname: budget-%d\ndescription: "%s"\n---\n\n# budget-%d\n' "$i" "$DESC" "$i" > "$w/skills/budget-$i/SKILL.md"
done
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "registry-description-budget: BREACH"; then
  ok "RED: description-budget breach -> BREACH marker, check exits 1"
else
  bad "budget-breach RED case: expected exit 1 + BREACH marker, got rc=$rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- RED: invocation-graph violation (a flipped skill invoked from another's body) -
w="$(mktemp -d)"
mkdir -p "$w/skills/skill-builder/scripts" "$w/skills/flipped" "$w/skills/caller"
cp "$ROOT/skills/skill-builder/scripts/validate-skill.sh" "$w/skills/skill-builder/scripts/"
chmod +x "$w/skills/skill-builder/scripts/"*.sh
cat > "$w/skills/flipped/SKILL.md" <<'SKILLEOF'
---
name: flipped
description: "use when testing the invocation-graph rule"
disable-model-invocation: true
---

# flipped
SKILLEOF
cat > "$w/skills/caller/SKILL.md" <<'SKILLEOF'
---
name: caller
description: "use when testing that a caller cannot invoke a flipped skill"
---

# caller

Run `flipped` to do the thing.
SKILLEOF
rm -f /tmp/ac-lint-registry.out
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
detail="/tmp/ac-lint-registry.out"
if [ "$rc" = 1 ] && [ -f "$detail" ] && grep -q "GRAPH:" "$detail"; then
  ok "RED: invocation-graph violation -> judge fails, check exits 1"
else
  bad "invocation-graph RED case: expected exit 1 + GRAPH violation, got rc=$rc"
  printf '%s\n' "$out"; [ -f "$detail" ] && cat "$detail"
fi
rm -rf "$w"

# --- RED: manifest leg names a dead skill (no skills/<name>/SKILL.md) ------------
w="$(mktemp -d)"
mkdir -p "$w/skills/skill-builder/scripts" "$w/skills/foo"
cp "$ROOT/skills/skill-builder/scripts/validate-skill.sh" "$w/skills/skill-builder/scripts/"
chmod +x "$w/skills/skill-builder/scripts/"*.sh
cat > "$w/skills/foo/SKILL.md" <<'SKILLEOF'
---
name: foo
description: "use when testing the manifest dead-name leg"
---

# foo
SKILLEOF
cat > "$w/skills/packages.json" <<'JSONEOF'
{
  "pkg1": {"skills": ["foo", "ghost"]}
}
JSONEOF
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "manifest names a dead skill"; then
  ok "RED: manifest names a dead skill -> check exits 1"
else
  bad "manifest dead-name RED case: expected exit 1 + dead-skill message, got rc=$rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

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
