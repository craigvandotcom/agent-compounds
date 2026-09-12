---
name: ac-plan
description: 'Turn an idea into ONE ac2 plan file — problem, approach, deliverables, assumptions, risk + sequence, out-of-scope, and a success criterion that can come out FALSE. Explorers optional, chosen by size. Triggers: "ac2 plan", "write an ac2 plan", "plan this for ac2". Hands off to ac-polish.'
---

# ac-plan — idea in, one plan file out

## I/O Contract

|                  |                                                                              |
| ---------------- | ---------------------------------------------------------------------------- |
| **Input**        | An idea, a backlog item, or a problem statement                               |
| **Output**       | ONE plan file, `_plans/YYYY-MM-DD-HHMM-<slug>.md`, unstamped                  |
| **Artifacts**    | Explorer notes in `_plans/research/` — only if explorers were run             |
| **Verification** | `ac-polish plan <path>` to fixpoint; `ac-polish/references/plan-checklist.md` is the bar |

Doctrine: `skills/ac-pipeline/SKILL.md` — including the model-tier Calibration (planning runs
OPUS-tier; a Calibration with a retirement measurement, not a fact to restate here). Bead and
commit canon: `beads-standards` and `ac-pipeline/references/` BY POINTER — restated nowhere.

## Before anything: the task-size floor

**A trivial single-file change with no dependency structure BYPASSES ac2 entirely** — no plan,
no beads, no ceremony. Applying the pipeline to a nit is a defect in judgement, not diligence.

## What goes in the plan — the ten-year test

Be optimistic about the model, pessimistic about what we must actually say. State only what
a capable model **cannot infer**: our conventions, our file locations, our failure history,
the specific decisions this work turns on. Every line that would be obvious in ten years is
a line to cut — the plan is graded on whether its claims are checkable, never on its length.

## Procedure

1. **Size the work.** Below the floor → stop, do it directly. Otherwise continue.
2. **Explorers are OPTIONAL, and size selects them** — run them only when the surface is
   genuinely unknown; a small, well-understood change gets none. ONE mechanical exception:
   `rg` each Deliverable's name; a hit means the plan RESHAPES an existing object, and that
   object gets one blind seams reader (`ac-polish/references/seams-reader-prompt.md`)
   before the Approach is written — its touchers become deliverables or Out-of-scope
   entries, its findings feed Problem. Notes land in `_plans/research/`; none ran → say so
   in one line.
3. **Write the ONE plan file.** One file, these sections, nothing ornamental:
   - **Problem** — what is wrong now, with the evidence that it is wrong.
   - **Approach** — the shape of the fix and the alternatives rejected, each with its reason.
    - **Deliverables** — every one named as an ARTIFACT (a path, a script, a receipt), never
      as an intention (` — one-shot` marks migration scratch existing only to land the epic, D4). Unnamed = unconsumable by `## Delivers`.
    - **Assumptions** — the ones the plan RESTS on: what the plan becomes if false, what
      DETECTS the falsity (`Detect:` backtick when runnable, prose otherwise), by when. No rule = a bet.
   - **Decisions** (`## Decisions`) — every fork as a card (`references/decisions.md` holds the
     shape): state `settled: <choice> — <why>` or `needs-human`; escalation test before a card.
   - **Risk + sequence** — the order of work, with the tree GREEN at every step of it. A step
     that turns lint, CI or a gate red before its enabling step lands is a sequencing defect.
     Each risk gets a countermeasure that is a mechanism, not a resolution to be careful. A
     `Human gates:` line names every authorization gate (store submit, PROD migration) for
     beadify to compile with `human-gate` + `Gate-reason: authorization` (`references/decisions.md`).
   - **Out of scope** — stated explicitly, each exclusion either deferred (and to what) or
     refused (and why). An unbounded plan cannot be finished, only abandoned.
   - **Success criterion** — exactly one. See the refusal below.
3b. **Ask the live human once** — one batched AskUserQuestion round for every `needs-human`
    card, recorded `DECISION (<human>): <choice> — <why>`; unattended → stays `needs-human`.
4. **Hand off** (§ below). Do not stop at a written plan.

## The success criterion — a refusal, not a suggestion

**REFUSE to emit a plan whose success criterion cannot come out FALSE.** Write the observed
falsifier beside it. Three ways a criterion fails, each sends it back:

- **Unfalsifiable** — no observation could contradict it. It is a slogan.
- **Already true today** — the plan asserts nothing, satisfied by an empty diff; measure
  now, and if it passes the criterion is not the plan's criterion.
- **Unowned** — nobody and nothing is named to evaluate it, on what artifact, and when.

One criterion, not three. A plan with several success criteria has not decided what it is for.

## Hand-off — plan, then hand off

`ac-plan` ENDS by handing the finished file to **`ac-polish plan <path>`**, which polishes
to fixpoint and ends by invoking `ac-beadify`. A polished plan with no beads is a measured
dead-end — our census found `loop-ready` plans with no live successor. Never end by reporting
a written plan and stopping; if the hand-off cannot happen now, queue it with the human.
