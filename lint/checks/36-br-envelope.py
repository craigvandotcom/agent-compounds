#!/usr/bin/env python3
# ---
# id: 36-br-envelope
# prevents: a raw `br … --json` read that bypasses the envelope-aware helper — with --json a br
#   failure is a VALID error envelope on STDOUT and an EMPTY stderr, so a raw piped/captured read
#   converts a dead read into EMPTY DATA and the gate downstream reads "no labels", "no beads",
#   "nothing stale" — and passes
# scope: SCRIPTS
# severity: fail
# fixture: lint/fixtures/36-br-envelope
# ---
"""36-br-envelope — every `br … --json` read routes through br_call (or the python twin).

The D9 completeness sensor: the thirteen shell consumers converted to the
envelope-aware helper (skills/_tools/br-call.sh) plus the python twin
(skills/ac-polish/scripts/bead-artifact.py) are the routed population, and a
future call site written raw is a RED COMMIT. The check senses; it never
rewrites a call site.

Exit: 0 every br --json read routed and at least thirteen routed call sites
scanned, 1 findings (or the floor missed), 2 nothing scanned (NOT-GATED, never
a pass).
"""

import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import scope  # noqa: E402

CHECK_ID = "36-br-envelope"

# The vacuous-detector floor (Check 19's shape): a scan that finds fewer than
# thirteen routed call sites has lost its subject and refuses, rather than
# reporting a clean board it never examined. The check counts OVER the floor,
# never down to it — a fourteenth (or fifteenth) site does not defeat it.
FLOOR = 13

# The raw-read shape the conversions replaced: a `br … --json` whose output is
# piped or captured without routing through the envelope-aware helper. The same
# rg shape ac-heyt.4's derivation used, including the `"$BR"` variable form.
RAW_READ = re.compile(r'(?:"?\$\{?BR\}?"?|\bbr\b)\s+.*--json')
ROUTED_READ = re.compile(r"\bbr_call\b[^\n]*--json")

# The sanctioned engines — the ONLY files that may touch the binary with --json
# and remain clean. They ARE the envelope-aware readers; everything else routes
# through them.
SANCTIONED = frozenset({
    "skills/_tools/br-call.sh",
    "skills/ac-polish/scripts/bead-artifact.py",
})


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    if os.path.abspath(root) != scope.ROOT:
        os.environ["LINT_ROOT"] = os.path.abspath(root)
        import importlib
        importlib.reload(scope)

    files = sorted(scope.SCRIPTS)
    if not files:
        print(f"{CHECK_ID} NOT-CHECKED: no .sh/.py script under skills/ or scripts/ "
              f"in {root} — verified nothing", file=sys.stderr)
        return 2

    findings = []
    routed = 0
    for rel in files:
        path = os.path.join(root, rel)
        try:
            with open(path, encoding="utf-8", errors="replace") as fh:
                text = fh.read()
        except OSError as exc:
            findings.append(f"unreadable {rel}: {exc}")
            continue
        if rel in SANCTIONED:
            continue  # the engines may touch the binary with --json by contract
        for lineno, line in enumerate(text.splitlines(), 1):
            if RAW_READ.search(line):
                findings.append(f"raw br --json read in {rel}:{lineno}: {line.strip()}")
            if ROUTED_READ.search(line):
                routed += 1

    # The python twin counts once toward the floor — the thirteenth call site.
    if os.path.isfile(os.path.join(root, "skills/ac-polish/scripts/bead-artifact.py")):
        routed += 1

    if findings:
        for f in findings:
            print(f"FAIL {CHECK_ID}: {f}")
        return 1
    if routed < FLOOR:
        print(f"FAIL {CHECK_ID}: {routed} routed call site(s) — below the "
              f"{FLOOR}-site floor; the scan lost its subject and refuses, never a clean board",
              file=sys.stderr)
        return 1
    print(f"  ok: {CHECK_ID} — every br --json read routes through br_call or the "
          f"python twin ({routed} routed call site(s), floor {FLOOR})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
