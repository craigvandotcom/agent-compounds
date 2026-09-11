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

The `--changed --staged` lane (the pre-commit hook's mode) judges what a
commit will contain, not the checkout on disk: every check's DECLARED SCOPE is
still selected from the staged file list (`staged_files()`), but each SELECTED
check is then run against a temp dir holding the INDEX snapshot
(`materialize_staged()`), never the working tree — a sibling writer's dirty,
half-finished file sitting in the same shared checkout must not fail this
committer's commit (measured: a foreign edit refused a worker's commit until
it happened to land, FRICTIONS.md:711). Checks that shell out to git (14, 25,
29, 31 today) still need a real `.git` to resolve base refs / `git show` a
committed blob / diff `--cached`; rather than special-case their invocation,
the snapshot dir is handed `GIT_DIR` (the real repo's) and `GIT_WORK_TREE`
(the snapshot dir) as environment, so any git command a check runs resolves
against real history while "the working tree" IS the staged snapshot —
`git diff <base>` (no `--cached`) then already compares base against staged
content, with no per-check code required. The one exception is 14's leg 2,
which shells to OTHER repos entirely (`git -C <that repo>`); an inherited
GIT_DIR/GIT_WORK_TREE pointing at THIS repo would misdirect those calls, so
leg 2 reads the LINT_STAGED=1 env var this runner also sets and skips itself
in the staged lane (it audits other repos' local state, which this commit
cannot fix anyway — see that check's own docstring).
"""

import concurrent.futures
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
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


def run_check(path, root, timeout=300, extra_env=None):
    cmd = [sys.executable, path, root] if path.endswith(".py") else ["bash", path, root]
    env = os.environ.copy()
    if extra_env:
        env.update(extra_env)
    t0 = time.time()
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, env=env)
        return proc.returncode, proc.stdout, proc.stderr, time.time() - t0
    except subprocess.TimeoutExpired:
        return 3, "", f"timeout after {timeout}s", time.time() - t0


# A check discloses a verdict on stderr (SKIP / WARN / NOT-GATED). The runner must surface
# those lines: dropping them made a degraded run — e.g. Check 07/12 SKIPping on a bare
# checkout — read as a clean one, the disclosure the check promises never reaching the report.
_DISCLOSURE_TOKENS = ("FAIL", "SKIP", "WARN", "NOTICE", "NOT-GATED", "NOT-CHECKED")


def _disclosure(line):
    return any(tok in line for tok in _DISCLOSURE_TOKENS)


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


def _staged_index_env():
    """Base env for a git call that must see the CALLER's staged content.

    A pathspec-scoped `git commit -F msg -- path` (this repo's mandated commit
    pattern) never touches the real `.git/index` — git builds a TEMPORARY index
    for exactly that partial commit and points GIT_INDEX_FILE at it while hooks
    run. hooks/pre-commit captures that path as LINT_CALLER_GIT_INDEX_FILE
    (never the real GIT_INDEX_FILE name, so it never leaks as ambient env into
    an unrelated fixture-building subprocess) before stripping the raw
    variable. Without this, `git diff --cached`/`checkout-index` fall back to
    the real index and see NONE of a pathspec'd-but-never-`git add`-ed change —
    measured: a same-file edit to 14-no-net-growth.py landed via that exact
    pattern and 14-no-net-growth itself reported "skipped LIVE_TEXT".
    """
    env = os.environ.copy()
    caller_index = os.environ.get("LINT_CALLER_GIT_INDEX_FILE")
    if caller_index:
        env["GIT_INDEX_FILE"] = caller_index
    return env


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
            capture_output=True, text=True, timeout=30, env=_staged_index_env(),
        )
        return set(line for line in diff.stdout.splitlines() if line.strip())
    except (subprocess.SubprocessError, OSError):
        return None


def git_dir_of(root):
    """The real repo's absolute `.git` dir, or None (not a git checkout / git missing)."""
    try:
        proc = subprocess.run(
            ["git", "-C", root, "rev-parse", "--absolute-git-dir"],
            capture_output=True, text=True, timeout=30,
        )
    except (subprocess.SubprocessError, OSError):
        return None
    return proc.stdout.strip() if proc.returncode == 0 and proc.stdout.strip() else None


def materialize_staged(root):
    """Snapshot the INDEX — what a commit will actually contain — into a fresh temp dir.

    `git checkout-index` writes only what is IN the index; an unstaged edit or an
    untracked scratch file elsewhere in the shared checkout is never written here,
    so a sibling writer's dirty file cannot leak into this committer's lint run.
    Returns (worktree_dir, git_dir) on success, (None, None) on any failure — the
    caller's cue to fall back to the real checkout, never a crash.
    """
    git_dir = git_dir_of(root)
    if not git_dir:
        return None, None
    tmp = tempfile.mkdtemp(prefix="ac-lint-staged-")
    try:
        proc = subprocess.run(
            ["git", "checkout-index", "-a", "-f", f"--prefix={tmp}{os.sep}"],
            cwd=root, capture_output=True, text=True, timeout=60, env=_staged_index_env(),
        )
    except (subprocess.SubprocessError, OSError):
        proc = None
    if proc is None or proc.returncode != 0:
        shutil.rmtree(tmp, ignore_errors=True)
        return None, None
    return tmp, git_dir


def intersect(scope_set, files, files_root):
    """A declared scope touches a changed file when the change is IN it.

    `files` is git-diff-relative to `files_root`; `scope_set`'s members are
    relative to `scope.ROOT` — two independently-resolved bases that a plain
    string compare assumes are the same string, and silently are not whenever
    the checkout is reached through two different-looking-but-identical paths
    (a symlink, a second mount, macOS's /tmp vs /private/tmp — exactly the
    shape of a shared, multi-agent checkout). Both sides are normalised to a
    real absolute path before comparing, so a genuine intersection cannot read
    as "no scope hit" (measured: 22-ledger-integrity skipped LEDGER on a
    commit that staged an actual ledger file).
    """
    real_files = {os.path.realpath(os.path.join(files_root, f)) for f in files}
    real_dirs = {os.path.realpath(os.path.join(scope.ROOT, m.rsplit("/", 1)[0])) + os.sep
                 for m in scope_set}
    for m in scope_set:
        if os.path.realpath(os.path.join(scope.ROOT, m)) in real_files:
            return True
    # a change under a directory the set's members live in (e.g. a new
    # references file) touches LIVE_TEXT even if not itself a member
    for rf in real_files:
        if any(rf.startswith(d) for d in real_dirs):
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
            real_files = {os.path.realpath(os.path.join(args.root, f)) for f in files}
            for c in selected:
                if os.path.realpath(c) in real_files:
                    # the check's OWN source changed — always re-run it, scope or not:
                    # a check whose own file is part of the commit must prove itself
                    # against that commit, never sit out on a scope technicality.
                    continue
                h = header_of(c)
                if str(h.get("changed", "")).lower() == "skip":
                    # audits state OUTSIDE the repo (e.g. consumer harness layers); a
                    # commit-scoped run cannot fix it and must not be gated by it
                    skipped[check_id(c)] = "changed:skip"
                    continue
                s = getattr(scope, str(h.get("scope", "")), None)
                if not isinstance(s, frozenset) or not intersect(s, files, args.root):
                    skipped[check_id(c)] = h.get("scope", "?")

    # The staged lane judges what a commit will CONTAIN, not the working tree on disk:
    # every check runs against a fresh snapshot of the INDEX so a sibling writer's dirty,
    # half-finished file in the same shared checkout can never fail this commit's lint
    # (measured: FRICTIONS.md:711). Checks that shell to git (14, 25, 29, 31 today) still
    # need a real .git — GIT_DIR/GIT_WORK_TREE redirect any git call THEY make at the real
    # history while "the working tree" is the snapshot, so `git diff <base>` (no --cached)
    # already compares base against staged content with no per-check special-casing.
    run_root = args.root
    extra_env = None
    staged_worktree = None
    if args.changed and args.staged:
        staged_worktree, git_dir = materialize_staged(args.root)
        if staged_worktree:
            run_root = staged_worktree
            extra_env = {"GIT_DIR": git_dir, "GIT_WORK_TREE": staged_worktree, "LINT_STAGED": "1"}
            # A check's own `--cached` read (14's leg 1) must see the SAME index this
            # materialisation used, not the real repo's ambient one — see
            # _staged_index_env()'s docstring.
            caller_index = os.environ.get("LINT_CALLER_GIT_INDEX_FILE")
            if caller_index:
                extra_env["GIT_INDEX_FILE"] = caller_index
        else:
            print("NOTICE: staged-lane materialisation failed — running the staged scope against "
                  "the real checkout instead (an unrelated dirty file could affect this run)",
                  file=sys.stderr)

    try:
        results = []
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as ex:
            futs = {ex.submit(run_check, c, run_root, 300, extra_env): c
                    for c in selected if check_id(c) not in skipped}
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
                                    if line.strip() and _disclosure(line)]),
                })
    finally:
        # scratch snapshot only — never the real checkout; always cleaned up, success or not
        if staged_worktree:
            shutil.rmtree(staged_worktree, ignore_errors=True)

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
