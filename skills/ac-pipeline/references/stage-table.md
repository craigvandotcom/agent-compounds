# Stage table — the canonical order

THE single home for the pipeline's stage order: one row per live stage, align to land,
plus the cadence stages that interleave with every wave. The five facts per stage are
surface, not doctrine — the owner skill is the doctrine; this table only routes.
**Point here; restate nothing.** (Audit 2026-09-04: three documents carried three
contradictory orders and none contained polish, prove or distribute.)

**No stage invokes the next.** Every stage ends by stopping on its own `Next` cell below —
a question first when a human act comes next, then the skill. Chaining happens only when
the human says "X then Y".

| Stage | Owner skill | Trigger | Human gate | Artifact | Next | Non-ac skills loaded |
|---|---|---|---|---|---|---|
| Align | `ac-align` | weekly (scheduled) + on demand | proposal only — human approves direction | alignment report | "Approve the direction?" then `/ac-plan` | — |
| Plan | `ac-plan` | human intent | human approval via `plan-approve.sh approve` | ONE plan file (`_plans/`) | "Approve the plan?" then `/ac-polish plan <path>` | — |
| Polish (plan) | `ac-polish` | plan authored | conditional regate via `plan-approve.sh ready` — only when an approved section moved | refined plan (seams maps where traced) | `/ac-beadify <path>` (regate: re-approve, then retry) | `context-engineering` |
| Beadify | `ac-beadify` | `plan-approve.sh check` passes | none — ACs gate themselves (`no probe, no bead`) | beads, Consumes-wired | `/ac-polish bead <epic>` | `beads-standards` |
| Implement | `ac-implement` (conductor) + workers (`references/worker.md`) | eligible beads on the board (`ac-triage` must have fed it ≥30 min prior) | human-gate beads only | commits on the run's branch, closed beads | `/ac-publish` | `beads-standards` · `agent-mail` (+ domain skill per bead) |
| Publish | `ac-publish` (prover: `ac-prove`) | batch ready to ship | release gate — version + tag are human-priced | version tag on the proven SHA | "Authorize the release?" then `/ac-distribute` | `beads-standards` |
| Distribute | `ac-distribute` | proven build in hand | store submission is human-authorized | TestFlight / App Store submission | "Authorize store submission?" then `/ac-land` | app `CORE/distribution.md` |
| Land | `ac-land` | loop exit — LAST, after everything above | none | run ledger + retro + memory | — (loop exit) | `reflect` |
| Triage | `ac-triage` | scheduled, ≥30 min before any swarm | proposal only — files beads | defect beads | — (feeds the board, not a stage in the chain) | app `CORE/triage.md` |
| Housekeeping | `ac-tidy` · `ac-hygiene` (weekly panel) · `ac-review <range>` (targeted manual) | cross-cadence — see `ac-pipeline/references/schedule.md` | fixes commit direct; repairs are bounded | tidy proposals · hygiene fixes · audit findings→beads | — (cross-cadence, no single next) | `ac-review` (checklists behind the panel) |

Retired names own no row (anything under `_archive/skills/` with no live successor): their
live duties are folded into the rows above (`ac-implement` conducts; the swarm commits to
the run's branch directly — there is no merge stage; `ac-beadify` + the refine stamp own bead quality).

## Pull order

The next move is always the one closest to implement: finish what is nearest done before
feeding the front. `ac-board`'s `🎯 NEXT` ranks every move by this ladder, and `ac-human`'s
docket presents its human rungs (3 · 7 · 8) in the same order. Code: `scripts/pull_order.py`.

| # | Rung | Route |
|---|---|---|
| ⚡ | a red PR — an interrupt, it poisons whatever lands next | `gh pr checks` |
| 1 | reclaim in-progress beads no live agent holds | `ac-tidy` |
| 2 | implement ready beads | `ac-implement` |
| 3 | human gates that block beads, most beads freed first | `ac-human` |
| 4 | polish unrefined beads | `ac-polish bead` |
| 5 | plans nearest beads: `bead-ready` → beadify · `refined` (a needs-human card) → rule · approved and polished → `plan-approve.sh ready` | `ac-beadify` · `ac-human` |
| 6 | polish approved plans | `ac-polish plan` |
| 7 | approve draft plans | `ac-human` |
| 8 | human gates that block nothing, then promote the pool | `ac-human` · `ac-align` |

Within a rung: most beads freed, then priority, then oldest.
