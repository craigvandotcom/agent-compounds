#!/usr/bin/env python3
# ---
# id: 38-machine-file-untracked
# prevents: machine.json — this machine's absolute paths, on a public repo — riding a commit as a
#   tracked or staged file; the .gitignore rule is the only thing keeping it out, and nothing
#   verifies the rule still holds
# scope: ALL
# severity: fail
# fixture: lint/fixtures/38-machine-file-untracked
# ---
"""38-machine-file-untracked — `machine.json` is never tracked and never staged.

`machine.json` states THIS machine's facts in full: its org root and every target's
absolute path. The repository is public, so the file is gitignored and only
`machine.example.json` is committed. The ignore rule is the whole defence, and an
ignore rule is defeated by exactly one thing: `git add -f`. This check is the
feedback loop on that — it asks git, not the filesystem, whether the file would
travel.

Tracked-ness is GIT STATE, not a file population, which is why the fixture is a
runner (`lint/fixtures/38-machine-file-untracked/run.sh`) that builds a throwaway
repo rather than a static tree: a committed tree can only ever show the file
absent. The subject is a fixed path, so the check reads no file contents and needs
no scope set — `ALL` is the cross-cutting-repo-state declaration `--changed` uses
to run it on any edit.

Three git reads, in order of severity:

  HEAD:machine.json   committed — it is in the published tree and in every clone
  index               staged — a `git add -f` is one `git commit` from publishing it

and one state that is NEITHER: in HEAD's tree but ABSENT from the index. That is
`git rm --cached` in flight — this check's own printed remediation, whose commit this
check gates — so it passes with a DISCLOSED one-commit amnesty instead of deadlocking the
fix. The next run reads the committed tree, where the file is gone, so the amnesty cannot
outlive the commit it permits; a file that stays tracked keeps failing.

Exit: 0 neither tracked nor staged (or the staged removal that untracks it); 1 either;
2 not a git checkout (NOT-GATED, never a pass).
"""

import os
import subprocess
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import scope  # noqa: E402

CHECK_ID = "38-machine-file-untracked"
MACHINE_FILE = "machine.json"


def git(root, *args):
    """One git call against `root`. Never raises — callers judge the exit code."""
    return subprocess.run(
        ["git", "--no-optional-locks", "-C", root, *args],
        capture_output=True, text=True, timeout=60,
    )


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    root = os.path.abspath(root)

    try:
        probe = git(root, "rev-parse", "--git-dir")
    except (OSError, subprocess.SubprocessError) as exc:
        print(f"{CHECK_ID} NOT-CHECKED: git is unavailable ({exc}) — tracked-ness of "
              f"{MACHINE_FILE} verified nothing", file=sys.stderr)
        return 2
    if probe.returncode != 0:
        print(f"{CHECK_ID} NOT-CHECKED: {root} is not a git checkout — tracked-ness of "
              f"{MACHINE_FILE} verified nothing", file=sys.stderr)
        return 2

    # `git ls-files` reads the index: a tracked file and a staged one both appear.
    indexed = git(root, "ls-files", "-z", "--", MACHINE_FILE)
    if indexed.returncode != 0:
        print(f"{CHECK_ID} NOT-CHECKED: `git ls-files` failed in {root} "
              f"({indexed.stderr.strip() or 'no detail'}) — verified nothing", file=sys.stderr)
        return 2
    in_index = bool(indexed.stdout.strip("\0"))

    # HEAD is absent in a fresh repo with no commit yet; that is not an error, it just
    # means nothing is committed. Only when HEAD resolves is the tree compared.
    committed = False
    if git(root, "rev-parse", "--verify", "-q", "HEAD").returncode == 0:
        tree = git(root, "ls-tree", "-r", "--name-only", "HEAD", "--", MACHINE_FILE)
        if tree.returncode != 0:
            print(f"{CHECK_ID} NOT-CHECKED: `git ls-tree HEAD` failed in {root} "
                  f"({tree.stderr.strip() or 'no detail'}) — verified nothing", file=sys.stderr)
            return 2
        committed = bool(tree.stdout.strip())

    # A tracked-in-HEAD file STAGED FOR REMOVAL is the remediation in flight, not the
    # defect. `git rm --cached` leaves the file in HEAD's tree until that commit lands, and
    # this check gates that very commit — so refusing here would deadlock the fix and make
    # `git commit --no-verify` the only way to obey the gate. The amnesty is disclosed and
    # lasts one commit: the next run reads the tree it just wrote.
    if committed and not in_index:
        print(f"  ok: {CHECK_ID} — {MACHINE_FILE} is in HEAD's tree but staged for removal; "
              "the untracking commit is in flight, so amnesty holds until it lands")
        return 0

    if committed:
        print(f"FAIL {CHECK_ID}: {MACHINE_FILE} is TRACKED — it holds this machine's absolute "
              "paths and this repository is public, so it must never be committed.")
        print(f"  remove it from history's tip and the index: git rm --cached {MACHINE_FILE}")
        return 1

    if in_index:
        print(f"FAIL {CHECK_ID}: {MACHINE_FILE} is STAGED for commit — it holds this machine's "
              "absolute paths and this repository is public, so it must never be committed.")
        print(f"  unstage it: git rm --cached {MACHINE_FILE}")
        return 1

    print(f"  ok: {CHECK_ID} — {MACHINE_FILE} is neither tracked nor staged")
    return 0


if __name__ == "__main__":
    sys.exit(main())
