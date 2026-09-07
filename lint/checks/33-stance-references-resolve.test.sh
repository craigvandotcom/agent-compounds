#!/usr/bin/env bash
# 33-stance-references-resolve.test.sh — the fixture proving the contract.
#
#   PROBE: a root whose skill text names `browser-tester` subagents (agent deleted)
#           is RED; subagent_type "phantom" is RED; roster names and harness
#           built-ins are GREEN; FRICTIONS.md is exempt; missing dirs NOT-GATED (2).
#
# ASSURANCE
#   PROBE:    bash lint/checks/33-stance-references-resolve.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/33-stance-references-resolve.py"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

mkroot() {
  local d="$1"
  mkdir -p "$d/agents" "$d/skills/demo"
  printf -- '---\nname: researcher\ntier: coordinator\n---\nbody\n' > "$d/agents/researcher.md"
  printf -- '---\nname: implementer\ntier: worker\n---\nbody\n' > "$d/agents/implementer.md"
}

# --- RED: decorated stance that no longer exists ---------------------------------
w="$(mktemp -d)"; mkroot "$w"
printf -- 'dispatch to the `browser-tester` subagents\n' > "$w/skills/demo/SKILL.md"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "browser-tester"; then
  ok "RED: backticked phantom stance -> exit 1"
else
  bad "RED case: expected 1, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- RED: machine spawn call to a phantom ----------------------------------------
w="$(mktemp -d)"; mkroot "$w"
printf -- 'Task(subagent_type: "phantom-agent", prompt: "x")\n' > "$w/skills/demo/SKILL.md"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'subagent_type "phantom-agent"'; then
  ok "RED: subagent_type phantom -> exit 1"
else
  bad "machine-call case: expected 1, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- GREEN: roster + built-ins resolve; FRICTIONS.md exempt -----------------------
w="$(mktemp -d)"; mkroot "$w"
cat > "$w/skills/demo/SKILL.md" <<'EOF'
- `implementer` subagents do the work
- subagent_type: "general-purpose" is a harness built-in
EOF
cat > "$w/skills/demo/FRICTIONS.md" <<'EOF'
the old `browser-tester` subagent is history
EOF
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q "resolves"; then
  ok "GREEN: roster + built-ins resolve, FRICTIONS.md exempt"
else
  bad "GREEN case: expected 0, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- NOT-GATED: no skills/ dir ----------------------------------------------------
w="$(mktemp -d)"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q "NOT-CHECKED"; then
  ok "NOT-GATED: missing dirs -> exit 2"
else
  bad "NOT-GATED case: expected 2, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

echo "33-stance-references-resolve.test.sh: ${fails} failure(s)"
[ "$fails" -eq 0 ]
