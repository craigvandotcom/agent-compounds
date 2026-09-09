# ac-align — phase mechanics

Mode-scoped detail behind the spine. The spine carries the run contract and decision points;
this file carries the how. Read the spine first — the phases here are keyed to its section
numbers.

## Phase 0 — initialize mechanics

Run-ledger task list (one `TaskCreate` per phase; `TaskUpdate` to `in_progress`/`completed`
as each phase starts/ends; unavailable → track inline in progress.md):

```
TaskCreate("Init — resolve _strategy/ or a stated north star")
TaskCreate("Strategy ingestion — synthesize value prop, user, milestone, launch sequence")
TaskCreate("Pipeline scan — read the board (beads/plans/backlog)")
TaskCreate("Alignment audit — strategic necessity, timing, missing execution")
TaskCreate("Sequencing review — pull-forward/push-back/crystallization order")
TaskCreate("Pool → active promotion")
TaskCreate("Report — alignment findings")
TaskCreate("Present user decisions")   # INTERACTIVE only — omit for REVIEW mode
```

Ledger contract: `ac-pipeline/references/run-ledger.md` — one task per section, advance as
you go; ledger = run position, never work items.

`_strategy/` resolution: `PROJECT_ROOT=$(git rev-parse --show-toplevel)`. If `_strategy/`
exists, proceed to Phase 1. If not:

```
AskUserQuestion — header "Strategy":
"No _strategy/ directory found. What's the current north star or core goal for this project?"
- "Describe it now" — "I'll state the goal in free text"
- "Create _strategy/ first" — "Stop here — I'll set up strategy docs before aligning"
```

A free-text goal is a valid alignment target; note in the report that `_strategy/` would make
future alignment more rigorous.

## Phase 1 — strategy ingestion detail

Read all files in `_strategy/`. Synthesize:

1. **Core value proposition** — the one thing this product does that matters most
2. **Target user and their primary pain**
3. **Business model** — how value is captured
4. **Current phase / milestone** — the immediate target (e.g., v1.0 launch, beta, MVP)
5. **Launch sequence** — what must be true before each milestone

Identify internal gaps or inconsistencies in the strategy itself (e.g., a premium tier
mentioned but no pricing model defined). Note these — do not halt on them.

## Phase 2 — pipeline scan lens

Read the board per `ac-pipeline/references/board-scan.md` (scans A beads · B plans · C
backlog, in parallel) — the single, shared definition of how pipeline state is read. Your
lens on the board: for every backlog item, plan, and bead, note which folder it's in (per the
active/pool model), the `horizon`/`priority` hints, `status` (esp. `candidate` vs `captured`
— see Phase 4.5), and rough scope — the inputs to the alignment audit and to promotion.

## Phase 4 — sequencing review detail

Across the full pipeline, assess ordering:

**Pull forward** — items that should be done sooner:
- Architectural foundations that multiple other items depend on
- Items whose early crystallization would clarify everything behind them
- Blockers that are sitting too late

**Push back** — items that should be deferred:
- Features that don't serve the core loop at the current phase
- Nice-to-have polish before core functionality is stable
- Items with unresolved upstream dependencies

**Crystallization order** — for items at the same pipeline level, which order minimizes
future rework? Note where current ordering creates downstream technical debt risk.

## Phase 4.5 — promotion mechanics

Score the pool against live strategy (spine § Phase 4.5). Promotion mechanics:

**INTERACTIVE — promote approved items:**

```
AskUserQuestion — header "Promote", multiSelect: true:
"active/ is running low. Promote these pool items into committed scope?"
- "{pool_file}" — "{why it fits current strategy / what it unblocks}"
- ...
```

On approval:

```bash
git mv "$PROJECT_ROOT/_backlog/pool/<file>" "$PROJECT_ROOT/_backlog/active/<file>"
```

Set `horizon: next` in frontmatter if absent. Leave everything else in the pool.
**Promotion is the only path into `active/`.** New captures always land in `pool/` via
`ac-backlog`; nothing else writes to `active/`.

**REVIEW — emit the slate** (spine § Phase 4.5): proposal file + `human-gate,pipeline-proposal`
bead, dedup on an open such bead's populated `bead:` slot. REVIEW applies nothing.

## Transition tolerance (legacy version folders)

If an app still uses version folders (`v1-0/`, `v1-1/`, …), treat the in-progress milestone
folder (per `ROADMAP.md`) as `active/`-equivalent and the rest as `pool/`-equivalent, and
offer a one-time migration to `{active/, pool/, _done/}`.

## Remember (doctrine, full set)

- **Strategy guides pipeline — not the reverse.** The backlog must serve the strategy, not
  accumulate for its own sake.
- **Versions bind late, here.** Capture pools ideas; `ac-align` promotes `pool → active`
  against live strategy. Never pre-assign a version at capture.
- **Crystallization matters.** What gets built first shapes what comes after — sequencing is
  a strategic decision, not just scheduling.
- **Ask before changing (INTERACTIVE).** Suggest archival, deferral, or promotion — never
  silently delete or move. In **REVIEW** mode there is no human to ask: emit a proposal
  instead and apply nothing.
- **Traceability.** Where possible, ensure backlog items and plans reference the strategy
  element they fulfill.
- **Graceful without strategy docs.** A user-stated north star is sufficient for a useful
  alignment session.