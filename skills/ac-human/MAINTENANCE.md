---
skill: ac-human
archetype: orchestrator
last_pass: 2026-09-22
---

# ac-human — maintenance ledger

## Health

The docket's mechanical layer now lives in `scripts/docket.sh` (proof: `scripts/docket.test.sh`);
the spine keeps only the judgment and the drive. References describe what the script computes,
never a second procedure for it.

## Holding pen

Content removed from the skill, aged here before git-delete. Resolve or delete by the
review-by date; the default resolution applies if nobody acts.

### `references/tiers-template.md` (33 lines)

- **Removed:** 2026-09-22.
- **Why:** `docket.sh` renders the header and the three tiers; a hand template beside it is a
  second source that drifts.
- **Recoverable from:** git history of `skills/ac-human/references/tiers-template.md`.
- **Review by:** 2026-12-22.
- **Default resolution:** git-delete stands.

### `references/session-scan.md` org-wide bash loop · `references/docket-lanes.md` § Why

- **Removed:** 2026-09-22.
- **Why:** the loop is now `docket.sh --org` (machine.sh fallback when `REPOS_ROOT`/`APPS_LIST`
  are unset); the lane incident narrative was provenance, and its app-specific sitting bead
  moved out of the registry with the declared-lane format.
- **Recoverable from:** git history of both files.
- **Review by:** 2026-12-22.
- **Default resolution:** git-delete stands.

### SKILL.md "Phase 2: Scan (parallel), then apply the loop boundary" · "Phase 3: Situational-awareness header" · "Phase 4: The three tiers (silver platter, exit-first)"

- **Removed:** 2026-09-22, merged into "Phase 2–4: What the script computes, what you judge".
- **Why:** collector, loop boundary, header line, lane counts, estimate and tier order are
  computed by `docket.sh`; the judgment half (verify, harm, apply/discard, `⚡` note) stays in
  the merged section.
- **Recoverable from:** git history of `skills/ac-human/SKILL.md`.
- **Review by:** 2026-12-22.
- **Default resolution:** git-delete stands.

## Cut-log

- [2026-09-22] docket.sh + docket.test.sh added; SKILL.md 114 → 92 lines; declared batch lanes
  (`<project>/.claude/docket-lanes.json`) replace the registry's app-specific lane text;
  🧰 frictions + 🧠 memory cards added to the action loop.
