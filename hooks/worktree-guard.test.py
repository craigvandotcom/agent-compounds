# ASSURANCE-ROLE: test-harness
# CALLER: scripts/run-all-proofs.sh (glob-discovered, executed by the registry-lint
# `proofs` CI job).
# Deliberately UNWIRED in engine/hooks.wiring.json: it is the PROOF for worktree-guard.py,
# not a hook itself. Declared so orphan detection (lint Check 21) does not read a live
# proof harness as a dead executable.
import json
import os
import subprocess
import sys

G = os.path.join(os.path.dirname(os.path.abspath(__file__)), "worktree-guard.py")
DENY, ALLOW = "deny", "allow"


def run(stdin):
    return subprocess.run([sys.executable, G], input=stdin, capture_output=True,
                          text=True, timeout=30, check=False)


def call(tool, tin=None):
    return json.dumps({"tool_name": tool, "tool_input": tin if tin is not None else {}})


cases = [
    (DENY, call("Agent", {"isolation": "worktree", "prompt": "x"}), "Agent + isolation worktree"),
    (DENY, call("Task", {"isolation": "worktree"}),                 "Task + isolation worktree"),
    (DENY, call("EnterWorktree", {"name": "x"}),                    "EnterWorktree"),
    (DENY, call("EnterWorktree"),                                   "EnterWorktree, empty input"),
    (ALLOW, call("Agent", {"prompt": "x"}),                         "Agent, no isolation"),
    (ALLOW, call("Agent", {"isolation": "remote"}),                 "Agent, isolation other"),
    (ALLOW, call("Agent", {"isolation": None}),                     "Agent, isolation null"),
    (ALLOW, call("Task", {"prompt": "x"}),                          "Task, no isolation"),
    (ALLOW, call("Bash", {"command": "git worktree add /tmp/w"}),   "Bash git worktree add untouched"),
    (ALLOW, call("Edit", {"isolation": "worktree"}),                "other tool, even with the field"),
    (ALLOW, call("ExitWorktree"),                                   "ExitWorktree passes"),
    (ALLOW, "not json {",                                           "garbage stdin -> fail open"),
    (ALLOW, "",                                                     "empty stdin -> fail open"),
    (ALLOW, "[1,2]",                                                "non-object JSON -> fail open"),
    (ALLOW, json.dumps({"tool_name": "Agent", "tool_input": "str"}), "malformed tool_input -> fail open"),
]

fails = 0
for want, stdin, label in cases:
    p = run(stdin)
    got, shape_ok = ALLOW, True
    if p.stdout.strip():
        try:
            h = json.loads(p.stdout)["hookSpecificOutput"]
            got = h["permissionDecision"]
            shape_ok = (h["hookEventName"] == "PreToolUse"
                        and "worktree" in h["permissionDecisionReason"].lower())
        except Exception:
            got, shape_ok = "unparseable", False
    ok = got == want and shape_ok and p.returncode == 0
    if not ok:
        fails += 1
    print(f"{'ok  ' if ok else 'FAIL'}  {want.upper():5} {label}"
          + ("" if ok else f"\n      got={got} rc={p.returncode} out={p.stdout[:120]!r} err={p.stderr[:120]!r}"))

print(f"\n{len(cases) - fails}/{len(cases)} passed")
sys.exit(1 if fails else 0)
