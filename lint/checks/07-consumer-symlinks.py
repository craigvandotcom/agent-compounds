#!/usr/bin/env python3
# ---
# id: 07-consumer-symlinks
# prevents: a dangling symlink in a consumer's harness layer (.claude/, .agents/, .factory/ of the org
#   dirs and every deploy target) — a dead pointer that breaks a skill load or silently skips one
# scope: LIVE_TEXT
# changed: skip
#   audits consumer layers OUTSIDE this repo (org and app .claude/.agents/.factory),
#   which a commit-scoped pre-commit run cannot fix and must not be gated by.
#   Full lint and CI still run it, and infra-sync re-stamps the fleet.
# severity: fail
# fixture: lint/fixtures/07-consumer-symlinks
# ---
"""07-consumer-symlinks — every symlink in a consumer harness layer resolves (ac-1p7j.14).

Ported from the legacy Check 7 bash block in lint.sh (proven by lint/parity.sh
against the extracted legacy block before the block was removed). Same verdicts:
walk each consumer dir in the union (lib.consumers — org-level dirs ∪ the
ac-deploy-targets.list apps ∪ vitest-affected), flag every symlink whose target
does not exist, naming the link.

scope: LIVE_TEXT is the nearest standing set — the audited files live OUTSIDE
this repo (consumer dirs), which no lib.scope set can name. A `--changed` skip
window is lost, never a false pass on a bare run.

Exit: 0 every symlink resolves, or the consumer root is absent (SKIP, disclosed
— the audited dirs live OUTSIDE this repo and a bare checkout has none);
1 broken symlink(s); 2 consumer root present but no consumer dir resolves
(NOT-GATED, never a pass).
"""

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(_HERE))
from lib import consumers, scope  # noqa: E402

violations = []


def fail(msg):
    violations.append(msg)


def scan():
    if not consumers.base_present():
        print(f"07-consumer-symlinks: SKIP — consumer root {consumers.base()} absent "
              "(a consumer-less checkout); nothing to walk", file=sys.stderr)
        return 0
    scanned = 0
    for d in consumers.consumer_dirs():
        if not os.path.isdir(d):
            continue  # skip non-existent dirs silently — the legacy verdict
        scanned += 1
        for dirpath, dirnames, filenames in os.walk(d):
            for name in dirnames + filenames:
                p = os.path.join(dirpath, name)
                if os.path.islink(p) and not os.path.exists(p):
                    fail(f"broken symlink: {p}")

    if scanned == 0:
        print("07-consumer-symlinks NOT-CHECKED: no consumer dir exists under "
              f"{consumers.base()} — verified nothing", file=sys.stderr)
        return 2
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
