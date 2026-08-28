#!/usr/bin/env python3
"""code-manifest.py — the artifact ac2-polish code mode measures.

One `sha256  path` line per in-scope file, sorted by path. Fixpoint on this file means no file
in scope changed this round. The loop edits real files in place; nothing round-trips through an
export, because a concatenation that has to be written back cannot be written back safely.

FAILS CLOSED. A scope that matches nothing, or a file that cannot be read, writes no manifest:
a short manifest silently drops files from every later round, and the loop then converges on a
scope smaller than the one it claims to have polished.

Usage:
  code-manifest.py --out <dir> --scope <glob>[ --scope <glob>...] [--exclude <glob>...]

Globs are repo-relative and support `**`. Run from the repo root.

Exit 0 written · 1 a scope matched nothing or a file was unreadable · 2 NOT-GATED (usage).
"""
import argparse
import hashlib
import os
import sys
from pathlib import Path


def die(code, msg):
    print(f"code-manifest: {msg}", file=sys.stderr)
    sys.exit(code)


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    ap = argparse.ArgumentParser(prog="code-manifest.py")
    ap.add_argument("--out", required=True, help="directory to write manifest.txt into")
    ap.add_argument("--scope", required=True, action="append",
                    help="repo-relative glob; repeat for several")
    ap.add_argument("--exclude", action="append", default=[],
                    help="repo-relative glob to drop; repeat for several")
    args = ap.parse_args()

    root = Path.cwd()
    excluded = set()
    for pattern in args.exclude:
        excluded.update(p.resolve() for p in root.glob(pattern))

    selected, empty = set(), []
    for pattern in args.scope:
        hits = [p for p in root.glob(pattern) if p.is_file() and p.resolve() not in excluded]
        if not hits:
            empty.append(pattern)
        selected.update(hits)

    # A scope that matches nothing is a typo, not an empty scope. Refuse rather than
    # measure a manifest that will trivially reach fixpoint.
    if empty:
        for pattern in empty:
            print(f"code-manifest: FAIL scope matched no files: {pattern!r}", file=sys.stderr)
        die(1, "REFUSED — a scope that matches nothing would converge on the first round.")

    if not selected:
        die(1, "REFUSED — every scope was excluded; there is nothing to polish.")

    lines, unreadable = [], []
    for path in sorted(selected, key=lambda p: str(p.relative_to(root))):
        try:
            lines.append(f"{sha256(path)}  {path.relative_to(root)}")
        except OSError as exc:
            unreadable.append((path, exc))

    if unreadable:
        for path, exc in unreadable:
            print(f"code-manifest: FAIL unreadable: {path} — {exc}", file=sys.stderr)
        die(1, f"REFUSED — {len(unreadable)} file(s) unreadable; no manifest written. "
               "A short manifest drops files from every later round.")

    os.makedirs(args.out, exist_ok=True)
    out = os.path.join(args.out, "manifest.txt")
    with open(out, "w") as fh:
        fh.write("\n".join(lines) + "\n")
    print(f"code-manifest: WROTE {len(lines)} files -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
