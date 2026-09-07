#!/usr/bin/env python3
# ---
# id: 1-dead-patterns
# prevents: dead patterns (strings naming retired machinery) living in skills/ and agents/ text — zero tolerance; a reader who copies the string revives the dead thing
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/1-dead-patterns
# ---
"""1-dead-patterns — the legacy lint.sh Check 1 block, ported to the runner.

Dead patterns are zero tolerance in skills/ and agents/: each string names a
thing that no longer exists, so every live mention is a revival waiting to be
copied. The list carries its history as comments — a pattern is retired by
deleting its entry, never by allowing its hits.

    "persona-catalog"            retired 2026-06
    "craigs-setup"               retired 2026-06
    "browser-qa-agent"           retired 2026-06
    "agent-compounds/commands/"  dead command-dir links (the /commands/ era)

(`run /ac-plan first` / `Run /ac-plan ` were dead while the planner was
ac-plan-init. After the ac2->ac rename, ac-plan IS the planner and those
strings are correct. Retired 2026-09-02.)

Exit: 0 every pattern clean and at least one file scanned, 1 findings,
2 nothing scanned (NOT-GATED, never a pass).
"""

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import scope  # noqa: E402

CHECK_ID = "1-dead-patterns"

# Zero tolerance. A pattern leaves this list only by dying on disk first —
# `run /ac-plan first` / `Run /ac-plan ` were dead while the planner was
# ac-plan-init; after the ac2->ac rename ac-plan IS the planner and those
# strings are correct, so they were retired 2026-09-02.
DEAD_PATTERNS = (
    "persona-catalog",
    "craigs-setup",
    "browser-qa-agent",
    "agent-compounds/commands/",
)


def main():
    import argparse

    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("root", nargs="?", default=None,
                    help="repo root to lint (default: this checkout)")
    args = ap.parse_args()
    root = args.root or scope.ROOT

    scanned = 0
    findings = []
    for sub in ("skills", "agents"):
        base = os.path.join(root, sub)
        if not os.path.isdir(base):
            continue
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = [d for d in dirnames
                           if d not in ("node_modules", "__pycache__", ".git")]
            for fn in filenames:
                if not fn.endswith(".md"):
                    continue
                path = os.path.join(dirpath, fn)
                scanned += 1
                try:
                    with open(path, encoding="utf-8", errors="replace") as fh:
                        text = fh.read()
                except OSError as exc:
                    findings.append(f"unreadable file {os.path.relpath(path, root)}: {exc}")
                    continue
                for pattern in DEAD_PATTERNS:
                    if pattern in text:
                        findings.append(
                            f"dead pattern '{pattern}' found in {os.path.relpath(path, root)}")
    if scanned == 0:
        print(f"{CHECK_ID} NOT-CHECKED: no *.md file under skills/ or agents/ in {root} — verified nothing",
              file=sys.stderr)
        return 2
    for f in findings:
        print(f"FAIL {CHECK_ID}: {f}")
    if findings:
        return 1
    print(f"  ok: {CHECK_ID} — no dead pattern in skills/ or agents/ ({scanned} file(s) scanned)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
