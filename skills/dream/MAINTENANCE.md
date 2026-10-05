---
skill: dream
archetype: orchestrator
last_pass: 2026-10-05
---

# dream — maintenance ledger

## Health

Dream is a human-run session only: ac-human's 🧰/🧠 card offers `/dream`, approved items are
fixed in-session with the operator reviewing the diff, no beads. The old automated apply
path (daily queue job, auto-act tiers, bead filing) is gone — see Holding pen.

## Holding pen

Content removed from the skill, aged here before git-delete. Resolve or delete by the
review-by date; the default resolution applies if nobody acts.

### `workflows/dream-daily.md` (111 lines)

- **Removed:** 2026-10-05.
- **Why:** described the 02:00 unattended apply engine (auto-tier apply, Slack approval
  cards, bead filing) — no cron invokes dream anymore; the session is human-started only.
- **Recoverable from:** git history of `skills/dream/workflows/dream-daily.md`.
- **Review by:** 2026-12-05.
- **Default resolution:** git-delete stands.

### `references/auto-act-rubric.md` (126 lines)

- **Removed:** 2026-10-05.
- **Why:** defined the Tier-0/Tier-1 deterministic-autonomy split that let the daily queue
  job apply proposals without a human gate. That queue job no longer exists; every ruling
  now happens in-session with the operator.
- **Recoverable from:** git history of `skills/dream/references/auto-act-rubric.md`.
- **Review by:** 2026-12-05.
- **Default resolution:** git-delete stands.

## Cut-log

- [2026-10-05] Removed the automated-cycle apparatus (dream-daily.md, auto-act-rubric.md)
  and the SKILL.md "polish gate" + `weekly.json` disabled-jobs language — dream is now a
  human session only. `references/lint-checks.md` and `scripts/memory-rollup.py` stay —
  both are live inputs to the session.
