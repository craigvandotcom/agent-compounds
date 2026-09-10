#!/usr/bin/env python3
"""run.py — the lint v2 runner.

Discovers lint/checks/* (harness *.test.sh files excluded), runs them in
parallel, prints ONE table, and exits:

  0   every executed check green
  1   at least one check reported findings
  2   NOT-GATED — an executed check scanned zero files (the check itself
      exits 2). An empty scan is never read as a pass.

Invocation contract for a check: `python3 <check>.py [root]` / `bash <check>.sh
[root]`; root defaults to the real repo root. Exit 0 green, 1 findings, 2
scanned-nothing. The header contract the checks declare is enforced by
00-meta.py; the runner only executes and tabulates.

Flags: --check <id> (repeatable, id is the filename's NN prefix or the full
stem), --changed (only checks whose declared scope intersects `git diff
--name-only HEAD` plus untracked files; out-of-scope checks are skipped, never
silent), --json (machine output), --list (print the discovered checks).
"""

import concurrent.futures
import json
import os
import re
import subprocess
import sys
import time

_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_HERE = os.path.join(_ROOT, "lint")
sys.path.insert(0, _HERE)

from lib import frontmatter, scope  # noqa: E402

STEM = re.compile(r"^(\d{2})-([a-z0-9-]+)\.(py|sh)$")


def discover():
    out = []
    for rel in sorted(scope.CHECKS):
        fn = os.path.basename(rel)
        if fn.endswith(".test.sh"):
            continue  # proof harnesses run under run-all-harnesses.sh, not the lint suite
        if fn.endswith(".py") or fn.endswith(".sh"):
            out.append(os.path.join(_ROOT, rel))
    return out


def header_of(path):
    return frontmatter.parse_file(path)


def check_id(path):
    return os.path.basename(path).rsplit(".", 1)[0]


def run_check(path, root, timeout=300):
    cmd = [sys.executable, path, root] if path.endswith(".py") else ["bash", path, root]
    t0 = time.time()
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return proc.returncode, proc.stdout, proc.stderr, time.time() - t0
    except subprocess.TimeoutExpired:
        return 3, "", f"timeout after {timeout}s", time.time() - t0


def changed_files(root):
    try:
        diff = subprocess.run(
            ["git", "diff", "--name-only", "HEAD"], cwd=root,
            capture_output=True, text=True, timeout=30,
        )
        out = set(line for line in diff.stdout.splitlines() if line.strip())
        untracked = subprocess.run(
            ["git", "ls-files", "--others", "--exclude-standard"], cwd=root,
            capture_output=True, text=True, timeout=30,
        )
        out |= set(line for line in untracked.stdout.splitlines() if line.strip())
        return out
    except (subprocess.SubprocessError, OSError):
        return None  # cannot know -> run everything, never silently skip


def staged_files(root):
    """The paths in the index — what a commit will actually contain.

    A pre-commit lane must scope to the STAGED set, not the whole working tree: an
    uncommitted sibling edit, or a ledger dirtied by another writer's claims, must not
    trigger this committer's scope (measured: a dirty `.beads/issues.jsonl` pulled HOOKS
    Check 35 into every writer's commit and deadlocked the swarm).
    """
    try:
        diff = subprocess.run(
            ["git", "diff", "--cached", "--name-only", "HEAD"], cwd=root,
            capture_output=True, text=True, timeout=30,
        )
        return set(line for line in diff.stdout.splitlines() if line.strip())
    except (subprocess.SubprocessError, OSError):
        return None


def intersect(scope_set, files):
    """A declared scope touches a changed file when the change is IN it."""
    for f in files:
        if f in scope_set:
            return True
        # a change under a directory the set's members live in (e.g. a new
        # references file) touches LIVE_TEXT even if not itself a member
        if any(f.startswith(m.rsplit("/", 1)[0] + "/") for m in scope_set):
            return True
    return False


def main():
    import argparse

    ap = argparse.ArgumentParser(description="lint v2 runner — one table over lint/checks/*")
    ap.add_argument("--check", action="append", default=[], metavar="ID",
                    help="run only this check (filename NN prefix or full stem); repeatable")
    ap.add_argument("--changed", action="store_true",
                    help="only checks whose scope intersects the working-tree diff")
    ap.add_argument("--staged", action="store_true",
                    help="with --changed, scope to the staged index (what a commit contains), not the working tree")
    ap.add_argument("--json", action="store_true", dest="as_json",
                    help="emit results as JSON")
    ap.add_argument("--root", default=_ROOT, help="repo root to lint (default: this checkout)")
    args = ap.parse_args()

    all_checks = discover()
    if args.check:
        def _norm(w: str) -> str:
            return w.lstrip("0") or "0"
        ids_full = {check_id(c) for c in all_checks}
        ids_prefix = {_norm(i.split("-", 1)[0]) for i in ids_full}
        selected = [c for c in all_checks if _norm(check_id(c)) in {_norm(w) for w in args.check}
                    or _norm(check_id(c).split("-", 1)[0]) in {_norm(w) for w in args.check}]
        unknown = [w for w in args.check
                   if _norm(w) not in {_norm(i) for i in ids_full} and _norm(w) not in ids_prefix]
        if unknown:
            print(f"NOT-GATED: unknown --check id(s): {unknown} — nothing ran", file=sys.stderr)
            return 2
    else:
        selected = all_checks

    if not selected:
        print("NOT-GATED: no check files discovered under lint/checks — verified nothing", file=sys.stderr)
        return 2

    skipped = {}
    if args.changed:
        files = staged_files(args.root) if args.staged else changed_files(args.root)
        if files is None:
            skipped = {}  # cannot compute a diff -> change nothing, run all
        else:
            for c in selected:
                h = header_of(c)
                if str(h.get("changed", "")).lower() == "skip":
                    # audits state OUTSIDE the repo (e.g. consumer harness layers); a
                    # commit-scoped run cannot fix it and must not be gated by it
                    skipped[check_id(c)] = "changed:skip"
                    continue
                s = getattr(scope, str(h.get("scope", "")), None)
                if not isinstance(s, frozenset) or not intersect(s, files):
                    skipped[check_id(c)] = h.get("scope", "?")

    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as ex:
        futs = {ex.submit(run_check, c, args.root): c for c in selected if check_id(c) not in skipped}
        for fut in concurrent.futures.as_completed(futs):
            c = futs[fut]
            rc, out, err, secs = fut.result()
            results.append({
                "id": check_id(c),
                "file": os.path.relpath(c, args.root),
                "exit": rc,
                "seconds": round(secs, 2),
                "findings": ([line for line in out.splitlines() if line.strip()]
                             + [line for line in err.splitlines()
                                if line.strip() and line.startswith("FAIL")]),
            })

    for cid, s in sorted(skipped.items()):
        results.append({"id": cid, "file": None, "exit": None, "seconds": 0,
                        "findings": [], "skipped_scope": s})
    results.sort(key=lambda r: r["id"])

    for r in results:
        if r.get("skipped_scope") is not None:
            r["result"] = "skipped"
        elif r["exit"] == 0:
            r["result"] = "ok"
        elif r["exit"] == 2:
            r["result"] = "not-gated"
        else:
            r["result"] = "fail"

    if args.as_json:
        print(json.dumps({"root": args.root, "checks": results}, indent=2))
    else:
        print(f"{'ID':<14} {'RESULT':<10} {'SEC':>6}  DETAIL")
        for r in results:
            detail = r["skipped_scope"] if r.get("skipped_scope") else "; ".join(r["findings"][:1])
            print(f"{r['id']:<14} {r['result']:<10} {r['seconds']:>6.2f}  {detail}")
        for r in results:
            if r["result"] == "fail" and len(r["findings"]) > 1:
                for line in r["findings"][1:]:
                    print(f"    {line}")

    exits = [r["exit"] for r in results if not r.get("skipped_scope")]
    if 2 in exits:
        return 2
    if 1 in exits:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
