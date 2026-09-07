#!/usr/bin/env python3
# ---
# id: 6-portability
# prevents: app-specific strings (schema names, app prose, local endpoints, old tracker ids) in skills/ text — the zero-tolerance grep layer under the instance-token gate's allowlist policy
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/6-portability
# ---
"""6-portability — the legacy lint.sh Check 6 block, ported to the runner.

Portability patterns are zero tolerance in skills/: each string names one
specific deployment's vocabulary, so a live mention makes the skill text
non-portable. The instance-token members of this list are ALSO carried by
Check 27's token set; Check 27 is the allowlist policy (SHRINK-ONLY carriers),
this check remains the zero-tolerance grep — a carrier 27's allowlist accepts
still fails here, so the two verdicts can disagree by design and the stricter
layer is the portability backstop.

Exit: 0 every pattern clean and at least one file scanned, 1 findings,
2 nothing scanned (NOT-GATED, never a pass).
"""

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import scope  # noqa: E402

CHECK_ID = "6-portability"

PORTABILITY_PATTERNS = (
    "canonical_ingredients",
    "For Body Compass",
    "127.0.0.1:54321",
    "bd-8nse",
    "bd-9veq",
)


def main():
    import argparse

    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("root", nargs="?", default=None,
                    help="repo root to lint (default: this checkout)")
    args = ap.parse_args()
    root = args.root or scope.ROOT

    base = os.path.join(root, "skills")
    if not os.path.isdir(base):
        print(f"{CHECK_ID} NOT-CHECKED: no skills/ directory under {root} — verified nothing",
              file=sys.stderr)
        return 2

    scanned = 0
    findings = []
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = [d for d in dirnames
                       if d not in ("node_modules", "__pycache__", ".git")]
        for fn in filenames:
            if not fn.endswith(".md"):
                continue
            path = os.path.join(dirpath, fn)
            scanned += 1
            try:
                text = open(path, encoding="utf-8", errors="replace").read()
            except OSError as exc:
                findings.append(f"unreadable file {os.path.relpath(path, root)}: {exc}")
                continue
            for pattern in PORTABILITY_PATTERNS:
                if pattern in text:
                    findings.append(
                        f"portability violation '{pattern}' found in {os.path.relpath(path, root)}")
    if scanned == 0:
        print(f"{CHECK_ID} NOT-CHECKED: no *.md file under skills/ in {root} — verified nothing",
              file=sys.stderr)
        return 2
    for f in findings:
        print(f"FAIL {CHECK_ID}: {f}")
    if findings:
        return 1
    print(f"  ok: {CHECK_ID} — no portability violation in skills/ ({scanned} file(s) scanned)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
