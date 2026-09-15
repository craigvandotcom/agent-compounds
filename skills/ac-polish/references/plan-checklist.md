# plan-checklist — the question set ac-polish runs over a plan

The loop that runs this (fresh reader per round, severity gating, fixpoint at zero changes
on a FROZEN plan, bounded rounds) belongs to `ac-polish/SKILL.md`. This file is only the
questions. **Routine bound-exhaustion indicts THIS FILE, not the plan.**

Cite, don't restate: bead taxonomy and the refined contract are `beads-standards`
(`reference/bead-conventions.md`); run, commit and delegation discipline are
`ac-pipeline/references/`. A polished plan that produces no beads is a dead end — plan mode
ends by handing off to `ac-beadify`.

**SEVERITY GATE for a plan — correctness · contradiction · unimplementability.** These are the
only reportable classes. Style, preference and wording are not findings.

A question you cannot answer YES with evidence is a **DECLINED** item, not a finding — unless
the gap is itself a correctness, contradiction or unimplementability defect. Declining honestly
is the reader doing its job; reaching for a finding to justify the round is not.

**Citations.** A `path:line` whose line merely moved (same text, new line number) is DECLINED,
never a re-raised finding; a citation whose path no longer exists in the tree is class (a). A
DECLINED item the plan already owns from an earlier round is listed once, never restated as if
newly found.

## 1. completeness

- Is every deliverable named as an artifact — a path, a script, a receipt — rather than an
  intention?
- Is the work partitioned with no gap between parts: does something own each seam, each
  caller, each trigger, each write-path the plan disturbs? The oracle is MECHANICAL: for every
  object the plan's `## Seams` table names (`references/plan-seams-reader.md`'s output), re-run
  `touchers.sh derive <path>` for its SOURCE row and the same TEST globs the reader used. Any
  file either returns that carries no row in `## Seams`, is not itself a Deliverable, and is
  not named in Out of scope is an **unowned seam** — class (c), no defined mechanism updates
  it.
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

## 5. premortem (imagine this failed)

- It is 6 months in the future: this plan was implemented and it completely failed. What went
  wrong? Name 3+ concrete failure scenarios, each with what happened, the root cause, the
  warning sign that should have been obvious, and the specific plan change that prevents it
  (Jeffrey Emanuel's premortem pattern — the iterative-refinement method it belongs to:
  `skills/ac-plan-lab/references/methodology.md`; the full prompt lives in the planning archive).
- Which assumption is this plan making that could be false? For each: what breaks if it is
  wrong, and what hedges it?
- What are the edge cases and integration risks — degraded network, unexpected input,
  dependency failure, load, stale or corrupted state, a rollout that goes wrong — and does the
  plan name a rollback for the irreversible ones?
- For each failure mode: what is the hardening measure, expressed as a proposed change to the
  plan itself — never a resolution to be careful?

## 6. out-of-scope stated

- Does the plan say what it is NOT doing, explicitly? An unbounded plan cannot be finished,
  only abandoned.
- For each exclusion: is it deferred (and to what) or refused (and why)?

## 7. decisions closed

- Is every fork the plan turns on settled in a Decisions card (`settled:` or `needs-human`)?
  A step two implementations could both satisfy is class (c) unimplementability. The
  prescribed edit is to APPEND a `needs-human` card to the plan's Decisions section — never
  to pick a side on the plan's behalf.
- Is there a `needs-human` card a query settles? That is class (a) correctness — run the
  query and record `settled: <choice> — <why>` instead.
- Does a `## Vision` section exist, and does no Decisions card contradict it? A plan with
  forks but no stated Vision has nothing to settle them against.
- Is every `settled:` card traceable to a quote from `## Vision`? A settled card with no
  vision quote is class (a) — the choice was made without the one thing the plan claims to
  steer by.
- Appended `needs-human` cards and recorded `settled:` cards both follow the one card
  grammar in `skills/ac-plan/references/decisions.md`.
