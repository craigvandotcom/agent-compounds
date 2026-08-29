---
name: ac2-plan
description: 'Turn an idea into ONE ac2 plan file — problem, approach, deliverables, assumptions, risk + sequence, out-of-scope, and a success criterion that can come out FALSE. Explorers optional, chosen by size. Triggers: "ac2 plan", "write an ac2 plan", "plan this for ac2". Hands off to ac2-polish.'
---

# ac2-plan — idea in, one plan file out

## I/O Contract

|                  |                                                                              |
| ---------------- | ---------------------------------------------------------------------------- |
| **Input**        | An idea, a backlog item, or a problem statement                               |
| **Output**       | ONE plan file, `_plans/YYYY-MM-DD-HHMM-<slug>.md`, unstamped                  |
| **Artifacts**    | Explorer notes in `_plans/research/` — only if explorers were run             |
| **Verification** | `ac2-polish plan <path>` to fixpoint; its `references/plan-checklist.md` is the bar |

Doctrine: `skills/ac2-pipeline/SKILL.md` — including the model-tier Calibration (planning
runs OPUS-tier; that is a Calibration with a retirement measurement, not a fact to restate
here). Bead and commit canon: `beads-standards` and `ac-pipeline/references/` BY POINTER —
this skill restates neither.

## Before anything: the task-size floor

**A trivial single-file change with no dependency structure BYPASSES ac2 entirely.** No plan,
no beads, no ceremony — do the work. The lean pipeline never becomes mandatory ceremony for
nits, and applying it to one is a defect in judgement, not diligence.

## What goes in the plan — the ten-year test

Be optimistic about the model, pessimistic about what we must actually say. State only what
a capable model **cannot infer**: our conventions, our file locations, our failure history,
the specific decisions this work turns on. Do not teach a competent engineer how to think
about the problem. Every line that would be obvious in ten years is a line to cut — and the
plan is graded on whether its claims are checkable, never on its length.

## Procedure

1. **Size the work.** Below the floor → stop, do it directly. Otherwise continue.
2. **Explorers are OPTIONAL, and size selects them.** Run them only when the surface is
   genuinely unknown — an unfamiliar subsystem, a cross-repo seam, a failure whose cause is
   not yet located. A small, well-understood change gets none: a mandatory research phase is
   how a lean plan acquires a heavy front end. When run, notes land in `_plans/research/` and
   the plan cites them; when not, say so in one line so the omission is a decision on the
   record rather than a gap.
3. **Write the ONE plan file.** One file, these sections, nothing ornamental:
   - **Problem** — what is wrong now, with the evidence that it is wrong.
   - **Approach** — the shape of the fix and the alternatives rejected, each with its reason.
   - **Deliverables** — every one named as an ARTIFACT (a path, a script, a receipt), never
     as an intention. An unnamed deliverable cannot be consumed by a bead's `## Delivers`.
   - **Assumptions** — the ones the plan RESTS on, each with what the plan becomes if it is
     false and what DETECTS the falsity, by when. An assumption with no detection rule is a
     bet, not an assumption.
   - **Risk + sequence** — the order of work, with the tree GREEN at every step of it. A step
     that turns lint, CI or a gate red before its enabling step lands is a sequencing defect,
     and it is cheaper to find here than at implement. Each risk gets a countermeasure that
     is a mechanism, not a resolution to be careful.
   - **Out of scope** — stated explicitly, each exclusion either deferred (and to what) or
     refused (and why). An unbounded plan cannot be finished, only abandoned.
   - **Success criterion** — exactly one. See the refusal below.
4. **Hand off** (§ below). Do not stop at a written plan.

## The success criterion — a refusal, not a suggestion

**REFUSE to emit a plan whose success criterion cannot come out FALSE.** Write the observed
result that would falsify it, in the plan, next to it. Three ways a criterion fails this bar,
and each one sends it back to be rewritten rather than through:

- **Unfalsifiable** — no observation could contradict it. It is a slogan.
- **Already true today** — then the plan asserts nothing and can be satisfied by an empty
  diff. Measure it now; if it passes, the criterion is not the plan's criterion.
- **Unowned** — nobody and nothing is named to evaluate it, on what artifact, and when.

One criterion, not three. A plan with several success criteria has not decided what it is for.

## Hand-off — plan, then hand off

`ac2-plan` ENDS by handing the finished file to **`ac2-polish plan <path>`**, which polishes
to fixpoint and itself ends by invoking `ac2-beadify`. A polished plan with no beads is a
measured dead-end in both this system and Jef's — our own census found `loop-ready` plans
with no live successor. Never end a run by reporting a written plan and stopping; if the
hand-off cannot happen now, queue it explicitly with the human and say so.
