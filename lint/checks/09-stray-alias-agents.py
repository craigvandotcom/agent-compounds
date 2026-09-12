#!/usr/bin/env python3
# ---
# id: 09-stray-alias-agents
# prevents: a retired alias agent file coming back — engineer.md and reviewer.md were renamed to
#   implementer and validator, and a stray copy re-splits the stance registry while deploy.sh keeps
#   stamping the retired name into every harness
# scope: LIVE_TEXT AGENT_STANCES
# severity: fail
# fixture: lint/fixtures/09-stray-alias-agents
# ---
"""09-stray-alias-agents — the retired alias agent files stay retired.

The legacy lint.sh Check 9 block verbatim: agents/engineer.md and
agents/reviewer.md must not exist (renamed to implementer and validator;
the aliases are retired). A stray copy re-splits the stance registry.

Exit: 0 neither alias exists, 1 an alias file exists, 2 nothing scanned
(the audited root has no agents/ directory at all).
"""

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import scope  # noqa: E402

CHECK_ID = "09-stray-alias-agents"
RETIRED_ALIASES = (
    ("engineer.md", "retired alias agent (renamed to implementer 2026-06-11)"),
    ("reviewer.md", "retired alias agent (renamed to validator 2026-06-11)"),
)


def main():
    import argparse

    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("root", nargs="?", default=None,
                    help="repo root to lint (default: this checkout)")
    args = ap.parse_args()
    root = args.root or scope.ROOT
    agents_dir = os.path.join(root, "agents")
    if not os.path.isdir(agents_dir):
        print(f"{CHECK_ID} NOT-CHECKED: no agents/ directory under {root} — verified nothing", file=sys.stderr)
        return 2
    findings = []
    for fn, why in RETIRED_ALIASES:
        if os.path.exists(os.path.join(agents_dir, fn)):
            findings.append(f"agents/{fn} exists — {why}")
    for f in findings:
        print(f"FAIL {CHECK_ID}: {f}")
    if findings:
        return 1
    print(f"  ok: {CHECK_ID} — no retired alias agent file exists")
    return 0


if __name__ == "__main__":
    sys.exit(main())
