---
name: ac-plan-init
description: Use to CREATE a first-draft implementation plan from a backlog item or feature request — parallel explorers investigate, you synthesize an actionable plan with test specs. The entry point of the planning chain. Triggers: 'make a plan', 'plan this feature', 'plan init', 'start a plan for X'. To improve an existing draft use ac-plan-clean / ac-plan-refine-internal / ac-plan-refine-external; to pressure-test it use ac-plan-review-genius / ac-plan-transcender-alien.
---


**You are the orchestrator creating implementation plans.** Three explorers investigate in parallel. You synthesize findings into an actionable plan with test specs. **DO NOT implement code — only plan.**

---

## I/O Contract

|                  |                                                                                                      |
| ---------------- | ---------------------------------------------------------------------------------------------------- |
| **Input**        | User request (feature, fix, improvement) or backlog item                                             |
| **Output**       | Approved plan in `_plans/YYYY-MM-DD-HHMM-[feature].md`, ready for refinement (`/ac-plan-clean`, `/ac-plan-refine-*`) or `/ac-beadify`     |
| **Artifacts**    | Research in `_plans/research/`, validation baseline, progress in `$ARTIFACTS_DIR/progress.md` |
| **Verification** | Plan committed to current branch, success criterion defined, tools verified                         |

## Prerequisites

- Dev server runnable (see AGENTS.md > Project Commands > Dev server)

## Phase 0: Initialize

**MANDATORY FIRST STEP: Create task list with TaskCreate BEFORE starting.**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
CURRENT_BRANCH=$(git branch --show-current)
echo "Planning on branch: $CURRENT_BRANCH"
```

Plans can be created on any branch — wave branches, feature branches, or main. The plan file is committed wherever you are. Never stash or force a branch switch to satisfy this skill.

### Configuration

```
ARTIFACTS_DIR=/tmp/plan-init-$(date +%Y%m%d-%H%M%S)
```

```bash
mkdir -p "$ARTIFACTS_DIR"
```

### Create Workflow Tasks

```
TaskCreate(subject: "Phase 0: Initialize and classify", description: "Verify branch, classify request type and complexity", activeForm: "Initializing plan session...")

TaskCreate(subject: "Phase 1: Parallel code exploration", description: "Spawn 3 parallel code exploration agents (Haiku, general-purpose): patterns, dependencies, constraints", activeForm: "Exploring codebase...")

TaskCreate(subject: "Phase 2: Validation baseline", description: "Capture current state, verify tools, define success criterion and test specs", activeForm: "Establishing baseline...")

TaskCreate(subject: "Phase 3: Synthesize plan", description: "Combine exploration findings into actionable implementation plan", activeForm: "Creating plan...")

TaskCreate(subject: "Phase 4: Get approval and commit", description: "Present plan for user approval, then commit artifacts to current branch", activeForm: "Awaiting approval...")
```

### Compaction Recovery

If `$ARTIFACTS_DIR/progress.md` exists, parse its `### Phase N` entries to recover state. If research files already exist in `_plans/research/`, skip to the next incomplete phase.


### Classify the Request

```
User request -> Classify:
├── Type: BUILD | IMPROVE | FIX
└── Complexity: MINIMAL | MORE | A LOT (auto-detect or user-specified)
```

**Complexity Detection:**

- MINIMAL: <3 files, clear pattern, 1-2 hours work
- MORE: 3-10 files, some decisions, 2-4 hours work
- A LOT: >10 files, architectural decisions, 4+ hours work

### Mark Active Work

If a source backlog item was identified, update its frontmatter to signal this skill is running:

```yaml
---
status: in_progress
working_skill: ac-plan-init
working_since: YYYY-MM-DD
---
```

(Skip if no `source_backlog` was identified.)

### Signal Active Work (Agent Mail)

Use the agent name registered at session start (from `macro_start_session`). If a source backlog item was identified, compute `BACKLOG_REL` = relative path from `PROJECT_ROOT` (e.g. `_backlog/v1-0/foo.md`). If no backlog item, use `_plans/new` as a placeholder.

**Reserve the source item:**

```
mcp__mcp-agent-mail__file_reservation_paths(
  project_key: PROJECT_ROOT,
  agent_name: <session agent name>,
  paths: [BACKLOG_REL],   # or "_plans/new" if no source backlog
  ttl_seconds: 10800,
  exclusive: true,
  reason: "ac-plan-init — creating plan"
)
```

**Broadcast WIP signal:**

```
mcp__mcp-agent-mail__send_message(
  project_key: PROJECT_ROOT,
  sender_name: <session agent name>,
  to: [<session agent name>],
  subject: "WIP: ac-plan-init — {BACKLOG_REL}",
  body_md: "Starting `ac-plan-init` for `{BACKLOG_REL}`.",
  topic: "pipeline-wip"
)
```

Append to `$ARTIFACTS_DIR/progress.md`:

```markdown
### Phase 0: Initialize

- **Type:** {BUILD|IMPROVE|FIX}
- **Complexity:** {MINIMAL|MORE|A LOT}
- **Request:** {brief summary}
```

**TaskUpdate(task: "Phase 0", status: "completed")**

---

## Phase 1: Parallel Code Exploration

**TaskUpdate(task: "Phase 1", status: "in_progress")**

### Skill Routing

**Engineering skill first.** Before routing to domain-specific skills, load this project's engineering standard declared in `CORE/SKILL.md` (§ "Engineering standard"). For all current neoMeta apps this is `capacitor-native` (`capacitor/SKILL.md`). Read it now if any aspect of the plan touches UI, navigation, data fetching, auth, storage, lifecycle, or build — which is almost always.

After loading the engineering skill, check `AGENTS.md` > "Available Skills" for additional domain skills. Include relevant skill paths in each agent prompt.

### Spawn 3 Explorers Simultaneously

**CRITICAL: All 3 agents run IN PARALLEL using a single message with 3 Task calls.** Each writes findings to `_plans/research/`. Competitive framing: agents compete — only evidence-backed findings count.

Use the prompts in **`references/explorers.md`** (Patterns, Dependencies, Constraints — all Haiku), substituting `[feature]` and the optional skill-hint line. Each writes to `_plans/research/…-exploration-{role}-[feature].md`.

**Wait for all 3 agents to complete. Read their output files.**

Append to `$ARTIFACTS_DIR/progress.md`:

```markdown
### Phase 1: Exploration

- **Patterns found:** {count} across {files}
- **Dependencies identified:** {count} ({existing} exist, {new} need creation)
- **Constraints found:** {count}
- **Key finding:** {most important discovery}
```

**TaskUpdate(task: "Phase 1", status: "completed")**

---

## Phase 2: Validation Baseline ("Taste the Tools")

**TaskUpdate(task: "Phase 2", status: "in_progress")**

**Purpose:** Capture current state AND verify you can actually measure success BEFORE planning.

### Step 1: Identify Validation Method

| Task Type   | Primary Validation       | Secondary             |
| ----------- | ------------------------ | --------------------- |
| UI Feature  | Browser automation test  | Screenshot comparison |
| API Change  | Response shape assertion | Integration tests     |
| Bug Fix     | Reproduction script      | Unit tests            |
| Performance | Baseline metrics         | Load tests            |

### Step 2: Capture Current State

**For UI features (ALWAYS capture both):**

```markdown
1. Start dev server (see AGENTS.md > Project Commands > Dev server) if not running
2. Navigate to relevant page using browser automation tool (if available)
3. Take accessibility snapshot (if browser tool available)
   -> Save as: research/YYYY-MM-DD-HHMM-baseline-snapshot-[feature].md
4. Take screenshot (if browser tool available)
   -> Save as: research/YYYY-MM-DD-HHMM-baseline-screenshot-[feature].png
5. Document current state
```

**For API changes:** Hit current endpoint, record response shape, note errors/limitations.

**For bug fixes:** Follow reproduction steps, document broken behavior, confirm you can see the bug.

**Save baseline to:** `_plans/research/YYYY-MM-DD-HHMM-baseline-[feature].md`

### Step 3: "Taste the Tools" (Verify Validation Capability)

```markdown
## Tool Verification Checklist

### Unit/Integration Tests

- [ ] Run project test command (see AGENTS.md > Project Commands > Test)
- [ ] Result: [X passing / Y failing]
- [ ] Status: Can run tests | BLOCKED

### Browser Access (if available)

- [ ] Navigate to: /[relevant-page]
- [ ] Result: [Can access | Cannot access]
- [ ] Status: Can browse | BLOCKED | N/A

### Dev Server

- [ ] Check: dev server running (see AGENTS.md > Project Commands > Dev server)
- [ ] Result: [Running | Not running]
- [ ] Status: Accessible | BLOCKED

### API Endpoints (if applicable)

- [ ] Endpoint: /api/[endpoint]
- [ ] Result: [Response code]
- [ ] Status: Reachable | BLOCKED
```

**IF all tools blocked:** STOP. Present blocker details and recovery procedure. Await user confirmation.

**IF partial tools available:** Present working vs blocked tools. Propose alternative validation. Get user approval before proceeding with adjusted criteria.

### Step 4: Define Success Criterion (Silver Bullet)

```markdown
## Success Criterion (Silver Bullet)

**Type:** [Journey | Screenshot | Test | Output | Metric]

**Definition:**
[What exactly constitutes success - machine-verifiable]

**Validation Command:**
[Exact command to run - e.g., pytest tests/test_feature.py, pnpm test tests/feature.spec.ts]

**Expected Outcome:**
[What passing looks like - e.g., "All 3 assertions pass, journey completes"]
```

### Step 5: Define Test Specifications (Machine-Readable)

**CRITICAL: Tests are designed here, built in implementation phase.** These specs are "hardcoded" in the plan — engineer cannot modify them during implementation.

```yaml
## Test Specifications

test_specs:
  silver_bullet:
    file: '[test-file-path]'
    type: 'Journey' # Journey | Screenshot | API | Performance | Custom
    description: '[What this test verifies]'
    assertions:
      - '[First assertion]'
      - '[Second assertion]'
      - '[Third assertion]'

  supporting_tests:
    - name: '[Test 1 Name]'
      file: '[unit-test-file-path]'
      type: 'Unit'
      description: '[What it verifies]'
      cases:
        - '[happy path]'
        - '[edge case]'
        - '[error case]'

    - name: '[Test 2 Name]'
      file: '[integration-test-file-path]'
      type: 'Integration'
      description: '[What it verifies]'
      cases:
        - '[case 1]'
        - '[case 2]'
```

**Why structured YAML:** Machine-parseable by implementation commands. Tests designed before code prevents "cheating". User reviews specs. Engineer implements to spec, can't modify requirements.

### Step 6: Document Baseline vs Target

```markdown
## Baseline vs Target

| Aspect         | Current State      | Target State        |
| -------------- | ------------------ | ------------------- |
| [Feature area] | [What exists now]  | [What should exist] |
| [Behavior]     | [Current behavior] | [Desired behavior]  |
| [Test status]  | [Current coverage] | [Expected coverage] |
```

Append to `$ARTIFACTS_DIR/progress.md`:

```markdown
### Phase 2: Validation Baseline

- **Tools verified:** {list of working tools}
- **Blocked tools:** {list, or "none"}
- **Success criterion:** {brief description}
- **Tests designed:** 1 Silver Bullet + {X} supporting tests
```

**TaskUpdate(task: "Phase 2", status: "completed")**

---

## Phase 3: Synthesize Findings and Create Plan

**TaskUpdate(task: "Phase 3", status: "in_progress")**

**THIS IS YOUR CORE WORK. Do not delegate synthesis.**

### Review All Research

Read the outputs:

- `_plans/research/*-patterns-*.md`
- `_plans/research/*-dependencies-*.md`
- `_plans/research/*-constraints-*.md`
- `_plans/research/*-baseline-*.md`

### Check for Conflicts/Gaps

- Multiple conflicting patterns found?
- Missing information needing more exploration?
- Unclear requirements needing user input?
- Architectural decisions required?

If any gaps are blocking, use `AskUserQuestion` to clarify before proceeding.

### Create Plan Document

**Create plan file:** `_plans/YYYY-MM-DD-HHMM-[feature-name].md`

**The plan must stand on its own.** The source backlog item is archived after plan-init, so capture all relevant context directly in the plan.

### Select Template Based on Complexity

Pick the template matching the Phase-0 complexity (MINIMAL / MORE / A LOT) from **`references/plan-templates.md`** and write `_plans/YYYY-MM-DD-HHMM-[feature].md` from it. The reference has the selection table + the full markdown skeleton for each tier.

Append to `$ARTIFACTS_DIR/progress.md`:

```markdown
### Phase 3: Plan Created

- **Plan file:** {path}
- **Complexity:** {MINIMAL|MORE|A LOT}
- **Phases:** {count}
- **Test specs:** 1 Silver Bullet + {X} supporting
```

**TaskUpdate(task: "Phase 3", status: "completed")**

---

## Phase 4: Present for Approval and Commit

**TaskUpdate(task: "Phase 4", status: "in_progress")**

### Ask Questions If Needed

If ambiguities remain, use `AskUserQuestion` to resolve them before presenting.

### Present Plan Summary

```markdown
## Plan Created: [Feature Name]

**Plan:** `_plans/YYYY-MM-DD-HHMM-[feature].md`
**Research:** `_plans/research/` ({N} files)

### Summary

[2-3 sentences describing approach]

### Type & Complexity

- **Type:** BUILD | IMPROVE | FIX
- **Complexity:** MINIMAL | MORE | A LOT

### Validation Baseline

- **Current state captured:** {yes/no}
- **Tools verified:** {list of working tools}
- **Success criterion:** [Brief description]

### Key Decisions

- **Architecture:** [Main choice]
- **Dependencies:** [New libraries, if any]
- **Database:** [Schema changes, if any]

### Test Specs

- **Silver Bullet:** [file + description]
- **Supporting:** [count] tests

---

**Approve to commit — next step is refinement or beadification, not implementation.**
```

**Present plan for approval with `AskUserQuestion`:**

```
AskUserQuestion(
  questions: [{
    question: "Plan created for [Feature Name]. Approve?",
    header: "Approval",
    multiSelect: false,
    options: [
      { label: "Approve", description: "Mark plan as approved and commit to current branch — refinement or beadification comes next, not implementation" },
      { label: "Adjust", description: "Needs changes — specify what to revise (will re-present after edits)" },
      { label: "Reject", description: "Wrong approach — discuss concerns and rethink" }
    ]
  }]
)
```

- **Approve** -> Commit plan to current branch, then choose next step (refinement, beadify, or done)
- **Adjust** -> Update plan based on feedback, re-present
- **Reject** -> Discuss concerns, revise approach

### Safety Check (Before Commit)

```bash
git status --short
```

**If ANY deletions (D):** STOP and ask "You're about to delete X files. Is this intentional?" Wait for confirmation.

### Commit Plan Artifacts

**Plans are low-risk documentation — commit directly to the current branch.**

```bash
git add _plans/research/*.md
git add _plans/YYYY-MM-DD-HHMM-[feature].md
git commit -m "$(cat <<'EOF'
docs(plan): [feature-name] - approved implementation plan

Research: patterns, dependencies, constraints
Baseline: current state captured, tools verified
Success criterion: [brief description]
Tests designed: 1 Silver Bullet + [X] supporting tests

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
git push
```

### Update Plan Status

Update the YAML frontmatter at the top of the plan file:

```yaml
---
status: approved
refinement_rounds: 0
source_backlog: _backlog/{version}/{filename}.md
approved_at: YYYY-MM-DD
---
```

Also archive the source backlog item (if a `source_backlog` was set):

1. Update its frontmatter to `status: planned` and add a `plans:` field linking to this plan.
2. Move it to `_done/`:
```bash
mkdir -p "$(dirname $SOURCE_BACKLOG)/_done"
mv "$SOURCE_BACKLOG" "$(dirname $SOURCE_BACKLOG)/_done/$(basename $SOURCE_BACKLOG)"
```

### Release Active Work Signal (Agent Mail)

**Release reservation:**

```
mcp__mcp-agent-mail__release_file_reservations(
  project_key: PROJECT_ROOT,
  agent_name: <session agent name>,
  paths: [BACKLOG_REL]
)
```

**Broadcast DONE signal:**

```
mcp__mcp-agent-mail__send_message(
  project_key: PROJECT_ROOT,
  sender_name: <session agent name>,
  to: [<session agent name>],
  subject: "DONE: ac-plan-init — {BACKLOG_REL}",
  body_md: "Completed `ac-plan-init` for `{BACKLOG_REL}`. Plan committed.",
  topic: "pipeline-wip"
)
```

### Report Completion and Hand-Off

```markdown
## Plan Complete: [Feature Name]

**Plan:** `_plans/YYYY-MM-DD-HHMM-[feature].md`
**Status:** Approved & Committed

### Ready for Implementation

| Complexity | Recommended Next Step                                            |
| ---------- | ---------------------------------------------------------------- |
| MINIMAL    | `/ac-beadify` directly, then `/ac-bead-refine` -> `/ac-implement` |
| MORE       | `/ac-plan-refine-internal` -> `/ac-plan-clean` -> `/ac-beadify` |
| A LOT      | `/ac-plan-refine-internal` or `/ac-plan-refine-external` -> `/ac-plan-clean` -> `/ac-beadify` |

**Pipeline next steps (each is now its own skill):**

- `/ac-plan-refine-internal` — multi-agent refinement (no external models)
- `/ac-plan-refine-external` — multi-model/OpenRouter refinement for high-stakes plans
- `/ac-plan-clean` — correctness/structure hygiene pass (final polish)
- `/ac-plan-review-genius` / `/ac-plan-transcender-alien` — forensic / paradigm-breaking review
- `/ac-beadify` — convert plan to beads with parallel validation (then `/ac-bead-refine`)
- `/ac-implement` — sequential implementation (conductor + engineer sub-agents)

**Key context:**

- Plan: `_plans/YYYY-MM-DD-HHMM-[feature].md`
- Success criterion: [from plan]
- Watch out for: [one key constraint or pattern discovered]

**Plan committed. Ready for next step.**
```

**Present next step choice with `AskUserQuestion`:**

```
AskUserQuestion(
  questions: [{
    question: "Plan approved and committed. What's next?",
    header: "Next step",
    multiSelect: false,
    options: [
      { label: "Refine plan (Recommended)", description: "Run /ac-plan-refine-internal — multi-agent refinement before beadification" },
      { label: "Beadify directly", description: "Run /ac-beadify — convert plan to beads (skip refinement for simple plans)" },
      { label: "External multi-model refine", description: "Run /ac-plan-refine-external — multiple diverse AI models for critical decisions" },
      { label: "Done for now", description: "Plan saved — pick up implementation later" }
    ]
  }]
)
```

**TaskUpdate(task: "Phase 4", status: "completed")**

---

## Flexibility & Overrides

### User Can Adjust Process

**"Just do a quick plan"**
-> Skip parallel exploration, use single-pass analysis

**"Focus on [specific aspect]"**
-> Emphasize that area in plan

**"Skip validation baseline"**
-> Proceed without tool verification (risky but fast)

**Trust the user's judgment on when to follow/skip steps.**

---

## Remember

- **YOU synthesize findings and create the plan** — explorers find patterns, you decide what matters
- **Planning is thinking, not doing** — do NOT write implementation code
- **Competitive framing sharpens exploration** — agents cite files, not guesses
- **Tests are designed in plan, built in implementation** — specs are hardcoded
- **Artifacts survive compaction** — always read from files, not memory
- **Progress file is compaction recovery** — parse it to know where you left off
- **Plans commit to current branch** — low-risk documentation, always pushed
- **WAIT for approval** — never proceed without the user's explicit approval

---

_Plan init: classify, explore, baseline, synthesize, approve. For refinement: `/ac-plan-refine-internal`. For beadification: `/ac-beadify`._

---

## Refinement & review — now separate skills

Plan creation (above) gets you to a first draft. Deepening, verifying, and pressure-testing it are now **distinct skills** (split out of the old monolithic plan skill), each invokable on its own:

| Skill | When |
| --- | --- |
| `/ac-plan-refine-internal` | Multi-agent refinement (light/medium/heavy), no external AI |
| `/ac-plan-refine-external` | Multi-model iterative refinement via 3–4 external AI models (OpenRouter) |
| `/ac-plan-clean` | 3 Sonnet agents verify accuracy, structure, completeness (final polish) |
| `/ac-plan-review-genius` | Multi-disciplinary first-principles forensic review of the plan |
| `/ac-plan-transcender-alien` | Push the plan beyond human cognitive defaults — paradigm-breaking angles |

Typical order: `/ac-plan-init` → `/ac-plan-refine-internal` → `/ac-plan-clean` → (`/ac-plan-refine-external` / `/ac-plan-review-genius` / `/ac-plan-transcender-alien` as warranted) → `/ac-beadify`.
