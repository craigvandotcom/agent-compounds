#!/usr/bin/env python3
# ---
# id: 10-d-series-conformance
# prevents: a D-series doctrine landing silently regressing — a canon file losing its load-bearing
#   marker (write-back section, sole-owner statement, defer language), a stale wave-branch pattern
#   surviving, or the tier-age-ordering note going missing
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/10-d-series-conformance
# ---
"""10-d-series-conformance — the ported Check 10 (ac-1p7j.15).

Ported VERBATIM from the legacy bash block (proven by lint/parity.sh against
the extracted block, before the block was removed from lint.sh). Same rows,
same verdict strings. The retired rows keep their retirement records — a:
retires with its subject; the git history preserves the full prose.

  D5   ac-plan-lab (merged genius+alien plan skill, 2026-07-20) carries the
       write-back section (Write Back header, or the genius_reviewed /
       transcended frontmatter flags).
  D8.1 version-bump.md (moved to the surviving ac-publish, which absorbed
       ac-merge) keeps the sole-owner statement.
  D8.2 ac-distribute survives the cutover and keeps defer-to-owner language.
  D9b  zero startswith("wave/") in ac-loop/SKILL.md (the allocator script is
       deleted; this is the surviving check for stale wave/ assumptions).
  D10  ac-human Phase 4 Three Tiers render documents tier-first, then
       oldest-within-tier ordering. The ERE is deliberately discriminating —
       bare "oldest|age|created_at" substring-matches tri-AGE/st-AGE-d.

Retired, never re-pointed (a: retires with its subject; re-pointing would
manufacture a permanent red against a contract the lean pipeline never
adopted): D2/D3/D4/D6/D7 — their subjects (the conformance-status section,
ac-plan-init _backlog, the plan-status gate, the "pre-merge gate" claim, the
version-bump scan) are in the Phase-4 archive set or appear nowhere in the
successors. D9 retired with the allocator script it checked.

Exit: 0 clean, 1 violations, 2 no skills/ under root (NOT-GATED, never a pass).
"""

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import conformance  # noqa: E402

TABLE = [
    ("D5", "skills/ac-plan-lab/SKILL.md", "present",
     r"Write Back|genius_reviewed|transcended",
     "skills/ac-plan-lab/SKILL.md missing write-back section "
     "(Write Back / genius_reviewed / transcended)"),
    ("D8", "skills/ac-publish/references/version-bump.md", "present_i",
     r"sole.*owner",
     "skills/ac-publish/references/version-bump.md missing the sole-owner statement"),
    ("D8", "skills/ac-distribute/SKILL.md", "present_i",
     r"defer",
     "skills/ac-distribute/SKILL.md missing defer-to-version-bump-owner language"),
    ("D9b", "skills/ac-loop/SKILL.md", "absent",
     'startswith("wave/")',
     "skills/ac-loop/SKILL.md still contains stale 'startswith(\"wave/\")' pattern"),
    ("D10", "skills/ac-human/SKILL.md", "present",
     r"oldest-first|oldest-within|oldest-bead-first|P0.{0,3}P4 then oldest",
     "skills/ac-human/SKILL.md missing the tier-first/oldest-within-tier "
     "age-ordering note (Phase 4 render)"),
]


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(_LINT)
    return conformance.run(root, TABLE, "10-d-series-conformance")


if __name__ == "__main__":
    sys.exit(main())
