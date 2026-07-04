---
name: ac-beadify
description: Use to CONVERT an approved/refined plan into a beads task structure (create only). Triggers: 'beadify', 'turn plan into beads', 'create beads from plan', 'break plan into tasks'. Requires an existing plan; to refine the resulting beads afterward use ac-bead-refine.
---


# Flywheel Beadify Command

Convert refined plan to beads task structure using beads_rust.

## I/O Contract

|                  |                                                                                |
| ---------------- | ------------------------------------------------------------------------------ |
| **Input**        | Refined plan file (from `/ac-plan-init`, optionally refined via the `ac-plan-*` skills) |
| **Output**       | Beads created in `br` with dependencies, ready for `/ac-bead-refine`  |
| **Artifacts**    | Validation findings in `$ARTIFACTS_DIR/validation-*.md`                        |
| **Verification** | `br list --json`, `br dep cycles`, `br lint`                                   |

## Prerequisites

- Refined plan from `/ac-plan-init` (steady state reached, optionally via `ac-plan-clean` / `ac-plan-refine-internal` / `ac-plan-refine-external`)
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

Check argument, then `_plans/*.md`, then `PLAN.md` in project root. If none found, STOP: "No plan found. Provide a path or run /ac-plan-init first."

### Plan-Status Gate

Read the plan file's YAML frontmatter `status` field. Only proceed automatically if it is one of:

- `approved`
- `loop-ready`
- `refined`

**Any other value — including `draft`, `in_progress`, or a missing/absent `status` field — is a STOP condition.** A plan that crashed mid-refinement is otherwise indistinguishable from one that reached convergence deliberately; beadifying it bakes half-finished thinking into the beads as if it were settled.

STOP and ask via `AskUserQuestion`:

```
AskUserQuestion(
  questions: [{
    question: "Plan status is '{status}' (expected approved/loop-ready/refined). This plan may be mid-refinement or unfinished — beadifying it now risks converting incomplete thinking into beads. Proceed anyway?",
    header: "Status gate",
    multiSelect: false,
    options: [
      { label: "Override — beadify anyway", description: "I've confirmed this plan is actually ready despite the status field" },
      { label: "Abort", description: "Stop here — run /ac-plan-clean or /ac-plan-refine-internal first, or fix the frontmatter" }
    ]
  }]
)
```

Only continue past this gate on explicit user override.

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
6. Order beads so each commits safely in sequence — every bead independently green +
   shippable (branch/user-surface never left half-wired), add-new-before-remove-old,
   migrations additive-first. Atomic-change escape hatch: a feature flag, or (rare) a
   short-lived sub-branch.
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

**Spawn all 3 validators in a single message for parallel execution.** Use the prompts in **`references/validators.md`** (Completeness, Dependency, Granularity — all Sonnet), substituting `{PLAN_CONTENT}`, `{PROPOSED_STRUCTURE}`, and `{ARTIFACTS_DIR}`. Each writes findings to `$ARTIFACTS_DIR/validation-{role}.md`.

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
- Test requirements included — **plus a declared test scope**: the file paths/globs this bead
  touches, so its per-bead (Tier-1) check runs only the affected tests (feeds `vitest-affected`)
- No need to reference original plan
- "So detailed that we never need the plan again"
- Sufficient background and reasoning that an agent cold-starting on this bead can implement without any other context

Use `--description` for the core spec and `br comments add` for supplementary context (background, reasoning, edge cases).

### Label All Beads as Unrefined

**Every bead created by beadify gets the `unrefined` label.** This signals to `/ac-implement` (and the loop's prep step) that these beads have not yet been through `/ac-bead-refine`.

```bash
br label add <id> "unrefined"
```

This label is removed by `/ac-bead-refine` when convergence is reached.

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

**Refine beads** -> `/ac-bead-refine` (severity-based convergence with 3 parallel reviewers)

> "Check your beads N times, implement once." Planning tokens are cheaper than implementation tokens. Bead refinement is not optional — it's where the `unrefined` label gets removed and beads become truly agent-ready.
```

**Proceed to `/ac-bead-refine`.** Only skip if the user explicitly opts out:

```
AskUserQuestion(
  questions: [{
    question: "Proceeding to /ac-bead-refine (bead refinement is essential). Skip?",
    header: "Refine",
    multiSelect: false,
    options: [
      { label: "Refine beads", description: "Run /ac-bead-refine — recommended, ensures beads are self-contained and agent-ready" },
      { label: "Skip refinement", description: "Go straight to /ac-implement — only if you've already refined manually" },
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

_Beadify: plan -> beads with parallel validation. For refinement: `/ac-bead-refine`. For implementation: `/ac-implement`._

---

## Next: refine the beads

Beadify creates the structure; refinement makes each bead self-contained and agent-ready. That is now a **separate skill** — run **`/ac-bead-refine`** (3 parallel reviewers, severity-based convergence, removes the `unrefined` label). Do not skip it.
