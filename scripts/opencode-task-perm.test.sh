#!/usr/bin/env bash
# scripts/opencode-task-perm.test.sh — the OpenCode task projection keys on Agent.
#
# OpenCode denies a subagent the task tool only when its own permission names no
# task rule, so the projected `task:` line decides whether a stance can spawn.
# A stance that lists Agent (or Task, its older name) projects task=allow; the
# worker stances list neither and stay task=deny, so nesting stops at workers.
# The function under test is the one engine/sync.sh calls, via
# --print-opencode-task-perm, not a reimplementation.
#
# ASSURANCE
#   PROBE:    bash scripts/opencode-task-perm.test.sh
#   SCHEDULE: scripts/run-all-proofs.sh
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SYNC="$ROOT/engine/sync.sh"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

[ -f "$SYNC" ] || { echo "HARNESS FAIL: missing $SYNC"; exit 1; }

if grep -qE '^  task: deny$' "$SYNC"; then
  bad "engine/sync.sh still hardcodes task: deny"
else
  ok "no hardcoded task: deny in engine/sync.sh"
fi

perm_for() { # <agent.md or tools-line> — ask the real sync.sh decision
  local line="$1"
  if [ -f "$1" ]; then
    line="$(awk '/^---[[:space:]]*$/{c++; next} c==1 && /^tools:/{print; exit}' "$1")"
  fi
  bash "$SYNC" --print-opencode-task-perm "$line"
}

expect() { # <label> <want> <got>
  if [ "$2" = "$3" ]; then ok "$1 -> $3"; else bad "$1: want $2, got $3"; fi
}

expect "orchestrator (lists Agent)" allow "$(perm_for "$ROOT/agents/orchestrator.md")"
expect "coordinator (lists Agent)" allow "$(perm_for "$ROOT/agents/coordinator.md")"
expect "researcher (worker)" deny "$(perm_for "$ROOT/agents/researcher.md")"
expect "implementer (worker)" deny "$(perm_for "$ROOT/agents/implementer.md")"
expect "validator (worker)" deny "$(perm_for "$ROOT/agents/validator.md")"
expect "Task, the older name" allow "$(perm_for 'tools: Read, Task, Bash')"
expect "Agent with a type list" allow "$(perm_for 'tools: Read, Agent(researcher)')"
expect "TaskCreate is not Task" deny "$(perm_for 'tools: Read, TaskCreate')"
expect "agent-mail tools are not Agent" deny "$(perm_for 'tools: mcp__mcp-agent-mail__send_message')"
expect "empty tools line" deny "$(perm_for '')"

echo
if [ "$fails" -eq 0 ]; then
  echo "OK: every opencode-task-perm case passed ($(basename "$0"))"
  exit 0
else
  echo "FAILURES: $fails — OpenCode task permission is outside its contract ($(basename "$0"))"
  exit 1
fi
