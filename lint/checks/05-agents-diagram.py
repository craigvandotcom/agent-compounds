#!/usr/bin/env python3
# ---
# id: 05-agents-diagram
# prevents: the repo map lying — an AGENTS.md diagram naming a top-level path that is not on disk, with the gitignored carve-out keeping a local-only dir (absent from a bare CI clone) from holding registry-lint red forever
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/05-agents-diagram
# ---
"""05-agents-diagram — every AGENTS.md diagram path exists (or is declared local-only).

The legacy lint.sh Check 5 block's exact leg: for each of
skills, agents, deploy.sh, templates, _plans — the path must exist, UNLESS it
is gitignored (a dir-only ignore rule does NOT match the bare name when the
directory is absent in a CI clone, so both the bare and trailing-slash forms
are probed); a gitignored absent path is a NOTICE, never a failure.

Exit: 0 every path exists or is an absent gitignored one, 1 a non-ignored
path is missing, 2 nothing scanned (the audited root itself does not exist).
"""

import os
import subprocess
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import scope  # noqa: E402

CHECK_ID = "05-agents-diagram"
DIAGRAM_PATHS = ("skills", "agents", "deploy.sh", "templates", "_plans")


def git_ignored(root, path):
    for form in (path, path + "/"):
        proc = subprocess.run(
            ["git", "-C", root, "check-ignore", "-q", form],
            capture_output=True, timeout=30,
        )
        if proc.returncode == 0:
            return True
    return False


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    if not os.path.isdir(root):
        print(f"{CHECK_ID} NOT-CHECKED: root {root} does not exist — verified nothing", file=sys.stderr)
        return 2
    findings = []
    for path in DIAGRAM_PATHS:
        if os.path.exists(os.path.join(root, path)):
            continue
        # git -C climbs to the enclosing repo, so a fixture inside this
        # checkout inherits the registry's ignore rules — exactly what the
        # legacy block did; no local-.git guard here.
        if git_ignored(root, path):
            print(f"NOTICE: diagram path '{path}' is gitignored (local-only) and absent here — skipped")
            continue
        findings.append(f"AGENTS.md diagram path missing: {path}")
    for f in findings:
        print(f"FAIL {CHECK_ID}: {f}")
    if findings:
        return 1
    print(f"  ok: {CHECK_ID} — every diagram path exists or is an absent gitignored one")
    return 0


if __name__ == "__main__":
    sys.exit(main())
