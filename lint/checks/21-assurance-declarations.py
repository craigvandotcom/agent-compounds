#!/usr/bin/env python3
# ---
# id: 21-assurance-declarations
# prevents: a mechanism that does not say what it does when it breaks — a hooks/ guard that stayed fail-open against a store that does not exist, and an executable with no wiring at all, neither detectable while "wired" was the only claim anyone made
# scope: HOOKS
# severity: fail
# fixture: lint/fixtures/21-assurance-declarations
# ---
"""21-assurance-declarations — every mechanism DECLARES its failure semantics.

Check 18 proves a guard CAN fire; Check 20 proves a proof test IS RUN; this
proves a mechanism SAYS WHAT IT DOES WHEN IT BREAKS. The judge audits every
hooks.json wiring entry's `assurance` object (PROBE / SCHEDULE / MODE /
ON-FAILURE, fail-open legal only for advisory, escapes verifiable), plus
orphan detection over hooks/ executables:

    scripts/assurance-declarations-check.sh <root>

This file is the port of the legacy lint.sh block onto the lint v2 runner
contract; the judge is unchanged, so the verdict cannot drift:

  exit 0  judge green — every wiring entry and hooks/ executable declared
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

CHECK_ID = "21-assurance-declarations"
JUDGE = "scripts/assurance-declarations-check.sh"


def main():
    import argparse

    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("root", nargs="?", default=None,
                    help="repo root to lint (default: this checkout)")
    args = ap.parse_args()
    root = args.root or scope.ROOT
    script = os.path.join(root, JUDGE)
    if not os.path.isfile(script):
        print(f"{CHECK_ID} NOT-CHECKED: {JUDGE} not found in {root} — declarations unverified", file=sys.stderr)
        return 2
    proc = subprocess.run(["bash", script, root], capture_output=True, text=True)
    out = (proc.stdout + proc.stderr).strip()
    if proc.returncode == 0:
        for line in out.splitlines():
            print("  " + line)
        print(f"  ok: {CHECK_ID} — every wiring entry and hooks/ executable carries a conforming declaration")
        return 0
    if proc.returncode == 2:
        print(f"{CHECK_ID} NOT-GATED: the judge verified nothing — {out}", file=sys.stderr)
        return 2
    for line in out.splitlines():
        print(line)
    print(f"FAIL {CHECK_ID}: undeclared or wrongly-declared mechanism(s) — see above")
    return 1


if __name__ == "__main__":
    sys.exit(main())
