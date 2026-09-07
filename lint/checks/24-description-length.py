#!/usr/bin/env python3
# ---
# id: 24-description-length
# prevents: a skill description silently dropped by a consumer harness — opencode documents a 1-1024 character cap on skill descriptions, and the registry was once inside 6 characters of the limit with nothing watching
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/24-description-length
# ---
"""24-description-length — the cross-harness description cap.

The legacy lint.sh Check 24 block's exact legs over skills/*/SKILL.md:

  hard cap   1024 characters (opencode documents the cap; measured, it is
             not enforced at load — a dropped skill is invisible from inside
             the registry, so this is insurance against an upstream
             tightening).
  warn band  >= 950 characters prints a WARN line so the cap is not
             discovered by hitting it. WARN lines are reported, never
             findings — the verdict is the hard cap only.

Characters, not bytes: descriptions carry em dashes and awk's length() counts
bytes, over-reporting a UTF-8 description by ~2 per dash. The count is a
Python string length on the description value (what opencode measures).

Exit: 0 every description inside the cap, 1 at least one over it, 2 nothing
scanned (no skills directory) — NOT-GATED, never a pass.
"""

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import scope  # noqa: E402

CHECK_ID = "24-description-length"
DESC_HARD = 1024
DESC_WARN = 950


def description_length(path):
    """Character length of the frontmatter description value, or None."""
    with open(path, encoding="utf-8", errors="replace") as fh:
        lines = fh.read().split("\n")
    fences = 0
    for ln in lines:
        if ln.strip() == "---":
            fences += 1
            if fences == 2:
                break
            continue
        if fences == 1 and ln.startswith("description:"):
            return len(ln[len("description:"):].strip())
    return None


def main():
    import argparse

    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("root", nargs="?", default=None,
                    help="repo root to lint (default: this checkout)")
    args = ap.parse_args()
    root = args.root or scope.ROOT
    skills = os.path.join(root, "skills")
    if not os.path.isdir(skills):
        print(f"{CHECK_ID} NOT-CHECKED: no skills/ directory under {root} — verified nothing", file=sys.stderr)
        return 2
    over = 0
    scanned = 0
    for d in sorted(os.listdir(skills)):
        p = os.path.join(skills, d, "SKILL.md")
        if not os.path.isfile(p):
            continue
        scanned += 1
        dlen = description_length(p)
        if dlen is None:
            continue
        if dlen > DESC_HARD:
            print(f"  {d}: description {dlen} chars, over the {DESC_HARD} cap")
            over += 1
        elif dlen >= DESC_WARN:
            print(f"  WARN {d}: description {dlen} chars, within {DESC_HARD - dlen} of the {DESC_HARD} cap")
    if over:
        print(f"FAIL {CHECK_ID}: {over} skill description(s) over the {DESC_HARD}-char cross-harness cap")
        return 1
    print(f"  ok: {CHECK_ID} — every skill description is within the {DESC_HARD}-char cap ({scanned} skill(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main())
