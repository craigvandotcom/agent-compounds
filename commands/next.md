---
description: Pipeline dashboard — scan backlog/plans/beads, show funnel status, offer next action
---

**You are a pipeline scanner.** Read-only. No mutations. Scan all three data stores, cross-reference, report status, and offer the most actionable next step.

---

## I/O Contract

|                  |                                                                      |
| ---------------- | -------------------------------------------------------------------- |
| **Input**        | None (reads project state directly)                                  |
| **Output**       | Pipeline funnel report + interactive action selection                 |
| **Artifacts**    | None (stateless — no temp files)                                     |
| **Verification** | N/A (read-only command)                                              |

## Prerequisites

- beads_rust (`br`) installed — verify with `which br`
- Project has `_backlog/` directory (optional — skipped if missing)
- Project has `.claude/plans/` directory (optional — skipped if missing)

---

## Phase 0: Initialize

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

Read `AGENTS.md` for project context.

---

## Phase 1: Scan (parallel)

Run all three scans simultaneously. Each scan collects structured data for Phase 2.

### Scan A: Beads

```bash
br list --json
br ready --json
```

Categorize every bead into one of:

| Category | Criteria |
|----------|----------|
| **Ready** | Appears in `br ready` output (status=open, all deps satisfied) |
| **Blocked** | status=open but NOT in ready list (has unsatisfied deps) |
| **In Progress** | status=in_progress |
| **Closed** | status=closed or done |

For each epic (beads with `dependent_count > 3` or "epic" in title), count: total children, ready children, blocked children, closed children.

### Scan B: Plans

```bash
# List active plans (not in _done/ or subdirectories)
ls "$PROJECT_ROOT/.claude/plans/"*.md 2>/dev/null
```

For each plan file, read the first 50 lines to determine:

1. **Has matching beads?** — Check if any bead's `description` field references the plan filename. If yes, mark as "beadified".
2. **Approval state** — Look for markers like `APPROVED`, `Status: approved`, `## Approval`, or similar in the plan content. If absent, mark as "needs refinement".
3. **Size** — File size as a rough complexity indicator.

Skip: `README.md`, files in `_done/`, `research/`, `refinement-reports/`, `templates/`, `review/`, `checkpoints/`, `testing/`.

### Scan C: Backlog

```bash
# Find backlog files (skip templates, meta files, done/shipped)
find "$PROJECT_ROOT/_backlog" -name "*.md" \
  -not -name "_*" -not -name "ROADMAP.md" -not -name "BUSINESS-STRATEGY.md" \
  -not -path "*/_done/*" -not -path "*/_shipped/*" -not -path "*/complete/*" \
  -not -path "*/assets/*" -not -path "*/audits/*" \
  2>/dev/null
```

For each backlog file, read it and extract:

1. **Status** from frontmatter (`status: captured`, `status: planned`, `status: complete`)
2. **Task count** — count `- [ ]` lines (uncompleted tasks)
3. **Version milestone** — from frontmatter or parent directory name (v1-0, v1-1, etc.)
4. **Has matching plan?** — Check if any active plan references this backlog item or covers the same domain. Use filename keywords to fuzzy-match.

Only include items with `status != complete` and at least one unchecked task.

---

## Phase 2: Cross-Reference + Prioritize

Build a single ordered list by pipeline stage (most actionable first):

### Priority Order

1. **Ready beads** — can be built right now. Sort by: priority (desc), then dependency_count (asc, prefer leaf beads).
2. **Plans ready to beadify** — approved plans with no matching beads in `br`. These are one `/beadify` away from implementation.
3. **Plans needing refinement** — draft plans that need `/plan-refine-internal` or review.
4. **Backlog needing planning** — captured items not yet covered by any plan. These need `/plan-init`.
5. **Blocked beads** — shown as epic summaries for awareness, not actionable directly.

---

## Phase 3: Report

Output a concise funnel report. Use exact counts. No fluff.

```
## Pipeline Status

### Ready to Build ({count} beads)
  {id}  {title}  [{priority}, {dep info}]
  {id}  {title}  [{priority}, {dep info}]
  ...
  (show top 8, then "{N} more..." if truncated)

### In Progress ({count} beads)
  {id}  {title}  [claimed by {user}]
  (show all — should be small)

### Blocked ({count} beads across {epic_count} epics)
  {epic_id}  {epic_title}  ({ready}/{total} children ready)
  ...

### Plans Awaiting Beadification ({count})
  {filename}  [{approval state}]
  ...

### Plans Awaiting Refinement ({count})
  {filename}  [{size indicator}]
  ...

### Backlog Awaiting Planning ({count} items across {file_count} files)
  {version}/{filename}  [{task_count} tasks]
  ...
```

**Omit any section with zero items.** Don't show empty categories.

After the funnel, output a one-line summary:

```
Pipeline: {ready_beads} ready | {blocked_beads} blocked | {plans_to_beadify} plans pending | {backlog_items} backlog items
```

---

## Phase 4: Offer Next Actions

Generate up to 4 options from the prioritized list. Each option maps to a specific downstream command. Pick the top item from each non-empty category (max 4 total, in priority order).

**Option generation rules:**

| Category | Action Label | Suggested Command |
|----------|-------------|-------------------|
| Ready beads | "Build: {bead_id} — {title}" | `/bead-work` |
| Plans to beadify | "Beadify: {filename}" | `/beadify {path}` |
| Plans to refine | "Refine: {filename}" | `/plan-refine-internal {path}` |
| Backlog to plan | "Plan: {filename}" | `/plan-init` (reference the backlog) |

Present via `AskUserQuestion`:

```
AskUserQuestion(
  questions: [{
    question: "Pick your next action:",
    header: "What's Next",
    multiSelect: false,
    options: [
      { label: "<action 1>", description: "<suggested command to run>" },
      { label: "<action 2>", description: "<suggested command to run>" },
      { label: "<action 3>", description: "<suggested command to run>" },
      { label: "<action 4>", description: "<suggested command to run>" },
      { label: "Just browsing", description: "No action — I wanted the status report" }
    ]
  }]
)
```

Always include "Just browsing" as the final option.

### After Selection

When the user selects an action, **print the command they should run** with the appropriate arguments. Do NOT attempt to run the command yourself — `/next` is read-only.

Example output after selection:

```
Run this:

  /bead-work

Target bead bd-2ec.4 (transition_zone RPC) — it's highest priority with no blockers.
```

---

## Remember

- **Read-only** — no file writes, no bead mutations, no git operations
- **Fast** — scan and report, don't analyze deeply. Plans get 50 lines, not full reads
- **Honest** — if cross-referencing is ambiguous, say so. Don't guess plan↔bead mappings
- **Stateless** — no artifacts, no temp files, no progress tracking
- **Omit empty sections** — only show categories that have items
- **"Just browsing" always available** — not every scan leads to action

---

_Pipeline dashboard — scan, report, decide. For implementation: `/bead-work`. For planning: `/plan-init`._
