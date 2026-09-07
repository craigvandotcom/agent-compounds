#!/usr/bin/env python3
# ---
# id: 20-harness-scheduling
# prevents: a proof-test harness that no workflow runs — coverage that exists as a file but never executes, the way two harnesses sat red at HEAD for an unknown period because nothing executed a single one
# scope: HARNESSES
# severity: fail
# fixture: lint/fixtures/20-harness-scheduling
# ---
"""20-harness-scheduling — every proof-test harness is scheduled.

Check 18 proves a guard CAN fire. This proves a proof test IS RUN. When the
check was written, 15 harnesses existed and no workflow executed a single
one — and two of them had been red at HEAD for an unknown period, invisible
for exactly that reason. The logic lives in its own judge script so it can
carry a RED/GREEN harness of its own (which is itself scheduled by the
runner this check audits):

    scripts/harness-scheduling-check.sh <root>

The judge recomputes the harness inventory INDEPENDENTLY (its own find, its
own excludes) and compares it against what the runner claims via `--list`,
and proves some workflow actually invokes the runner. Two implementations of
the same question; when they disagree, coverage has silently shrunk.

This file is the port of the legacy lint.sh block onto the lint v2 runner
contract; the judge is unchanged, so the verdict cannot drift:

  exit 0  judge green — every harness scheduled
  exit 1  judge reported findings, passed through verbatim
  exit 2  judge missing from the audited root, or the judge itself verified
          nothing — NOT-GATED, never a pass
"""

import os
import subprocess
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import scope  # noqa: E402

CHECK_ID = "20-harness-scheduling"
JUDGE = "scripts/harness-scheduling-check.sh"


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    script = os.path.join(root, JUDGE)
    if not os.path.isfile(script):
        print(f"{CHECK_ID} NOT-CHECKED: {JUDGE} not found in {root} — harness scheduling unverified", file=sys.stderr)
        return 2
    proc = subprocess.run(["bash", script, root], capture_output=True, text=True)
    out = (proc.stdout + proc.stderr).strip()
    if proc.returncode == 0:
        for line in out.splitlines():
            print("  " + line)
        print(f"  ok: {CHECK_ID} — every proof-test harness is scheduled")
        return 0
    if proc.returncode == 2:
        print(f"{CHECK_ID} NOT-GATED: the judge verified nothing — {out}", file=sys.stderr)
        return 2
    for line in out.splitlines():
        print(line)
    print(f"FAIL {CHECK_ID}: unscheduled proof-test harness(es) — see above")
    return 1


if __name__ == "__main__":
    sys.exit(main())
