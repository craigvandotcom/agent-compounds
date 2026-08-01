---
name: ac-beadify
description: 'Use to CONVERT an approved/refined plan into a beads task structure (create only). Triggers: ''beadify'', ''turn plan into beads'', ''create beads from plan'', ''break plan into tasks''. Requires an existing plan; to refine the resulting beads afterward use ac-bead-refine.'
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
# Mint RUN_ID if the orchestrator didn't hand one down (contract: ac-pipeline/references/run-id.md
# mint-if-absent rule) — keeps standalone and orchestrated runs on the same formula.
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"
ARTIFACTS_DIR=/tmp/beadify-${RUN_ID}   # RUN_ID carries the PID → no same-second collision (ac-pipeline/references/run-id.md)
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

**Any other value — including `draft`, `in_progress`, or a missing/absent `status` field — is a STOP condition:** a plan that crashed mid-refinement is indistinguishable from one that converged deliberately, and beadifying it bakes half-finished thinking into the beads as if it were settled.

STOP and ask via `AskUserQuestion`:

```
question: "Plan status is '{status}' (expected approved/loop-ready/refined). This plan may be mid-refinement or unfinished — beadifying it now risks converting incomplete thinking into beads. Proceed anyway?"
header: "Status gate"
multiSelect: false
options:
  - label: "Override — beadify anyway"
    description: "I've confirmed this plan is actually ready despite the status field"
  - label: "Abort"
    description: "Stop here — run /ac-plan-clean or /ac-plan-refine-internal first, or fix the frontmatter"
```

Only continue past this gate on explicit user override.

### Create Workflow Tasks

**One task per major section — every section you'd report on gets its own ledger line.**

```
TaskCreate(subject: "Analyze plan and propose structure", description: "Read plan, identify epics/tasks/deps, propose bead structure to user", activeForm: "Analyzing plan...")

TaskCreate(subject: "Validate proposed structure (3 parallel agents) + synthesize", description: "Spawn Completeness/Dependency/Granularity validators, read all findings, auto-apply Critical/High + consensus fixes", activeForm: "Validating structure...")

TaskCreate(subject: "Present structure for user approval", description: "Ask about remaining single-validator findings, apply selections, gate on explicit approval before creating beads", activeForm: "Awaiting approval...")

TaskCreate(subject: "Create beads", description: "Execute br commands to create all beads with descriptions, deps, comments, and the unrefined label", activeForm: "Creating beads...")

TaskCreate(subject: "Verify bead structure", description: "Run br list, dep cycles, lint, ready, dep tree, bv", activeForm: "Verifying beads...")

TaskCreate(subject: "Archive source plan", description: "Update plan frontmatter to beadified, move to _plans/_done/, reference from epic bead", activeForm: "Archiving source plan...")

TaskCreate(subject: "Report + handoff to ac-bead-refine", description: "Present beadification summary, proceed to bead refinement unless user opts out", activeForm: "Reporting...")
```

### Compaction Recovery

If `$ARTIFACTS_DIR/progress.md` exists, parse it to recover state. If beads already exist (`br list --json` returns non-empty), skip to Phase 4 (Verify).

---

## Phase 1: Analyze Plan and Propose Structure

**TaskUpdate(task: "Analyze plan and propose structure", status: "in_progress")**

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

**TaskUpdate(task: "Analyze plan and propose structure", status: "completed")**

---

## Phase 2: Validate Proposed Structure (Parallel Agents)

**TaskUpdate(task: "Validate proposed structure (3 parallel agents) + synthesize", status: "in_progress")**

**Spawn all 3 validators in a single message for parallel execution.** Use the prompts in **`references/validators.md`** (Completeness, Dependency, Granularity — all Sonnet), substituting `{PLAN_CONTENT}`, `{PROPOSED_STRUCTURE}`, and `{ARTIFACTS_DIR}`. Each writes findings to `$ARTIFACTS_DIR/validation-{role}.md`.

### Synthesize Validation Results

**Read all 3 validation findings files.** This is your job — do not delegate.

- **Consensus is high-signal** — 2+ validators flagging the same issue is real
- **Critical/High first** — skip Medium unless trivial
- **Apply fixes to the proposed structure** before creating beads

If validators found Critical/High issues, **revise the proposed structure** and present findings for user selection.

<!-- mirror of ac-pipeline/references/review-consensus.md §The auto-apply cascade (conditions 1-2; beadify is single-round, no cross-round condition) — edit there first -->
**Auto-apply a finding if EITHER condition is met:**

1. **Severity-based:** The issue is Critical or High severity — these are defects, not preferences
2. **Consensus-based:** 2+ validators independently flagged the same issue (regardless of severity) — multi-validator agreement is high-signal

**Apply these immediately. Log them as "Auto-applied".**

**TaskUpdate(task: "Validate proposed structure (3 parallel agents) + synthesize", status: "completed")**
**TaskUpdate(task: "Present structure for user approval", status: "in_progress")**

**Ask only about remaining items (Medium/Low AND single-validator):**

```
question: "Auto-applied {N} fixes (Critical/High + consensus). {M} single-validator findings remain:"
header: "Remaining"
multiSelect: true
options:
  - label: "Fix X: <title>"
    description: "Medium — <validator>: <one-line summary>"
  - label: "Fix Y: <title>"
    description: "Medium — <validator>: <one-line summary>"
```

**If no remaining items after auto-apply:** Skip the question entirely — just report what was applied.

**If more than 4 remaining items:** Split across multiple `AskUserQuestion` calls.

Apply selected fixes to the proposed structure. Re-present updated version if structural changes were significant. Only proceed to Phase 3 after the user approves.

**TaskUpdate(task: "Present structure for user approval", status: "completed")**

---

## Phase 3: Create Beads

**TaskUpdate(task: "Create beads", status: "in_progress")**

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

<!-- mirror of beads-standards/reference/bead-conventions.md §Body template (incl. its Test Scope bullet) — edit there first -->
Each bead description must be **self-contained** (typed headers per
`beads-standards/reference/bead-conventions.md` §Body template — `## Acceptance Criteria`,
`## Test Scope`, `## Steps to Reproduce` on bugs, `## Delivers` +
`## Consumes` on every implementable bead — emitted at creation, so
`br lint` passes and refine verifies instead of authoring):

- Clear acceptance criteria — each one with a **nameable check** (the command,
  test, or observation that verifies it; an AC no one can name a check for is
  not an AC)
- **UI beads derived from a visual reference** (a human-shared screenshot/mockup/comp
  saved per `ac-pipeline/references/design-refs.md`) MUST carry the reference-image path
  (`docs/design-refs/<surface>-<source>-reference.<ext>`) in `## Acceptance Criteria` —
  not just a prose description of it. Losing the path here is how geometry (shape,
  radius, spacing) silently drops between research doc and bead.
- Test requirements included — **plus a declared test scope**: the file paths/globs this bead
  touches, so its per-bead (Tier-1) check runs only the affected tests (feeds `vitest-affected`)
- User-facing beads carry forward the plan's **Journeys touched** into their `## Test Scope`
  QA-modality declaration (`beads-standards/reference/bead-conventions.md` §Test Scope) — propagate the plan's
  named journeys, don't re-derive them from scratch
- **Bead I/O contract** (`beads-standards/reference/bead-conventions.md` §Bead I/O contract): `## Delivers`
  lists the concrete artifacts (file/endpoint/migration/schema/doc/decision/config) this
  bead produces; `## Consumes` names the payload taken from each blocker
  (`<blocker-id> → <artifact>`, or the literal `- none`). Beadify holds the plan's
  cross-bead data flow — emit the contract here, while it's in context; every Consumes
  line must match a dep edge you create in this phase. Epics carry `## Delivers` only,
  derived from the plan's Outcome Definition
- No need to reference original plan
- "So detailed that we never need the plan again"
- Sufficient background and reasoning that an agent cold-starting on this bead can implement without any other context
- **Binding vs advisory** (`beads-standards/reference/bead-conventions.md` §Binding vs advisory): binding
  sections (ACs, Delivers/Consumes, Test Scope, repro) reference only the present tree
  (grep before citing) or an upstream blocker's `## Delivers` — never the bead's own
  dependents or unpromised future state. Implementation how-to goes under
  `## Approach (advisory)` — write it freely there, it's allowed to go stale

Use `--description` for the core spec and `br comments add` for supplementary context (background, reasoning, edge cases).

### Label All Beads as Unrefined

<!-- mirror of beads-standards/reference/bead-conventions.md §Lifecycle labels — edit there first -->
**Every bead created by beadify gets the `unrefined` label.** This signals to `/ac-implement` (and the loop's prep step) that these beads have not yet been through `/ac-bead-refine`.

```bash
br label add <id> "unrefined"
```

This label is removed by `/ac-bead-refine` when convergence is reached.

### Stamp the `plan-<slug>` join label on every epic

Every epic ac-beadify creates also gets a `plan-<slug>` label, where `<slug>` derives from
the plan filename (kebab-case, **no slashes** — `br` rejects them). This is the **join
key** the loop's plan-completion gate reads to know which epics belong to one plan — this
bead is the producer that DEFINES the label format; the gate that consumes it lives in
`ac-loop`.

```bash
# slug from the plan filename, e.g. 2026-07-12-bead-io-contract.md -> 2026-07-12-bead-io-contract
PLAN_SLUG=$(basename "$PLAN_FILE" .md)
br label add <epic-id> "plan-${PLAN_SLUG}"
```

### Fork-check — wire open human-gate beads that gate the new beads

At beadify of ANY plan, before the new beads go ready, reconcile them against the open
decision docket. This is the forward-looking half of two-sided fork wiring — the other
half, wiring at decision-creation, is `beads-standards`' existing mandatory-wiring rule.

1. List open `human-gate` beads (a small, docket-sized set):
   ```bash
   br list --json --limit 1000 | jq -r '.issues[] | select(.status=="open") | select((.labels // []) | index("human-gate")) | .id + "  " + .title'
   ```
2. Judge which of them gate any of the NEW beads just created, and wire the `blocks` edge
   for each such pair:
   ```bash
   br dep add <new-bead-id> <human-gate-id>
   ```
3. Re-run cycle detection (`br dep add` does NO cycle prevention — `beads-standards`
   § br gotchas): `br dep cycles` must return clean.

Manual beadify outside the loop stays a human-judgment override: this step surfaces the
forks and wires the obvious edges, but adds **no gate CHECK** here — the plan-completion
gate itself lives in `ac-loop`.

### Create Commands Reference

```bash
# Create epics (parent beads)
br create "Epic: User Authentication" --priority P0 --labels "auth" --description "..."

# Create child tasks under epics — ALWAYS unrefined at creation (refine stamps readiness)
br create "Create user schema" --priority P0 --labels "auth,backend,unrefined" --parent <epic-id> --description "..."

# Deps + comments: standard br forms — beads-standards § br cheatsheet
```

Save progress to `$ARTIFACTS_DIR/progress.md` after each epic is created (compaction recovery).

**TaskUpdate(task: "Create beads", status: "completed")**

---

## Phase 4: Verify and Report

**TaskUpdate(task: "Verify bead structure", status: "in_progress")**

```bash
# Verify structure
br list --json
br dep cycles   # Must return clean
br lint         # Check for missing sections

# Check unblocked beads
br ready --json

# Verify dependency tree from each epic
br dep tree <epic-id>

# Graph sanity (agents: robot flags ONLY — bare `bv` is a blocking TUI, human-use only)
bv --robot-triage
```

**TaskUpdate(task: "Verify bead structure", status: "completed")**
**TaskUpdate(task: "Archive source plan", status: "in_progress")**

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

**Why archive?** If beads still need the plan, they're not self-contained enough — archiving forces this discipline (the plan is preserved in `_done/`, not deleted).

**TaskUpdate(task: "Archive source plan", status: "completed")**
**TaskUpdate(task: "Report + handoff to ac-bead-refine", status: "in_progress")**

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

> Bead refinement is not optional — it's where the `unrefined` label gets removed and beads become truly agent-ready; planning tokens are cheaper than implementation tokens.
```

**Proceed to `/ac-bead-refine`.** Only skip if the user explicitly opts out. In a delegated autonomous run whose prompt says to proceed without confirmation (e.g. ac-loop's "always proceed to ac-bead-refine, no confirmation needed"), skip the question below and proceed directly:

```
question: "Proceeding to /ac-bead-refine (bead refinement is essential). Skip?"
header: "Refine"
multiSelect: false
options:
  - label: "Refine beads"
    description: "Run /ac-bead-refine — recommended, ensures beads are self-contained and agent-ready"
  - label: "Skip refinement"
    description: "Go straight to /ac-implement — only if you've already refined manually"
  - label: "Review visually first"
    description: "Open bv TUI to inspect before refining"
```

**TaskUpdate(task: "Report + handoff to ac-bead-refine", status: "completed")**

---

## Jeffrey's Standard

> "The beads should be so detailed that we never need to consult back to the original markdown plan document."

---

_Beadify: plan -> beads with parallel validation. Next: `/ac-bead-refine` (do not skip). For implementation: `/ac-implement`._
