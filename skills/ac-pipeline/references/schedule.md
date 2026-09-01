# Cross-cadence schedule — the single home for scheduling rules

Several stages run **headless, on a schedule**, independent of any single pipeline invocation.
Their cadences are cross-cutting (they interleave with every wave in flight), so this table is
the **single home** for "when does X run" — job configs and stage skills point here rather than
restating times in more than one place.

Recovered 2026-09-02: this section lived in the pre-merge `ac-pipeline/SKILL.md` and was lost
as collateral when the constitution overwrote that file at the `ac2-* → ac-*` rename. Rehomed
here as an owner-hosted operating contract, with two archived skill names updated.

| Job | Cadence | Mode | Skill |
|---|---|---|---|
| Curator | Daily ~23:00 | scheduled run (ingredient review/amend) | `curate` |
| Tidy | Nightly ~00:45 (after the 00:30 maintenance job) | NIGHTLY — propose + bounded auto-act | `ac-tidy` |
| Align | Weekly, Saturday ~06:00 | REVIEW — propose only, no writes | `ac-align` |
| Dream | Weekly, Sunday ~05:00 | CYCLE — propose only, no writes | `dream` |
| Triage | Must fire **≥30 min before** any `ac-implement` swarm | scheduled, feeds beads ahead of shipping | `ac-triage` |
| Hygiene | Weekly per active repo (manual until the first monitored run signs off scheduling) | 7-lens panel; fixes commit direct to `main`, close via `ac-publish`; deferred → epic beads. **Sole owner of the standing review of `main`** when no batch shipped in >7 days — `ac-review` provides only the diff-range mechanism and never self-schedules it | `ac-hygiene` |
| Audit | **Not yet scheduled** — human-triggered today; checklists serve as reference depth behind the weekly hygiene panel | findings → beads, never fixes in place | `audit` |

**Triage-before-swarm ordering** is the one cadence rule with a *hard dependency* on another
job — triage must feed the board before the swarm consumes it — rather than a fixed wall-clock
slot. It was enforced at the archived `ac-loop`'s own "Scheduling" section, decoupled so a
triage failure never blocked shipping. **That enforcer went with `ac-loop` and nothing has
replaced it:** `ac-implement`'s coordinator does not check when triage last ran. Until it does,
this row is a stated rule with no mechanism, and is recorded as such rather than left implied.
