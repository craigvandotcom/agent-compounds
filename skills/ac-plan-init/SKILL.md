---
name: ac-plan-init
description: 'Use to CREATE a first-draft implementation plan from a backlog item or feature request — parallel explorers investigate, you synthesize an actionable plan with test specs. The entry point of the planning chain. Triggers: ''make a plan'', ''plan this feature'', ''plan init'', ''start a plan for X''. To improve an existing draft use ac-plan-clean / ac-plan-refine-internal / ac-plan-refine-external; to pressure-test or transcend it use ac-plan-lab (genius + alien modes).'
---


**DO NOT implement code — only plan.**

> **Method:** this chain applies the scope-oscillation planning methodology — see the `planning` skill for the underlying lenses.

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

**Plans always commit to main.** If on a wave branch, switch to main before doing any git work:

```bash
if [ "$CURRENT_BRANCH" != "main" ]; then
  echo "On branch $CURRENT_BRANCH — switching to main (plans are docs, never branch work)"
  git checkout main
  git pull --rebase --autostash
fi
```

### Configuration

```
# Mint RUN_ID if the orchestrator didn't hand one down (contract: _shared/run-id.md
# mint-if-absent rule) — keeps standalone and orchestrated runs on the same formula.
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"
ARTIFACTS_DIR=/tmp/plan-init-${RUN_ID}   # RUN_ID carries the PID → no same-second collision (_shared/run-id.md)
```

```bash
mkdir -p "$ARTIFACTS_DIR"
```

### Create Workflow Tasks

**One task per major section** — a dropped/compacted session must be able to tell exactly
which action it reached, not just which of the 5 phases:

```
TaskCreate(subject: "Initialize — verify branch, classify request type and complexity", activeForm: "Initializing plan session...")

TaskCreate(subject: "Parallel code exploration — patterns, dependencies, constraints", description: "Spawn 3 parallel code exploration agents (Haiku, general-purpose)", activeForm: "Exploring codebase...")

TaskCreate(subject: "Validation baseline — identify method + capture current state", description: "Phase 2 steps 1-2: pick the validation method, capture the current-state baseline", activeForm: "Capturing baseline...")

TaskCreate(subject: "Taste the tools — verify validation capability", description: "Phase 2 step 3: confirm tests/browser/dev-server/API are actually reachable before planning against them", activeForm: "Tasting the tools...")

TaskCreate(subject: "Validation baseline — success criterion + test specs", description: "Phase 2 steps 4-6: Silver Bullet success criterion, machine-readable test specs, baseline-vs-target doc", activeForm: "Defining success criterion...")

TaskCreate(subject: "Synthesize plan — combine research into implementation plan", description: "Read research outputs, resolve conflicts, write the plan doc from the complexity-matched template", activeForm: "Creating plan...")

TaskCreate(subject: "Present plan for approval", description: "Present summary + AskUserQuestion approve/adjust/reject gate", activeForm: "Awaiting approval...")

TaskCreate(subject: "Commit plan artifacts + update status", description: "Safety check, commit to main, update plan frontmatter, archive source backlog item", activeForm: "Committing plan...")

TaskCreate(subject: "Release signal + report + hand-off", description: "Release Agent Mail reservation, broadcast DONE, report completion, present next-step choice", activeForm: "Reporting completion...")
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

### Surface Assumptions & Clarify (interview before you plan)

**Highest-leverage step for non-trivial work** — a wrong starting assumption compounds through every later refinement round, so surface it *now*, before exploration.

- **Human present + MORE/A-LOT or ambiguous:** ask the sharpest clarifying questions via `AskUserQuestion` — scope boundaries, the non-obvious constraints, UX/edge-case calls, and any either/or fork that would change the plan. Limit to the 2–4 questions whose answers most change the design.
- **Always record an `## Assumptions` log** in the plan: the decisions you're making *absent* an answer, plus the questions that would change the plan if answered differently. For autonomous runs (no human), this *replaces* the interview — state assumptions explicitly instead of guessing silently.
- **MINIMAL with a clear one-sentence diff:** skip the interview; note any single load-bearing assumption (or "none").

Refinement and review then pressure-test the *stated* assumptions, not hidden ones.

### Locate Backlog Item (if applicable)

If the input names a backlog item (rather than a fresh feature request), list `_backlog/active/` to locate the matching file — that is the current pool of unversioned, ready-to-plan items (version binds late, at plan-approval, not at capture).

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

**If the plan ADOPTS existing open beads** (rather than creating new ones at beadify), claim
them NOW: `br update <id> --status in_progress` on each, plus a comment on their epic
recording the plan claim. An active ac-loop treats every un-gated open bead as committed
work and will ship a divergent fix mid-planning — `br ready` excludes `in_progress`, making
the claim the only race-proof gate (shipped evidence: 2026-07-10, a concurrent loop closed 3
adopted beads with divergent implementations while the plan was being drafted). Un-gating a
decision bead makes it instantly loop-eligible: claim it in the same action. Beadify later
flips claimed beads back to open-with-wave-marker as it adopts each.

### Signal Active Work (Agent Mail)

Use the agent name registered at session start (from `macro_start_session` — NOTE: that tool takes `human_key`; the other agent-mail tools below take `project_key`). If a source backlog item was identified, compute `BACKLOG_REL` = relative path from `PROJECT_ROOT` (e.g. `_backlog/active/foo.md`). If no backlog item, use `_plans/new` as a placeholder.

> **Token + shell discipline: `_shared/agent-mail.md` § Mint** — thread
> `registration_token` explicitly on every mutating Agent Mail call; re-assert any
> variable this skill carries across phases (`PROJECT_ROOT`, `BACKLOG_REL`,
> `SOURCE_BACKLOG`, `ARTIFACTS_DIR`) in the SAME bash call that consumes it.

**Reserve the source item:**

```
mcp__mcp-agent-mail__file_reservation_paths(
  project_key: CANONICAL_PROJECT_KEY,   // canonical "neometa/<app-dir>" key — key-format + never-absolute rule: _shared/agent-identity.md § Project key format
                                        # mirror: _shared/agent-identity.md — edit there first
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
  project_key: CANONICAL_PROJECT_KEY,   // canonical "neometa/<app-dir>" key — key-format + never-absolute rule: _shared/agent-identity.md § Project key format
                                        # mirror: _shared/agent-identity.md — edit there first
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
- **Backlog item:** {BACKLOG_REL, or "_plans/new" if none} <!-- durable copy — Phase 4 re-derives BACKLOG_REL from here; shell vars are call-scoped -->
```

**TaskUpdate(task: "Initialize", status: "completed")**

---

## Phase 1: Parallel Code Exploration

**TaskUpdate(task: "Parallel code exploration", status: "in_progress")**

### Skill Routing

**Engineering skill first.** Before routing to domain-specific skills, load this project's engineering standard declared in `CORE/SKILL.md` (§ "Engineering standard"). For all current neoMeta apps this is `capacitor` (`capacitor/SKILL.md`). Read it now if any aspect of the plan touches UI, navigation, data fetching, auth, storage, lifecycle, or build — which is almost always.

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

**TaskUpdate(task: "Parallel code exploration", status: "completed")**

---

## Phase 2: Validation Baseline ("Taste the Tools")

**TaskUpdate(task: "Validation baseline — identify method + capture current state", status: "in_progress")**

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

**Human-shared visual references are a different artifact from the baseline screenshot above, and persisting them is not optional.** If Craig (or any human) shares a visual reference — screenshot, mockup, design comp — as the target to build toward, save it IMMEDIATELY to `docs/design-refs/<surface>-<source>-reference.<ext>` (NOT under `.claude/` — that's one harness's mount) and cite that exact path in the research doc / plan frontmatter; do not just describe it into prose. An image referenced-but-not-committed is a refine-blocking gap. Contrast with the baseline above: `research/YYYY-MM-DD-HHMM-baseline-screenshot-[feature].png` is agent-captured *current* state; `docs/design-refs/` is human-shared *target* state.

**For API changes:** Hit current endpoint, record response shape, note errors/limitations.

**For bug fixes:** Follow reproduction steps, document broken behavior, confirm you can see the bug.

**Save baseline to:** `_plans/research/YYYY-MM-DD-HHMM-baseline-[feature].md`

Mark task "Validation baseline — identify method + capture current state" `completed`;
`TaskUpdate(task: "Taste the tools — verify validation capability", status: "in_progress")`.

### Step 3: "Taste the Tools" (Verify Validation Capability)

Fill in the **Tool Verification Checklist** from **`references/plan-templates.md`** § "Phase 2 Step 3 — Tool Verification Checklist" (Unit/Integration Tests, Browser Access, Dev Server, API Endpoints — each with check items + a Status line).

**IF all tools blocked:** STOP. Present blocker details and recovery procedure. Await user confirmation.

**IF partial tools available:** Present working vs blocked tools. Propose alternative validation. Get user approval before proceeding with adjusted criteria.

Mark task "Taste the tools — verify validation capability" `completed`;
`TaskUpdate(task: "Validation baseline — success criterion + test specs", status: "in_progress")`.

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

Write the specs from the YAML skeleton in **`references/plan-templates.md`** § "Phase 2 Step 5 — Test Specifications (YAML skeleton)" (`silver_bullet` + `supporting_tests`).

**Why structured YAML:** machine-parseable by implementation commands, and specs fixed before code prevent "cheating".

### Step 6: Document Baseline vs Target

Document it with the **Baseline vs Target** table skeleton in **`references/plan-templates.md`** § "Phase 2 Step 6 — Baseline vs Target" (Aspect | Current State | Target State rows).

Append to `$ARTIFACTS_DIR/progress.md`:

```markdown
### Phase 2: Validation Baseline

- **Tools verified:** {list of working tools}
- **Blocked tools:** {list, or "none"}
- **Success criterion:** {brief description}
- **Tests designed:** 1 Silver Bullet + {X} supporting tests
```

**TaskUpdate(task: "Validation baseline — success criterion + test specs", status: "completed")**

---

## Phase 3: Synthesize Findings and Create Plan

**TaskUpdate(task: "Synthesize plan — combine research into implementation plan", status: "in_progress")**

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

**TaskUpdate(task: "Synthesize plan — combine research into implementation plan", status: "completed")**

---

## Phase 4: Present for Approval and Commit

**TaskUpdate(task: "Present plan for approval", status: "in_progress")**

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

On **Approve**, mark task "Present plan for approval" `completed`;
`TaskUpdate(task: "Commit plan artifacts + update status", status: "in_progress")`.
(On Adjust/Reject, leave the task `in_progress` — you're still in the approval loop.)

### Safety Check (Before Commit)

```bash
git status --short
```

**If ANY deletions (D):** STOP and ask "You're about to delete X files. Is this intentional?" Wait for confirmation.

### Commit Plan Artifacts

**Plans are docs — always commit to main** (branch policy: only code on wave branches).

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
source_backlog: _backlog/active/{filename}.md
approved_at: YYYY-MM-DD
---
```

Also archive the source backlog item (if a `source_backlog` was set):

1. Update its frontmatter to `status: planned` and add a `plans:` field linking to this plan.
2. Move it to `_done/`:
```bash
# Re-derive at point of use — shell vars are call-scoped, nothing survives from Phase 0's bash calls
PROJECT_ROOT=$(git rev-parse --show-toplevel)
BACKLOG_REL=<restate the Phase-0 value — read it back from "$ARTIFACTS_DIR/progress.md" (Phase 0 "Backlog item" line) if unsure>
SOURCE_BACKLOG="$PROJECT_ROOT/$BACKLOG_REL"
mkdir -p "$(dirname $SOURCE_BACKLOG)/_done"
mv "$SOURCE_BACKLOG" "$(dirname $SOURCE_BACKLOG)/_done/$(basename $SOURCE_BACKLOG)"
```

Mark task "Commit plan artifacts + update status" `completed`;
`TaskUpdate(task: "Release signal + report + hand-off", status: "in_progress")`.

### Release Active Work Signal (Agent Mail)

Re-derive `BACKLOG_REL` at point of use (shell vars are call-scoped — Phase 0's value did not survive): recompute it as in Phase 0, or read it back from `$ARTIFACTS_DIR/progress.md` (Phase 0 "Backlog item" line). Pass the captured `registration_token` on both calls below.

**Release reservation:**

```
mcp__mcp-agent-mail__release_file_reservations(
  project_key: CANONICAL_PROJECT_KEY,   // canonical "neometa/<app-dir>" key — key-format + never-absolute rule: _shared/agent-identity.md § Project key format
                                        # mirror: _shared/agent-identity.md — edit there first
  agent_name: <session agent name>,
  paths: [BACKLOG_REL]
)
```

**Broadcast DONE signal:**

```
mcp__mcp-agent-mail__send_message(
  project_key: CANONICAL_PROJECT_KEY,   // canonical "neometa/<app-dir>" key — key-format + never-absolute rule: _shared/agent-identity.md § Project key format
                                        # mirror: _shared/agent-identity.md — edit there first
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

**TaskUpdate(task: "Release signal + report + hand-off", status: "completed")**

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
- **Tests are designed in plan, built in implementation** — specs are hardcoded
- **Artifacts survive compaction** — always read from files, not memory
- **Progress file is compaction recovery** — parse it to know where you left off
- **WAIT for approval** — never proceed without the user's explicit approval

---

## Refinement & review — now separate skills

Plan creation (above) gets you to a first draft. Deepening, verifying, and pressure-testing it are now **distinct skills** (split out of the old monolithic plan skill), each invokable on its own:

| Skill | When |
| --- | --- |
| `/ac-plan-refine-internal` | Multi-agent refinement (light/medium/heavy), no external AI |
| `/ac-plan-refine-external` | Multi-model iterative refinement via 3–4 external AI models (OpenRouter) |
| `/ac-plan-clean` | 3 Sonnet agents verify accuracy, structure, completeness (final polish) |
| `/ac-plan-lab` | Deep analysis of the plan — genius mode (first-principles forensic review) + alien mode (push beyond cognitive defaults, paradigm-breaking angles) |
| `/ac-beadify` | Plan ready — convert plan to beads with parallel validation (then `/ac-bead-refine`) |
| `/ac-implement` | Beads refined — sequential implementation (conductor + engineer sub-agents) |

Typical order: `/ac-plan-init` → `/ac-plan-refine-internal` → `/ac-plan-clean` → (`/ac-plan-refine-external` / `/ac-plan-lab` as warranted) → `/ac-beadify`.
