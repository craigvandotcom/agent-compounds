# ac-loop delegation prompts (single source — Phase 1 AND Phase 2)

The verbatim child-prompt payloads both loop phases dispatch. Each opens with the
Child-spawn preamble (`ac-pipeline/references/delegation-contract.md` § Child-spawn preamble — included
VERBATIM, per the SKILL.md rule). Slots in `{BRACES}` are filled by the conductor at
dispatch:

- `{SCOPE}` — Phase 1: ``all N orphan beads``; Phase 2: ``all refined ready beads for
  plan `<plan-name>` ``
- `{FLAVOR}` — Phase 1: empty; Phase 2: ``(ac-loop autonomous run)``

## Refine prompt

> "Run ac-bead-refine scoped to {REFINE_SCOPE — an epic id, or explicit bead-id list}.
> `RUN_ID=<RUN_ID>`; your artifacts dir is per-CHILD (`run-id.md` fan-out corollary —
> compute your own discriminator, never accept one). Defer beads-DB writes per
> `ac-pipeline/references/ceremony-batching-pool.md` § Beads-DB mutation deferral: hold
> ALL `br` mutation verbs (`br update`/`br close`/`br label`/`br comments add`) until the
> conductor's ledger commit lands — reads are free. Headless: no AskUserQuestion; a
> genuine fork becomes a decision bead (Exhaust Rule). Report ≤400 words: beads
> refined→stamped with IDs, premise failures found (de-stamped + commented), anything
> blocked, + the structured `friction:` block (§ Child friction schema below)."

## Beadify prompt

> "Run ac-beadify on plan `{PLAN_PATH}` (status already verified loop-ready).
> `RUN_ID=<RUN_ID>`. Skip the user-approval asks — autonomous run: auto-apply
> Critical/High + consensus validator findings, log the rest. Always proceed to
> ac-bead-refine at the end (no confirmation question). Same beads-DB-hold + report +
> `friction:` contract as the Refine prompt above."

## Implement prompt

> "Run ac-implement targeting {SCOPE} (IDs: `<list>`, already claimed — in_progress +
> assignee `<AGENT_NAME>`, claim id `<claim-id>`). `CLAIM_ASSIGNEE=<AGENT_NAME>` (MY loop
> identity) — make EVERY bead claim, including any incremental/replacement claim, under
> `--assignee <AGENT_NAME>`, NOT your own session name, so the BEADS-CLOSED-GATE sees
> them. TARGET_BEADS=N. `RUN_ID=<RUN_ID>` (scopes the bead-work dir — `ac-pipeline/references/run-id.md`).
> Skip the bead-count setup question — answer is pre-supplied. For baseline test failures:
> file a P1 bead and proceed (do not ask). Report when complete as a compact structured
> summary (≤400 words, cap unchanged: beads shipped/closed with IDs, gate outcomes,
> anything blocked, every Agent Mail identity you claimed beads under, AND a structured
> `friction:` block — one item per stage that hit friction, keys `stage` / `cost` /
> `lesson` / `class` (`friction: []` if the stage was clean); see § Child friction schema
> below) — the loop advances to verify → review → close."

## Child friction schema (D1)

The `friction:` block the summary contract above asks for. Structured (not prose) so the
conductor can aggregate it mechanically and `dream` can key on `stage`/`cost` later. One
list item per stage that hit friction; a clean stage returns `friction: []`. Lives INSIDE
the existing ≤400-word summary cap — a slot in that summary, not a new unbounded field.

```
friction:
  - stage: implement          # pipeline stage that hit it
    cost: material|minor       # + optional "~Nmin" when quantifiable
    lesson: "vi.mock hoist trap swallowed the first two runs"
    class: defect|improvement|observation   # child's pre-classification HINT
```

`class` is a HINT only — `ac-land`/`reflect` re-adjudicate it against the objective bar;
never treat it as authoritative. This file is the ONE definition of the four keys —
SKILL.md's `## Remember` child-summary bullet references it (bd-jv33f.2 aggregates on
them).

## Review prompt

> "Run ac-review (trunk-direct: on main, scope = batch since the review-mark — no branch
> argument){FLAVOR}. `report_dest=.claude/reviews/pending/` (stage the findings report
> there so ac-batch-close's Act 2(a) can accept it instead of re-running the panel; NEVER
> `.claude/reviews/batch/` — that path is the review-mark and only ac-batch-close's Act 3
> may write it, bd-kudrb). This is an autonomous loop run. For DESIGN_DECISION or
> SCOPE_ESCALATION items: apply the Exhaust Rule (create decision beads, do not
> AskUserQuestion). Do not ask 'what's next?' at Phase 8 — exit after printing the summary
> with VERDICT: line."

## Batch-close prompt

> "Run ac-batch-close for batch `<batch-id>`{FLAVOR}. CI config for this project:
> `<cached-answer>`. The step-4 ac-review already reviewed this exact diff and committed
> its findings report (with a `VERDICT:` line) to `.claude/reviews/pending/` — take that
> as the pre-supplied equivalent-review artifact (Act 2(a)) and carry it into
> `.claude/reviews/batch/` in your Act 3 commit; do NOT re-run the review panel on the
> same diff. For uncertain CI-finding items: create decision beads (Exhaust Rule). Do not
> ask 'what's next?' after merge."
