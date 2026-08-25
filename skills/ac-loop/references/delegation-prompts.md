# ac-loop delegation prompts (single source — Phase 1 AND Phase 2)

The verbatim child-prompt payloads both loop phases dispatch. Each opens with the
Child-spawn preamble (`ac-pipeline/references/delegation-contract.md` § Child-spawn preamble — included
VERBATIM, per the SKILL.md rule). Slots in `{BRACES}` are filled by the conductor at
dispatch:

- `{SCOPE}` — Phase 1: ``all N orphan beads``; Phase 2: ``all refined ready beads for
  plan `<plan-name>` ``
- `{FLAVOR}` — Phase 1: empty; Phase 2: ``(ac-loop autonomous run)``

## Spawn-site rule (binds every prompt below)

Every dispatched prompt carries an **explicit `AGENT_NAME=<name>`** — every child, claiming
or not. An unset `AGENT_NAME` degrades silently in two directions: an empty `CHILD_ID`
segment that collapses two children onto one artifacts path, or a fallback to the Tier-2
chore identity FoggyCreek. The conductor is the only agent that can set it.

Append this clause VERBATIM to every prompt below:

> `AGENT_NAME=<name>` — export it in every shell you commit from. ASSERT each segment of
> any identity you build from it is non-empty, and FAIL LOUDLY if not: never let an empty
> segment degrade to a shared path. Your run ledger is your `progress.md` — you hold no
> Task tools; the conductor owns the Task-tool ledger.

## Brief-claim rule (binds every prompt below)

Compose-time: state a fact only with a citation — a commit SHA or a `br show`
verdict. A claim about work still in flight is not citable. Write "premise, NOT
verified" or wait for the child's return. Never restate a bead's preconditions as
established fact.

Dispatch-time: append this clause VERBATIM to every prompt below.

> This brief is a POINTER, not a substitute for the spec — read `br show <id>` in
> full. Any uncited claim here is a premise, not a fact; verify it against the
> primary source. If a stated premise is false, follow the bead's own acceptance
> criteria, not this brief.

## Refine prompt

> "Run ac-bead-refine scoped to {REFINE_SCOPE — an epic id, or explicit bead-id list}.
> `RUN_ID=<RUN_ID>`; your artifacts dir is per-CHILD (`run-id.md` fan-out corollary —
> compute your own discriminator, never accept one). If you write a `progress.md`, its
> header MUST carry `KIND=refine` — you ship no code and close no beads, and the marker
> is what keeps your file out of the close gate's completeness union. Defer beads-DB writes per
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
> ac-bead-refine at the end (no confirmation question). If you write a `progress.md`,
> its header MUST carry `KIND=beadify` (same reason as the Refine prompt). Same
> beads-DB-hold + report + `friction:` contract as the Refine prompt above."

## Implement prompt

> "Run ac-implement targeting {SCOPE} (IDs: `<list>`, already claimed — in_progress +
> assignee `<AGENT_NAME>`, claim id `<claim-id>`). `CLAIM_ASSIGNEE=<AGENT_NAME>` (MY loop
> identity) — make EVERY bead claim, including any incremental/replacement claim, under
> `--assignee <AGENT_NAME>`, NOT your own session name, so the BEADS-CLOSED-GATE sees
> them. TARGET_BEADS=N. `RUN_ID=<RUN_ID>` (scopes the bead-work dir — `ac-pipeline/references/run-id.md`).
> Skip the bead-count setup question — answer is pre-supplied. For baseline test failures:
> apply Phase 0's FIX RUBRIC — fix and commit when all four clauses hold. Only if the rubric
> fails, anchor-dedupe and file exactly ONE bead (typed per the rubric; never P1 by default),
> then proceed. Do not ask. Report when complete as a compact structured
> summary (≤400 words, cap unchanged: beads shipped/closed with IDs, gate outcomes,
> anything blocked, every Agent Mail identity you claimed beads under, AND a structured
> `friction:` block — one item per stage that hit friction, keys `stage` / `cost` /
> `lesson` / `class` (`friction: []` if the stage was clean); see § Child friction schema
> below) — the loop advances to verify → close.
> **Your file territory:** you own exactly these paths: {TERRITORY — explicit list}. Do
> not write outside them. Width-safety (parallel children on disjoint file sets) holds
> for **source files only** — it does NOT hold for shared build/scratch state, disjoint
> in no one's diff: `.next/`, `node_modules/.cache/`, `dist/`, the vitest cache, `/tmp`
> artifact dirs keyed by anything less specific than the claim id, and the beads ledger.
> Treat every one of those as contended even when your source territory is clean:
> serialize through the conductor, or key the path by claim id.
> If any claimed ID is `cross-repo` (or its Repo ownership names agent-compounds /
> root ~/Repos): implement it in THIS session; commit in the repo that tracks the
> bytes per `ac-pipeline/references/commit-discipline.md` § Cross-repo skill/infra
> beads. Do not skip; the other repo's loop cannot see this id."

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

## Batch-close prompt

> "Run ac-batch-close for batch `<batch-id>`{FLAVOR}. CI config for this project:
> `<cached-answer>`. This pipeline has no review panel — the verification gate cleared this
> batch, and standing code quality is ac-hygiene's lane on its own cadence. For uncertain
> CI-finding items: create decision beads (Exhaust Rule). Do not ask 'what's next?' after
> merge."
