#!/usr/bin/env python3
# ---
# id: 17-dcg-blocked-redirects
# prevents: a published markdown snippet prescribing a truncating redirect to a shell-expanded path — a shape dcg refuses, so the snippet is unrunnable on this fleet
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/17-dcg-blocked-redirects
# ---
"""17-dcg-blocked-redirects — the legacy lint.sh Check 17 block, ported.

dcg's `core.filesystem:redirect-truncate-dynamic-path` refuses a TRUNCATING
redirect whose target is shell-expanded — it cannot prove the path before the
file is opened O_TRUNC. A published snippet prescribing that shape is
UNRUNNABLE on this fleet.

Why this check exists (bd-scjgv): bd-5ndzm was closed as Fixed on 2026-07-30
having scoped six skills and mechanically fixed exactly ONE. Nothing
re-detected the rest, so the class read as "fixed" on the board while three
separate published snippets still shipped it and kept costing conductors live
time in Phase 0. The DETECTOR is the deliverable — without it the next snippet
reintroduces the class and no one learns until someone loses a run.

The discriminator is literal-vs-variable TARGET, not compound-vs-simple
command (probed against dcg 0.6.7). NOT matched, because all three are allowed:
  >> "$VAR/path"      appends never truncate
  >/dev/null          fully-literal target
  tee "$VAR/path"     tee is not a redirect

Escape hatch: put `dcg-allow` in a comment on the same line to document the
antipattern deliberately (shell-guardrails.md does exactly that).

The `/` is anchored directly after the variable name ON PURPOSE. An earlier
form used `[^"[:space:]]*/` and matched NOTHING under macOS grep's
leftmost-longest semantics (no backtracking) — a detector that silently
matches nothing is worse than no detector, so this pattern is proved
red-then-green against fixtures before being trusted.

SCOPE: markdown PRESCRIPTIONS only, deliberately not `*.sh`. dcg intercepts
commands an agent submits to its Bash tool; a shell script executed as a FILE
(`bash foo.sh`) is never inspected, so the same shape inside a committed
script is not broken and flagging it would be a false positive that erodes
trust in the check. Only lines INSIDE ```bash / ```sh fences are
prescriptions; prose naming the antipattern must not trip it.

Exit: 0 no violation and at least one file scanned, 1 findings, 2 nothing
scanned (NOT-GATED, never a pass).
"""

import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import scope  # noqa: E402

CHECK_ID = "17-dcg-blocked-redirects"

DCG_BAD_RE = re.compile(r"(^|[ \t]|[0-9]|&)>[ \t]*\"?\$\{?[A-Za-z_][A-Za-z0-9_:%+-]*/")
FENCE_OPEN_RE = re.compile(r"^[ \t]*```(bash|sh)[ \t]*$")


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

    files = []
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = [d for d in dirnames
                       if d not in ("node_modules", "__pycache__", ".git")]
        for fn in sorted(filenames):
            if fn.endswith(".md"):
                files.append(os.path.join(dirpath, fn))
    files.sort()

    if not files:
        print(f"FAIL {CHECK_ID}: zero files scanned under skills/ — the sweep is vacuous")
        return 1

    findings = []
    for path in files:
        rel = os.path.relpath(path, root)
        try:
            with open(path, encoding="utf-8", errors="replace") as fh:
                lines = fh.read().splitlines()
        except OSError as exc:
            findings.append(f"unreadable file {rel}: {exc}")
            continue
        in_fence = False
        for i, line in enumerate(lines, 1):
            if FENCE_OPEN_RE.match(line):
                in_fence = True
                continue
            if line.lstrip().startswith("```"):
                in_fence = False
                continue
            if not in_fence:
                continue
            for m in DCG_BAD_RE.finditer(line):
                if "dcg-allow" in line:
                    continue
                findings.append(
                    "dcg-blocked truncating redirect to a variable path — "
                    f"{rel}:{i}:{line.strip()}")

    for f in findings:
        print(f"FAIL {CHECK_ID}: {f}")
    if findings:
        return 1
    print(f"  ok: {CHECK_ID} — dcg redirect shapes: 0 violations across "
          f"{len(files)} skill file(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
