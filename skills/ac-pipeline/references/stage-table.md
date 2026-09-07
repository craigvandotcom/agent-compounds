# Stage table — the canonical order

THE single home for the pipeline's stage order: one row per live stage, align to land,
plus the cadence stages that interleave with every wave. The four facts per stage are
surface, not doctrine — the owner skill is the doctrine; this table only routes.
**Point here; restate nothing.** (Audit 2026-09-04: three documents carried three
contradictory orders and none contained polish, prove or distribute.)

| Stage | Owner skill | Trigger | Human gate | Artifact | Non-ac skills loaded |
|---|---|---|---|---|---|
| Align | `ac-align` | weekly (scheduled) + on demand | proposal only — human approves direction | alignment report | — |
| Plan | `ac-plan` | human intent | intent approval | ONE plan file (`_plans/`) | — |
| Polish (plan) | `ac-polish` | plan authored | none — fixpoint is measured | refined plan (seams maps where traced) | `context-engineering` |
| Beadify | `ac-beadify` | plan approved | none — ACs gate themselves (`no probe, no bead`) | beads, Consumes-wired | `beads-standards` |
| Implement | `ac-implement` (conductor) + workers (`references/worker.md`) | eligible beads on the board (`ac-triage` must have fed it ≥30 min prior) | human-gate beads only | commits on `main`, closed beads | `beads-standards` · `agent-mail` (+ domain skill per bead) |
| Review | `ac-review` | batch boundary (post-batch, different model) | NEEDS_DECISION findings | review report + findings | `skill-builder` (standards) |
| Publish | `ac-publish` (prover: `ac-prove`) | batch ready to ship | release gate — version + tag are human-priced | version tag on the proven SHA | `beads-standards` |
| Distribute | `ac-distribute` | proven build in hand | store submission is human-authorized | TestFlight / App Store submission | app `CORE/distribution.md` |
| Land | `ac-land` | loop exit — LAST, after everything above | none | run ledger + retro + memory | `reflect` |
| Triage | `ac-triage` | scheduled, ≥30 min before any swarm | proposal only — files beads | defect beads | app `CORE/triage.md` |
| Housekeeping | `ac-tidy` (nightly) · `ac-hygiene` (weekly panel) · `audit` (human-triggered) | cross-cadence — see `ac-pipeline/references/schedule.md` | fixes commit direct; repairs are bounded | tidy proposals · hygiene fixes · audit findings→beads | `audit` (checklists behind the panel) |

Retired names (`ac-loop`, `ac-merge`, `ac-batch-close`, `ac-bead-refine`) own no row: their
live duties are folded into the rows above (`ac-implement` conducts; the swarm commits to
`main` directly — there is no merge stage; `ac-beadify` + the refine stamp own bead quality).
