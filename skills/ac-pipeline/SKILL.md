---
name: ac-pipeline
description: End-to-end engineering pipeline orchestrator — chains align → next → plan → beadify → implement → (land + review, either order) → merge with gates between stages. Use when you want the whole flow run hands-off, or a named slice of it. Triggers: "run the pipeline", "take this from idea to merged", "ship this end to end", "/pipeline <goal>".
---

# Pipeline Orchestrator

This is a **thin conductor**, not an implementation. It owns *ordering, gates, and handoffs* — each stage's intelligence lives in its own skill. Invoke a stage skill directly when you only want that stage; invoke `ac-pipeline` when you want the chain run with enforced gates.

## The chain

```
ac-align → ac-plan-init → ac-beadify → ac-implement → verify(gate) → ac-land ┐
                                       ↑_______________________________________|         ├→ ac-merge
                                                                               ac-review ┘
                                                                               ac-hygiene (anytime)
```

**Verify is a gate, not a fixed run.** After implement, consult
`_shared/verification-gate.md` — it classifies the wave diff and runs **only** the
selected `ac-ui-polish` / `ac-qa-browser` / `ac-qa-device` passes at the selected
depth. A docs-only wave runs nothing; a UI wave runs ui-polish + browser QA; a
native wave adds device QA (Mac only). Always emit the gate's decision line so a
skip is visible. This is the same gate `ac-loop` consults — pipeline and loop verify
identically.

**Two-path model (pre-merge gates):**
- `ac-land` is per-session closure — push, retrospective, system compounding. Runs once per implement session.
- `ac-review` is per-feature-branch review — PR code review, blocking findings. Runs once per wave.
- Verify, land, and review must all complete before `ac-merge`. Verify comes right after implement; land/review order is flexible.
- `ac-merge` always comes last, and re-runs a **smoke** pass on the post-rebase state via the same gate (its safety net — see `ac-merge`).

| # | Stage | Skill | Produces (gate to advance) |
|---|-------|-------|----------------------------|
| 1 | Align & Select | `ac-align` | Pipeline reconciled with strategy; `pool → active` promoted; the next item to advance is chosen |
| 2 | Plan | `ac-plan-init` | An approved plan file (`_plans/…`) |
| 3 | Beadify | `ac-beadify` | Beads created from the plan (`br list` shows the wave) |
| 4 | Implement | `ac-implement` | Wave implemented; per-bead quality gates green |
| 4.5 | Verify | `_shared/verification-gate.md` → selected passes | Gate-selected ui-polish/QA passes PASS; findings filed as beads; no open `qa-blocker`; decision line emitted |
| 5a | Land | `ac-land` | Session closed; learnings captured; system compounded (pre-merge gate) |
| 5b | Review | `ac-review` | Branch reviewed; blocking findings fixed or escalated (pre-merge gate) |
| 6 | Merge | `ac-merge` | PR merged to main; version/build bumped (runs after both 5a and 5b) |

**Stage 1 (Align) absorbs item selection** — its strategy reconciliation + `pool → active` promotion + sequencing review *is* the "what do we advance next" decision (formerly the separate `ac-next` stage). **Stage 4.5 (Verify) runs right after implement; stages 5a and 5b are both required before stage 6 with flexible mutual order.** Verify stays thin — it consults `_shared/verification-gate.md` and runs what the gate selects.

**Adjuncts (not inside the gated chain):**
- `ac-backlog` — capture ideas at the front, before `ac-align`.
- `ac-tidy` — pipeline housekeeping (archive done items, reconcile backlog/plans/beads). Run between waves.
- `ac-hygiene` — codebase cleanup pass. Run between waves.
- `ac-human-session` — the human command center: surfaces what needs *your* decision (blockers, plans to approve, hopper) and conducts the sit-down. Absorbs the old `ac-next` funnel view.
- `ac-loop` — **scheduled autonomous conductor**: ships orphan beads + plan waves without human checkpoints, pauses on simple decisions via Slack buttons, nudges human about remaining blocks. Use instead of `ac-pipeline` for unattended runs.

## Operating rules

1. **One stage at a time, in order.** Announce the stage, delegate to its skill, then verify the gate before advancing.
2. **Gates are hard.** Do not start stage N+1 until stage N's artifact exists and is verified (e.g. a plan file must exist before `ac-beadify`; `br list` must show beads before `ac-implement`). If a gate fails, stop and surface it — never paper over it.
3. **Checkpoint with the human at stage boundaries** unless told to run hands-off. Default to pausing after `ac-plan-init` (approve the plan) and before `ac-merge` (approve the PR).
4. **Partial runs are first-class.** "Run the pipeline from plan to review" → start at stage 2, end at stage 5b. "Just plan and beadify" → stages 2–3.
5. **Failure handling.** If `ac-implement` or `ac-review` surfaces blocking issues, loop within that stage (or drop back one stage) rather than pushing a broken artifact forward. Cap auto-fix loops; escalate to the human past the cap.
6. **Stay thin.** Do not re-implement stage logic here. If a stage needs to change, change that stage's skill.

## Usage

```
/ac-pipeline <goal>                   # full chain from the current state
/ac-pipeline from ac-plan-init             # start at plan (assumes stage 1 done)
/ac-pipeline ac-plan-init..ac-review       # run a slice
/ac-pipeline --hands-off <goal>       # skip boundary checkpoints (trust the gates)
```

When invoked, first run (or confirm) `ac-align` to establish *what* is being advanced (it reconciles, promotes `pool → active`, and selects the next item), then proceed down the chain, gating at each step.
