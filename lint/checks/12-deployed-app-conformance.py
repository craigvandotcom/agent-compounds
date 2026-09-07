#!/usr/bin/env python3
# ---
# id: 12-deployed-app-conformance
# prevents: deployed apps' every-prompt context (hook files + AGENTS.md) still routing agents to dead pipeline commands, dead delegation tools, or dead pipeline stage names left behind by a doctrine-landing sweep
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/12-deployed-app-conformance
# ---
"""12-deployed-app-conformance — no dead names in every-prompt surfaces (ac-1p7j.14).

Ported from the legacy Check 12 bash block in lint.sh (proven by lint/parity.sh
against the extracted legacy block, over the consumer union the legacy Check 7
block built, before both blocks were removed). Same verdicts: probe each
consumer's hooks/workflow-reminder.md (C1 dead pipeline commands), its
.codex/hooks twin where present, hooks/delegation-reminder.md (C2 dead
delegation tools), and the app-root AGENTS.md (C3 dead pipeline stage names).

Scope is deliberately narrow — only the named every-prompt files — so the check
never fires on documentation that legitimately mentions these strings as
history/examples rather than live guidance.

scope: LIVE_TEXT is the nearest standing set — the audited files live OUTSIDE
this repo (consumer dirs), which no lib.scope set can name. A `--changed` skip
window is lost, never a false pass on a bare run.

Exit: 0 clean, 1 dead names, 2 no consumer dir exists (NOT-GATED, never a pass).
"""

import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(_HERE))
from lib import consumers, scope  # noqa: E402

C1_PATTERN = "/ac/bead-work|/ac/wave-merge|/ac/backlog-add|/ac/bead-land|/ac/work-review"
C2_PATTERN = "cass search"
C3_PATTERN = "bead-work|wave-merge"

violations = []


def fail(msg):
    violations.append(msg)


def disp(path):
    """What the violation names — the consumer path with the $HOME/ prefix off,
    exactly as the legacy block displayed it."""
    home_prefix = os.path.expanduser("~") + os.sep
    return path[len(home_prefix):] if path.startswith(home_prefix) else path


def scan():
    scanned = 0
    for d in consumers.consumer_dirs():
        if not os.path.isdir(d):
            continue  # skip non-existent dirs silently — the legacy verdict
        scanned += 1
        app_root = os.path.dirname(d)
        for hooks_dir in (os.path.join(d, "hooks"), os.path.join(app_root, ".codex", "hooks")):
            wr = os.path.join(hooks_dir, "workflow-reminder.md")
            if os.path.isfile(wr) and re.search(C1_PATTERN, _read(wr)):
                fail(f"C1: {disp(wr)} still contains dead pipeline command name(s)")
            dr = os.path.join(hooks_dir, "delegation-reminder.md")
            if os.path.isfile(dr) and re.search(C2_PATTERN, _read(dr)):
                fail(f"C2: {disp(dr)} still contains dead delegation tool name(s)")
        agents_md = os.path.join(app_root, "AGENTS.md")
        if os.path.isfile(agents_md) and re.search(C3_PATTERN, _read(agents_md)):
            fail(f"C3: {disp(agents_md)} still contains dead pipeline stage name(s)")

    if scanned == 0:
        print("12-deployed-app-conformance NOT-CHECKED: no consumer dir exists under "
              f"{consumers.base()} — verified nothing", file=sys.stderr)
        return 2
    print(f"12-deployed-app-conformance: {scanned} consumer dir(s) scanned")
    if violations:
        print("FAIL 12-deployed-app-conformance: dead name(s) in every-prompt surfaces:")
        for v in violations:
            print(f"  - {v}")
        return 1
    print("12-deployed-app-conformance: PASS")
    return 0


def _read(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    if os.path.abspath(root) != scope.ROOT:
        os.environ["LINT_ROOT"] = os.path.abspath(root)
    return scan()


if __name__ == "__main__":
    sys.exit(main())
