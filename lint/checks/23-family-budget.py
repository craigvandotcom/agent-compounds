#!/usr/bin/env python3
# ---
# id: 23-family-budget
# prevents: the lean-family files growing without a number anyone defends — every previous "keep it
#   small" rule was prose, and every one of them lost; the cap is counted over the LOADED PATH with
#   the mandatory-load set DERIVED from the pointers, not a hardcoded list (the measured evasion with
#   an extra step)
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/23-family-budget
# ---
"""23-family-budget — the lean-family + loaded-path anti-drift assertion.

The legacy lint.sh Check 23 block delegated to ONE judge and this port keeps
that judge unchanged, so the verdict cannot drift:

    scripts/ac-budget-check.sh <root>

Past the judge's green, the per-package leg reads the package budgets through
the manifest (skills/packages.json via lint/lib/manifest.py): every package's
live-measured spine and loaded lines must fit its manifest budget.

The judge's legs: family <=800 SKILL.md lines across the six lean workflow
skills + the constitution; spine / worst-path / total numbers DERIVED from
each SKILL.md's pointers and mode tables (a pointer that resolves to nothing
FAILS; a reference file nothing points at FAILS; workflows with no mode
table are NOT-GATED — fat cannot hide either way); pointed-at canon reported,
never capped; and assurance declarations for family scripts (Check 21 is
hooks.json-scoped and cannot see them). It fails CLOSED: a discovery set
that resolves to nothing exits non-zero — a cap that measured no files is
not a cap that held.

Exit: 0 judge green, 1 judge reported findings (passed through verbatim —
the judge's own NOT-GATED lines are failures, never passes), 2 judge missing
from the audited root — NOT-GATED, never a pass.
"""

import os
import subprocess
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import manifest, scope  # noqa: E402  (per-package budgets read through the manifest)

CHECK_ID = "23-family-budget"
JUDGE = "scripts/ac-budget-check.sh"


def count_lines(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        return sum(1 for _ in fh)


def package_budgets(root):
    """The per-package budgets THROUGH the manifest (ac-6asz.3): every package's
    live-measured spine (member SKILL.md lines, the always-loaded surface) and
    loaded (all Markdown under member dirs) must fit its manifest budget —
    the same measure the manifest's `_measured` block records, recomputed from
    the files on every run, never reread from memory. A root without the
    manifest predates it (synthetic fixture trees): NOTICE and stand aside,
    the judge's verdict stands — the real tree always carries it, so the leg
    always runs there."""
    try:
        pkgs = manifest.packages(root)
    except manifest.ManifestMissing as exc:
        print(f"  NOTICE {CHECK_ID}: {exc} — per-package budget leg skipped, judge verdict stands")
        return 0
    failures = 0
    for name, pkg in sorted(pkgs.items()):
        if name.startswith("_") or not isinstance(pkg, dict):
            continue
        members = pkg.get("skills", [])
        budget = pkg.get("budget", {})
        if not isinstance(budget, dict) or "spine" not in budget or "loaded" not in budget:
            print(f"FAIL {CHECK_ID}: package '{name}' carries no spine/loaded budget — "
                  "a package without a budget is unbudgeted growth")
            failures += 1
            continue
        spine = 0
        loaded = 0
        for skill in members:
            smd = os.path.join(root, "skills", skill, "SKILL.md")
            if os.path.isfile(smd):
                spine += count_lines(smd)
            sdir = os.path.join(root, "skills", skill)
            for dirpath, _dirnames, filenames in os.walk(sdir):
                for fn in filenames:
                    if fn.endswith(".md"):
                        loaded += count_lines(os.path.join(dirpath, fn))
        legs = []
        if spine > budget["spine"]:
            legs.append(f"spine {spine} > {budget['spine']}")
        if loaded > budget["loaded"]:
            legs.append(f"loaded {loaded} > {budget['loaded']}")
        if legs:
            print(f"FAIL {CHECK_ID}: package '{name}' over budget — {', '.join(legs)} "
                  f"({len(members)} member(s)) — diet the package or raise the budget deliberately")
            failures += 1
        else:
            print(f"  PASS {name:<22} spine {spine:>6}/{budget['spine']:<6} "
                  f"loaded {loaded:>6}/{budget['loaded']:<6}")
    return 1 if failures else 0


def main():
    import argparse

    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("root", nargs="?", default=None,
                    help="repo root to lint (default: this checkout)")
    args = ap.parse_args()
    root = args.root or scope.ROOT
    script = os.path.join(root, JUDGE)
    if not os.path.isfile(script):
        print(f"{CHECK_ID} NOT-CHECKED: {JUDGE} not found in {root} — family caps NOT-GATED", file=sys.stderr)
        return 2
    proc = subprocess.run(["bash", script, root], capture_output=True, text=True)
    out = (proc.stdout + proc.stderr).strip()
    if proc.returncode == 0:
        if package_budgets(root) != 0:
            print(f"FAIL {CHECK_ID}: per-package budget violation(s) — see above")
            return 1
        for line in out.splitlines():
            print("  " + line)
        print(f"  ok: {CHECK_ID} — the family budget and anti-drift legs hold")
        return 0
    if proc.returncode == 2:
        print(f"{CHECK_ID} NOT-GATED: the judge verified nothing — {out}", file=sys.stderr)
        return 2
    for line in out.splitlines():
        print(line)
    print(f"FAIL {CHECK_ID}: family budget/anti-drift violation(s) — see above")
    return 1


if __name__ == "__main__":
    sys.exit(main())
