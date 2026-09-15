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

**The citation rule.** Every claim about the tree cites a path plus a quoted phrase or the
finding command — never `file:line`, which drifts on a shared trunk before the claim does.

## Procedure

1. **Size the work.** Below the floor → stop, do it directly. Otherwise continue.
2. **Ask only the obvious questions** — the ones without which the brief would be a guess; a
   capable read of the codebase answers the rest. Explorers are OPTIONAL, size selects them.
   Notes land in `_plans/research/`; none ran → say so.
3. **Draft the vision brief** in plain prose, corrected by the human in free text, then
   frozen verbatim as `## Vision` — every later Decisions card and the seams scan read against it.
4. **Seams scan.** Every existing `## Deliverables` path is an object, no cap. Derive its
   file list (`skills/_tools/touchers.sh derive <path>` plus the repo's test globs) and spawn
   one fresh reader per object IN PARALLEL, `references/plan-seams-reader.md` sent verbatim —
   one row per file, silence banned, completeness by count. An OUT-OF-PLAN claim survives
   only when it names the deliverable it compromises, is P0–P2, and a fresh second reader
   confirms it (same file, § Confirming an OUT-OF-PLAN claim).
5. **Write the ONE plan file**, `## Vision` first: Problem, Approach, Deliverables (artifacts,
   never intentions — ` — one-shot` marks migration scratch, D4), Assumptions (what DETECTS
   the falsity, by when), Decisions (§ next step), `## Seams` (after Decisions — one row per
   surviving finding, object by object; `plan-checklist.md` § 1 re-derives every object's
   touchers against it — an uncovered file is an unowned seam), Risk + sequence (`Human
   gates:` names every authorization gate), Out of scope, Success criterion.
6. **Decisions and improvements** per `references/decisions.md`: `settled: <choice> — <why>`
   or `needs-human`, each settled card quoting its `## Vision` line; up to two opt-in
   improvements alongside, never folded into Deliverables on the agent's own judgement.
7. **Approve.** Render `references/approval-brief.md`'s brief and run ONE question round —
   open cards plus **Approve / Change / Park**. Approve runs
   `skills/_tools/plan-approve.sh approve <plan> "$(git config user.name)"`, the ONE writer,
   never a hand edit. Unattended: the plan stays `draft` and the docket shows it waiting.
8. **Stop.** End with the line `Next: /ac-polish plan <path>` — never invoke the next stage.

## The success criterion — a refusal, not a suggestion

**REFUSE to emit a plan whose success criterion cannot come out FALSE.** Write the observed
falsifier beside it. Three ways a criterion fails, each sends it back:

- **Unfalsifiable** — no observation could contradict it. It is a slogan.
- **Already true today** — the plan asserts nothing, satisfied by an empty diff; measure
  now, and if it passes the criterion is not the plan's criterion.
- **Unowned** — nobody and nothing is named to evaluate it, on what artifact, and when.

One criterion, not three. A plan with several success criteria has not decided what it is for.
