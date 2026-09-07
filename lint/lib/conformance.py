"""conformance — the one engine for the named-file doctrine-landing checks.

Check 10 (D-series) and Check 11 (G-series) assert the same thing: a fixed
table of (tag, canon file, matcher, message) rows over named files. One
engine, two data tables — the tables ARE the checks, and a new row is a
reviewable diff.

Matcher kinds (legacy grep semantics, preserved exactly):
  present     ERE regex, case-sensitive, must match            (grep -qE)
  present_i   ERE regex, case-insensitive, must match          (grep -qi)
  absent      literal string, must NOT appear                  (grep -qF)

A missing canon file FAILS a `present` row (grep on a missing file finds
nothing) and PASSES an `absent` row — identical to the legacy blocks, where a
deleted doctrine file is a red conformance violation, never a silent pass.
"""

import os
import re
import sys


def run(root, table, check_id):
    """Execute one conformance table. Returns the check's exit code."""
    if not os.path.isdir(os.path.join(root, "skills")):
        print(f"{check_id} NOT-CHECKED: no skills/ under root — nothing scanned", file=sys.stderr)
        return 2
    findings = []
    for tag, rel, kind, pattern, message in table:
        text = ""
        path = os.path.join(root, rel)
        if os.path.isfile(path):
            with open(path, encoding="utf-8", errors="replace") as fh:
                text = fh.read()
        if kind == "absent":
            ok = pattern not in text
        elif kind == "present_i":
            ok = re.search(pattern, text, re.IGNORECASE) is not None
        else:
            ok = re.search(pattern, text) is not None
        if not ok:
            findings.append(f"{tag}: {message}")
    for f in findings:
        print(f"FAIL {check_id}: {f}")
    return 1 if findings else 0
