# Stage table — the canonical order

THE single home for the pipeline's stage order: one row per live stage, align to land,
plus the cadence stages that interleave with every wave. The five facts per stage are
surface, not doctrine — the owner skill is the doctrine; this table only routes.
**Point here; restate nothing.** (Audit 2026-09-04: three documents carried three
contradictory orders and none contained polish, prove or distribute.)

**No stage invokes the next.** Every stage ends by stopping on its own `Next` cell below —
a question first when a human act comes next, then the skill. A direct yes to that question
is the human's own words, and so is the human typing "X then Y" in this session — a `Next:`
line alone is never that permission. A session goal ("finish the epic"), a board ranking or
the pull order grants nothing either, and a stage's stamp makes work eligible, it does not
authorize the next stage.

One standing authorization exists, and it is a grant, not a stage's stamp: a scheduled
workflow that the project's `.claude/factory.json` `autopilot` block enables is permission
for `ac-polish bead`, Implement and the batch push, and for nothing else. It never reaches
Ship — version, tag and each store submission stay human-authorized.

| Stage | Owner skill | Trigger | Human gate | Artifact | Next | Non-ac skills loaded |
|---|---|---|---|---|---|---|
| Align | `ac-align` | weekly (scheduled) + on demand | proposal only — human approves direction | alignment report | "Approve the direction?" then `/ac-plan` | — |
| Plan | `ac-plan` | human intent | human approval — provisional Go, then final approval via `plan-approve.sh approve` | ONE plan file (`_plans/`) | "Start beadify now?" then `/ac-beadify <path>` | `context-engineering` |
| Beadify | `ac-beadify` | `plan-approve.sh check` passes | none — ACs gate themselves (`no probe, no bead`) | beads, Consumes-wired | "Start implement now?" then `/ac-implement <epic>` | `beads-standards` |
| Implement | `ac-implement` (conductor) + workers (`references/worker.md`) | eligible beads on the board (`ac-triage` must have fed it ≥30 min prior) | human-gate beads only | commits on the run's branch, closed beads | `/ac-publish` | `beads-standards` · `agent-mail` (+ domain skill per bead) |
| Ship | `ac-publish` | batch ready to ship | release gate — version, tag and each store submission are human-authorized | promoted, verified build at the proven SHA; version tag on release | "Authorize the release?" then `/ac-land` | `beads-standards` · app `CORE/distribution.md` |
| Land | `ac-land` | loop exit — LAST, after everything above | none | run ledger + retro + memory | — (loop exit) | `reflect` |
| Triage | `ac-triage` | scheduled, ≥30 min before any swarm | proposal only — files beads | defect beads | — (feeds the board, not a stage in the chain) | app `CORE/triage.md` |
| Housekeeping | `ac-tidy` · `ac-hygiene` (weekly panel) · `ac-review <range>` (targeted manual) | cross-cadence — see `ac-pipeline/references/schedule.md` | fixes commit direct; repairs are bounded | tidy proposals · hygiene fixes · audit findings→beads | — (cross-cadence, no single next) | `ac-review` (checklists behind the panel) |

Retired names own no row (anything under `_archive/skills/` with no live successor): their
live duties are folded into the rows above (`ac-implement` conducts; the swarm commits to
the run's branch directly — there is no merge stage; `ac-beadify` + the refine stamp own bead quality).

## Pull order

The next move is always the one closest to implement: finish what is nearest done before
feeding the front. `ac-board`'s `🎯 NEXT` ranks every move by this ladder, and `ac-human`'s
docket presents its human rungs (3 · 7 · 8 · 9) in the same order. Code: `scripts/pull_order.py`.

| # | Rung | Route |
|---|---|---|
| ⚡ | a red PR — an interrupt, it poisons whatever lands next | `gh pr checks` |
| 1 | reclaim in-progress beads no live agent holds | `ac-tidy` |
| 2 | implement ready beads | `ac-implement` |
| 3 | human gates that block beads, most beads freed first | `ac-human` |
| 4 | polish unrefined beads | `ac-polish bead` |
| 5 | plans nearest beads: `bead-ready` → beadify · `refined` (a needs-human card) → `/ac-plan` · approved and polished → `/ac-plan` (regate: re-approve, then ready) | `ac-beadify` · `/ac-plan` |
| 6 | polish approved plans | `ac-polish plan` |
| 7 | approve draft plans | `/ac-plan` |
| 8 | human gates that block nothing, then promote the pool | `ac-human` · `ac-align` |
| 9 | human gates still waiting on loop work: after the steps before them | `ac-human` |

Within a rung: most beads freed, then priority, then oldest.
