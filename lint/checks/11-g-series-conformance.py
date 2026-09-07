#!/usr/bin/env python3
# ---
# id: 11-g-series-conformance
# prevents: a G-series doctrine landing silently regressing — the cross-cadence schedule table, the backlog shape-check, the QA-freshness rule, or the skill-hotfix emit instruction going missing, or the retired UI Validation Suite block surviving
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/11-g-series-conformance
# ---
"""11-g-series-conformance — the ported Check 11 (ac-1p7j.15).

Ported VERBATIM from the legacy bash block (proven by lint/parity.sh against
the extracted block, before the block was removed from lint.sh). Same rows,
same verdict strings.

  G1   the cross-cadence schedule table lives in
       ac-pipeline/references/schedule.md (rehomed 2026-09-02 from the
       ac-pipeline SKILL.md the constitution overwrote).
  G2   ac-bead-capture carries the reverse shape-check (routing-to-backlog
       language).
  G4   ac-distribute carries the fast-forward-equivalent QA-freshness rule.
  G6   ac-land's inline Apply-Approved-Upgrades path EMITS a skill-hotfix:
       commit for the approved-upgrade case (conditional; routine compound
       stays chore:), so dream's Phase 5 dedupe can grep it.
  G7a  the retired "1c. UI Validation Suite" block stays gone from ac-land.

Retired, never re-pointed: G5 (the loop's read of ac-review's VERDICT before
ac-merge — the loop has no review step and ships trunk-direct; slot left
numbered to keep G6+ stable); G7b/G7c/G7d (their subjects are in the Phase-4
archive set; ac-implement carries no UI-validation deferral at all, and the
conformance-status section retired whole at the rename).

Exit: 0 clean, 1 violations, 2 no skills/ under root (NOT-GATED, never a pass).
"""

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import conformance  # noqa: E402

TABLE = [
    ("G1", "skills/ac-pipeline/references/schedule.md", "present",
     r"23:00|Cross-cadence",
     "skills/ac-pipeline/references/schedule.md missing the cross-cadence schedule table"),
    ("G2", "skills/ac-bead-capture/SKILL.md", "present_i",
     r"backlog",
     "skills/ac-bead-capture/SKILL.md missing the reverse shape-check routing-to-backlog language"),
    ("G4", "skills/ac-distribute/SKILL.md", "present",
     r"fast-forward-equivalent",
     "skills/ac-distribute/SKILL.md missing the fast-forward-equivalent QA-freshness rule"),
    ("G6", "skills/ac-land/SKILL.md", "present",
     r"skill-hotfix:",
     "skills/ac-land/SKILL.md missing the skill-hotfix: emit instruction for the approved-upgrade apply case"),
    ("G7a", "skills/ac-land/SKILL.md", "absent",
     "1c. UI Validation Suite",
     "skills/ac-land/SKILL.md still contains the retired '1c. UI Validation Suite' block"),
]


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(_LINT)
    return conformance.run(root, TABLE, "11-g-series-conformance")


if __name__ == "__main__":
    sys.exit(main())
