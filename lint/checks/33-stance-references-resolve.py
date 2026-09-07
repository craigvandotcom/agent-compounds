#!/usr/bin/env python3
# ---
# id: 33-stance-references-resolve
# prevents: skill or hook text naming a subagent stance that no longer exists — "engineer" survived its 2026-06-11 rename for months and the review/* agents went spawn-orphaned because nothing checked that spawn instructions resolve to the roster
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/33-stance-references-resolve
# ---
"""33-stance-references-resolve — every named subagent stance resolves to the roster.

Scans skills/, hooks/, and commands/ *.md for two spawn-language shapes:

  1. backtick/bold-decorated stance tokens:  `browser-tester` subagents
  2. machine spawn calls:                     subagent_type: "X"  /  Task(X,

Every resolved name must be a defined agent (agents/*.md) or a harness
built-in (general, general-purpose, explore, build). Historical friction logs
(FRICTIONS.md) are exempt — they are records, not instructions.

Exit: 0 all references resolve, 1 a reference does not, 2 nothing scanned.
"""

import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import scope  # noqa: E402

CHECK_ID = "33-stance-references-resolve"

# harness built-in subagent types that are not registry agents
BUILTINS = {"general", "general-purpose", "explore", "build", "plan"}

# <name> subagent(s) with backtick or bold decoration — the documented spawn style
DECORATED = re.compile(r"(?:`|\*\*)([a-z][a-z-]{2,})(?:`|\*\*)\s+subagents?\b")
# machine spawn calls
SUBAGENT_TYPE = re.compile(r'subagent_type:\s*"([a-z][a-z-]+)"')


def scan_files(root):
    dirs = [os.path.join(root, d) for d in ("skills", "hooks", "commands")]
    for base in dirs:
        if not os.path.isdir(base):
            continue
        for dirpath, _dirnames, filenames in os.walk(base):
            if "_archive" in dirpath or "__pycache__" in dirpath:
                continue
            for fn in filenames:
                if not fn.endswith(".md") or fn == "FRICTIONS.md":
                    continue
                yield os.path.join(dirpath, fn)


def main():
    import argparse

    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("root", nargs="?", default=None,
                    help="repo root to lint (default: this checkout)")
    args = ap.parse_args()
    root = args.root or scope.ROOT

    agents_dir = os.path.join(root, "agents")
    if not os.path.isdir(agents_dir) or not os.path.isdir(os.path.join(root, "skills")):
        print(f"{CHECK_ID} NOT-CHECKED: agents/ or skills/ missing under {root} — verified nothing", file=sys.stderr)
        return 2

    roster = {os.path.splitext(fn)[0] for fn in os.listdir(agents_dir) if fn.endswith(".md")}
    known = roster | BUILTINS

    findings = []
    scanned = 0
    for path in scan_files(root):
        scanned += 1
        with open(path, encoding="utf-8") as f:
            text = f.read()
        rel = os.path.relpath(path, root)
        for m in DECORATED.finditer(text):
            name = m.group(1)
            if name not in known:
                findings.append(f"{rel}: '{m.group(0).strip()}' — no agent named '{name}' in agents/ (stance references must resolve; write a lens prompt instead)")
        for m in SUBAGENT_TYPE.finditer(text):
            name = m.group(1)
            if name not in known:
                findings.append(f"{rel}: subagent_type \"{name}\" — no agent named '{name}' in agents/")

    if scanned == 0:
        print(f"{CHECK_ID} NOT-CHECKED: no .md files found under skills/hooks/commands — verified nothing", file=sys.stderr)
        return 2
    for f in findings:
        print(f"FAIL {CHECK_ID}: {f}")
    if findings:
        return 1
    print(f"  ok: {CHECK_ID} — every named subagent stance resolves ({scanned} file(s) scanned, roster: {', '.join(sorted(roster))})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
