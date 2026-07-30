# Docket anti-rot — why the `events` read is a mandatory step

Pulled out of `SKILL.md` core 2026-07-30 as a doctrine **Extract** (still needed, just not every
run — `skill-builder/references/promotion-ladder.md` § What routes through the holding zone). The
spine carries the enforcement; this file carries the evidence behind it. Nothing here is a rule —
if you are looking for what to DO, go back to the spine's Decision Docket bullet.

## The incident that made it a step

`bd-06opv.12` ("DECISION: V5 zone-classification pipeline — ship, keep-V4, or kill?") was
**decided 2026-07-10** and deliberately released by Craig **three separate times**, each with
written reasoning. Its full `events` history:

| when | event |
|---|---|
| 2026-07-10 11:49 | `human-gate` added at creation |
| 2026-07-11 08:08:**25** | REMOVED — **one second** after Craig's "DECISION: VALIDATE-THEN-SHIP" comment |
| 2026-07-11 22:49 | re-added |
| 2026-07-12 09:19 | REMOVED — *"DOCKET RELEASE (Craig): decision already recorded 07-10"* |
| 2026-07-15 11:51 | re-added |
| 2026-07-15 14:58 | REMOVED — *"decision recorded + docket released … backfill over-gated"* |
| 2026-07-27 18:35 | re-added by `bd-r0be9`'s apply |
| 2026-07-27 18:**40** | REMOVED **four minutes later by that same session** — it caught itself |
| 2026-07-30 08:45 | re-added **in error** by an `ac-human-session` conductor |
| 2026-07-30 | reverted |

## Why the conductor got it wrong

It read **`bd-r0be9`'s comment**, which recorded the 18:35 re-add and **not** the 18:40 revert four
minutes later. A comment is written by an agent mid-action and can be incomplete or simply wrong;
the `events` table is append-only and was authoritative the entire time.

Compounding it: the error landed **minutes after that same conductor filed `bd-rc9kk`** — a bead
about exactly this detector defect — and **two existing memory rules both named `bd-06opv.12` by
id**:

- `completion-marker-absence-is-not-a-need-signal` (recurrence 2)
- `human-gate-beads-rot-verify-before-presenting` (recurrence 3)

Neither was injected on that turn; the recall hook surfaced an unrelated tmux fact. **Two written
rules lost to one unread audit trail.** That is why this check was escalated out of the memory
substrate and into a step in the spine (agent-compounds `a7ac7f2`) rather than restated a third
time — see `infrastructure/memory/auto/recurring-rule-escalates-to-a-gate-not-a-restatement.md`
and the parent doctrine at `context-engineering` § PROMOTION & DEMOTION.

## The generalisable shape

The re-gating is not a data-loss bug — nothing was ever lost. The cost is **churn**: four
gate/release cycles on one bead in 20 days, three of them consuming an explicit human
re-decision on a question already settled on day one. A docket that keeps re-presenting settled
work is what erodes trust in the docket as a whole.

Root cause of the *detector* half is tracked in `bd-rc9kk`: inferring "needs a human" from a
MISSING label cannot distinguish *never gated* from *gated, decided, released*, because the
release ritual **is** removing the label.
