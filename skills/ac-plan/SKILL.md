---
name: ac-plan
description: 'Turn an idea into ONE ac2 plan file — problem, approach, deliverables, assumptions, risk + sequence, out-of-scope, and a success criterion that can come out FALSE. Explorers optional, chosen by size. Triggers: "ac2 plan", "write an ac2 plan", "plan this for ac2". Hands off to ac-prep (or ac-polish, one stage at a time).'
---

# ac-plan — idea in, one plan file out

## I/O Contract

|                  |                                                                              |
| ---------------- | ---------------------------------------------------------------------------- |
| **Input**        | An idea, a backlog item, or a problem statement                               |
| **Output**       | ONE plan file, `_plans/YYYY-MM-DD-HHMM-<slug>.md`, unstamped                  |
| **Artifacts**    | Explorer notes in `_plans/research/` — only if explorers were run             |
| **Verification** | `ac-polish plan <path>` to fixpoint; `ac-polish/references/plan-checklist.md` is the bar |

Doctrine: `skills/ac-pipeline/SKILL.md` — including the model-tier Calibration (planning runs OPUS-tier; a Calibration with a retirement measurement, not a fact to restate here). Bead and
commit canon: `beads-standards` and `ac-pipeline/references/` BY POINTER — restated nowhere.

## Before anything: the task-size floor

**A trivial single-file change with no dependency structure BYPASSES ac2 entirely** — no plan, no beads, no ceremony. Applying the pipeline to a nit is a defect in judgement, not diligence.

## What goes in the plan — the ten-year test

Be optimistic about the model, pessimistic about what we must actually say. State only what a capable model **cannot infer**: our conventions, our file locations, our failure history, the specific decisions this work turns on. Every line that would be obvious in ten years is
a line to cut — the plan is graded on whether its claims are checkable, never on its length.

**The citation rule.** Every claim about the tree cites a path plus a quoted phrase or the finding command — never `file:line`, which drifts on a shared trunk before the claim does.

## Procedure

1. **Size the work.** Below the floor → stop, do it directly. Otherwise continue.
2. **Ask only the obvious questions** — the ones without which the brief would be a guess; a capable read of the codebase answers the rest. Explorers are OPTIONAL, size selects them. Notes land in `_plans/research/`; none ran → say so.
3. **Draft the vision brief** in plain words a non-engineer follows — no pipeline
   jargon, and the same rule wherever the vision or plan is shown to the human —
   corrected by the human in free text, then frozen verbatim as `## Vision`.
4. **Seams scan.** Every path in the conductor's drafted deliverable list is an object, no
   cap — `## Deliverables` is written in step 5, so the scan reads the draft, never the
   plan. Derive its file list (`skills/_tools/touchers.sh derive <path>` plus the repo's
   test globs) and spawn one fresh reader per object IN PARALLEL, sent
   `references/plan-seams-reader.md` verbatim — only for a non-empty derived list (empty
   gets no reader: an empty sweep proves nothing). One row per file, silence banned,
   completeness by count; an OUT-OF-PLAN claim survives only when it names the deliverable
   it compromises, is P0–P2, and a fresh second reader confirms it (same file, § Confirming
   an OUT-OF-PLAN claim).
5. **Write the ONE plan file**, `## Vision` first: Problem, Approach, Deliverables (artifacts, never intentions — ` — one-shot` marks migration scratch, D4), Assumptions (what DETECTS
   the falsity, by when), Decisions (§ next step), `## Seams` (after Decisions — one row per surviving finding, object by object; `plan-checklist.md` § 1 re-derives every object's touchers against it — an uncovered file is an unowned seam), `## Planned layer` (after Seams — from `skills/_tools/planned-layer.sh scan <plan>`: one `- <id> · <relationship> — <why, naming the shared paths>` row per match, relationship one of consumes|supersedes|conflicts|independent; no matches → body is `none`; a `conflicts` row also opens a `needs-human` card, `references/decisions.md`), Risk + sequence (`Human gates:` names every authorization gate), Out of scope, Success criterion.
6. **Decisions and improvements** per `references/decisions.md`: `settled: <choice> — <why>` or `needs-human`, each settled card quoting its `## Vision` line;
   up to two opt-in improvements alongside, never folded into Deliverables on the agent's own judgement — each accepted one appends one sentence to `## Vision`, quoted by its card.
7. **Diet pass, bounded.** Spawn a fresh orchestrator-tier reader with the plan and one question — where is the fat: the same functionality,
   experience and reliability with less or simpler. It returns cuts, each naming what replaces it, never edits. The conductor checks each claim and
   applies a cut only when nothing concrete is lost — a safeguard, a Seams finding, a Vision sentence left unmet — keeping the rest without a card; a
   question is answered by lookup; a trade it still backs rides the opt-in line (`references/decisions.md` § Improvements). Stop when a round applies nothing, three rounds at most.
8. **Approve.** Render `references/approval-brief.md`'s brief and run ONE question round — open cards plus **Approve / Change / Park**. Approve runs
   `skills/_tools/plan-approve.sh approve <plan> "$(git config user.name)"`, the ONE writer, never a hand edit. Unattended: the plan stays `draft` and the docket shows it waiting.
9. **Stop.** End with the line `Next: /ac-prep <path>` (or `/ac-polish plan <path>` for one stage at a time) — never invoke the next stage.

## The success criterion — a refusal, not a suggestion

**REFUSE to emit a plan whose success criterion cannot come out FALSE.** Under the heading `## Success criterion` it is the Silver Bullet: one command, its expected result, run while planning, its failing output pasted in. Three ways it fails, each sends it back:

- **Unfalsifiable** — prose, not a command; no observation could contradict it. It is a slogan.
- **Already true today** — it passes now, so nothing was asserted; paste the failing output, or it is not this plan's criterion.
- **Unowned** — nobody is named to run the command, on what artifact, and when.

One Silver Bullet, not three. Every `## Deliverables` bullet carries a "Done when:" line with concrete values: what goes in, what comes out.
