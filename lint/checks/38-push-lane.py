#!/usr/bin/env python3
# ---
# prevents: a push site outside the push layer reintroducing a bare `git push` — the
#   whole-tree gate (skills/ac-pipeline/scripts/push.sh) silently loses a caller and the
#   tree it was meant to gate reaches origin unchecked again
# fixture: lint/fixtures/38-push-lane
# ---
"""38-push-lane — push.sh is the only file on the routed surface that runs `git push`.

The routed surface (ac-ftfz.10): every push site named by the swarm-gates plan —
`skills/ac-implement/`, `skills/ac-land/`, `skills/ac-hygiene/references/run-loop.md`,
`skills/ac-pipeline/references/commit-discipline.md` — moved its push off a bare `git push`
and onto `skills/ac-pipeline/scripts/push.sh`, the one step that refuses a dirty tree, merges
origin in, runs the repo's whole-tree checks, and only then pushes. This check is what keeps
a later edit from quietly re-opening a second door: a live code line on the surface that
invokes `git push` directly is the exact regression the whole-tree gate exists to prevent.

Scanned as CODE, not prose: for a `.md` file, only the content inside fenced ``` code
blocks; for a `.sh` file, the whole file. Either way, a line whose stripped text starts
with `#` is a comment and is out of scope — the doctrine text on this very surface quotes
`git push` in backticks and in comments to explain what it forbids, and a check that
reddened on its own explanation would be deleted within a week (the same carve-out
Check 37 makes for `engine/` prose).

`push.sh` itself (any path ending `/push.sh`, matched case-sensitively on the basename)
and every proof harness (`*.test.sh`) are excluded — the harness's fixture repo commits
build a REAL bare remote and drive a REAL `git push` through it; that is what the harness
is FOR, not a regression of the doctrine it proves.

Exit: 0 clean (>=1 file scanned), 1 a live `git push` found off the routed surface, 2 none
of the routed surface exists under root (NOT-CHECKED, never a pass).
"""

import os
import re
import sys

import _bootstrap  # noqa: F401
from lib import scope  # noqa: E402

CHECK_ID = "38-push-lane"

# The routed surface, repo-root-relative. Two directories (walked recursively) and two
# single files — exactly the paths ac-ftfz.10's own AC names.
SURFACE_DIRS = ("skills/ac-implement", "skills/ac-land")
SURFACE_FILES = (
    "skills/ac-hygiene/references/run-loop.md",
    "skills/ac-pipeline/references/commit-discipline.md",
)

GIT_PUSH_RE = re.compile(r"\bgit\s+push\b")
FENCE_RE = re.compile(r"^\s*```")


def _excluded(rel):
    base = os.path.basename(rel)
    return base == "push.sh" or base.endswith(".test.sh")


def _code_lines(path):
    """Yield (lineno, text) for lines this check treats as CODE — never a comment, and
    for markdown, never outside a fenced block."""
    with open(path, encoding="utf-8", errors="replace") as fh:
        lines = fh.read().splitlines()
    is_md = path.endswith(".md")
    in_fence = False
    for i, line in enumerate(lines, 1):
        if is_md:
            if FENCE_RE.match(line):
                in_fence = not in_fence
                continue
            if not in_fence:
                continue
        if line.lstrip().startswith("#"):
            continue
        yield i, line


def _walk_dir(root, rel_dir):
    abs_dir = os.path.join(root, rel_dir)
    if not os.path.isdir(abs_dir):
        return
    for dirpath, dirnames, filenames in os.walk(abs_dir):
        dirnames[:] = [d for d in dirnames if d not in scope.SKIP_DIRS]
        for fn in sorted(filenames):
            abs_path = os.path.join(dirpath, fn)
            rel = os.path.relpath(abs_path, root).replace(os.sep, "/")
            yield rel


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT

    candidates = []
    for rel_dir in SURFACE_DIRS:
        candidates.extend(_walk_dir(root, rel_dir))
    for rel_file in SURFACE_FILES:
        if os.path.isfile(os.path.join(root, rel_file)):
            candidates.append(rel_file)

    scanned = [rel for rel in sorted(set(candidates)) if not _excluded(rel)]

    if not scanned:
        print(f"{CHECK_ID} NOT-CHECKED: none of the routed surface exists under {root}",
              file=sys.stderr)
        return 2

    findings = []
    for rel in scanned:
        path = os.path.join(root, rel)
        try:
            for lineno, line in _code_lines(path):
                if GIT_PUSH_RE.search(line):
                    findings.append(f"{rel}:{lineno}: bare `git push` off the push layer — "
                                     f"route through skills/ac-pipeline/scripts/push.sh instead")
        except OSError as exc:
            findings.append(f"{rel}: unreadable ({exc})")

    if findings:
        for f in findings:
            print(f"{CHECK_ID} FAIL: {f}", file=sys.stderr)
        return 1

    print(f"    ok: {CHECK_ID} — {len(scanned)} file(s) on the routed surface, "
          f"push.sh is the only `git push`")
    return 0


if __name__ == "__main__":
    sys.exit(main())
