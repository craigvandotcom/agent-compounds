#!/usr/bin/env python3
# ---
# id: 08-deploy-dry-run-inert
# prevents: deploy.sh's --dry-run writing into the target dir it is asked to preview (a "dry" run that
#   stamps) or exiting nonzero — inertness is proven by running the real dry run against a temp dir on
#   the first skill found
# scope: LIVE_TEXT DEPLOY_SCRIPT
# severity: fail
# fixture: lint/fixtures/08-deploy-dry-run-inert
# ---
"""08-deploy-dry-run-inert — deploy.sh --dry-run must be inert.

Run `engine/deploy.sh <tmp> --skills <first-skill> -n`; a nonzero exit is a
finding, and any file left in the temp dir is a finding (a crash before any
write would also leave the dir empty, so the exit code is checked too — or
the inertness test passes for a broken deploy.sh).

A "dry-run self-test could not find any skill to test with" is a finding, never
NOT-GATED: an empty skills tree is exactly the state this check must flag.

scope: LIVE_TEXT DEPLOY_SCRIPT is the nearest standing set, kept only for
00-meta.py's header contract — there is no deploy-surface set. The check
exercises deploy.sh and the first SKILL.md found, not a text scan; no
selection reads the declared scope (every run means the whole suite).

Exit: 0 dry run inert, 1 findings. Never 2 — the check always scans.
"""

import os
import subprocess
import sys
import tempfile

import _bootstrap  # noqa: F401
from lib import scope

FIND = "/usr/bin/find"

violations = []


def fail(msg):
    violations.append(msg)


def first_skill(root):
    """First SKILL.md under root/skills, in `find`'s traversal order."""
    skills_dir = os.path.join(root, "skills")
    if not os.path.isdir(skills_dir):
        return ""
    try:
        out = subprocess.run(
            [FIND, skills_dir, "-name", "SKILL.md"],
            capture_output=True, text=True, timeout=60, check=False,
        ).stdout
    except (subprocess.SubprocessError, OSError):
        return ""
    lines = [line for line in out.splitlines() if line.strip()]
    if not lines:
        return ""
    return lines[0].removeprefix(skills_dir + "/").removesuffix("/SKILL.md")


def scan(root):
    first = first_skill(root)
    if not first:
        fail("deploy.sh dry-run self-test: could not find any skill to test with")
    else:
        deploy = os.path.join(root, "engine", "deploy.sh")
        with tempfile.TemporaryDirectory(prefix="ac-lint-08-") as tmp:
            try:
                proc = subprocess.run(
                    [deploy, tmp, "--skills", first, "-n"],
                    capture_output=True, text=True, timeout=120, check=False,
                )
                dryrun_exit = proc.returncode
            except PermissionError:
                dryrun_exit = 126  # what bash reports for a non-executable
            except FileNotFoundError:
                dryrun_exit = 127  # what bash reports for a missing script
            except subprocess.TimeoutExpired:
                dryrun_exit = 124
            if dryrun_exit != 0:
                fail(f"deploy.sh --dry-run exited {dryrun_exit} (expected 0)")
            leaked = sorted(os.listdir(tmp)) if os.path.isdir(tmp) else []
            if leaked:
                fail("deploy.sh --dry-run created files in temp dir "
                     f"(should be inert): {', '.join(leaked)} (tmp: {tmp})")
    print(f"08-deploy-dry-run-inert: dry run of skill '{first or 'NONE'}' checked")
    if violations:
        print("FAIL 08-deploy-dry-run-inert: dry-run inertness breached:")
        for v in violations:
            print(f"  - {v}")
        return 1
    print("08-deploy-dry-run-inert: PASS")
    return 0


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    return scan(root)


if __name__ == "__main__":
    sys.exit(main())
