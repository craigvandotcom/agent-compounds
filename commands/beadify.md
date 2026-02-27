---
description: Convert refined plan to beads task structure using beads_rust
---

# Flywheel Beadify Command

Convert refined plan to beads task structure using beads_rust.

## I/O Contract

|                  |                                                                                |
| ---------------- | ------------------------------------------------------------------------------ |
| **Input**        | Refined plan file (from `/plan-refine-internal` or `/plan-review-genius`) |
| **Output**       | Beads created in `br` with dependencies, ready for `/bead-refine`  |
| **Artifacts**    | Validation findings in `$ARTIFACTS_DIR/validation-*.md`                        |
| **Verification** | `br list --json`, `br dep cycles`, `br lint`                                   |

## Prerequisites

- Refined plan from `/plan-refine-internal` or `/plan-review` (steady state reached)
- beads_rust (`br`) and beads_viewer (`bv`) installed — verify with `which br && which bv`

## Phase 0: Initialize

**MANDATORY FIRST STEP: Create task list with TaskCreate BEFORE starting.**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

### Configuration

```
ARTIFACTS_DIR=/tmp/beadify-$(date +%Y%m%d-%H%M%S)
```

```bash
mkdir -p "$ARTIFACTS_DIR"
```

### Identify Plan File

Check argument, then `_plans/*.md`, then `PLAN.md` in project root. If none found, STOP: "No plan found. Provide a path or run /plan-init first."

### Create Workflow Tasks

```
TaskCreate(subject: "Phase 1: Analyze plan and propose structure", description: "Read plan, identify epics/tasks/deps, propose bead structure to user", activeForm: "Analyzing plan...")

TaskCreate(subject: "Phase 2: Validate proposed structure (parallel agents)", description: "Spawn 3 validators to check completeness, dependencies, and granularity", activeForm: "Validating structure...")

TaskCreate(subject: "Phase 3: Create beads", description: "Execute br commands to create all beads with descriptions, deps, and comments", activeForm: "Creating beads...")

TaskCreate(subject: "Phase 4: Verify and report", description: "Run br list, dep cycles, lint, ready. Present summary.", activeForm: "Verifying beads...")
```

### Compaction Recovery

If `$ARTIFACTS_DIR/progress.md` exists, parse it to recover state. If beads already exist (`br list --json` returns non-empty), skip to Phase 4 (Verify).

---

## Phase 1: Analyze Plan and Propose Structure

**TaskUpdate(task: "Phase 1", status: "in_progress")**

```
1. Read the refined plan file
2. Identify epic-level groupings
3. Identify task-level items within each epic
4. Identify dependencies between tasks
5. Identify priority indicators (P0/P1/P2)
```

### Present Proposed Structure

Present to user for approval:

```
Epic: User Authentication
├── BR-1: Create user schema (P0, labels: auth,backend)
├── BR-2: Implement JWT middleware (P0, depends: BR-1, labels: auth,backend)
├── BR-3: Add login endpoint (P0, depends: BR-2, labels: auth,api)
├── BR-4: Add registration endpoint (P1, depends: BR-2, labels: auth,api)
└── BR-5: Add password reset (P2, depends: BR-3, labels: auth,api)

Epic: Dashboard
├── BR-6: Create layout component (P0, labels: dashboard,frontend)
├── BR-7: Add navigation (P0, depends: BR-6, labels: dashboard,frontend)
...
```

**Save proposed structure to `$ARTIFACTS_DIR/proposed-structure.md` for validator reference.**

**TaskUpdate(task: "Phase 1", status: "completed")**

---

## Phase 2: Validate Proposed Structure (Parallel Agents)

**TaskUpdate(task: "Phase 2", status: "in_progress")**

**Spawn all 3 validators in a single message for parallel execution.** Each writes findings to `$ARTIFACTS_DIR/validation-{role}.md`.

**Validator 1: Completeness Checker**

```
Task(subagent_type: "general-purpose", model: "sonnet", prompt: """
First: read AGENTS.md for project context, coding standards, and conventions.

You are validating a proposed bead structure against its source plan. You compete with 2 other validators — only evidence-backed findings count.

## Your Task

Cross-reference every section of the plan against the proposed beads. Flag anything dropped, oversimplified, or missing.

## Inputs

### Original Plan
{PLAN_CONTENT}

### Proposed Bead Structure
{PROPOSED_STRUCTURE from artifacts}

## Check

For each plan section/feature:
- Is it fully represented in at least one proposed bead?
- Were any details, edge cases, or requirements lost?
- Are test requirements from the plan captured?

## Output

Write findings to {ARTIFACTS_DIR}/validation-completeness.md

For each issue:
## Issue N: Title
**Severity:** Critical | High | Medium
**Plan section:** <which section>
**Problem:** What's missing or oversimplified
**Fix:** Add bead X, or expand bead Y to include Z

Limit: top 5 issues. Under 400 words. If nothing missing, say so.
""")
```

**Validator 2: Dependency Checker**

```
Task(subagent_type: "general-purpose", model: "sonnet", prompt: """
First: read AGENTS.md for project context, coding standards, and conventions.

You are validating the dependency structure of a proposed bead breakdown. You compete with 2 other validators — only evidence-backed findings count.

## Your Task

Check the proposed dependency graph for correctness — missing links, wrong ordering, potential cycles.

## Inputs

### Proposed Bead Structure
{PROPOSED_STRUCTURE from artifacts}

## Check

Trace the dependency graph for correctness: are links genuine? Are any missing or unnecessary? Could reordering unblock more parallel work? Any cycles? Is the critical path reasonable?

You have codebase access. Read referenced files to verify what actually exists vs what needs to be created. Use your judgment on what matters most for a sound dependency structure.

## Output

Write findings to {ARTIFACTS_DIR}/validation-dependencies.md

For each issue:
## Issue N: Title
**Severity:** Critical | High | Medium
**Bead(s):** <which beads>
**Problem:** Missing/wrong/unnecessary dependency
**Fix:** Add dep X->Y, remove dep A->B, reorder C before D

Limit: top 5 issues. Under 400 words. If structure is sound, say so.
""")
```

**Validator 3: Granularity Reviewer**

```
Task(subagent_type: "general-purpose", model: "sonnet", prompt: """
First: read AGENTS.md for project context, coding standards, and conventions.

You are validating the granularity and sizing of a proposed bead breakdown. You compete with 2 other validators — only evidence-backed findings count.

## Your Task

Check that each bead is right-sized for a single agent session — not too big (needs splitting), and rich enough to be self-contained. Bias toward MORE detail per bead, not less. Thin beads that lack context force agents back to the plan — that's a failure.

## Inputs

### Proposed Bead Structure
{PROPOSED_STRUCTURE from artifacts}

## Check

For each proposed bead:
1. Can an agent implement this in one focused session? (If >5 files or >2 concerns -> split)
2. Is it self-contained? (Must include enough context, acceptance criteria, and reasoning that an agent NEVER needs the original plan)
3. Does it mix backend + frontend work? (-> split candidate)
4. Is the acceptance criteria clear enough for mechanical implementation?
5. Are priorities (P0/P1/P2) assigned correctly? (P0 = critical path, P2 = deferrable)
6. Does it include test requirements? (Every bead should specify what to test)

## Output

Write findings to {ARTIFACTS_DIR}/validation-granularity.md

For each issue:
## Issue N: Title
**Severity:** Critical | High | Medium
**Bead(s):** <which beads>
**Problem:** Too big / too thin (lacking context) / mixed concerns / wrong priority
**Fix:** Split into X+Y, enrich A with missing context, reassign priority

Limit: top 5 issues. Under 400 words. If granularity is good, say so.
""")
```

### Synthesize Validation Results

**Read all 3 validation findings files.** This is your job — do not delegate.

- **Consensus is high-signal** — 2+ validators flagging the same issue is real
- **Critical/High first** — skip Medium unless trivial
- **Apply fixes to the proposed structure** before creating beads

If validators found Critical/High issues, **revise the proposed structure** and present findings for user selection.

**Auto-apply a finding if EITHER condition is met:**

1. **Severity-based:** The issue is Critical or High severity — these are defects, not preferences
2. **Consensus-based:** 2+ validators independently flagged the same issue (regardless of severity) — multi-validator agreement is high-signal

**Apply these immediately. Log them as "Auto-applied".**

**Ask only about remaining items (Medium/Low AND single-validator):**

```
AskUserQuestion(
  questions: [{
    question: "Auto-applied {N} fixes (Critical/High + consensus). {M} single-validator findings remain:",
    header: "Remaining",
    multiSelect: true,
    options: [
      { label: "Fix X: <title>", description: "Medium — <validator>: <one-line summary>" },
      { label: "Fix Y: <title>", description: "Medium — <validator>: <one-line summary>" }
    ]
  }]
)
```

**If no remaining items after auto-apply:** Skip the question entirely — just report what was applied.

**If more than 4 remaining items:** Split across multiple `AskUserQuestion` calls.

Apply selected fixes to the proposed structure. Re-present updated version if structural changes were significant. Only proceed to Phase 3 after the user approves.

**TaskUpdate(task: "Phase 2", status: "completed")**

---

## Phase 3: Create Beads

**TaskUpdate(task: "Phase 3", status: "in_progress")**

After approval, execute using the conversion prompt approach:

```
Take ALL of the approved structure and create a comprehensive set of beads
with tasks, subtasks, and dependency structure. Each bead must be totally
self-contained and self-documenting — include relevant background,
reasoning/justification, considerations, acceptance criteria, and test
requirements. Anything we'd want our "future self" to know about the goals,
intentions, and thought process.

Use only the `br` tool to create and modify beads and add dependencies.
```

### Bead Content Requirements

Each bead description must be **self-contained**:

- Clear acceptance criteria
- Test requirements included
- No need to reference original plan
- "So detailed that we never need the plan again"
- Sufficient background and reasoning that an agent cold-starting on this bead can implement without any other context

Use `--description` for the core spec and `br comments add` for supplementary context (background, reasoning, edge cases).

### Label All Beads as Unrefined

**Every bead created by beadify gets the `unrefined` label.** This signals to `/backlog-next` and `/bead-work` that these beads have not yet been through `/bead-refine`.

```bash
br label add <id> "unrefined"
```

This label is removed by `/bead-refine` when convergence is reached.

### Create Commands Reference

```bash
# Create epics (parent beads)
br create "Epic: User Authentication" --priority P0 --labels "auth" --description "..."

# Create child tasks under epics
br create "Create user schema" --priority P0 --labels "auth,backend" --parent <epic-id> --description "..."

# Add dependencies
br dep add <child-id> <depends-on-id>

# Add rich context as comments
br comments add <id> "Acceptance criteria: ..."
br comments add <id> "Background: ..."
```

Save progress to `$ARTIFACTS_DIR/progress.md` after each epic is created (compaction recovery).

**TaskUpdate(task: "Phase 3", status: "completed")**

---

## Phase 4: Verify and Report

**TaskUpdate(task: "Phase 4", status: "in_progress")**

```bash
# Verify structure
br list --json
br dep cycles   # Must return clean
br lint         # Check for missing sections

# Check unblocked beads
br ready --json

# Verify dependency tree from each epic
br dep tree <epic-id>

# Visual TUI overview
bv
```

### Archive Source Plan

**Once beads are created, the plan is a historical artifact.** Beads are now the source of truth. Archive the plan to enforce this.

1. Update plan frontmatter:
```yaml
---
status: beadified
beadified_at: YYYY-MM-DD
---
```

2. Move plan to `_done/`:
```bash
mv "$PLAN_FILE" "$PROJECT_ROOT/_plans/_done/$(basename $PLAN_FILE)"
```

3. Add a reference comment to the epic bead:
```bash
br comments add <epic-id> "Source plan archived: _plans/_done/$(basename $PLAN_FILE)"
```

**Why archive?** If beads still need the plan, they're not self-contained enough. Archiving forces this discipline. The plan is preserved in `_done/` — it's not deleted, just removed from the active workspace.

### Report

```markdown
## Beadification Complete

**Plan:** {PLAN_FILE} (archived to _done/)
**Epics created:** {count}
**Beads created:** {count} (all labeled `unrefined`)
**Dependencies:** {count}
**Ready to implement:** {count} (`br ready`) — after refinement
**Dep cycles:** {clean/issues}

### Next Step

**Refine beads** -> `/bead-refine` (severity-based convergence with 3 parallel reviewers)

> "Check your beads N times, implement once." Planning tokens are cheaper than implementation tokens. Bead refinement is not optional — it's where the `unrefined` label gets removed and beads become truly agent-ready.
```

**Proceed directly to `/bead-refine`.** Only skip if the user explicitly opts out:

```
AskUserQuestion(
  questions: [{
    question: "Proceeding to /bead-refine (bead refinement is essential). Skip?",
    header: "Refine",
    multiSelect: false,
    options: [
      { label: "Refine beads", description: "Run /bead-refine — recommended, ensures beads are self-contained and agent-ready" },
      { label: "Skip refinement", description: "Go straight to /bead-work — only if you've already refined manually" },
      { label: "Review visually first", description: "Open bv TUI to inspect before refining" }
    ]
  }]
)
```

**TaskUpdate(task: "Phase 4", status: "completed")**

---

## Jeffrey's Standard

> "The beads should be so detailed that we never need to consult back to the original markdown plan document."

---

_Beadify: plan -> beads with parallel validation. For refinement: `/bead-refine`. For implementation: `/bead-work`._
