#!/usr/bin/env python3
# ---
# id: 07-consumer-symlinks
# prevents: a dangling symlink in a consumer's harness layer (.claude/, .agents/, .factory/ of the org
#   dirs and every deploy target) — a dead pointer that breaks a skill load or silently skips one
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/07-consumer-symlinks
# ---
"""07-consumer-symlinks — every symlink in a consumer harness layer resolves (ac-1p7j.14).

Ported from the legacy Check 7 bash block in lint.sh (parity proven at port time
against the extracted legacy block, before the block was removed). Same verdicts:
walk each consumer dir in the union (lib.consumers — the org root's `.claude` ∪ the
deploy targets' `.claude`, both asked of engine/machine.sh), flag every symlink whose
target does not exist, naming the link.

scope: LIVE_TEXT is the nearest standing set, kept only for 00-meta.py's header
contract — the audited files live OUTSIDE this repo (consumer dirs), which no
lib.scope set can name, and no selection reads it (there is no scope-to-diff
selection; every run means the whole suite).

Exit: 0 every symlink resolves, or no consumer dir resolves at all (SKIP,
disclosed — the audited dirs live OUTSIDE this repo and a fresh/consumer-less
checkout has none); 1 broken symlink(s); 2 the machine's facts are unresolved-or-
refused (NOT-CHECKED — a human must fix the machine file, so a green here would be a
claim nobody made). A skip is reported as a skip and never prints a pass claim — it
gated nothing, so it verified nothing.
"""

import os
import sys

import _bootstrap  # noqa: F401
from lib import consumers, scope

violations = []


def fail(msg):
    violations.append(msg)


def scan():
    try:
        dirs = consumers.consumer_dirs()
    except consumers.MachineNotConfigured as exc:
        print(f"SKIP 07-consumer-symlinks: {exc} — the consumer union is unknown here, "
              "so nothing was walked and nothing was verified", file=sys.stderr)
        return 0
    except consumers.MachineWrong as exc:
        print(f"07-consumer-symlinks: {exc}", file=sys.stderr)
        return 2
    if not any(os.path.isdir(d) for d in dirs):
        print(f"SKIP 07-consumer-symlinks: no consumer dir resolves under "
              f"{consumers.org_root()} (a consumer-less checkout, e.g. a fresh clone "
              "with no deployed harness layer); nothing to walk, nothing verified",
              file=sys.stderr)
        return 0
    scanned = 0
    for d in dirs:
        if not os.path.isdir(d):
            continue  # skip non-existent dirs silently — the legacy verdict
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
        # zero dirs proved nothing — skip, never claim a pass and never NOT-GATE
        # (exit 2 blocks a suite this check cannot fix).
        print("SKIP 07-consumer-symlinks: no consumer dir resolved on scan; "
              "nothing to walk, nothing verified", file=sys.stderr)
        return 0
    print(f"07-consumer-symlinks: {scanned} consumer dir(s) walked")
    if violations:
        print("FAIL 07-consumer-symlinks: broken symlink(s) in a consumer harness layer:")
        for v in violations:
            print(f"  - {v}")
        return 1
    print("07-consumer-symlinks: PASS")
    return 0


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    if os.path.abspath(root) != scope.ROOT:
        os.environ["LINT_ROOT"] = os.path.abspath(root)
    return scan()


if __name__ == "__main__":
    sys.exit(main())
