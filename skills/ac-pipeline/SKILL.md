---
name: ac-pipeline
description: End-to-end engineering pipeline orchestrator — chains align → next → plan → beadify → implement → (land + review, either order) → merge with gates between stages. Use when you want the whole flow run hands-off, or a named slice of it. Triggers: "run the pipeline", "take this from idea to merged", "ship this end to end", "/pipeline <goal>".
---

# Pipeline Orchestrator

This is a **thin conductor**, not an implementation. It owns *ordering, gates, and handoffs* — each stage's intelligence lives in its own skill. Invoke a stage skill directly when you only want that stage; invoke `ac-pipeline` when you want the chain run with enforced gates.

## The chain

```
ac-align → ac-next → ac-plan-init → ac-beadify → ac-implement → ac-land ┐
                                       ↑__________________________|       ├→ ac-merge
                                                                  ac-review ┘
                                                                  ac-hygiene (anytime)
```

**Two-path model (pre-merge gates):**
- `ac-land` is per-session closure — push, retrospective, system compounding. Runs once per implement session.
- `ac-review` is per-feature-branch review — PR code review, blocking findings. Runs once per wave.
- Both must complete before `ac-merge`. Their mutual order is flexible: run review then land, or land then review — either is valid.
- `ac-merge` always comes last (after both land and review have completed for the wave).

| # | Stage | Skill | Produces (gate to advance) |
|---|-------|-------|----------------------------|
| 1 | Align | `ac-align` | Pipeline reconciled with strategy; no orphaned/missequenced work |
| 2 | Next | `ac-next` | A chosen item to advance toward implementation-ready |
| 3 | Plan | `ac-plan-init` | An approved plan file (`_plans/…`) |
| 4 | Beadify | `ac-beadify` | Beads created from the plan (`br list` shows the wave) |
| 5 | Implement | `ac-implement` | Wave implemented; per-bead quality gates green |
| 6a | Land | `ac-land` | Session closed; learnings captured; system compounded (pre-merge gate) |
| 6b | Review | `ac-review` | Branch reviewed; blocking findings fixed or escalated (pre-merge gate) |
| 7 | Merge | `ac-merge` | PR merged to main; version/build bumped (runs after both 6a and 6b) |

**Stages 6a and 6b are both required before stage 7. Their mutual order is flexible.**

**Adjuncts (not inside the gated chain):**
- `ac-backlog` — capture ideas at the front, before `ac-align`/`ac-next`.
- `ac-tidy` — pipeline housekeeping (archive done items, reconcile backlog/plans/beads). Run between waves.
- `ac-hygiene` — codebase cleanup pass. Run between waves.
- `ac-human-next` — the human-facing counterpart to `ac-next` (surfaces what needs *your* decision).
- `ac-loop` — **scheduled autonomous conductor**: ships orphan beads + plan waves without human checkpoints, pauses on simple decisions via Slack buttons, nudges human about remaining blocks. Use instead of `ac-pipeline` for unattended runs.

## Operating rules

1. **One stage at a time, in order.** Announce the stage, delegate to its skill, then verify the gate before advancing.
2. **Gates are hard.** Do not start stage N+1 until stage N's artifact exists and is verified (e.g. a plan file must exist before `ac-beadify`; `br list` must show beads before `ac-implement`). If a gate fails, stop and surface it — never paper over it.
3. **Checkpoint with the human at stage boundaries** unless told to run hands-off. Default to pausing after `ac-plan-init` (approve the plan) and before `ac-merge` (approve the PR).
4. **Partial runs are first-class.** "Run the pipeline from plan to review" → start at stage 3, end at stage 6. "Just plan and beadify" → stages 3–4.
5. **Failure handling.** If `ac-implement` or `ac-review` surfaces blocking issues, loop within that stage (or drop back one stage) rather than pushing a broken artifact forward. Cap auto-fix loops; escalate to the human past the cap.
6. **Stay thin.** Do not re-implement stage logic here. If a stage needs to change, change that stage's skill.

## Usage

```
/ac-pipeline <goal>                   # full chain from the current state
/ac-pipeline from ac-plan-init             # start at plan (assumes 1–2 done)
/ac-pipeline ac-plan-init..ac-review       # run a slice
/ac-pipeline --hands-off <goal>       # skip boundary checkpoints (trust the gates)
```

When invoked, first run (or confirm) `ac-align` + `ac-next` to establish *what* is being advanced, then proceed down the chain, gating at each step.
