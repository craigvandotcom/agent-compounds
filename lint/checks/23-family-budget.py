#!/usr/bin/env python3
# ---
# id: 23-family-budget
# prevents: the lean-family files growing without a number anyone defends — every previous "keep it
#   small" rule was prose, and every one of them lost; the cap is counted over the LOADED PATH with
#   the mandatory-load set DERIVED from the pointers, not a hardcoded list (the measured evasion with
#   an extra step)
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/23-family-budget
# ---
"""23-family-budget — the lean-family + loaded-path anti-drift assertion.

The legacy lint.sh Check 23 block delegated to ONE judge and this port keeps
that judge unchanged, so the verdict cannot drift:

    scripts/ac-budget-check.sh <root>

The judge's legs: family <=800 SKILL.md lines across the six lean workflow
skills + the constitution; spine / worst-path / total numbers DERIVED from
each SKILL.md's pointers and mode tables (a pointer that resolves to nothing
FAILS; a reference file nothing points at FAILS; workflows with no mode
table are NOT-GATED — fat cannot hide either way); pointed-at canon reported,
never capped; and assurance declarations for family scripts (Check 21 is
hooks.json-scoped and cannot see them). It fails CLOSED: a discovery set
that resolves to nothing exits non-zero — a cap that measured no files is
not a cap that held.

Exit: 0 judge green, 1 judge reported findings (passed through verbatim —
the judge's own NOT-GATED lines are failures, never passes), 2 judge missing
from the audited root — NOT-GATED, never a pass.
"""

import os
import subprocess
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import scope  # noqa: E402

CHECK_ID = "23-family-budget"
JUDGE = "scripts/ac-budget-check.sh"


def main():
    import argparse

    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("root", nargs="?", default=None,
                    help="repo root to lint (default: this checkout)")
    args = ap.parse_args()
    root = args.root or scope.ROOT
    script = os.path.join(root, JUDGE)
    if not os.path.isfile(script):
        print(f"{CHECK_ID} NOT-CHECKED: {JUDGE} not found in {root} — family caps NOT-GATED", file=sys.stderr)
        return 2
    proc = subprocess.run(["bash", script, root], capture_output=True, text=True)
    out = (proc.stdout + proc.stderr).strip()
    if proc.returncode == 0:
        for line in out.splitlines():
            print("  " + line)
        print(f"  ok: {CHECK_ID} — the family budget and anti-drift legs hold")
        return 0
    if proc.returncode == 2:
        print(f"{CHECK_ID} NOT-GATED: the judge verified nothing — {out}", file=sys.stderr)
        return 2
    for line in out.splitlines():
        print(line)
    print(f"FAIL {CHECK_ID}: family budget/anti-drift violation(s) — see above")
    return 1


if __name__ == "__main__":
    sys.exit(main())
