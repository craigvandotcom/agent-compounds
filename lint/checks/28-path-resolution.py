#!/usr/bin/env python3
# ---
# id: 28-path-resolution
# prevents: skill text citing a file that does not exist on disk — moved and retired paths staying
#   cited for months (Check 2 and the budget check both skip these by design)
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/28-path-resolution
# ---
"""28-path-resolution — every cross-skill file path cited in LIVE_TEXT resolves.

Grammar (both forms):
  1. `skills/<name>/.../<file>.<ext>`  — repo-root-relative, resolved as written.
  2. `<skill>/references/<file>.<ext>` (also `reference/`) — resolved as
     `skills/<skill>/references/<file>.<ext>`.

A citation resolving under either form is fine; under neither it is a finding,
unless the allowlist admits it. Exempt: CORPUS (a test corpus, not doctrine)
and lint/fixtures/ — a fixture tree is the check's own RED material, scanned
only when it IS the root (the 00-meta RED leg), never as live text. OUT: bare
script names (`lint.sh`) and dir-only mentions (`skills/agents`) — no file
extension, not a citation.

Allowlist `lint/allowlists/28-path-resolution.txt`: lib.ratchet's `DATE key
[# why]` format, `key` being the dangling path and `DATE` the day it was
admitted. Shrink-only is mechanical: an entry whose path RESOLVES today is
itself a violation (the fix landed; delete the line). The check never adds
entries — a new dangling path fails, and admission is a dated edit by a
human or a bead.

Exit: 0 clean (>=1 file scanned), 1 findings, 2 scanned nothing.
"""

import os
import re
import sys

import _bootstrap  # noqa: F401
from lib import ratchet, scope

FORM1 = re.compile(
    r"(?<![\w/.\-])skills/[A-Za-z0-9][A-Za-z0-9._-]*(?:/[A-Za-z0-9._-]+)+"
    r"\.[A-Za-z0-9]{1,5}\b"
)
FORM2 = re.compile(
    r"(?<![\w/.\-])[A-Za-z0-9][A-Za-z0-9._-]*/(?:references|reference)/"
    r"[A-Za-z0-9._-]+\.[A-Za-z0-9]{1,5}\b"
)
ALLOWLIST = os.path.join("lint", "allowlists", "28-path-resolution.txt")


def resolves(root, tok):
    for cand in (os.path.join(root, tok), os.path.join(root, "skills", tok)):
        if os.path.isfile(cand):
            return True
    return False


def admitted_paths(root):
    """Returns (allowed set, defect list): lib.ratchet's shared parse, plus this
    check's own per-entry validity — a duplicate path, or a path that now
    RESOLVES (the fix landed; shrink-only demands the line go), is a defect
    lib.ratchet has no way to know about."""
    path = os.path.join(root, ALLOWLIST)
    if not os.path.isfile(path):
        return set(), []
    entries, defects = ratchet.load_allowlist(path)
    allowed, seen = set(), set()
    for _date, tok in entries:
        if tok in seen:
            defects.append(f"{ALLOWLIST}: duplicate entry {tok}")
            continue
        seen.add(tok)
        if resolves(root, tok):
            defects.append(
                f"{ALLOWLIST}: {tok} now RESOLVES — the fix landed; "
                "delete the line (shrink-only)"
            )
            continue
        allowed.add(tok)
    return allowed, defects


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    if os.path.abspath(root) != scope.ROOT:
        os.environ["LINT_ROOT"] = os.path.abspath(root)
        import importlib
        importlib.reload(scope)

    exempt = set(scope.CORPUS)
    scanned, hits, defects = 0, [], []
    for p in scope.scan(scope.LIVE_TEXT):
        rel = os.path.relpath(p, root).replace(os.sep, "/")
        if rel in exempt or rel.startswith("lint/fixtures/"):
            continue
        try:
            with open(p, encoding="utf-8", errors="replace") as fh:
                text = fh.read()
        except OSError:
            continue
        scanned += 1
        for n, line in enumerate(text.splitlines(), 1):
            toks = {m.group(0) for m in FORM1.finditer(line)}
            toks |= {m.group(0) for m in FORM2.finditer(line)}
            for tok in sorted(toks):
                if not resolves(root, tok):
                    hits.append(f"{rel}:{n} cites '{tok}' — no such file")

    allowed, al_defects = admitted_paths(root)
    defects += al_defects
    open_hits = [h for h in hits if not any(a in h for a in allowed)]
    for d in defects:
        print(f"FAIL 28-path-resolution: {d}")
    for h in open_hits:
        print(f"FAIL 28-path-resolution: {h}")

    if scanned == 0:
        print("28-path-resolution NOT-CHECKED: no LIVE_TEXT found — verified nothing",
              file=sys.stderr)
        return 2
    if defects or open_hits:
        print(
            "FAIL 28-path-resolution: "
            f"{len(open_hits)} dangling citation(s), {len(defects)} allowlist defect(s) "
            "— fix the citation or admit the path with a dated allowlist entry"
        )
        return 1
    print(f"  ok: 28-path-resolution — {scanned} live-text file(s), every cited path resolves")
    return 0


if __name__ == "__main__":
    sys.exit(main())
