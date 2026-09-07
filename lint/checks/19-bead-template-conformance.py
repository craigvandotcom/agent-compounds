#!/usr/bin/env python3
# ---
# id: 19-bead-template-conformance
# prevents: a non-conforming br create template shipping in the registry — a stale template is copied, so it reproduces the defect on every future run, and the agent copying it has no reason to doubt it
# scope: TEMPLATES
# severity: fail
# fixture: lint/fixtures/19-bead-template-conformance
# ---
"""19-bead-template-conformance — the ported Check 19 (ac-1p7j.15).

Ported VERBATIM from the legacy bash block (proven by lint/parity.sh against
the extracted block, before the block was removed from lint.sh). Same judge,
same verdict strings: scripts/bead-template-lint.py — the static twin of the
runtime bead-capture-guard — is the contract's ONE implementation; this check
hosts it, it never reimplements it.

Check 18 proves the runtime guard fires on what an agent TYPES; this proves
the templates the registry SHIPS are themselves conformant — the two are not
the same failure.

Exit: 0 clean, 1 violations (or the lint script missing), 2 never (a missing
script is a violation, not a silent gate — same as the legacy block).
"""

import os
import subprocess
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.dirname(os.path.dirname(_HERE))


def main(argv=()):
    """argv is injectable so harnesses can drive this check without stdin games."""
    args = list(argv)
    root = args[0] if args else _ROOT
    btl = os.path.realpath(os.path.join(root, "scripts", "bead-template-lint.py"))
    if not os.path.isfile(btl):
        print("FAIL 19-bead-template-conformance: scripts/bead-template-lint.py missing — "
              "template conformance unverified")
        return 1
    runner = [sys.executable, btl]
    proc = subprocess.run(runner, capture_output=True, text=True, timeout=300)
    if proc.returncode == 0:
        sys.stdout.write(proc.stdout)
        print("  all bead templates carry origin: + readiness")
        return 0
    sys.stdout.write(proc.stdout)
    sys.stderr.write(proc.stderr)
    print("FAIL 19-bead-template-conformance: non-conforming bead template(s) — see above")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
