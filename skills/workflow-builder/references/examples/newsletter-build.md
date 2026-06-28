# Worked example — building the `/newsletter` command

A project-specific instance of the 6-phase build process (from the original neoMeta/PAI
`/newsletter` build). **Illustrative, not doctrine** — the doctrine is in `../../SKILL.md`
and `../command-patterns.md`. The content-specific choices below are *one project's answers*,
not rules.

---

## Phase 0-1 · Discovery & research

Read the existing content commands and the writing SOPs; delegated a researcher to extract the
patterns (per-folder output, voice gates, section structure) and surface the open decisions.

## Phase 2 · Refinement (the decisions that mattered)

The expensive ones — both were initially *assumed wrong* and caused rework:

- **Purpose:** assumed a curiosity-gap *teaser*; the user actually wanted **standalone essays
  with full value**. Completely different structure. → *Always ask intent.*
- **Organization:** assumed multiple files; the user wanted a **single consolidated `plan.md`**
  per piece. → *Always ask consolidation.*

Project-specific answers captured (one project's choices):
- 600-800 word essay; sections: Hook → Framework → Core Insight → Takeaway → Bridge.
- Mobile-first; 1-2 sentences/paragraph; active voice; no em dashes ("coffee test").
- Per-folder output: `content/1-newsletter/YYYY-MM-DD-HHMM-topic-slug/`.

## Phase 3-4 · Design & implementation

- **Phases:** 0 init → 1 input analysis → 2 framework/pillar → 3 draft → 4 subject lines+images
  → 5 QA → 6 finalize.
- **Delegation:** an implementer (loading the content + writing-guidelines skills) drafts; the
  QA gate runs two validators **in parallel** — voice check + fact check — both blocking.
- **Output:** consolidated `plan.md` (strategy+status) + `draft.md` + `images/prompts.md`.

## Phase 5 · Verification

Full dry run; confirmed the voice gate actually blocked on an em-dash violation; confirmed the
per-folder structure and consolidated plan landed correctly.

---

## What generalized into doctrine (and what didn't)

| Stayed as doctrine (now in command-patterns) | Stayed project-specific (here only) |
| --- | --- |
| Run-ledger first; 5-7 phase skeleton | 600-800 words; the 5 named sections |
| Blocking parallel QA gates | "coffee test" / no em dashes |
| Consolidated source-of-truth file | per-folder content path |
| Ask-don't-assume (purpose, consolidation) | pillar/voice specifics |

> The original build also used *dedicated per-workflow agents* (`newsletter-reviewer`). That is
> now an **anti-pattern** — use a validator stance with the writing-guidelines skill loaded.
