---
name: ac-prep
description: 'Prepare an APPROVED plan for implementation in one run: polish the plan, beadify it, polish the beads — each stage conducted by a coordinator subagent and gated by its own script before the next starts. Human-started only: run it when the human types /ac-prep, never on your own initiative or from a Next: line. Stops at any regate or refusal and never starts implement. Triggers: "/ac-prep <plan>", "prepare the beads", "run bead prep". For one stage alone use ac-polish or ac-beadify.'
---

# ac-prep — approved plan in, refined beads out

**Typing `/ac-prep <plan>` is the human's "X then Y"** (`ac-pipeline/references/stage-table.md`).
It grants exactly three stages, for this plan, in this session. It is never inferred from a
goal, a board ranking or a `Next:` line, and it never reaches implement.

The session that runs it is the orchestrator: it holds the chain, spawns one `coordinator`
per stage, and runs each gate ITSELF. A stage's own report is never the gate.

## Pre-flight

Resolve `<plan>` in `_plans/` or `_plans/_done/`. Its frontmatter `status:` must be
`approved` or later; `draft` stops here with `Next: /ac-plan <plan> (approval step)`.

## The chain

For each row in order: if its gate already passes, skip the stage — a re-run resumes where the
last one stopped. Otherwise spawn ONE `coordinator` with exactly: *"Conduct one stage: run
`<stage>`. You are unattended — take every unattended branch. Run this stage only, never the
next. Return the stage's report and its final `Next:` line."* When it returns, run the gate.

| # | Stage | Gate the orchestrator runs | Passes when |
|---|---|---|---|
| 1 | `/ac-polish plan <plan>` | `skills/_tools/plan-approve.sh check <plan>` | exit 0 — bead-ready, approved sections unmoved |
| 2 | `/ac-beadify <plan>` | the retired plan in `_plans/_done/` carries `beadified: <epic>`, and `br show <epic>` resolves | both hold |
| 3 | `/ac-polish bead <epic>` | `RUST_LOG=error br list --json`, the open children of `<epic>` | every child that is not a `decision` carries `refined` |

## Stops

A gate that fails stops the chain. Never retry the stage and never repair its work from the
orchestrator. Report the stage, the gate's output and the coordinator's `Next:` line, then
stop. The usual ones:

- **`regate <sections>` after stage 1** — polish moved an approved section. The human reads
  it and re-approves (`plan-approve.sh approve <plan>`), then re-runs `/ac-prep <plan>`.
- **A beadify refusal** — no probe, no bead. The plan goes back to its author.
- **Children without `refined` after stage 3** — the restamp sweep sent them back to refine.

## Hand-off

All three gates green: report the epic, its `refined` count and any `decision` beads waiting on
the human, then stop with `Next: /ac-implement <epic>`. Never invoke it.
