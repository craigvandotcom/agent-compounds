#!/usr/bin/env python3
# ---
# id: 22-ledger-integrity
# prevents: a friction ledger and its controls drifting apart — entries citing controls the constitution does not define, receipts nobody kept, and a friction re-observed after its control landed accruing silently instead of surfacing as a FAILED CONTROL
# scope: LEDGER
# severity: fail
# fixture: lint/fixtures/22-ledger-integrity
# ---
"""22-ledger-integrity — the lean family's friction sensor: one check, two surfaces.

The lean family's controls and its friction ledger must still point at each
other: every entry cites a `receipt:` and the `control:` that treats it (or
is explicitly `untreated`), every control names the failure it prevents, and
a friction re-observed AFTER its control landed surfaces as a FAILED CONTROL
rather than accruing silently. Since 2026-09-08 this check is also the ONE
friction sensor for the ledger-health classes friction-rollup.py --strict
existed for: an entry with no scorable ordinal (impact/frequency/recurrence)
and a ledger whose declared `entries:` count disagrees with its parsed entries
are named findings — never mutations (the ledger edit is human-gated; the
frictions docket consumes the report rows). The judge parses the ledger through
the ONE shared parser (`skills/skill-builder/scripts/friction-rollup.py`) and
fails CLOSED — a missing or empty ledger exits non-zero, because an absent
sensor is not a clean one:

    scripts/ac-ledger-integrity.sh <root>

Findings are printed one row per line, grep-able for the docket builder on
their class tokens: `NOT-SCORABLE:` and `entry-count mismatch`, plus the
contract rows (unresolvable control, missing receipt, FAILED CONTROL, ...).

This file is the port of the legacy lint.sh block onto the lint v2 runner
contract; the judge's verdicts are passed through verbatim, so they cannot
drift:

  exit 0  judge green — the contract holds both directions
  exit 1  judge reported findings, passed through verbatim (this includes
          the judge's own fail-closed NOT-GATED verdicts, which are failures,
          never passes)
  exit 2  judge missing from the audited root, or the judge itself verified
          nothing (its shared parser missing) — NOT-GATED, never a pass
"""

import os
import subprocess
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import scope  # noqa: E402

CHECK_ID = "22-ledger-integrity"
JUDGE = "scripts/ac-ledger-integrity.sh"


def main():
    import argparse

    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("root", nargs="?", default=None,
                    help="repo root to lint (default: this checkout)")
    args = ap.parse_args()
    root = args.root or scope.ROOT
    script = os.path.join(root, JUDGE)
    if not os.path.isfile(script):
        print(f"{CHECK_ID} NOT-CHECKED: {JUDGE} not found in {root} — family ledger integrity NOT-GATED", file=sys.stderr)
        return 2
    proc = subprocess.run(["bash", script, root], capture_output=True, text=True)
    out = (proc.stdout + proc.stderr).strip()
    if proc.returncode == 0:
        for line in out.splitlines():
            print("  " + line)
        print(f"  ok: {CHECK_ID} — the ledger and the constitution satisfy the contract both directions")
        return 0
    if proc.returncode == 2:
        print(f"{CHECK_ID} NOT-GATED: the judge verified nothing — {out}", file=sys.stderr)
        return 2
    for line in out.splitlines():
        print(line)
    print(f"FAIL {CHECK_ID}: family ledger/control integrity violation(s) — see above")
    return 1


if __name__ == "__main__":
    sys.exit(main())
