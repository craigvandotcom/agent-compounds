#!/usr/bin/env python3
"""consumer-symlinks — every symlink in a consumer harness layer resolves.

This audits DEPLOY TARGETS, which sync.sh owns — lint.sh gates only this
repo's own tree, never a consumer's. Called as a subprocess from sync.sh's
--check leg; `lint/lib/consumers.py` stays put (lint check 14 also imports
it), so this file reaches into `lint/` for it rather than duplicating the
consumer-dir union logic.

Walks each consumer dir in the union (lib.consumers — the org root's
`.claude` union every deploy target's `.claude`, both asked of
engine/machine.sh), flagging every symlink whose target does not exist,
naming the link.

Exit: 0 every symlink resolves, or no consumer dir resolves at all (SKIP,
disclosed — the audited dirs live outside this repo and a fresh/consumer-
less checkout has none); 1 broken symlink(s); 2 the machine's facts are
unresolved-or-refused (NOT-CHECKED — a human must fix the machine file, so a
green here would be a claim nobody made).
"""

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))          # engine/checks
_ENGINE_DIR = os.path.dirname(_HERE)                         # engine
_AC_ROOT = os.path.dirname(_ENGINE_DIR)                       # repo root
_LINT_DIR = os.path.join(_AC_ROOT, "lint")
if _LINT_DIR not in sys.path:
    sys.path.insert(0, _LINT_DIR)

from lib import consumers  # noqa: E402

violations = []


def fail(msg):
    violations.append(msg)


def scan():
    try:
        dirs = consumers.consumer_dirs()
    except consumers.MachineNotConfigured as exc:
        print(f"SKIP consumer-symlinks: {exc} — the consumer union is unknown here, "
              "so nothing was walked and nothing was verified", file=sys.stderr)
        return 0
    except consumers.MachineWrong as exc:
        print(f"consumer-symlinks: {exc}", file=sys.stderr)
        return 2
    if not any(os.path.isdir(d) for d in dirs):
        print(f"SKIP consumer-symlinks: no consumer dir resolves under "
              f"{consumers.org_root()} (a consumer-less checkout, e.g. a fresh clone "
              "with no deployed harness layer); nothing to walk, nothing verified",
              file=sys.stderr)
        return 0
    scanned = 0
    for d in dirs:
        if not os.path.isdir(d):
            continue  # non-existent dirs are skipped silently: a consumer-less
            # checkout is a disclosed SKIP above, not a per-dir failure here
        scanned += 1
        for dirpath, dirnames, filenames in os.walk(d):
            # Ambient job sandboxes (e.g. ~/.claude/jobs/*/tmp/...) are foreign
            # scratch trees no commit in this repo can fix — never descend.
            if "jobs" in dirnames:
                dirnames[:] = [x for x in dirnames if x != "jobs"]
            if "jobs" in os.path.relpath(dirpath, d).split(os.sep):
                dirnames[:] = []
                continue
            for name in dirnames + filenames:
                p = os.path.join(dirpath, name)
                if os.path.islink(p) and not os.path.exists(p):
                    fail(f"broken symlink: {p}")

    if scanned == 0:
        # A consumer dir resolved a moment ago; this branch should be unreachable
        # outside a race (a dir removed mid-scan). Either way, a scan that touched
        # zero dirs proved nothing — skip, never claim a pass.
        print("SKIP consumer-symlinks: no consumer dir resolved on scan; "
              "nothing to walk, nothing verified", file=sys.stderr)
        return 0
    print(f"consumer-symlinks: {scanned} consumer dir(s) walked")
    if violations:
        print("FAIL consumer-symlinks: broken symlink(s) in a consumer harness layer:")
        for v in violations:
            print(f"  - {v}")
        return 1
    print("consumer-symlinks: PASS")
    return 0


def main():
    return scan()


if __name__ == "__main__":
    sys.exit(main())
