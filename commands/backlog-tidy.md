---
description: Pipeline housekeeping — archive completed items, reconcile plans/beads/backlog, suggest merges
---

**You are the pipeline janitor.** Scan all three data stores, reconcile lifecycle state, archive completed work, flag orphans, suggest consolidation. All moves require user confirmation.

---

## I/O Contract

|                  |                                                                      |
| ---------------- | -------------------------------------------------------------------- |
| **Input**        | None (reads project state directly)                                  |
| **Output**       | Tidied pipeline — items archived, statuses reconciled, orphans flagged |
| **Artifacts**    | None (stateless)                                                     |
| **Verification** | Report of all changes made                                           |

## Prerequisites

- beads_rust (`br`) installed — verify with `which br`
- Project has `_backlog/` and/or `.claude/plans/` directories

---

## Phase 0: Initialize

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

Read `AGENTS.md` for project context.

---

## Phase 1: Scan Everything

Run all three scans. Collect structured data for reconciliation.

### Scan Beads

```bash
br list --json
```

Categorize:
- **Closed beads** — status=closed or done
- **Open beads** — status=open
- **Beads with `unrefined` label** — not yet through `/bead-refine`
- **Epic beads** — have dependents (track child completion ratios)

For each epic: count total children, closed children, open children.

### Scan Plans

```bash
ls "$PROJECT_ROOT/.claude/plans/"*.md 2>/dev/null
```

For each plan (skip `README.md`, subdirectories):

1. Read frontmatter for `status` field
2. Check for `## Refinement Log` (indicates refinement has occurred)
3. Check if referenced by any bead description (indicates beadified)
4. Note `source_backlog` field if present

### Scan Backlog

```bash
find "$PROJECT_ROOT/_backlog" -name "*.md" \
  -not -name "_*" -not -name "ROADMAP.md" -not -name "BUSINESS-STRATEGY.md" \
  -not -path "*/_done/*" -not -path "*/_shipped/*" -not -path "*/complete/*" \
  -not -path "*/assets/*" -not -path "*/audits/*" \
  2>/dev/null
```

For each backlog file:
1. Read frontmatter `status` and `plans` fields
2. Count unchecked tasks (`- [ ]`) vs checked (`- [x]`)
3. Note version folder

---

## Phase 2: Reconcile Lifecycle State

### 2a: Archive Completed Backlog Items

**Condition:** All tasks checked off (`- [x]`) OR frontmatter `status: complete`

**Action:** Propose moving to `_backlog/_done/`:

```
AskUserQuestion(
  questions: [{
    question: "{count} backlog files appear complete. Archive them?",
    header: "Archive Backlog",
    multiSelect: true,
    options: [
      { label: "{filename}", description: "{checked}/{total} tasks done" },
      ...
    ]
  }]
)
```

For approved items:
1. Update frontmatter: `status: complete`
2. Move to `_backlog/_done/`

### 2b: Archive Beadified Plans

**Condition:** Plan frontmatter `status: beadified` OR plan is referenced by beads in `br` AND all those beads exist

Plans that have been fully converted to beads are historical artifacts — beads are now the source of truth.

**Action:** Propose moving to `.claude/plans/_done/`:

```
AskUserQuestion(
  questions: [{
    question: "{count} plans have been beadified. Archive to _done/?",
    header: "Archive Plans",
    multiSelect: true,
    options: [
      { label: "{filename}", description: "Beadified — beads are the source of truth" },
      ...
    ]
  }]
)
```

For approved items:
1. Update frontmatter: `status: done`
2. Move to `.claude/plans/_done/`

### 2c: Archive Completed Plans (All Beads Closed)

**Condition:** Plan has matching beads AND all matching beads are closed

**Action:** Same archive flow as 2b, but with different description:

```
{ label: "{filename}", description: "All {count} beads closed — work complete" }
```

### 2d: Update Backlog Status for Planned Items

**Condition:** Backlog file has `status: captured` but a matching plan exists (either via `plans:` frontmatter field or keyword matching)

**Action:** Update frontmatter to `status: planned` and add `plans:` field if missing.

Report: "Updated {filename}: status → planned (plan: {plan_name})"

### 2e: Fix Missing Plan Frontmatter

**Condition:** Plan files that lack YAML frontmatter entirely

**Action:** Infer status from content:
- Has `## Refinement Log` with rounds → `status: refined`
- Has `Status: Approved` text → `status: approved`
- Referenced by beads → `status: beadified`
- None of the above → `status: draft`

Add frontmatter:

```yaml
---
status: {inferred}
refinement_rounds: {count from Refinement Log, or 0}
---
```

Report each inference for user awareness.

---

## Phase 3: Flag Orphans

### Orphan Plans
- Plans with no matching backlog item AND no beads referencing them
- Report: "Orphan plan: {filename} — no backlog source, no beads. Where did this come from?"

### Orphan Beads
- Beads whose description references a plan file that doesn't exist (not in active or `_done/`)
- Report: "Orphan bead {id}: references plan {name} which doesn't exist"

### Stale Backlog
- Backlog items with `status: planned` but linked plan has been archived/deleted
- Report: "Stale backlog: {filename} says 'planned' but plan is gone"

### Stale "In Progress" Items
- Backlog with `status: in_progress` but no recent git activity in related files (>30 days)
- Report as informational, don't auto-change

---

## Phase 4: Suggest Consolidation

Scan active backlog files for merge opportunities:

### Small File Merge Candidates
- Files with only 1-2 unchecked tasks in the same domain
- Propose: "Merge {file1} (1 task) + {file2} (2 tasks)? Both are {domain}."

### Duplicate Detection
- Backlog items that describe the same work in different words
- Propose: "Possible duplicate: {file1} task '{task}' ≈ {file2} task '{task}'?"

Present merge suggestions (if any) via `AskUserQuestion`. Only suggest, never force.

---

## Phase 5: Report

```
## Backlog Tidy Report

### Archived
- {count} backlog files → _done/
- {count} plans → _done/

### Status Updates
- {count} backlog items: captured → planned
- {count} plans: frontmatter added/corrected

### Orphans Flagged
- {count} orphan plans (no source, no beads)
- {count} orphan beads (missing plan reference)
- {count} stale backlog items

### Merge Suggestions
- {count} potential consolidations offered

### Pipeline Health
- Active backlog items: {count} across {file_count} files
- Active plans: {count} ({draft}/{refined}/{approved}/{beadified})
- Active beads: {count} ({ready}/{blocked}/{in_progress})
```

### Commit Changes

If any files were moved or updated:

```bash
git add -A _backlog/ .claude/plans/
git commit -m "$(cat <<'EOF'
chore: backlog-tidy — archive completed items, reconcile pipeline state

{summary of changes}

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
git push
```

---

## Remember

- **All moves require confirmation** — never archive without asking
- **Infer conservatively** — when in doubt about status, flag rather than change
- **Beads are source of truth** — once beadified, the plan is archival
- **Frontmatter is the API** — pipeline tracking depends on structured metadata
- **Suggest, don't force merges** — consolidation is a recommendation
- **Run before `/backlog-next`** — clean pipeline makes better recommendations

---

_Pipeline janitor — archive, reconcile, flag, suggest. For capturing: `/backlog-add`. For next action: `/backlog-next`._
