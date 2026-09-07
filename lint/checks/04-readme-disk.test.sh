#!/usr/bin/env bash
# 04-readme-disk.test.sh — the fixture proving Check 4's contract.
#
#   PROBE: the committed static fixture is RED on 4a (unmentioned skill),
#           4c (dead skill link) and 4d (dead agent link); an unmentioned
#           agent is RED on 4b; a missing README is RED (fail closed, never
#           a silent no-op); the real registry is GREEN; an empty root is
#           NOT-GATED (2).
#
# ASSURANCE
#   PROBE:    bash lint/checks/04-readme-disk.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/04-readme-disk.py"
ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

# --- RED: the committed static fixture fires 4a + 4c + 4d -----------------------
out="$(python3 "$CHECK" "$ROOT/lint/fixtures/04-readme-disk" 2>&1)"; rc=$?
if [ "$rc" = 1 ] \
   && printf '%s' "$out" | grep -q "skill 'ghosted' (has SKILL.md) not mentioned" \
   && printf '%s' "$out" | grep -q "links to ./skills/vanished/ but that directory does not exist" \
   && printf '%s' "$out" | grep -q "links to ./agents/phantom.md but that file does not exist"; then
  ok "RED: static fixture -> exit 1 naming 4a, 4c and 4d"
else
  bad "RED case: expected 1 naming 4a/4c/4d, got $rc"; printf '%s\n' "$out"
fi

# --- RED: an unmentioned agent (leg 4b) ------------------------------------------
w="$(mktemp -d)"
mkdir -p "$w/agents"
printf -- '---\nname: hidden\ntier: worker\n---\n\nbody\n' > "$w/agents/hidden.md"
printf '# Readme — mentions nobody\n' > "$w/README.md"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "agent 'hidden' not mentioned in README.md"; then
  ok "RED: unmentioned agent -> exit 1 (4b)"
else
  bad "4b case: expected 1, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- RED: missing README fails closed --------------------------------------------
w="$(mktemp -d)"
mkdir -p "$w/skills/lonely"
printf -- '---\nname: lonely\ndescription: "x"\n---\n\nbody\n' > "$w/skills/lonely/SKILL.md"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "README.md is missing"; then
  ok "RED: missing README -> exit 1 (fail closed)"
else
  bad "missing-README case: expected 1, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- GREEN: the real registry ----------------------------------------------------
out="$(python3 "$CHECK" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  ok "GREEN: the real README and the disk agree"
else
  bad "real-tree case: expected 0, got $rc"; printf '%s\n' "$out"
fi

# --- NOT-GATED: a root with no README, skills or agents --------------------------
w="$(mktemp -d)"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q "NOT-CHECKED"; then
  ok "NOT-GATED: empty root -> exit 2, verified nothing"
else
  bad "NOT-GATED case: expected 2, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

echo "04-readme-disk.test.sh: ${fails} failure(s)"
[ "$fails" -eq 0 ]
