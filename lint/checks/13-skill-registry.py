#!/usr/bin/env python3
# ---
# id: 13-skill-registry
# prevents: the always-loaded skill-listing budget being breached, a description over the per-skill 1024-char cap, and a skill flagged disable-model-invocation being invoked from another skill's body — the invocation graph recomputed from the files on every run, never from memory
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/13-skill-registry
# ---
"""13-skill-registry — description budget + invocation-graph rule.

The legacy lint.sh Check 13 block delegated to ONE judge and this port keeps
that judge unchanged, so the verdict cannot drift:

    skills/skill-builder/scripts/validate-skill.sh --registry <root>/skills

The judge validates the registry against the deployed budget
(skillListingBudgetFraction), the per-skill 1024-char description cap, and
the invocation-graph rule (a disable-model-invocation skill invoked from
another skill's body is a hard FAIL). The budget leg gets its OWN failure
line (the registry-description-budget: BREACH marker) because a budget
breach, an over-cap description and a graph violation fail the judge alike,
and one generic line would land a newly-introduced breach silently behind
the other two.

Exit: 0 judge green, 1 judge reported findings (the dedicated budget line
first when the BREACH marker is present, then the generic line), 2 judge
missing from the audited root or the judge verified nothing — NOT-GATED,
never a pass.
"""

import os
import subprocess
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import scope  # noqa: E402

CHECK_ID = "13-skill-registry"
JUDGE = "skills/skill-builder/scripts/validate-skill.sh"


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    script = os.path.join(root, JUDGE)
    skills = os.path.join(root, "skills")
    if not os.path.isfile(script):
        print(f"{CHECK_ID} NOT-CHECKED: {JUDGE} not found in {root} — the skill registry is unverified", file=sys.stderr)
        return 2
    if not os.path.isdir(skills):
        print(f"{CHECK_ID} NOT-CHECKED: no skills/ directory under {root} — the registry is unverified", file=sys.stderr)
        return 2
    proc = subprocess.run(["bash", script, "--registry", skills], capture_output=True, text=True)
    if proc.returncode == 0:
        print(f"  ok: {CHECK_ID} — the skill registry is inside its budget, every description is under the cap, and the invocation graph holds")
        return 0
    if proc.returncode == 2:
        print(f"{CHECK_ID} NOT-GATED: the judge verified nothing — {(proc.stdout + proc.stderr).strip()}", file=sys.stderr)
        return 2
    # Legacy parked the judge's full output in a temp file and named the path —
    # mirror that: only the dedicated budget line and the generic line print,
    # so the violation set stays the legacy block's violation set.
    detail = "/tmp/ac-lint-registry.out"
    with open(detail, "w", encoding="utf-8") as fh:
        fh.write(proc.stdout + proc.stderr)
    breach = next((l for l in proc.stdout.splitlines() if l.startswith("registry-description-budget: BREACH")), "")
    if breach:
        print(f"FAIL {CHECK_ID} budget: {breach} — the always-loaded skill-listing budget is over. Diet descriptions or archive absorbed skills; raising skillListingBudgetFraction is a deliberate, separate decision.")
    print(f"FAIL {CHECK_ID}: skill-registry validation (budget / >1024 desc / invocation-graph) — details: {detail}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
