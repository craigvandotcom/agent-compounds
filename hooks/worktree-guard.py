#!/usr/bin/env python3
"""PreToolUse(Agent|Task|EnterWorktree) guard -- agent worktree isolation is blocked.

Denies (a) an Agent/Task spawn whose tool_input.isolation == "worktree", and (b) any
EnterWorktree call. Everything else passes. A `git worktree add` from a shell is NOT
this guard's business (ac-review's disposable sabotage worktree keeps working): the
matcher never sees Bash.

Block dialect: stdout hookSpecificOutput JSON (permissionDecision "deny" +
permissionDecisionReason), exit 0 -- the documented Claude Code PreToolUse deny, and the
shape dcg already uses. Only Claude has Agent/EnterWorktree tools, so this entry is
wired for claude only (org + app scope).

FAIL-OPEN on unparseable or malformed stdin and on any exception: a guard must not wedge
an unattended run.

Rule and rationale: memory rule-no-agent-worktree-isolation (infrastructure lane).
Proof: hooks/worktree-guard.test.py.
"""
import json
import sys

REASON = (
    "Worktree isolation is blocked on this machine (rule-no-agent-worktree-isolation). "
    "Work in the main checkout instead. Parallel agents that share one build (e.g. one "
    "Vite app) run sequentially, or the work goes to one agent with a single integration "
    "step that builds once; lanes on disjoint files can share the main checkout. "
    "`git worktree add` from a shell (ac-review's disposable sabotage worktree) is unaffected."
)


def is_denied(payload):
    if not isinstance(payload, dict):
        return False
    tool = payload.get("tool_name")
    if tool == "EnterWorktree":
        return True
    if tool in ("Agent", "Task"):
        tin = payload.get("tool_input")
        return isinstance(tin, dict) and tin.get("isolation") == "worktree"
    return False


def main():
    try:
        payload = json.loads(sys.stdin.read())
        if not is_denied(payload):
            return 0
        sys.stdout.write(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": REASON,
        }}))
    except Exception:
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
