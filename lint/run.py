#!/usr/bin/env python3
"""run.py — the lint v2 runner. Full contract: lint/README.md.

Usage: `python3 lint/run.py [--root DIR] [--check ID]... [--staged] [--json]`
(normally invoked via `./lint.sh`, which is the documented front door).

  --check ID   run only this check (filename NN prefix or full stem); repeatable
  --staged     run the whole suite against the STAGED index (what a commit
               would contain) instead of the working tree on disk
  --json       emit results as JSON instead of the table
  --root DIR   repo root to lint (default: this checkout)

Exit 0 pass · 1 fail (outranks a bare 2) · 2 NOT-GATED (an executed check
scanned zero files). See lint/README.md for the full exit-code and check
header contract.

The `--staged` lane's rationale (why a temp INDEX snapshot, GIT_DIR/
GIT_WORK_TREE redirection, and adopter-local linking) lives beside the code
that does it: see `materialize_staged()`, `_adopter_local_paths()` and the
staged-lane block in `main()` below.
"""

import concurrent.futures
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time

_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_HERE = os.path.join(_ROOT, "lint")
sys.path.insert(0, _HERE)

from lib import scope  # noqa: E402


def discover():
    out = []
    for rel in sorted(scope.CHECKS):
        fn = os.path.basename(rel)
        if fn.endswith(".test.sh"):
            continue  # proof harnesses run under run-all-proofs.sh, not the lint suite
        if fn.endswith(".py") or fn.endswith(".sh"):
            out.append(os.path.join(_ROOT, rel))
    return out


def check_id(path):
    return os.path.basename(path).rsplit(".", 1)[0]


def run_check(path, root, timeout=300, extra_env=None):
    cmd = [sys.executable, path, root] if path.endswith(".py") else ["bash", path, root]
    env = os.environ.copy()
    # Every check's `from lib import ...` needs lint/ on sys.path. Setting it here — the
    # ONE place a check's own process is launched — is why no check's source carries the
    # sys.path.insert dance itself; lint/checks/_bootstrap.py covers the standalone
    # `python3 lint/checks/NN.py` invocation this runner does not own.
    existing = env.get("PYTHONPATH", "")
    env["PYTHONPATH"] = _HERE + (os.pathsep + existing if existing else "")
    if extra_env:
        env.update(extra_env)
    t0 = time.time()
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, env=env)
        return proc.returncode, proc.stdout, proc.stderr, time.time() - t0
    except subprocess.TimeoutExpired:
        return 3, "", f"timeout after {timeout}s", time.time() - t0


# A check discloses a verdict on stderr (SKIP / WARN / NOT-GATED). The runner must surface
# those lines: dropping them made a degraded run — e.g. an adopter-local-input check
# (22/25/27/35) SKIPping on a checkout without that input — read as a clean one, the
# disclosure the check promises never reaching the report.
_DISCLOSURE_TOKENS = ("FAIL", "SKIP", "WARN", "NOTICE", "NOT-GATED", "NOT-CHECKED")


def _disclosure(line):
    return any(tok in line for tok in _DISCLOSURE_TOKENS)


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


# Fixed, repo-relative adopter-local paths some checks read directly by name
# (never through a lib.scope set, since those sets are the WALK and these are
# gitignored). Each is included only if it exists in the real root.
_ADOPTER_LOCAL_FIXED = (
    ".beads/issues.jsonl",       # 35-board-integrity's board
    "lint/instance-tokens.local.txt",  # 27-instance-tokens' banned-word list
    "_archive",                  # 25-archived-names' retired-skill population
    "machine.json",              # engine/machine.sh's one input (18, 07, 12, 14, 38)
)


def _adopter_local_paths(root):
    """Repo-relative paths of gitignored inputs some checks read at commit time.

    `git checkout-index` (materialize_staged) writes only the STAGED index —
    exactly what a clone would receive — so a gitignored adopter-local
    artifact (this deployment's friction ledger, its live bead board, its
    retired-skill archive, its instance-token list, its machine facts) is
    invisible to the staged snapshot. Checks 22/25/27/35 read one or more of
    these and would report an honest `skip` at every commit, never `ok`, on a
    machine that actually HAS the input — the fix is to link the input in,
    not to special-case the check.

    Derived from what the checks read: the fixed list above, plus every
    FRICTIONS.md/MAINTENANCE.md under skills/ (lib.scope.LEDGER_NAMES) that
    THIS checkout's git does not already track — a tracked one is written by
    checkout-index itself and must never be double-linked over.
    """
    candidates = set()
    for fixed in _ADOPTER_LOCAL_FIXED:
        if os.path.exists(os.path.join(root, fixed)):
            candidates.add(fixed)
    skills_dir = os.path.join(root, "skills")
    for dirpath, dirnames, filenames in os.walk(skills_dir):
        dirnames[:] = [d for d in dirnames if d not in scope.SKIP_DIRS]
        for fn in filenames:
            if fn in scope.LEDGER_NAMES:
                rel = os.path.relpath(os.path.join(dirpath, fn), root)
                candidates.add(rel.replace(os.sep, "/"))
    if not candidates:
        return []
    try:
        proc = subprocess.run(
            ["git", "--no-optional-locks", "-C", root, "ls-files", "-z", "--"] + sorted(candidates),
            capture_output=True, text=True, timeout=30, check=False,
        )
        tracked = set(p for p in proc.stdout.split("\0") if p) if proc.returncode == 0 else set()
    except (OSError, subprocess.SubprocessError):
        tracked = set()
    return sorted(p for p in candidates if p not in tracked)


def _link_adopter_local(real_root, snapshot_dir):
    """Symlink each adopter-local input from the real root into the snapshot, read-only."""
    for rel in _adopter_local_paths(real_root):
        src = os.path.join(real_root, rel)
        dst = os.path.join(snapshot_dir, rel)
        if os.path.lexists(dst):
            continue  # checkout-index already wrote something real here — never overlay it
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        try:
            os.symlink(src, dst)
        except OSError:
            pass  # best-effort: a check that needs it reports its own honest skip


def materialize_staged(root):
    """Snapshot the INDEX — what a commit will actually contain — into a fresh temp dir.

    `git checkout-index` writes only what is IN the index; an unstaged edit or an
    untracked scratch file elsewhere in the shared checkout is never written here,
    so a sibling writer's dirty file cannot leak into this committer's lint run.
    Adopter-local (gitignored) inputs are then linked in read-only — see
    `_link_adopter_local` — so a check that reads one sees what this machine
    actually has, not an artifact of the snapshot's tracked-only contents.
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
    _link_adopter_local(root, tmp)
    return tmp, git_dir


def main():
    import argparse

    ap = argparse.ArgumentParser(description="lint v2 runner — one table over lint/checks/*")
    ap.add_argument("--check", action="append", default=[], metavar="ID",
                    help="run only this check (filename NN prefix or full stem); repeatable")
    ap.add_argument("--staged", action="store_true",
                    help="run the whole suite against the staged index (what a commit "
                         "would contain), not the working tree on disk")
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

    # The staged lane judges what a commit will CONTAIN, not the working tree on disk:
    # every SELECTED check (still the whole suite — there is no scope-to-diff selection)
    # runs against a fresh snapshot of the INDEX so a sibling writer's dirty, half-finished
    # file in the same shared checkout can never fail this commit's lint (measured:
    # FRICTIONS.md:711). Checks that shell to git (14, 25, 29, 31 today) still need a real
    # .git — GIT_DIR/GIT_WORK_TREE redirect any git call THEY make at the real history
    # while "the working tree" is the snapshot, so `git diff <base>` (no --cached) already
    # compares base against staged content with no per-check special-casing.
    run_root = args.root
    extra_env = None
    staged_worktree = None
    if args.staged:
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
            # The checks themselves come from the snapshot too: an unstaged or untracked
            # check in the working tree is not part of this commit and never judges it.
            staged_checks = [os.path.join(staged_worktree, os.path.relpath(c, _ROOT)) for c in selected]
            selected = [c for c in staged_checks if os.path.isfile(c)]
        else:
            print("NOTICE: staged-lane materialisation failed — running against "
                  "the real checkout instead (an unrelated dirty file could affect this run)",
                  file=sys.stderr)

    try:
        results = []
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as ex:
            futs = {ex.submit(run_check, c, run_root, 300, extra_env): c for c in selected}
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

    results.sort(key=lambda r: r["id"])

    for r in results:
        if r["exit"] == 0:
            r["result"] = "ok"
        elif r["exit"] == 2:
            r["result"] = "not-gated"
        elif r["exit"] == 77:
            r["result"] = "skip"
        else:
            r["result"] = "fail"

    if args.as_json:
        print(json.dumps({"root": args.root, "checks": results}, indent=2))
    else:
        print(f"{'ID':<14} {'RESULT':<10} {'SEC':>6}  DETAIL")
        for r in results:
            detail = "; ".join(r["findings"][:1])
            print(f"{r['id']:<14} {r['result']:<10} {r['seconds']:>6.2f}  {detail}")
        for r in results:
            if r["result"] == "fail" and len(r["findings"]) > 1:
                for line in r["findings"][1:]:
                    print(f"    {line}")
        # A skip is not a pass: a check whose own adopter-local input was absent
        # gated nothing, and that must be visible in the same breath as the table,
        # never buried in a per-row DETAIL column only a careful reader checks.
        gated_skips = [r["id"] for r in results if r["result"] == "skip"]
        if gated_skips:
            print(f"NOT-FULLY-GATED: {len(gated_skips)} ({', '.join(gated_skips)})")

    # A 1 (real findings) outranks a bare 2 (NOT-GATED) — a check that both found
    # something AND another check scanned nothing must still report as a failure,
    # not a lesser NOT-GATED verdict. Skips (77) never appear here: they cannot
    # fail the run alone, per the 2026-09-20 adopter-local-input ruling.
    exits = [r["exit"] for r in results]
    if 1 in exits:
        return 1
    if 2 in exits:
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
