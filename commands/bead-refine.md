---
description: Refine bead structure before implementation — iterative rounds until severity-based convergence
---

**You are the conductor.** Three reviewers hunt independently. You synthesize, apply fixes, and iterate. Competitive framing: agents compete — only evidence-backed findings count.

---

## I/O Contract

|                  |                                                                                                  |
| ---------------- | ------------------------------------------------------------------------------------------------ |
| **Input**        | Open beads in `br` (from `/beadify` or any other source)                                         |
| **Output**       | Refined beads ready for `/bead-work`                                                 |
| **Artifacts**    | Round findings in `$ARTIFACTS_DIR/round-{N}-{role}.md`, progress in `$ARTIFACTS_DIR/progress.md` |
| **Verification** | `br list --json`, `br dep cycles`, `br lint`, `br ready --json`                                  |

## Prerequisites

- At least one open bead exists in `br`
- beads_rust (`br`) and beads_viewer (`bv`) installed — verify with `which br && which bv`

## Phase 0: Initialize

**MANDATORY FIRST STEP: Create task list with TaskCreate BEFORE starting.**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

### Configuration

```
CURRENT_ROUND=1
MAX_ROUNDS=5
ARTIFACTS_DIR=/tmp/bead-refine-$(date +%Y%m%d-%H%M%S)
```

```bash
mkdir -p "$ARTIFACTS_DIR"
```

### Initialize Consensus Registry

```bash
cat > "$ARTIFACTS_DIR/consensus-registry.md" <<'EOF'
# Consensus Registry

Tracks single-agent findings across rounds. If a finding recurs in a later round, it achieves cross-round consensus and is auto-applied.

## Deferred Findings

<!-- Format: | Round | Agent | Severity | Bead | Summary | -->
EOF
```

### Compaction Recovery

If `$ARTIFACTS_DIR/progress.md` exists, parse the last `### Round N` entry to recover `CURRENT_ROUND` (set to N+1). Previous rounds' changes are already applied to beads. Read any existing findings files in `$ARTIFACTS_DIR` for context on the most recent round. If `$ARTIFACTS_DIR/consensus-registry.md` exists, read it to recover the deferred findings pool for cross-round consensus detection.

### Identify Plan File + Skills

Locate the original plan file if one exists (check `_plans/*.md`, ask user if unclear). Use it for cross-referencing during review when available; if no plan exists, proceed with bead-only review.

**Skill routing:** Read the beads (`br list --json`) and scan for domain keywords. Check `AGENTS.md` > "Available Skills" for relevant skills. Include skill paths in agent prompts.

### Gather Bead Snapshot

```bash
# Current bead state
br list --json > "$ARTIFACTS_DIR/beads-snapshot.json"

# Dependency health
br dep cycles

# Full bead details for agent context
for id in $(br list --json | jq -r '.[].id'); do
    echo "=== Bead $id ==="
    br show "$id"
    br comments "$id"
    echo ""
done > "$ARTIFACTS_DIR/beads-full-dump.txt"
```

### Create Workflow Tasks

```
TaskCreate(subject: "Phase 0: Initialize bead-refine session", description: "Identify plan file, gather bead snapshot, create tasks", activeForm: "Initializing bead-refine...")

TaskCreate(subject: "Phase 1-4: Refinement loop", description: "Parallel agent review -> synthesize -> apply fixes -> convergence check. Repeat up to MAX_ROUNDS.", activeForm: "Refining beads...")

TaskCreate(subject: "Phase 5: Finalize and verify", description: "Final verification, commit, present summary", activeForm: "Finalizing refinement...")
```


**TaskUpdate(task: "Phase 0", status: "completed")**

---

## REFINEMENT LOOP: Phases 1-4

**TaskUpdate(task: "Phase 1-4: Refinement loop", status: "in_progress", description: "Round {CURRENT_ROUND}/{MAX_ROUNDS}")**

### Phase 1: Spawn 3 Reviewers (parallel)

**All 3 agents in a single message for parallel execution.** Each agent writes findings to `$ARTIFACTS_DIR/round-{CURRENT_ROUND}-{role}.md`.

**Agent 1: Completeness Reviewer**

```
Task(subagent_type: "general-purpose", model: "sonnet", prompt: """
First: read AGENTS.md for project context, coding standards, and conventions.
{If relevant skills identified: "Read the relevant skill file for domain patterns (see AGENTS.md > Available Skills)."}

You are a completeness auditor. You compete with 2 other reviewers — only evidence-backed findings count.

## Your Task

Cross-reference every bead against the original plan (if available) to ensure NOTHING was lost or oversimplified. If no plan exists, audit beads for self-containment and completeness.

## Method

Read ALL beads ({paste ARTIFACTS_DIR/beads-full-dump.txt or inline}). If a plan file exists ({PLAN_FILE}), cross-reference plan sections against the beads — check that nothing was lost, oversimplified, or omitted. If no plan file is available, focus on bead-only completeness: missing acceptance criteria, missing edge cases, gaps in implementation context. Either way, check each bead for self-containment: could an engineer implement it without external context? Are acceptance criteria specific and verifiable? Use your judgment on what matters most.

## Output

Write findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-completeness.md

For each issue:
## Issue N: Title
**Severity:** Critical | High | Medium
**Bead:** <id> (or "Missing bead")
**Evidence:** What the plan says vs what the bead says (or doesn't)
**Fix:** Specific change — new bead, updated description, added acceptance criteria

Limit: top 5 issues. If additional Critical/High, add as one-liners. Under 500 words. Skip Low.
If nothing found, say so — don't invent issues.
""")
```

**Agent 2: Implementability Reviewer**

```
Task(subagent_type: "general-purpose", model: "sonnet", prompt: """
First: read AGENTS.md for project context, coding standards, and conventions.
{If relevant skills identified: "Read the relevant skill file for domain patterns (see AGENTS.md > Available Skills)."}

You are an implementer auditing these beads. You compete with 2 other reviewers — only implementation-blocking findings count.

## Your Task

Can an engineer cold-start on each bead tomorrow and implement it mechanically? If you'd need to ask a question, that's a finding.

## Method

Read ALL beads ({paste ARTIFACTS_DIR/beads-full-dump.txt or inline}) and put yourself in the implementer's seat. For each bead: could you cold-start on it tomorrow and build it mechanically? If you'd need to ask a question, that's a finding. Check scope clarity, dependency correctness, granularity, and whether you could write RED tests from just the acceptance criteria. You have codebase access — read referenced files to verify functions, types, and patterns actually exist as described. **Verify test file paths against the project test-directory map (AGENTS.md):** if a bead specifies a test file path, validate the directory matches the project's split before approving. For Body Compass: supabase integration tests live in `__tests__/supabase-integration/` (run via `pnpm test:integration`, real local Postgres), NOT `__tests__/integration/` (mocked unit tests via `pnpm test`). Read AGENTS.md > Architecture > `__tests__/` block before approving any spec that names a test file path. Verify file existence too — if the bead claims a file does or doesn't exist, check it. Incorrect spec paths cost ~5 min/bead in conductor pre-flight; bd-9i7e.4 and bd-9i7e.9 both shipped from refine with `__tests__/integration/` when the right path was `__tests__/supabase-integration/`. Use your judgment on what blocks implementation.

## Output

Write findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-implementability.md

For each issue:
## Issue N: Title
**Severity:** Critical | High | Medium
**Bead:** <id>
**Evidence:** What's ambiguous/wrong/missing, with codebase citations
**Fix:** Specific change — clearer spec, split proposal, dependency fix

Limit: top 5 issues. If additional Critical/High, add as one-liners. Under 500 words. Skip Low.
If nothing found, say so — don't invent issues.
""")
```

**Agent 3: Structure Optimizer**

```
Task(subagent_type: "general-purpose", model: "sonnet", prompt: """
First: read AGENTS.md for project context, coding standards, and conventions.

You are a dependency graph and structure optimizer. You compete with 2 other reviewers — only structural improvements backed by evidence count.

## Your Task

Optimize the bead dependency graph, ordering, and granularity. Your only verbs: split, merge, reorder, add dep, remove dep.

## Method

1. Read ALL beads: {paste ARTIFACTS_DIR/beads-full-dump.txt or inline}
2. Check dependency graph:
   - Run `br dep cycles` mentally — any cycles?
   - Are there missing dependencies? (Bead A needs code from Bead B but no dep link)
   - Are there unnecessary dependencies? (Bead A depends on B but doesn't actually need it)
   - Is the critical path optimal? Could reordering unblock more parallel work?
3. Check granularity:
   - Beads that touch >5 files or span multiple concerns -> split candidate
   - Beads that are trivial (<30 min) with no dependents -> merge candidate
   - Beads that mix backend + frontend -> split candidate
4. Check priority assignments:
   - P0 beads should be on the critical path
   - P2 beads should genuinely be deferrable
5. Check pipeline coherence: do any other beads in the dump (other waves/epics) or plans in `_plans/` conflict with or duplicate the current bead set?

## Output

Write findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-structure.md

For each issue:
## Issue N: Title
**Severity:** Critical | High | Medium
**Bead(s):** <id(s)>
**Evidence:** Current structure, what's wrong, why it matters
**Fix:** Specific structural change — split into X+Y, merge A+B, add/remove dep

Limit: top 5 issues. If additional Critical/High, add as one-liners. Under 500 words. Skip Low.
If nothing found, say so — don't invent issues.
""")
```

### Phase 2: Synthesize and Apply

**THIS IS YOUR CORE WORK. Do not delegate synthesis.**

Read all 3 findings files from `$ARTIFACTS_DIR`.

Synthesis principles:

- **Consensus is high-signal** — 2+ agents flagging the same bead is almost certainly real
- **Evidence over opinion** — findings need bead IDs and specific content citations
- **Structure Optimizer counterbalances** — Completeness wants to add, Structure wants to simplify
- **Critical/High first** — skip Medium unless trivial to fix

Produce a numbered change list. For each item: target bead(s), what to change, the fix.

**Auto-apply without asking. No user approval needed per-round — the convergence loop self-corrects.**

- **Critical/High:** Apply immediately — these are defects, regardless of how many agents flagged it
- **Same-round consensus (2+ agents):** Apply immediately — multi-agent agreement is high-signal
- **Cross-round consensus:** A single-agent finding from THIS round matches a deferred finding in the consensus registry from a PREVIOUS round — recurrence across rounds is high-signal. Apply immediately.
- **Design decision gate (applies before all auto-apply rules):** If a finding represents a choice with no objectively superior technical answer, resolve it yourself — pick the better option. Only tag as `DESIGN_DECISION` and defer if the decision would **noticeably affect the end-user experience** or **profoundly change the development approach**. Minor design choices (spacing, naming, style) — just pick the better option and auto-apply. `DESIGN_DECISION` items are deferred regardless of severity or consensus — they skip the registry and go directly to the user in Phase 5.
- **Medium/Low + single-agent + no cross-round match:** Defer to consensus registry. Do NOT skip silently.

For each deferred finding, append to `$ARTIFACTS_DIR/consensus-registry.md`:

```markdown
| {CURRENT_ROUND} | {agent role} | {severity} | {bead ID} | {one-line summary} |
```

**Log all applied and deferred changes in the round summary.**

**Apply approved changes using `br` commands:**

```bash
# Update bead description/spec
br update <id> --description "Revised spec..."

# Add context, reasoning, edge cases as comments
br comments add <id> "Acceptance criteria update: ..."

# Fix dependency structure
br dep add <child-id> <depends-on-id>
br dep remove <child-id> <depends-on-id>

# Adjust priority or labels
br update <id> --priority P0
br label add <id> "new-label"

# Split a bead that's too large
br create "Split: first half" --parent <epic-id> --priority P0 --description "..."
br create "Split: second half" --parent <epic-id> --priority P0 --description "..."
br dep add <second-half-id> <first-half-id>
br close <original-id>
```

### Phase 3: Round Reporting

Append to `$ARTIFACTS_DIR/progress.md`:

```markdown
### Round {CURRENT_ROUND}

- **Findings:** {count} total ({Critical} Critical, {High} High, {Medium} Medium)
- **Changes applied:** {count} ({list bead IDs + brief change description})
- **Dependencies added/removed:** {count}
- **Structural changes:** {splits, new beads, merges — or "none"}
- **Consensus areas:** {where agents agreed}
- **Trajectory:** {assessment} -> {continue|finalize}
```

### Phase 4: Convergence Check

**Rule: if this round's agents found ANY Critical or High issues, you MUST run another round after applying fixes.** Fixes are unverified until the next round's agents confirm no new Critical/High issues emerge. Only finalize after a round where all findings are Medium or lower.

```
IF agents found any Critical or High issues -> apply fixes, continue (increment CURRENT_ROUND)
IF 3+ Medium issues across agents -> continue
IF only few Medium or no issues -> finalize (proceed to Phase 5)
IF CURRENT_ROUND >= MAX_ROUNDS -> force finalize (note unverified fixes in progress.md)
```

**Between rounds:** Include in next prompt: "Previous round findings are in {ARTIFACTS_DIR}/round-{N-1}-\*.md. Focus on areas NOT covered in previous rounds, plus verify previous fixes landed correctly."

**Loop back to Phase 1.**

---

## Phase 5: Finalize

**TaskUpdate(task: "Phase 1-4: Refinement loop", status: "completed")**
**TaskUpdate(task: "Phase 5: Finalize", status: "in_progress")**

### Conductor Final Review (Triage)

Read the consensus registry. Collect all remaining items:

1. **No-consensus findings:** Single-agent findings that never recurred across rounds
2. **DESIGN_DECISION items:** Findings deferred during rounds as genuine design decisions

**If nothing remains:** Skip — proceed to verification.

**Classify each remaining no-consensus finding:**

| Category | Criteria | Action |
|---|---|---|
| `AUTO_IMPLEMENT` | There is a clearly superior technical answer — better correctness, robustness, performance, or maintainability. The improvement is unambiguous. | Implement it now. |
| `DESIGN_DECISION` | No objectively superior answer AND the choice would **noticeably affect the end-user experience** or **profoundly change the development approach**. Minor design choices (spacing, naming, style) — just pick the better option and classify as `AUTO_IMPLEMENT`. | Defer to user. |
| `SCOPE_ESCALATION` | A technically superior option exists but requires profound structural change that constitutes a strategic commitment. | Defer to user with scope context. |

**Default bias: `AUTO_IMPLEMENT`.** Most findings have a correct answer — pick it.

**Apply all `AUTO_IMPLEMENT` items using `br` commands.** Log each with rationale.

### Present Decisions to User (if any)

**If no `DESIGN_DECISION` or `SCOPE_ESCALATION` items remain:** Skip — proceed to verification.

**If items remain:**

```
AskUserQuestion(
  questions: [{
    question: "Auto-applied {N} fixes (severity + consensus + technical triage). {M} items need your decision:",
    header: "Decisions",
    multiSelect: true,
    options: [
      { label: "Fix X: <title>", description: "DESIGN_DECISION — Round {R}, {severity} — {agent}: Bead {id} — {one-line summary}" },
      { label: "Fix Y: <title>", description: "SCOPE_ESCALATION — {severity} — {agent}: Bead {id} — {one-line summary}. Scope: {what it entails}" }
    ]
  }]
)
```

**If more than 4 items:** Split across multiple `AskUserQuestion` calls.

**Apply any user-approved findings using `br` commands.**

### Remove `unrefined` Label

**On successful convergence (Phase 5 reached), remove the `unrefined` label from all beads that were reviewed.**

```bash
# Remove unrefined label from all open beads
for id in $(br list --json | jq -r '.[] | select(.status == "open") | .id'); do
    br label remove "$id" "unrefined" 2>/dev/null
done
```

This signals to `/backlog-next` and `/bead-work` that these beads have been through refinement and are agent-ready.

### Verify Final Structure

```bash
br list --json
br dep cycles    # Must return clean
br lint          # Check for missing sections
br ready --json  # Show what's ready to implement
bv               # Visual TUI overview
```

### Quality Checklist

Verify:

- [ ] Beads are self-contained (no need to consult original plan — plan should already be archived)
- [ ] Dependencies correctly mapped (`br dep cycles` returns clean)
- [ ] Tasks appropriately granular for mechanical implementation
- [ ] Test requirements included in each bead
- [ ] Comments explain reasoning/justification
- [ ] Acceptance criteria are clear and verifiable
- [ ] `unrefined` label removed from all reviewed beads

### Report

```markdown
## Bead Refinement Complete

**Rounds completed:** {CURRENT_ROUND}
**Stop reason:** {severity converged | MAX_ROUNDS | user decision}

### Convergence

Round  Completeness  Implementability  Structure  Total  Applied  Deferred
  1      {n}            {n}              {n}       {n}     {n}       {n}
  2      {n}            {n}              {n}       {n}     {n}       {n}
  3      {n}            {n}              {n}       {n}     {n}       {n}

R1  {▓▓░░░████}  {total}
R2  {░████}      {total}  {-N%}
R3  {██}         {total}  {-N%}

▓ Critical  ░ High  █ Medium

### Resolution

Found: {total} across {CURRENT_ROUND} rounds
  ├─ Auto-applied (severity):      {n}  {bars}
  ├─ Auto-applied (same-round):    {n}  {bars}
  ├─ Auto-applied (cross-round):   {n}  {bars}
  ├─ Auto-implemented (conductor):  {n}  {bars}
  ├─ User-approved:                {n}  {bars}
  └─ Discarded (no consensus):     {n}  {bars}

### Bead Status

- Ready to implement: {count} (`br ready --json`)
- Total beads: {count}
- Blocked: {count}

### Next Steps

1. **Implement** -> `/bead-work`
2. **Further refine** -> Run again with updated beads
3. **Review beads** -> `bv` for visual overview
```

**Present next step choice with `AskUserQuestion`:**

```
AskUserQuestion(
  questions: [{
    question: "Bead refinement complete. What's next?",
    header: "Next step",
    multiSelect: false,
    options: [
      { label: "Implement (Recommended)", description: "Run /bead-work — sequential implementation with conductor + engineer sub-agents" },
      { label: "Further refine", description: "Run /bead-refine again — another round of 3 parallel reviewers" },
      { label: "Review visually", description: "Open bv TUI for manual inspection before deciding" }
    ]
  }]
)
```

**TaskUpdate(task: "Phase 5: Finalize", status: "completed")**

---

## Jeffrey's Standard

> "The beads should be so detailed that we never need to consult back to the original markdown plan document."

---

## Remember

- **YOU synthesize and apply fixes** — agents find issues, you decide and fix
- **Auto-apply Critical/High + same-round consensus + cross-round consensus — defer the rest**
- **Cross-round consensus:** single-agent findings that recur in later rounds are high-signal — auto-apply on match
- **Conductor triage before user** — remaining items get a final review: auto-implement clear technical improvements, only defer genuine design decisions (user-visible or development-transformative) and scope escalations to the user
- **Design decision gate every round** — choices that noticeably affect user experience or profoundly change development are deferred regardless of severity or consensus
- **Competitive framing sharpens output** — agents know they compete for relevance
- **Structure Optimizer counterbalances** — prevents completeness reviewer from piling on complexity
- **Findings files + consensus registry survive compaction** — always read from `$ARTIFACTS_DIR`, not memory
- **Progress file is compaction recovery** — parse it to know where you left off
- **3 agents per round > 1 pass repeated** — more perspectives, faster convergence
- **Evidence over opinion** — bead IDs and content citations, not vague concerns
- **Verify function signatures from source** — when a spec references a function call, check argument order against the actual implementation, not from memory or docs
- **Refinement checks codebase AND pipeline** — agents should flag conflicts with other beads/waves and plans in `_plans/`, not just existing code

---

_Bead refine: parallel agents iterate until severity-converged. For implementation: `/bead-work`. For landing: `/bead-land`._
