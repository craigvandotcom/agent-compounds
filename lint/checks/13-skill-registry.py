#!/usr/bin/env python3
# ---
# id: 13-skill-registry
# prevents: the always-loaded skill-listing budget being breached, a description over the per-skill
#   1024-char cap, and a skill flagged disable-model-invocation being invoked from another skill's
#   body — the invocation graph recomputed from the files on every run, never from memory
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/13-skill-registry
# ---
"""13-skill-registry — description budget + invocation-graph rule.

Delegates to ONE judge:

    skills/skill-builder/scripts/validate-skill.sh --registry <root>/skills --fast

`--fast` skips the judge's two ADVISORY scans (cross-skill exact-duplicate
lines, near-duplicate 5-word shingle pairs) — they are promotion-candidate
hints for a human hygiene pass, not a gate, and lint discarded their output
on green anyway; skipping them is most of the judge's own runtime. The
budget/1024-cap/invocation-graph legs still run in full.

The budget leg gets its OWN failure line (the registry-description-budget:
BREACH marker) because a budget breach, an over-cap description and a graph
violation fail the judge alike, and one generic line would land a
newly-introduced breach silently behind the other two.

Past the judge's green, the manifest leg reads the registry through the
manifest (skills/packages.json via lint/lib/manifest.py): every package
member must resolve to a dir carrying SKILL.md — the same dead-name refusal
the README generator enforces, so the deploy units cannot name a skill that
is not there.

Exit: 0 judge green, 1 judge reported findings (the dedicated budget line
first when the BREACH marker is present, then the generic line), 2 judge
missing from the audited root or the judge verified nothing — NOT-GATED,
never a pass. The judge itself only ever exits 0 or 1.
"""

import os
import subprocess
import sys

import _bootstrap  # noqa: F401
from lib import manifest, scope  # noqa: E402  (registry read through the manifest)

CHECK_ID = "13-skill-registry"
JUDGE = "skills/skill-builder/scripts/validate-skill.sh"


def manifest_leg(root):
    """The registry THROUGH the manifest: every package member must
    name a dir carrying SKILL.md — the same dead-name refusal the README
    generator enforces, so the package set deploy.sh installs from cannot name
    a skill that is not there. A root without the manifest predates it
    (synthetic fixture trees): NOTICE and stand aside, the judge's verdict
    stands — the real tree always carries it, so the leg always runs there."""
    try:
        pkgs = manifest.packages(root)
    except manifest.ManifestMissing as exc:
        print(f"  NOTICE {CHECK_ID}: {exc} — manifest leg skipped, judge verdict stands")
        return 0
    dead = []
    members = 0
    for name, pkg in sorted(pkgs.items()):
        if name.startswith("_") or not isinstance(pkg, dict):
            continue
        for skill in pkg.get("skills", []):
            members += 1
            if not os.path.isfile(os.path.join(root, "skills", skill, "SKILL.md")):
                dead.append(f"package '{name}' names '{skill}' with no skills/{skill}/SKILL.md")
    if dead:
        for d in dead:
            print(f"FAIL {CHECK_ID}: manifest names a dead skill — {d}")
        return 1
    print(f"  ok: {CHECK_ID} — manifest packages resolve ({members} member(s) across "
          f"{sum(1 for n, p in pkgs.items() if not n.startswith('_') and isinstance(p, dict))} package(s))")
    return 0


def main():
    import argparse

    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("root", nargs="?", default=None,
                    help="repo root to lint (default: this checkout)")
    args = ap.parse_args()
    root = args.root or scope.ROOT
    script = os.path.join(root, JUDGE)
    skills = os.path.join(root, "skills")
    if not os.path.isfile(script):
        print(f"{CHECK_ID} NOT-CHECKED: {JUDGE} not found in {root} — the skill registry is "
              "unverified", file=sys.stderr)
        return 2
    if not os.path.isdir(skills):
        print(f"{CHECK_ID} NOT-CHECKED: no skills/ directory under {root} — the registry is "
              "unverified", file=sys.stderr)
        return 2
    proc = subprocess.run(["bash", script, "--registry", skills, "--fast"], capture_output=True, text=True)
    if proc.returncode == 0:
        if manifest_leg(root) != 0:
            return 1
        print(f"  ok: {CHECK_ID} — the skill registry is inside its budget, every description is "
              "under the cap, and the invocation graph holds")
        return 0
    # The judge only ever exits 0 or 1: findings print directly (the dedicated
    # budget line first when the BREACH marker is present, then the full
    # judge output) — nothing is parked in a temp file for a caller to chase.
    breach = next((line for line in proc.stdout.splitlines()
                   if line.startswith("registry-description-budget: BREACH")), "")
    if breach:
        print(f"FAIL {CHECK_ID} budget: {breach} — the always-loaded skill-listing budget is over. "
              "Diet descriptions or archive absorbed skills; raising skillListingBudgetFraction is a "
              "deliberate, separate decision.")
    print(f"FAIL {CHECK_ID}: skill-registry validation (budget / >1024 desc / invocation-graph):")
    for line in (proc.stdout + proc.stderr).splitlines():
        print(f"  | {line}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
