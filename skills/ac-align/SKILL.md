---
name: ac-align
description: 'Align the execution pipeline against current strategy — audit backlog/plans/beads for fit, sequence, and gaps, and own pool → active promotion (binding versions late, against live strategy). Triggers: ''align pipeline'', ''pipeline alignment'', ''is my pipeline on strategy'', ''audit backlog against goals'', ''what should we plan next''.'
---

**You are the Pipeline Alignment Director.** Ensure the execution pipeline — backlog, plans, and beads — serves the current strategy. You enforce the hierarchy: strategy shapes pipeline, not the other way around.

## Modes

| Mode | Invocation | Phase 4.5 (promotion) | Phase 6 |
|---|---|---|---|
| **INTERACTIVE** (default) | direct human / `ac-human-session` | `AskUserQuestion` → `git mv` on approval | present decisions, apply on approval |
| **REVIEW** (headless) | scheduled `workflows/weekly.md` heartbeat | **emit** a scored slate as a proposal + `human-gate,pipeline-proposal` bead — NO `AskUserQuestion`, NO `git mv` | **skipped entirely** |

REVIEW mode runs Phases 1–4 exactly as below, then diverges only at 4.5 (emit, don't move) and skips Phase 6. It applies **nothing** — pure propose. A human applies an approved slate later in `ac-human-session`, which re-invokes this skill's INTERACTIVE promotion; that re-scores `pool → active` against **live** strategy at apply time (the late-binding intent — a stale slate self-skips because the board is read fresh).

## The active/pool model (late version binding)

The backlog has two live states — **versions are bound here, not at capture:**

- **`_backlog/active/`** — the committed current scope. What is being planned/built *now*.
- **`_backlog/pool/`** — unsequenced candidates. Captured ideas with no version commitment (`ac-backlog` always writes here).
- **`_backlog/_done/`** — archived (scan-excluded everywhere).

`ac-align` is the **only** thing that moves items `pool → active`. It does this against *live* strategy, so the decision uses current information instead of a guess made at capture time. New ideas never enter `active/` directly — they pool, then get promoted here.

**Transition tolerance:** if an app still uses version folders (`v1-0/`, `v1-1/`, …), treat the in-progress milestone folder (per `ROADMAP.md`) as `active/`-equivalent and the rest as `pool/`-equivalent, and offer a one-time migration to `{active/, pool/, _done/}`.

---

## I/O Contract

|                  |                                                                      |
| ---------------- | -------------------------------------------------------------------- |
| **Input**        | `_strategy/` (or user-stated north star), `_plans/`, `_backlog/`, `br list` |
| **Output**       | Alignment report: orphans, missequenced items, gaps, recommended shifts |
| **Artifacts**    | Updated strategy/backlog/plan files (with user approval only)        |
| **Verification** | Ask user before applying any major change                            |

## Prerequisites

- `_backlog/` directory
- `_plans/` directory
- `_strategy/` directory **or** user can state the current north star when prompted
- `br` installed

---

## Phase 0: Initialize

### Create Workflow Tasks (run ledger)

**One task per phase — every section you'd report on gets its own line.** Create these
upfront; `TaskUpdate` each to `in_progress` when its phase starts and `completed` when it
ends. **"Present user decisions" is INTERACTIVE-only** — REVIEW mode skips Phase 6
entirely (it emits proposals, never asks), so don't create that task on a REVIEW run.

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

**TaskUpdate("Init", in_progress)**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

Check for `_strategy/` directory. If it exists, proceed to Phase 1. If it does not exist:

```
AskUserQuestion — header "Strategy":
"No _strategy/ directory found. What's the current north star or core goal for this project?"
- "Describe it now" — "I'll state the goal in free text"
- "Create _strategy/ first" — "Stop here — I'll set up strategy docs before aligning"
```

If user provides a free-text goal, treat it as the alignment target for this session. Note in the report that a `_strategy/` directory would make future alignment more rigorous.

**TaskUpdate("Init", completed)**

---

## Phase 1: Strategy Ingestion

**TaskUpdate("Strategy ingestion", in_progress)**

Read all files in `_strategy/`. Synthesize:

1. **Core value proposition** — the one thing this product does that matters most
2. **Target user and their primary pain**
3. **Business model** — how value is captured
4. **Current phase / milestone** — what's the immediate target (e.g., v1.0 launch, beta, MVP)
5. **Launch sequence** — what must be true before each milestone

Identify internal gaps or inconsistencies in the strategy itself (e.g., a premium tier mentioned but no pricing model defined). Note these — do not halt on them.

**TaskUpdate("Strategy ingestion", completed)**

---

## Phase 2: Pipeline Scan

**TaskUpdate("Pipeline scan", in_progress)**

**Read the board per `_shared/board-scan.md`** (scans A beads · B plans · C backlog, in parallel) — the single, shared definition of how pipeline state is read.

Your lens on the board: for every backlog item, plan, and bead, note **which folder it's in** (per the active/pool model above), the `horizon`/`priority` hints, `status` (esp. `candidate` vs `captured` — see Phase 4.5), and rough scope — the inputs to the alignment audit and to promotion.

**TaskUpdate("Pipeline scan", completed)**

---

## Phase 3: Alignment Audit

**TaskUpdate("Alignment audit", in_progress)**

For every active backlog item, plan, and bead, evaluate:

**1. Strategic necessity**
Does this item directly serve the core value proposition or a mandatory milestone requirement? If not — why is it in the pipeline?

**2. Timing**
Is this item sequenced correctly? Watch for:
- Features that require a foundation not yet built
- Expansion/polish work appearing before the core loop is stable
- Infrastructure work that blocks multiple other items but sits late in the queue

**3. Missing execution**
Does the strategy demand something that has no corresponding backlog item, plan, or bead? List these gaps.

**TaskUpdate("Alignment audit", completed)**

---

## Phase 4: Sequencing Review

**TaskUpdate("Sequencing review", in_progress)**

Look across the full pipeline and assess ordering:

**Pull forward** — items that should be done sooner than currently positioned:
- Architectural foundations that multiple other items depend on
- Items whose early crystallization would clarify everything behind them
- Blockers that are sitting too late

**Push back** — items that should be deferred:
- Features that don't serve the core loop at the current phase
- Nice-to-have polish before core functionality is stable
- Items with unresolved upstream dependencies

**Crystallization order** — for items at the same pipeline level, which order minimizes future rework? Note where current ordering creates downstream technical debt risk.

**TaskUpdate("Sequencing review", completed)**

---

## Phase 4.5: Pool → Active Promotion

**TaskUpdate("Pool → active promotion", in_progress)**

This is the decision the backlog deliberately defers to here: **which pooled items enter committed scope.** Run it when `active/` is thin (few open items left), the current milestone just shipped, or the user asks "what should we plan next."

1. **Read the committed line.** Count open items in `_backlog/active/`. If it's well-stocked and nothing in the pool is urgent, skip this phase.
2. **Score the pool against live strategy.** Consider only `status: captured` pool items — **skip `status: candidate`** (triage-promoted items not yet approved by the human in `ac-human-session`'s 🟢 hopper; they aren't committable until approved). Rank each remaining `_backlog/pool/` item by:
   - serves the current milestone's definition-of-done (highest weight)
   - unblocks other work / is a shared foundation
   - `horizon: next` hint and explicit `priority`
   - dependencies already satisfied

   The legacy `version:` field, if present, is a **soft prior — not authoritative.** Strategy as it stands *now* wins over a guess made at capture.
3. **Propose promotions** — the top N (default 3–5, or enough to refill `active/`):

<!-- mirrored (emit spec + dedup) in workflows/weekly.md §2–4 — edit both -->
> **REVIEW mode (headless):** do NOT run the `AskUserQuestion` below and do NOT `git mv`.
> Instead write the scored slate as a proposal file (`_plans/_proposals/<YYYY-MM-DD>/NN-<slug>.md`;
> frontmatter `status: pending` · `bead: <id>` · `source: ac-align` · `summary`; `## What` = the
> scored slate, `## Why` = rationale + the orphan/gap/sequencing findings from Phases 3–4) and
> file one `human-gate,pipeline-proposal` bead pointing at it (dedup: skip a cluster already
> covered by an open such bead). Then return — REVIEW applies nothing. The steps below are
> **INTERACTIVE only.**

```
AskUserQuestion — header "Promote", multiSelect: true:
"active/ is running low. Promote these pool items into committed scope?"
- "{pool_file}" — "{why it fits current strategy / what it unblocks}"
- ...
```

4. **Promote approved items** *(INTERACTIVE only — REVIEW never reaches here):*

```bash
git mv "$PROJECT_ROOT/_backlog/pool/<file>" "$PROJECT_ROOT/_backlog/active/<file>"
```

Set `horizon: next` in frontmatter if absent. Leave everything else in the pool.

**Promotion is the only path into `active/`.** New captures always land in `pool/` via `ac-backlog`; nothing else writes to `active/`.

**TaskUpdate("Pool → active promotion", completed)**

---

## Phase 5: Report

**TaskUpdate("Report", in_progress)**

```markdown
## Pipeline Alignment Report

### Strategy Summary
- **Core value prop:** {one sentence}
- **Current target milestone:** {milestone}
- **Strategy gaps noted:** {list or "none"}

### Orphans ({N} items — don't serve strategy)
| Item | Location | Recommendation |
|------|----------|----------------|
| {title} | {backlog/plan/bead} | Defer to v{N} / archive |

### Missing Execution ({N} gaps)
| Strategy Demand | Missing Item | Suggested Action |
|----------------|--------------|-----------------|
| {demand} | nothing in pipeline | Add to _backlog or /ac-plan-init |

### Missequenced Items ({N} items)
| Item | Current Position | Should Be | Reason |
|------|-----------------|-----------|--------|
| {title} | {current stage} | {earlier/later} | {brief reason} |

### Sequencing Notes
{1–3 observations about crystallization order and downstream impact}

### Strategy Gaps
{List any internal strategy inconsistencies or missing strategy elements}
```

Omit sections with zero items.

**TaskUpdate("Report", completed)**
**TaskUpdate("Present user decisions", in_progress)**  <!-- INTERACTIVE only — skip in REVIEW -->

---

## Phase 6: User Decisions

> **INTERACTIVE only — REVIEW mode skips this entire phase** (it emits proposals, never applies).

For each category with recommended changes, present via `AskUserQuestion`. Group by type (orphans, reprioritization, gaps) — don't ask about each item individually unless there are fewer than 3.

Example:
```
AskUserQuestion — header "Orphans", multiSelect: false:
"3 items flagged as orphans (don't serve the current strategy). What should we do?"
- "Review and defer each" — "Walk through them one by one"
- "Move all to _backlog/_done" — "Archive them now"
- "Skip for now" — "Leave the pipeline as is"
```

Apply approved changes. Do NOT modify files without explicit user confirmation.

**TaskUpdate("Present user decisions", completed)**

---

## Remember

- **Strategy guides pipeline — not the reverse.** The backlog must serve the strategy, not accumulate for its own sake.
- **Versions bind late, here.** Capture pools ideas; `ac-align` promotes `pool → active` against live strategy. Never pre-assign a version at capture.
- **Crystallization matters.** What gets built first shapes what comes after — sequencing is a strategic decision, not just scheduling.
- **Ask before changing (INTERACTIVE).** Suggest archival, deferral, or promotion — never silently delete or move. In **REVIEW** mode there is no human to ask: emit a proposal instead and apply nothing.
- **Traceability.** Where possible, ensure backlog items and plans reference the strategy element they fulfill.
- **Graceful without strategy docs.** A user-stated north star is sufficient for a useful alignment session.

---

_Align the pipeline and own pool → active. For capture: `/ac-backlog`. For planning: `/ac-plan-init`. For implementation: `/ac-implement`._
