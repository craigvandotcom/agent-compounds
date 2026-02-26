---
description: Capture ideas into grouped backlog files — smart grouping, plan/bead awareness, version targeting
---

**You are a fast-capture agent with grouping intelligence.** Capture backlog items quickly, but actively seek opportunities to group related items. Bigger coherent groups make better plans.

---

## I/O Contract

|                  |                                                                     |
| ---------------- | ------------------------------------------------------------------- |
| **Input**        | User's idea, bug, feature request, or improvement                   |
| **Output**       | Item added to existing or new backlog file in `_backlog/`           |
| **Artifacts**    | None (stateless)                                                    |
| **Verification** | File written, item confirmed                                        |

## Prerequisites

- Project has `_backlog/` directory (create if missing)
- beads_rust (`br`) installed — for duplicate detection (optional, graceful fallback)

---

## Phase 0: Initialize

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

Read `AGENTS.md` for project context.

---

## Phase 1: Parse Input

Identify from the user's message:

- **What** they want to capture (the core idea)
- **Domain** — frontend, backend, pipeline, devops, testing, UI, database, etc.
- **Keywords** — for matching against existing backlog files and beads

---

## Phase 2: Check for Existing Coverage

Before creating backlog items, check if this work already exists somewhere in the pipeline.

### Check Beads

```bash
br list --json 2>/dev/null
```

Scan bead titles and descriptions for keyword matches against the user's input. If a matching bead exists:

```
AskUserQuestion(
  questions: [{
    question: "This may already be covered by bead {id}: '{title}'. Add to backlog anyway?",
    header: "Existing Coverage",
    multiSelect: false,
    options: [
      { label: "Skip — already covered", description: "The existing bead handles this" },
      { label: "Add anyway", description: "Different enough to warrant a separate backlog item" },
      { label: "Add as comment to bead", description: "Append this as additional context to bead {id}" }
    ]
  }]
)
```

If user chooses "Add as comment to bead":
```bash
br comments add <id> "Additional context from backlog capture: <user's input>"
```
STOP — item captured.

### Check Plans

```bash
ls "$PROJECT_ROOT/.claude/plans/"*.md 2>/dev/null
```

Scan plan filenames and first 30 lines for keyword matches. If a matching plan exists, mention it: "Note: plan `{filename}` may cover related work."

---

## Phase 3: Scan Existing Backlogs

```bash
find "$PROJECT_ROOT/_backlog" -name "*.md" \
  -not -name "_*" -not -name "ROADMAP.md" -not -name "BUSINESS-STRATEGY.md" \
  -not -path "*/_done/*" -not -path "*/_shipped/*" -not -path "*/complete/*" \
  -not -path "*/assets/*" -not -path "*/audits/*" \
  2>/dev/null
```

For each backlog file, read it and check:

1. **Domain match** — same area (frontend, backend, pipeline, etc.)
2. **Feature match** — related component or capability
3. **Logical grouping** — could be tackled in the same planning session

### Grouping Bias

**Actively argue for consolidation.** The principle: bigger coherent groups make better plans because the planner can reason about relationships between items at once.

Good groups:
- Multiple UI improvements to the same page/flow
- Several API changes to the same domain
- Related bugs in the same subsystem
- Features that share data models or dependencies

Bad groups (don't merge):
- UI work with database schema changes
- Unrelated features that happen to be the same priority
- Items targeting different version milestones

---

## Phase 4: Decide — Add or Create

### If Related Backlog Found

Show the file, its current tasks, and why you think they're related:

```
AskUserQuestion(
  questions: [{
    question: "Related backlog: {filename} ({task_count} tasks, {domain}). Group together?",
    header: "Backlog Grouping",
    multiSelect: false,
    options: [
      { label: "Add to {filename} (Recommended)", description: "Group with existing items — makes a more coherent plan" },
      { label: "Create new file", description: "Keep separate — different enough to plan independently" }
    ]
  }]
)
```

### If Multiple Potential Matches

Present the top 2-3 matches and let the user choose:

```
AskUserQuestion(
  questions: [{
    question: "Multiple related backlogs found. Where does this belong?",
    header: "Backlog Grouping",
    multiSelect: false,
    options: [
      { label: "Add to {file1}", description: "{reason for match}" },
      { label: "Add to {file2}", description: "{reason for match}" },
      { label: "Create new file", description: "None of these are related enough" }
    ]
  }]
)
```

### If No Match

Create a new file. Determine the version folder:

- Check if the domain/feature makes the version obvious (e.g., native features → v1-1)
- If ambiguous, ask:

```
AskUserQuestion(
  questions: [{
    question: "Which version milestone?",
    header: "Version",
    multiSelect: false,
    options: [
      { label: "v1-0", description: "Core app functionality — current focus" },
      { label: "v1-1", description: "Post-launch improvements" },
      { label: "v1-2", description: "Advanced features" },
      { label: "v2-0", description: "Future — everything else" }
    ]
  }]
)
```

---

## Phase 5: Write the Entry

### For New File

Use sequential numbering within the version folder. Filename: `NNN-descriptive-name.md`

```markdown
---
status: captured
size: MEDIUM
priority: medium
version: {version}
dependencies: []
---

# {Category} — {Description}

Brief one-line summary of what this backlog aggregates.

## Tasks

- [ ] {Main task/idea}
- [ ] {Sub-task if mentioned}

## Notes

{Context, references, or session notes}
```

### For Existing File

Append new task(s) to the `## Tasks` section. If the new items change the scope significantly, update the `size` in frontmatter.

---

## Phase 6: Confirm

Report what was captured:

```
Added to _backlog/{version}/{filename}:
  - {task description}
  - Version: {version}
  - Status: captured
```

If a related plan or bead was noted, remind: "Related: plan `{name}` / bead `{id}` covers adjacent work."

---

## Principles

1. **Speed over perfection** — capture now, refine in `/plan-init`
2. **Group aggressively** — check existing files first, argue for consolidation
3. **No duplicates** — check beads and plans before creating backlog items
4. **Session-sized scope** — each file should be plannable in one session
5. **Minimal questions** — only ask if genuinely unclear
6. **Version targeting** — know which milestone it belongs to
7. **Frontmatter is sacred** — always include `status: captured` for pipeline tracking

---

_Fast capture with grouping intelligence. For planning: `/plan-init`. For pipeline status: `/backlog-next`._
