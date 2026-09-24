#!/usr/bin/env python3
# ---
# id: 14-no-net-growth
# prevents: a SKILL.md spine growing unstamped, or a package's mandatory-load surface
#   growing unstamped even while every individual file holds — the per-file ratchet (each
#   SKILL.md holds or shrinks vs a base ref) closes the corpus-sum loophole where one
#   file's shrink pays for another's growth; the per-package budget closes the loophole
#   where references/ or workflows/ grows while no single file crosses a line
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/14-no-net-growth
# ---
"""14-no-net-growth — the registry's one size guard: a per-file ratchet plus a
per-package absolute budget.

  leg 1  every skills/*/SKILL.md's net line delta vs a base ref must be <= 0.
         The base honours `LINT_BASE_REF` (lib.ratchet.base_ref) — CI sets it
         to the pre-push/PR-base sha, so a multi-commit push is judged as a
         whole, never only its tip. Locally (LINT_BASE_REF unset), the base
         is the manifest's `base_ref` (origin/main); under trunk-direct the
         merge base collapses onto HEAD, so the base falls back to HEAD^ (one
         commit back — the unit of review). Base unresolvable (shallow/
         standalone checkout) -> NOTICE + green: a false-green is safer than
         a broken CI leg, and leg 2 still bounds absolute size.
  leg 2  every package's live-measured spine (member SKILL.md lines, the
         always-loaded surface) and loaded (all Markdown under member dirs)
         must fit its manifest budget (skills/packages.json's top-level
         package entries, keyed by name -> {skills: [...], budget: {spine,
         loaded}}). Bounds new-skill and references/ growth even when every
         file individually holds.

The ONE structural exception to leg 1: a NEW lean-family SKILL.md (a member
of the manifest's `lean_family` list) answers to the family TOTAL instead of
its own per-file delta — a deferral to the cap, never an amnesty. Creation is
told apart from a pure-addition edit by --diff-filter=A (both print `N 0` on
numstat). Growth of an existing member never defers, and a skill outside
`lean_family` never qualifies — it is bounded by the plain per-file ratchet
like any other skill. There is NO prose token: a written justification does
not pay for growth — only file content does.

Modes:
  <root>                    full run: leg 1 + leg 2 over the registry
Exit: 0 clean, 1 violations, 2 population empty (no tree, no skills/ dir).
"""

import os
import re
import subprocess
import sys

import _bootstrap  # noqa: F401
from lib import manifest, ratchet, scope  # noqa: E402

violations = []
notices = []


def git(repo, *args):
    proc = subprocess.run(
        ["git", "--no-optional-locks", "-C", repo, *args],
        capture_output=True, text=True, timeout=60,
    )
    return proc.stdout.strip()


def leg1_base(root, base_ref):
    """The commit leg 1 diffs against — lib.ratchet.base_ref (LINT_BASE_REF-aware),
    with the trunk-direct collapse silently recovered to HEAD^ (one commit back):
    the unit of review, not a FAIL. A base that is STILL HEAD after that recovery
    (single-commit history, no HEAD^ to fall back to) is left for run_full() to
    report — an unresolvable base is a checkout-depth defect, not a silent skip."""
    b = ratchet.base_ref(root, base_ref)
    if not b:
        return ""
    head = git(root, "rev-parse", "HEAD")
    if head and b == head:
        b = git(root, "rev-parse", "--verify", "--quiet", "HEAD^") or b
    return b


def load_config(root):
    """The check-14 lists (base_ref, lean_family, lean_family_cap), read from
    the manifest's `_lint` section through lint/lib/manifest.py — the manifest
    is the only source. Raises ManifestMissing naming the defect,
    which the caller reports as a FAIL (never a traceback)."""
    section = manifest.packages(root).get("_lint")
    if not isinstance(section, dict):
        raise manifest.ManifestMissing(
            f"manifest missing the '_lint' section: {os.path.join(root, 'skills', 'packages.json')}")
    for key in ("base_ref", "lean_family", "lean_family_cap"):
        if key not in section:
            raise manifest.ManifestMissing(
                f"manifest '_lint' section lacks '{key}': "
                f"{os.path.join(root, 'skills', 'packages.json')}")
    return section


def require_config(cfg_root):
    try:
        return load_config(cfg_root)
    except manifest.ManifestMissing as exc:
        print(f"FAIL 14-no-net-growth: {exc} — the manifest is the only source of these lists")
        sys.exit(1)


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
    """The per-file judge (leg 1). Returns True when anything under the spec was seen.

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
        member = member_of(path, cfg["lean_family"])
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


def check_package_budgets(root):
    """Leg 2 — every package's live-measured spine (member SKILL.md lines) and
    loaded (all Markdown under member dirs) must fit its manifest budget
    (skills/packages.json's top-level package entries). Ported from the
    retired Check 23's leg 7: the manifest is already required by leg 1's
    require_config, so a missing manifest cannot reach here. Returns a list
    of violation strings; prints a PASS line per conforming package as it goes.
    """
    pkgs = manifest.packages(root)
    failures = []
    for name, pkg in sorted(pkgs.items()):
        if name.startswith("_") or not isinstance(pkg, dict):
            continue
        members = pkg.get("skills", [])
        budget = pkg.get("budget", {})
        if not isinstance(budget, dict) or "spine" not in budget or "loaded" not in budget:
            failures.append(f"package '{name}' carries no spine/loaded budget — "
                             "a package without a budget is unbudgeted growth")
            continue
        spine = 0
        loaded = 0
        for skill in members:
            smd = os.path.join(root, "skills", skill, "SKILL.md")
            if os.path.isfile(smd):
                with open(smd, encoding="utf-8", errors="replace") as fh:
                    spine += sum(1 for _ in fh)
            sdir = os.path.join(root, "skills", skill)
            for dirpath, _dirnames, filenames in os.walk(sdir):
                for fn in filenames:
                    if fn.endswith(".md"):
                        with open(os.path.join(dirpath, fn), encoding="utf-8", errors="replace") as fh:
                            loaded += sum(1 for _ in fh)
        legs = []
        if spine > budget["spine"]:
            legs.append(f"spine {spine} > {budget['spine']}")
        if loaded > budget["loaded"]:
            legs.append(f"loaded {loaded} > {budget['loaded']}")
        if legs:
            failures.append(f"package '{name}' over budget — {', '.join(legs)} "
                             f"({len(members)} member(s)) — diet the package or raise the budget deliberately")
        else:
            print(f"  PASS  {name:<22} spine {spine:>6}/{budget['spine']:<6} "
                  f"loaded {loaded:>6}/{budget['loaded']:<6}")
    return failures


def run_full(root, cfg):
    pkg_violations = check_package_budgets(root)
    collapsed = False
    head = ""

    # The pre-commit staged lane (run.py --staged) sets LINT_STAGED=1 and
    # redirects GIT_DIR/GIT_WORK_TREE at the real repo around a staged-content
    # snapshot (lint/run.py's materialize_staged). Leg 1 then judges the INDEX
    # against HEAD directly — the ratchet must score what THIS commit contains, not
    # a merge-base diff that also picks up a sibling writer's unrelated dirty file
    # in the shared checkout. Leg 2 reads the working tree directly (no git diff at
    # all), so it runs unchanged in both lanes — the staged snapshot IS the tree it
    # reads.
    if os.environ.get("LINT_STAGED") == "1":
        scan(root, "agent-compounds", "HEAD", "skills/*/SKILL.md", cfg, staged=True)
    else:
        base = leg1_base(root, cfg["base_ref"])
        head = git(root, "rev-parse", "HEAD")
        if not base:
            notices.append(f"Check 14 leg 1 skipped — base ref '{cfg['base_ref']}' unresolvable (shallow "
                           "checkout, standalone clone, or no fetch of it) — no-net-growth not enforced "
                           "for the registry this run.")
        elif base == head:
            collapsed = True
        else:
            scan(root, "agent-compounds", base, "skills/*/SKILL.md", cfg)

    for n in notices:
        print(f"NOTICE: {n}")

    if collapsed:
        print(f"FAIL 14-no-net-growth: leg 1 base collapsed onto HEAD ({head[:12]}) — the ratchet "
              "would compare HEAD against itself; check checkout depth (HEAD^ must resolve)")
    if violations:
        print("FAIL 14-no-net-growth: net-positive SKILL.md file(s): " + ", ".join(violations)
              + " — core is loaded every invocation, so it holds or shrinks. Move the content to "
                "references/, or delete an equivalent amount from THIS file. A written justification "
                "is not a payment, and a shrink in another file does NOT offset it. (An "
                  "'ac-family-cap' entry is a CREATION over the family total — diet the family, do not "
                  "raise the cap.)")
    for v in pkg_violations:
        print(f"FAIL 14-no-net-growth: {v}")

    return 1 if (collapsed or violations or pkg_violations) else 0


def main():
    args = sys.argv[1:]
    cfg_root = scope.ROOT
    root = args[0] if args else scope.ROOT
    if os.path.abspath(root) != scope.ROOT:
        os.environ["LINT_ROOT"] = os.path.abspath(root)
        import importlib
        importlib.reload(scope)
        cfg_root = scope.ROOT
    cfg = require_config(cfg_root)
    rc = run_full(root, cfg)
    if rc == 0 and not notices and not os.path.isdir(os.path.join(root, "skills")):
        return 2
    return rc


if __name__ == "__main__":
    sys.exit(main())
