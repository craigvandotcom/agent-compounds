#!/usr/bin/env python3
"""
Dynamic Trauma Guard for Project Hot Stove.
Reads from ~/.cass-memory/traumas.jsonl and .cass/traumas.jsonl to enforce safety.

STATUS (verified 2026-07-19, re-verified 2026-08-27): this hook is live-wired as a
PreToolUse Bash hook in every harness (claude/codex/droid/grok — see hooks.json +
settings.json), but ~/.cass-memory/traumas.jsonl does not exist on this machine and no
project .cass/traumas.jsonl has ever been populated either (both repos that have a .cass/
dir contain only playbook.yaml, no traumas.jsonl). load_traumas() fails open on a missing
file, so this guard currently matches nothing and silently no-ops on every Bash call.

CITATION CORRECTED (ac-on0y.4, 2026-08-27): this docstring previously cited `org-bah` as
its trail. That is WRONG — org-bah is the CLOSED cm-playbook-removal decision and contains
zero trauma_guard content (read in full, cross-repo). Background only:
infrastructure/plans/2026-07-17-brain-gap-plan.md Phase 0 item 1, which explicitly DEFERS
this question rather than answering it.

Left wired (not deleted) pending the seed-vs-retire ruling — that fork is bead ac-on0y.5,
and its hooks.json declaration carries MODE: blocking / ON-FAILURE: open with
PENDING-DECISION: ac-on0y.5. Lint Check 21 expires that escape the moment ac-on0y.5 closes.
"""
import json
import sys
import re
import os
from pathlib import Path

GLOBAL_TRAUMA_FILE = Path.home() / ".cass-memory" / "traumas.jsonl"

def find_repo_root():
    """Find the root of the current git repository."""
    curr = Path.cwd()
    while curr != curr.parent:
        if (curr / ".git").exists():
            return curr
        curr = curr.parent
    return None

def load_traumas():
    """Load active traumas from global and project storage."""
    traumas = []
    
    # Load Global
    if GLOBAL_TRAUMA_FILE.exists():
        try:
            with open(GLOBAL_TRAUMA_FILE, "r", encoding="utf-8") as f:
                for line in f:
                    if line.strip():
                        try:
                            t = json.loads(line)
                            if isinstance(t, dict) and t.get("status") == "active":
                                traumas.append(t)
                        except:
                            pass
        except Exception:
            pass # Fail open on read error (don't block work if DB is corrupt)

    # Load Project
    repo_root = find_repo_root()
    if repo_root:
        repo_file = repo_root / ".cass" / "traumas.jsonl"
        if repo_file.exists():
            try:
                with open(repo_file, "r", encoding="utf-8") as f:
                    for line in f:
                        if line.strip():
                            try:
                                t = json.loads(line)
                                if isinstance(t, dict) and t.get("status") == "active":
                                    traumas.append(t)
                            except:
                                pass
            except Exception:
                pass

    return traumas

def check_command(command, traumas):
    """Check command against trauma patterns."""
    for trauma in traumas:
        if not isinstance(trauma, dict):
            continue

        pattern = trauma.get("pattern")
        if not isinstance(pattern, str) or not pattern:
            continue
            
        try:
            # Case-insensitive match
            if re.search(pattern, command, re.IGNORECASE):
                return trauma
        except re.error:
            continue
    return None

def main():
    # Read input from Claude/Generic Hook
    import select
    r, w, x = select.select([sys.stdin], [], [], 1.0)
    if not r:
        sys.exit(0)
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        # Not a JSON hook input, ignore
        sys.exit(0)

    if not isinstance(input_data, dict):
        # Fail open if the hook input isn't the expected object shape
        sys.exit(0)

    # Extract command
    # Claude Code format: {"tool_name": "Bash", "tool_input": {"command": "..."}}
    # Grok Build format:  {"toolName": "run_terminal_command", "toolInput": {"command": "..."}}
    tool_name = input_data.get("tool_name") or input_data.get("toolName")
    tool_input = input_data.get("tool_input") or input_data.get("toolInput") or {}
    if not isinstance(tool_input, dict):
        sys.exit(0)
    command = tool_input.get("command")

    # Only check shell-command tools (Claude/Codex/Droid names + Grok aliases)
    shell_tools = ["Bash", "run_shell_command", "run_terminal_command", "run_terminal_cmd"]
    if tool_name not in shell_tools or not isinstance(command, str) or not command:
        sys.exit(0)

    traumas = load_traumas()
    match = check_command(command, traumas)

    if match:
        trigger = match.get("trigger_event")
        if not isinstance(trigger, dict):
            trigger = {}
        msg = trigger.get("human_message") or "You previously caused a catastrophe with this command."
        ref = trigger.get("session_path") or "unknown"
        pattern = match.get("pattern") or "<unknown>"
        trauma_id = match.get("id") or "<unknown>"

        use_emoji = os.environ.get("CASS_MEMORY_NO_EMOJI") is None
        banner = (
            "🔥 HOT STOVE: VISCERAL SAFETY INTERVENTION 🔥"
            if use_emoji
            else "[HOT STOVE] VISCERAL SAFETY INTERVENTION"
        )
        reason = (
            f"{banner}\n\n"
            f"BLOCKED: This pattern matches a registered TRAUMA.\n"
            f"Pattern: {pattern}\n"
            f"Reason: {msg}\n"
            f"Reference: {ref}\n\n"
            f"If you MUST run this, heal it first with: cm trauma heal {trauma_id}"
        )

        if os.environ.get("GROK_HOOK_EVENT"):
            # Grok Build dialect: {"decision": "deny"} + exit 2. Grok is fail-open —
            # only this explicit decision blocks the call.
            output = {"decision": "deny", "reason": reason}
            sys.stdout.write(json.dumps(output))
            sys.stdout.flush()
            sys.exit(2)

        # Claude Code (and compatible) dialect
        output = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": reason,
            }
        }
        # Explicitly print to stdout and exit
        sys.stdout.write(json.dumps(output))
        sys.stdout.flush()
        sys.exit(0)

    # Allow
    sys.exit(0)

if __name__ == "__main__":
    main()
