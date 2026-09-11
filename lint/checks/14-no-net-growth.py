#!/usr/bin/env python3
# ---
# id: 14-no-net-growth
# prevents: a SKILL.md spine growing unstamped — the per-file ratchet (each SKILL.md holds or shrinks
#   vs a base ref) is the primary shrink mechanism, and per-file scoping closes the corpus-sum
#   loophole where one file's shrink pays for another's growth
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/14-no-net-growth
# ---
"""14-no-net-growth — the ported Check 14 judge (ac-1p7j.2).

Ported VERBATIM from the legacy bash block (proven by lint/parity.sh against the
extracted legacy functions, before the block was removed from lint.sh). Same
shape, same verdict strings, same degrades:

  leg 1  this registry: every skills/*/SKILL.md's net line delta vs a base ref
         must be <= 0. Under trunk-direct the merge base collapses onto HEAD, so
         the base falls back to HEAD^ (one commit back — the unit of review).
         Base unresolvable (shallow/standalone checkout) -> NOTICE + green: a
         false-green is safer than a broken CI leg, and Check 15's ceilings
         still bound absolute size.
  leg 2  every deploy target's own REAL local .claude/skills/*/SKILL.md (a
         symlinked dir is invisible to a git pathspec — exactly the blind spot
         this leg exists to cover). Untracked local skills are named, never
         read as checked.

The ONE structural exception: a NEW lean-family SKILL.md answers to the family
TOTAL (lint/config.json lean_family_cap) instead of its own per-file delta —
a deferral to the cap, never an amnesty. Creation is told apart from a
pure-addition edit by --diff-filter=A (both print `N 0` on numstat). Growth of
an existing member never defers. There is NO prose token: ec5fa64 removed
`net-growth-ok`, and this port keeps it removed.

Modes:
  <root>                    full run: leg 1 + leg 2 over the registry
  --scan <repo> <label> <base> <spec>   the raw judge over one repo (parity + harness)
  --base-of <repo>          print the default-branch merge base (nng_base_of)
  --leg1-base <root>        print leg 1's base (nng_leg1_base)
Exit: 0 clean, 1 violations, 2 population empty (no tree, no consumers).
"""

import json
import os
import re
import subprocess
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import scope  # noqa: E402

violations = []
notices = []


def git(repo, *args):
    proc = subprocess.run(
        ["git", "--no-optional-locks", "-C", repo, *args],
        capture_output=True, text=True, timeout=60,
    )
    return proc.stdout.strip()


def base_of(repo, base_ref):
    ref = git(repo, "symbolic-ref", "--quiet", "refs/remotes/origin/HEAD")
    if not ref:
        for cand in (base_ref, "origin/main", "origin/master"):
            if git(repo, "rev-parse", "--verify", "--quiet", cand):
                ref = cand
                break
    if not ref:
        return ""
    return git(repo, "merge-base", ref, "HEAD") or ""


def leg1_base(root, base_ref):
    b = ""
    if git(root, "rev-parse", "--verify", "--quiet", base_ref):
        b = git(root, "merge-base", base_ref, "HEAD") or ""
    if not b:
        b = base_of(root, base_ref)
    if not b:
        return ""
    head = git(root, "rev-parse", "HEAD")
    if head and b == head:
        b = git(root, "rev-parse", "--verify", "--quiet", "HEAD^") or b
    return b


def load_config(root):
    with open(os.path.join(root, "lint", "config.json"), encoding="utf-8") as fh:
        return json.load(fh)


def member_of(path, members):
    m = re.search(r"(?:^|/)skills/([^/]+)/SKILL\.md$", path)
    return m.group(1) if m and m.group(1) in members else None


def family_total(root, skills_dir, cfg):
    total = 0
    for name in cfg["lean_family"]:
        f = os.path.join(root, skills_dir, name, "SKILL.md")
        if not os.path.isfile(f):
            continue
        with open(f, encoding="utf-8", errors="replace") as fh:
            total += sum(1 for _ in fh)
    return total


def scan(repo, label, base, spec, cfg, staged=False):
    """The per-file judge. Returns True when anything under the spec was seen.

    `staged=True` (the pre-commit lane) judges the INDEX against HEAD
    (`git diff --cached`) instead of `base` against the working tree — a
    commit-scoped run must score what it will actually commit, not whatever
    else happens to be dirty in a shared checkout. `base` is still accepted
    (and printed) for message continuity; the diff itself ignores it.
    """
    diff_args = ("--cached", "HEAD") if staged else (base,)
    base_label = "the staged index vs HEAD" if staged else base
    added = set(line for line in git(repo, "diff", *diff_args, "--name-only", "--diff-filter=A",
                                     "--", spec).splitlines() if line.strip())
    numstat = git(repo, "diff", *diff_args, "--numstat", "--", spec)
    seen = False
    for line in numstat.splitlines():
        parts = line.split("\t")
        if len(parts) != 3:
            continue
        a, d, path = parts
        if a == "-":  # binary; SKILL.md never is
            continue
        seen = True
        net = int(a) - int(d)
        if net <= 0:
            print(f"no-net-growth: {label}/{path} net {net} line(s) vs {base_label} — PASS (neutral or shrinking)")
            continue
        member = member_of(path, cfg["creation_exception"])
        if member and path in added:
            skills_dir = path[: path.rfind("skills/") + len("skills")]
            fam = family_total(repo, skills_dir, cfg)
            if fam <= cfg["lean_family_cap"]:
                print(f"no-net-growth: {label}/{path} is a NEW lean-family SKILL.md — per-file ratchet "
                      f"deferred to the family cap (family total {fam} <= {cfg['lean_family_cap']}) — "
                      "PASS (ac-creation)")
                continue
            violations.append(f"{label}/{path} (ac-family-cap: family total {fam} > {cfg['lean_family_cap']})")
            continue
        violations.append(f"{label}/{path} (+{net})")
    if not seen:
        print(f"no-net-growth: {label} — no changes under '{spec}' vs {base_label} — PASS (nothing to check)")
    return seen


def consumer_dirs(root):
    """The union Check 7 builds: org dirs ∪ ac-deploy-targets.list ∪ vitest-affected."""
    home = os.path.expanduser("~")
    dirs = [
        os.path.join(home, "Repos/.claude"),
        os.path.join(home, "Repos/neometa/content/.claude"),
        os.path.join(home, "Repos/neometa/books/.claude"),
        os.path.join(home, "Repos/neometa/software/.claude"),
    ]
    lst = os.path.join(root, "..", "..", "infrastructure", "ac-deploy-targets.list")
    if not os.path.isfile(lst):
        # AC_ROOT/../../../infrastructure — resolve the same way lint.sh does
        lst = os.path.normpath(os.path.join(root, "..", "..", "..", "infrastructure", "ac-deploy-targets.list"))
    if os.path.isfile(lst):
        with open(lst, encoding="utf-8") as fh:
            for line in fh:
                line = line.split("#", 1)[0].strip()
                if line:
                    dirs.append(os.path.join(home, "Repos", "neometa", "software", line, ".claude"))
    dirs.append(os.path.join(home, "Repos/neometa/software/vitest-affected/.claude"))
    seen, out = set(), []
    for d in dirs:
        if d not in seen:
            seen.add(d)
            out.append(d)
    return out


def run_full(root, cfg):
    # The pre-commit staged lane (run.py --changed --staged) sets LINT_STAGED=1 and
    # redirects GIT_DIR/GIT_WORK_TREE at the real repo around a staged-content
    # snapshot (lint/run.py's materialize_staged). Leg 1 then judges the INDEX
    # against HEAD directly — the ratchet must score what THIS commit contains, not
    # a merge-base diff that also picks up a sibling writer's unrelated dirty file
    # in the shared checkout. Leg 2 shells to OTHER repos entirely (`git -C <that
    # repo>`); the redirected GIT_DIR/GIT_WORK_TREE would misdirect those calls, and
    # those repos' local state is not this commit's to fix anyway, so leg 2 sits out
    # the staged lane and still runs in full/CI (`bash lint.sh`, no --staged).
    if os.environ.get("LINT_STAGED") == "1":
        scan(root, "agent-compounds", "HEAD", "skills/*/SKILL.md", cfg, staged=True)
        notices.append("Check 14 leg 2 (other repos' local .claude/skills) sits out the staged "
                       "pre-commit lane — it audits state this commit cannot change; it still runs "
                       "in the full/CI lane.")
        for n in notices:
            print(f"NOTICE: {n}")
        if violations:
            print("FAIL 14-no-net-growth: net-positive SKILL.md file(s): " + ", ".join(violations)
                  + " — core is loaded every invocation, so it holds or shrinks. Move the content to "
                    "references/, or delete an equivalent amount from THIS file.")
            return 1
        return 0

    base = leg1_base(root, cfg["base_ref"])
    head = git(root, "rev-parse", "HEAD")
    if not base:
        notices.append(f"Check 14 leg 1 skipped — base ref '{cfg['base_ref']}' unresolvable (shallow "
                       "checkout, standalone clone, or no fetch of it) — no-net-growth not enforced "
                       "for the registry this run.")
    elif base == head:
        print(f"FAIL 14-no-net-growth: leg 1 base collapsed onto HEAD ({head[:12]}) — the ratchet "
              "would compare HEAD against itself; check checkout depth (HEAD^ must resolve)")
        return 1
    else:
        scan(root, "agent-compounds", base, "skills/*/SKILL.md", cfg)
    for d in consumer_dirs(root):
        skills = os.path.join(d, "skills")
        if not os.path.isdir(skills):
            continue
        local = []
        for name in sorted(os.listdir(skills)):
            p = os.path.join(skills, name, "SKILL.md")
            if os.path.isfile(p) and not os.path.islink(p):
                local.append(p)
        if not local:
            continue
        repo = git(d, "rev-parse", "--show-toplevel")
        if not repo or os.path.normpath(repo) == os.path.normpath(root):
            continue
        label = os.path.basename(repo)
        rel = os.path.relpath(d, repo)
        b = base_of(repo, cfg["base_ref"])
        if not b:
            notices.append(f"Check 14 leg 2 skipped for {label} — no resolvable default-branch ref — "
                           "its local SKILL.md files are NOT net-growth checked this run.")
            continue
        scan(repo, label, b, os.path.join(rel, "skills", "*", "SKILL.md"), cfg)
        for f in local:
            rf = os.path.relpath(f, repo)
            if subprocess.run(["git", "--no-optional-locks", "-C", repo, "ls-files", "--error-unmatch", "--", rf],
                              capture_output=True).returncode != 0:
                with open(f, encoding="utf-8", errors="replace") as fh:
                    n = sum(1 for _ in fh)
                notices.append(f"no-net-growth: {label}/{rf} is UNTRACKED/gitignored ({n} lines) — "
                               "real local skill, not diff-checkable there.")
    for n in notices:
        print(f"NOTICE: {n}")
    if violations:
        print("FAIL 14-no-net-growth: net-positive SKILL.md file(s): " + ", ".join(violations)
              + " — core is loaded every invocation, so it holds or shrinks. Move the content to "
                "references/, or delete an equivalent amount from THIS file. A written justification "
                "is not a payment, and a shrink in another file does NOT offset it. (An "
                "'ac-family-cap' entry is a CREATION over the family total — diet the family, do not "
                "raise the cap.)")
        return 1
    return 0


def main():
    args = sys.argv[1:]
    cfg_root = scope.ROOT
    if args and args[0] == "--scan":
        repo, label, base, spec = args[1], args[2], args[3], args[4]
        cfg = load_config(cfg_root)
        scan(repo, label, base, spec, cfg)
        if violations:
            print("FAIL 14-no-net-growth: net-positive SKILL.md file(s): " + ", ".join(violations))
            return 1
        return 0
    if args and args[0] == "--base-of":
        cfg = load_config(cfg_root)
        print(base_of(args[1], cfg["base_ref"]))
        return 0
    if args and args[0] == "--leg1-base":
        cfg = load_config(cfg_root)
        print(leg1_base(args[1], cfg["base_ref"]))
        return 0
    root = args[0] if args else scope.ROOT
    if os.path.abspath(root) != scope.ROOT:
        os.environ["LINT_ROOT"] = os.path.abspath(root)
        import importlib
        importlib.reload(scope)
        cfg_root = scope.ROOT
    cfg = load_config(cfg_root)
    rc = run_full(root, cfg)
    if rc == 0 and not notices and not os.path.isdir(os.path.join(root, "skills")):
        return 2
    return rc


if __name__ == "__main__":
    sys.exit(main())
