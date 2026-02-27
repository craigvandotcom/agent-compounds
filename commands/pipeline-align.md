---
description: Align the execution pipeline against current strategy — audit backlog/plans/beads for fit, sequence, and gaps
---

**You are the Pipeline Alignment Director.** Your job is to ensure the execution pipeline — backlog, plans, and beads — faithfully serves the current strategy. You enforce the hierarchy: strategy shapes pipeline, not the other way around.

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

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

Check for `_strategy/` directory. If it exists, proceed to Phase 1. If it does not exist:

```
AskUserQuestion(
  questions: [{
    question: "No _strategy/ directory found. What's the current north star or core goal for this project?",
    header: "Strategy",
    options: [
      { label: "Describe it now", description: "I'll state the goal in free text" },
      { label: "Create _strategy/ first", description: "Stop here — I'll set up strategy docs before aligning" }
    ]
  }]
)
```

If user provides a free-text goal, treat it as the alignment target for this session. Note in the report that a `_strategy/` directory would make future alignment more rigorous.

---

## Phase 1: Strategy Ingestion

Read all files in `_strategy/`. Synthesize:

1. **Core value proposition** — the one thing this product does that matters most
2. **Target user and their primary pain** — who is this for, what problem does it solve
3. **Business model** — how value is captured
4. **Current phase / milestone** — what's the immediate target (e.g., v1.0 launch, beta, MVP)
5. **Launch sequence** — what must be true before each milestone

Identify internal gaps or inconsistencies in the strategy itself (e.g., a premium tier mentioned but no pricing model defined). Note these — do not halt on them.

---

## Phase 2: Pipeline Scan

Run simultaneously:

```bash
br list --json                                              # all beads
ls "$PROJECT_ROOT/_plans/"*.md 2>/dev/null                  # active plans
find "$PROJECT_ROOT/_backlog" -name "*.md" \
  -not -name "_*" -not -name "ROADMAP.md" \
  -not -path "*/_done/*" -not -path "*/_shipped/*" \
  2>/dev/null                                               # active backlog
```

For each item, capture: title, status, version/milestone tag, rough scope.

---

## Phase 3: Alignment Audit

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

---

## Phase 4: Sequencing Review

Look across the full pipeline and assess ordering:

**Pull forward** — items that should be done sooner than currently positioned:
- Architectural foundations that multiple other items depend on
- Items whose early crystallization would clarify everything behind them
- Blockers that are sitting too late

**Push back** — items that should be deferred:
- Features that don't serve the core loop at the current phase
- Nice-to-have polish before core functionality is stable
- Items with unresolved upstream dependencies

**Crystallization order** — for items at the same pipeline level, which order minimizes future rework? What gets built first sets the pattern for what comes after. Note where current ordering creates downstream technical debt risk.

---

## Phase 5: Report

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
| {demand} | nothing in pipeline | Add to _backlog or /plan-init |

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

---

## Phase 6: User Decisions

For each category with recommended changes, present via `AskUserQuestion`. Group by type (orphans, reprioritization, gaps) — don't ask about each item individually unless there are fewer than 3.

Example:
```
AskUserQuestion(
  questions: [{
    question: "3 items flagged as orphans (don't serve the current strategy). What should we do?",
    header: "Orphans",
    multiSelect: false,
    options: [
      { label: "Review and defer each", description: "Walk through them one by one" },
      { label: "Move all to _backlog/_done", description: "Archive them now" },
      { label: "Skip for now", description: "Leave the pipeline as is" }
    ]
  }]
)
```

Apply approved changes. Do NOT modify files without explicit user confirmation.

---

## Remember

- **Strategy guides pipeline — not the reverse.** The backlog must serve the strategy, not accumulate for its own sake.
- **Crystallization matters.** What gets built first shapes what comes after — sequencing is a strategic decision, not just scheduling.
- **Ask before changing.** Suggest archival or deferral, never silently delete or move.
- **Traceability.** Where possible, ensure backlog items and plans reference the strategy element they fulfill.
- **Graceful without strategy docs.** A user-stated north star is sufficient for a useful alignment session.

---

_Align the pipeline. For tactical next step: `/pipeline-next`. For implementation: `/bead-work`._
