# plan-checklist — the question set ac2-polish runs over a plan

The loop that runs this (fresh reader per round, severity gating, fixpoint at zero changes
on a FROZEN plan, bounded rounds) belongs to `ac2-polish/SKILL.md`. This file is only the
questions. **Routine bound-exhaustion indicts THIS FILE, not the plan.**

Cite, don't restate: bead taxonomy and the refined contract are `beads-standards`
(`reference/bead-conventions.md`); run, commit and delegation discipline are
`ac-pipeline/references/`. A polished plan that produces no beads is a dead end — plan mode
ends by handing off to `ac2-beadify`.

Every question is answered YES **with the evidence that settles it**, or it is a finding.

## 1. completeness

- Is every deliverable named as an artifact — a path, a script, a receipt — rather than an
  intention?
- Is the work partitioned with no gap between parts: does something own each seam, each
  caller, each trigger, each write-path the plan disturbs?
- Does anything in the plan depend on a fact nobody verified? Name the command that
  verified it.

## 2. falsifiable success criterion

- Does the plan state ONE success criterion, and can it come out FALSE? Write the observed
  result that would falsify it. If none exists, the criterion is a slogan.
- Who or what evaluates it, when, and on what artifact?
- Is it already true today? Then the plan asserts nothing.

## 3. assumptions that change the plan if wrong

- Are the assumptions stated — not the harmless ones, the ones the plan RESTS on?
- For each: what would the plan become if it were false? An assumption whose falsity changes
  nothing does not belong; one whose falsity changes everything and is unlisted is the
  plan's real risk.
- What DETECTS the falsity, and by when? An assumption with no detection rule is a bet.

## 4. risk + sequence

- Is the order of work stated, and is the tree green at every step of it? A step that turns
  lint, CI or a gate red before its enabling step lands is a sequencing defect.
- Are the risks named with a countermeasure that is a mechanism, not a resolution to be
  careful?
- What is the biggest risk, and does the plan actually spend anything on it?

## 5. out-of-scope stated

- Does the plan say what it is NOT doing, explicitly? An unbounded plan cannot be finished,
  only abandoned.
- For each exclusion: is it deferred (and to what) or refused (and why)?
