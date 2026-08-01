
**You are the conductor.** Three Sonnet reviewers check plan correctness independently. You track consensus across rounds and apply fixes. This is a hygiene pass — targeted edits, not a rewrite.

Run this as the final step before implementation. The plan's strategy and architecture are already settled; you're checking that the document is accurate, consistent, and clean.

---

## I/O Contract

|                  |                                                                                            |
| ---------------- | ------------------------------------------------------------------------------------------ |
| **Input**        | Approved plan file (`_plans/*.md` or user-specified)                                |
| **Output**       | Same plan file, corrected in-place                                                         |
| **Artifacts**    | Findings in `$ARTIFACTS_DIR/`, consensus registry in `$ARTIFACTS_DIR/consensus-registry.md` |
| **Verification** | Plan committed after corrections                                                           |

## Phase 0: Initialize

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

### Identify Plan File

`PLAN_FILE`: Check argument, then `_plans/*.md`, then `PLAN.md` in project root. If none found, STOP: "No plan found. Provide a path or run /ac-plan-init first."

### Skill Routing

Scan the plan for domain keywords. Check `AGENTS.md > Available Skills` for relevant skills. Include skill paths in reviewer prompts where applicable.

### Configuration

```
CURRENT_ROUND=1
MIN_ROUNDS=3          # ABSOLUTE floor — cross-round consensus needs recurrence opportunities; never finalize before this, even on consecutive zero-finding rounds
MAX_ROUNDS=5
AGENT_MODEL=sonnet
# Mint RUN_ID if the orchestrator didn't hand one down (contract: ac-pipeline/references/run-id.md
# mint-if-absent rule) — keeps standalone and orchestrated runs on the same formula.
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"
ARTIFACTS_DIR=/tmp/plan-clean-${RUN_ID}   # RUN_ID carries the PID → no same-second collision (ac-pipeline/references/run-id.md)
```

```bash
mkdir -p "$ARTIFACTS_DIR"
```

### Checkpoint Plan

```bash
git add "$PLAN_FILE" && git commit -m "docs(plan): checkpoint before plan-clean

Co-Authored-By: Claude <noreply@anthropic.com>" || true
```

### Initialize Consensus Registry

Create the cross-round tracking file:

> **If `dcg` rejects this write, do NOT bypass it** — the guard blocks a redirect whose target path
> is variable-built. Sanctioned shapes (`tee`, the Write tool): `ac-pipeline/references/shell-guardrails.md`.

```bash
cat > "$ARTIFACTS_DIR/consensus-registry.md" <<'EOF'
# Consensus Registry

Tracks single-agent findings across rounds. If a finding recurs in a later round, it achieves cross-round consensus and is auto-applied.

## Deferred Findings

<!-- Format: | Round | Agent | Finding ID | Summary | Section | -->
EOF
```

### Mark Active Work

Update the plan file's frontmatter to signal this skill is running:

```yaml
---
status: in_progress
working_skill: plan-clean
working_since: YYYY-MM-DD
---
```

Preserve all other existing frontmatter fields.

### Signal Active Work (Agent Mail)

Use the agent name registered at session start (from `macro_start_session`). Compute `PLAN_REL` = path of `PLAN_FILE` relative to `PROJECT_ROOT` (e.g. `_plans/foo.md`).

> **Carry the registration_token (shakedown-verified 2026-07-08; widened `ac-g93`).** Capture the
> `registration_token` returned by `macro_start_session` and thread it EXPLICITLY on EVERY
> privileged / mutating Agent Mail call below — file reservations
> (`file_reservation_paths` / `release_file_reservations` / `renew_file_reservations` /
> `force_release_file_reservation`) take it as `registration_token`, `send_message` / `reply_message`
> as `sender_token`. Do NOT rely on same-session auth carry — it is transport-conditional. Canonical
> note: `agent-mail/references/agent-identity.md` § Call-scoped facts.

**Reserve the plan file:**

```
mcp__mcp-agent-mail__file_reservation_paths(
  project_key: CANONICAL_PROJECT_KEY,   // canonical "neometa/<app-dir>" key — key-format + never-absolute rule: agent-mail/references/agent-identity.md § Project key format
  agent_name: <session agent name>,
  paths: [PLAN_REL],
  ttl_seconds: 14400,
  exclusive: true,
  reason: "plan-clean — in progress"
)
```

**Broadcast WIP signal:**

```
mcp__mcp-agent-mail__send_message(
  project_key: CANONICAL_PROJECT_KEY,   // canonical "neometa/<app-dir>" key — key-format + never-absolute rule: agent-mail/references/agent-identity.md § Project key format
  sender_name: <session agent name>,
  to: [<session agent name>],
  subject: "WIP: plan-clean — {PLAN_REL}",
  body_md: "Starting `plan-clean` on `{PLAN_REL}`.",
  topic: "pipeline-wip"
)
```

### Compaction Recovery

If `$ARTIFACTS_DIR/progress.md` exists, parse the last `### Round N` entry to recover `CURRENT_ROUND` (set to N+1). If `consensus-registry.md` exists, read it to recover the deferred findings pool.

### Create Workflow Tasks (run ledger)

**One task per major section — the ledger exists for CLARITY + ACCOUNTABILITY**, so every
section you'd report on gets its own line (not a 3-phase skeleton). Create the fixed tasks
below at Phase 0; **ADD a "Round N" task at the start of each review round** (rounds are
dynamic — 3 floor, up to 5 — so the ledger grows to the real shape instead of pre-committing
to a round count or showing phantom rounds). `TaskUpdate` each to `in_progress` when you start
it and `completed` when done; put live detail in the description (per round: finding +
applied counts), so a glance at the ledger shows exactly where the run is.

```
# Fixed tasks — create upfront at Phase 0:
TaskCreate("Initialize — identify plan, checkpoint, consensus registry")
TaskCreate("Conductor triage — classify no-consensus + design-decision items")
TaskCreate("Present decisions to user")
TaskCreate("Apply fixes + update plan frontmatter + commit")
TaskCreate("Report")

# Per-round task — create ONE as each round begins (not upfront):
TaskCreate("Round {N} — reviewers → synthesize → apply")
# On completion, TaskUpdate its description: "{n} findings, {n} applied, {n} deferred"
```

With a 3-round run that's 8 tasks; a 5-round run, 10. **TaskUpdate("Initialize", in_progress)**
now, and mark it `completed` at the end of Phase 0. This ledger tracks plan-clean's top-level
sections only — keep it ~5 fixed + rounds.

---

## REVIEW LOOP: Phases 1-3

### Phase 1: Spawn 3 Reviewers (parallel)

**All 3 agents in a single message for parallel execution.** Each writes findings to `$ARTIFACTS_DIR/round-{CURRENT_ROUND}-{role}.md`.

**Agent 1: Verifier (Sonnet)**

```
Task(subagent_type: "general-purpose", model: "sonnet", prompt: """
First: read AGENTS.md for project context and conventions.

You are verifying plan ACCURACY against the actual codebase. You compete with 2 other reviewers — only evidence-backed findings count.

## Plan

{Read and include PLAN_FILE content}

## Your Method

Cross-reference the plan's claims against reality. Extract file paths, function names, type names, imports, and external APIs — then verify each against the actual codebase and package manifests.

## Examples of What to Look For (not exhaustive)

- File paths that don't exist or have wrong names
- Functions/types referenced with wrong signatures or locations
- External library APIs assumed incorrectly (wrong method names, wrong parameters)
- Version-specific features assumed but not available in installed version
- Internal plan references that point to wrong sections

Use your judgment — if something seems inaccurate, verify it.

## Output

Write findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-verifier.md

For each finding:
## Finding N: Title
**Section:** Which plan section contains the error
**Reference:** The exact claim in the plan
**Reality:** What actually exists (with file:line evidence)
**Fix:** The specific correction needed

Limit: top 7 findings. Under 400 words. Only report real inaccuracies — don't flag stylistic issues.
If nothing found, say so — don't invent issues.
""")
```

**Agent 2: Auditor (Sonnet)**

```
Task(subagent_type: "general-purpose", model: "sonnet", prompt: """
First: read AGENTS.md for project context and conventions.

You are auditing plan STRUCTURE and LOGIC. You compete with 2 other reviewers — only evidence-backed findings count.

## Plan

{Read and include PLAN_FILE content}

## Your Method

Read the plan end-to-end, checking that the logical flow holds. Trace what each phase produces and what the next phase consumes — verify the chain is unbroken.

## Examples of What to Look For (not exhaustive)

- Logical gaps: Phase 3 needs X but no prior phase creates X
- Contradictions: two sections making incompatible claims
- Circular dependencies: A needs B needs A
- Missing steps: jumps from state A to state C without B
- Unclear ownership: deliverables not assigned to a specific phase
- Redundant sections: same information stated in multiple places
- New user-facing surface with no registry update: plan adds a route/screen/entry point
  but doesn't add/update a `CORE/journeys/*.md` entry (schema:
  `ac-pipeline/references/verification-gate.md` §Journey registry)

Use your judgment — if the logic feels off somewhere, dig into it.

## Output

Write findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-auditor.md

For each finding:
## Finding N: Title
**Section(s):** Which plan section(s) are involved
**Issue:** What's wrong with the logic or structure
**Evidence:** Quote the conflicting/missing content
**Fix:** The specific correction needed

Limit: top 7 findings. Under 400 words. Only report structural issues — don't flag accuracy or style.
If nothing found, say so — don't invent issues.
""")
```

**Agent 3: Editor (Sonnet)**

```
Task(subagent_type: "general-purpose", model: "sonnet", prompt: """
First: read AGENTS.md for project context and conventions.

You are checking plan HYGIENE and CLARITY. You compete with 2 other reviewers — only evidence-backed findings count.

## Plan

{Read and include PLAN_FILE content}

## Your Method

Read the plan looking for anything that doesn't belong in a final, clean document. Check for artifacts of the planning process, verbosity, inconsistencies, and ambiguity.

## Examples of What to Look For (not exhaustive)

- Iteration artifacts: "TODO", "FIXME", "we discussed", "in a previous round", "originally we planned"
- Verbose commentary: paragraphs that could be bullet points, explanations of obvious things
- Inconsistent terminology: same concept called different names in different sections
- Formatting inconsistencies: mixed heading levels, inconsistent list styles
- Hedging language: "maybe", "possibly", "we could consider" — a final plan should be decisive
- Dead content: commented-out sections, crossed-out alternatives, old options that weren't chosen

Use your judgment — if something reads poorly for an implementer picking this up cold, flag it.

## Output

Write findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-editor.md

For each finding:
## Finding N: Title
**Section:** Which plan section
**Issue:** What's wrong with the presentation
**Current:** Quote the problematic text
**Suggested:** The cleaner replacement
**Fix:** Brief description of the edit

Limit: top 7 findings. Under 400 words. Only report hygiene issues — don't flag accuracy or logic.
If nothing found, say so — don't invent issues.
""")
```

**Wait for all 3 agents to complete. Read their output files.**

### Phase 2: Synthesize with Consensus Tracking

**THIS IS YOUR CORE WORK. Do not delegate synthesis.**

Read findings from all 3 agents. For each finding, determine its consensus status:

#### Step 1: Classify Each Finding

For every finding across all 3 agents:

1. **Same-round consensus:** 2+ agents flagged the same issue (same section, same underlying problem) in this round → **auto-apply**
2. **Cross-round consensus:** Check the consensus registry — was this same issue flagged by any agent in a previous round? If yes → **auto-apply**
3. **Single-agent, no prior match:** Add to the consensus registry as a deferred finding for potential cross-round consensus in the next round

#### Step 2: Auto-Apply Consensus Findings

Apply all consensus findings (both same-round and cross-round) immediately using the Edit tool. Log each as "Auto-applied" with the consensus type:

```markdown
- **Finding X:** [title] — Auto-applied (same-round consensus: Verifier + Auditor)
- **Finding Y:** [title] — Auto-applied (cross-round consensus: Round 1 Editor + Round 2 Verifier)
```

#### Step 2.5: Design Decision Gate

Before auto-applying any consensus finding, check: does this represent a choice with no objectively superior technical answer? If so, resolve it yourself — pick the better option. Only tag as `DESIGN_DECISION` and defer if the decision would **noticeably affect the end-user experience** or **profoundly change the development approach**. Minor design choices (spacing, naming, style) — just pick the better option and auto-apply. `DESIGN_DECISION` items are deferred regardless of consensus — they go directly to the user in Phase 4.

#### Step 3: Update Consensus Registry

For single-agent findings that had no consensus match, append them to the deferred pool:

```markdown
| {CURRENT_ROUND} | {agent role} | {finding ID} | {one-line summary} | {plan section} |
```

#### Step 4: Log Round Progress

Append to `$ARTIFACTS_DIR/progress.md`:

```markdown
### Round {CURRENT_ROUND}

- **Findings:** {count} total (Verifier: {n}, Auditor: {n}, Editor: {n})
- **Auto-applied (same-round consensus):** {count}
- **Auto-applied (cross-round consensus):** {count}
- **Deferred to registry:** {count}
- **Registry total:** {cumulative deferred count}
```

### Phase 3: Convergence Check

**Rule 1: if this round's agents found ANY findings, you MUST run another round after applying fixes.** Fixes are unverified until the next round's agents confirm no new issues emerge.

**Rule 2 (the round floor): the `MIN_ROUNDS=3` floor is ABSOLUTE.** Cross-round consensus —
the rule that promotes recurring single-agent findings — needs at least two later rounds in
which a deferral can recur. A clean round 1 is not evidence the plan is clean; it is evidence
one round isn't enough. **Two rounds is not sufficient** — even two consecutive zero-finding
rounds do NOT finalize before round 3; the dry-panel early exit is only reachable once
`CURRENT_ROUND >= MIN_ROUNDS`. Ceiling is `MAX_ROUNDS=5`.

```
# The floor is checked FIRST and is absolute — nothing exits before round 3.
IF CURRENT_ROUND < MIN_ROUNDS -> apply fixes, continue (increment CURRENT_ROUND)   # even on back-to-back zero-finding rounds
IF two consecutive rounds found ZERO findings (only reachable at CURRENT_ROUND >= MIN_ROUNDS) -> finalize early (panel is dry — stop burning agents)
IF any findings were auto-applied this round -> apply fixes, continue (increment CURRENT_ROUND)
IF no new findings this round -> finalize (proceed to Phase 4)
IF CURRENT_ROUND >= MAX_ROUNDS -> force finalize (note unverified fixes in progress.md)
IF this round found same issues as last round AND CURRENT_ROUND >= MIN_ROUNDS -> force finalize (agents are circling)
```

**Between rounds:** Include in the next prompt: "Previous round applied these fixes: {list}. Verify they're correct and look for anything missed."

---

## Phase 4: Finalize

### Conductor Final Review (Triage)

Read the consensus registry. Collect all remaining items:

1. **No-consensus findings:** Single-agent findings that never recurred across rounds
2. **DESIGN_DECISION items:** Findings deferred during rounds as genuine design decisions

**If nothing remains:** Skip — report a clean result.

**Classify each remaining no-consensus finding:**

| Category | Criteria | Action |
|---|---|---|
| `AUTO_IMPLEMENT` | There is a clearly superior technical answer — better correctness, robustness, performance, or maintainability. The improvement is unambiguous. | Implement it now. |
| `DESIGN_DECISION` | No objectively superior answer AND the choice would **noticeably affect the end-user experience** or **profoundly change the development approach**. Minor design choices (spacing, naming, style) — just pick the better option and classify as `AUTO_IMPLEMENT`. | Defer to user. |
| `SCOPE_ESCALATION` | A technically superior option exists but requires profound structural change that constitutes a strategic commitment. | Defer to user with scope context. |

**Default bias: `AUTO_IMPLEMENT`.** Most findings have a correct answer — pick it.

**Apply all `AUTO_IMPLEMENT` items using the Edit tool.** Log each with rationale.

### Present Decisions to User (if any)

**If no `DESIGN_DECISION` or `SCOPE_ESCALATION` items remain:** Skip — proceed to commit.

**If items remain:**

```
AskUserQuestion(
  questions: [{
    question: "Auto-applied {N} fixes (severity + consensus + technical triage). {M} items need your decision:",
    header: "Decisions",
    multiSelect: true,
    options: [
      { label: "Finding X: <title>", description: "DESIGN_DECISION — Round {R}, {agent}: {section} — {one-line summary}" },
      { label: "Finding Y: <title>", description: "SCOPE_ESCALATION — {agent}: {section} — {one-line summary}. Scope: {what it entails}" }
    ]
  }]
)
```

**If more than 4 items:** Split across multiple `AskUserQuestion` calls.

Apply any user-approved findings using the Edit tool.

### Update Plan Frontmatter

Update the YAML frontmatter to reflect the plan is clean and loop-ready:

```yaml
---
status: loop-ready
---
```

Preserve all other existing frontmatter fields (`refinement_rounds`, `refinement_tier`, `source_backlog`, etc.).

### Safety Check and Commit

```bash
git status --short
```

**If ANY deletions (D):** STOP and confirm with user.

```bash
git add "$PLAN_FILE"
git commit -m "docs(plan): plan-team correctness check - {CURRENT_ROUND} rounds

Plan: {PLAN_FILE}
Rounds: {CURRENT_ROUND} (3x Sonnet per round)
Consensus applied: {total auto-applied count}
User-approved: {user-approved count}
Deferred (no consensus): {remaining count}

Co-Authored-By: Claude <noreply@anthropic.com>"
git push
```

### Cleanup

```bash
find "$ARTIFACTS_DIR" -mindepth 1 -delete && rmdir "$ARTIFACTS_DIR" 2>/dev/null || true
```

### Release Active Work Signal (Agent Mail)

> **Same token-carry as the reserve step:** always pass the captured `registration_token`
> (`release_file_reservations`) / `sender_token` (`send_message`) — do not rely on same-session carry (`ac-g93`).

**Release reservation:**

```
mcp__mcp-agent-mail__release_file_reservations(
  project_key: CANONICAL_PROJECT_KEY,   // canonical "neometa/<app-dir>" key — key-format + never-absolute rule: agent-mail/references/agent-identity.md § Project key format
  agent_name: <session agent name>,
  paths: [PLAN_REL]
)
```

**Broadcast DONE signal:**

```
mcp__mcp-agent-mail__send_message(
  project_key: CANONICAL_PROJECT_KEY,   // canonical "neometa/<app-dir>" key — key-format + never-absolute rule: agent-mail/references/agent-identity.md § Project key format
  sender_name: <session agent name>,
  to: [<session agent name>],
  subject: "DONE: plan-clean — {PLAN_REL}",
  body_md: "Completed `plan-clean` on `{PLAN_REL}` ({CURRENT_ROUND} rounds).",
  topic: "pipeline-wip"
)
```

### Report

```markdown
## Plan Clean: Correctness Check Complete

**Plan:** {PLAN_FILE}
**Rounds:** {CURRENT_ROUND}

### Convergence

Round  Verifier  Auditor  Editor  Total  Applied  Deferred
  1      {n}       {n}     {n}     {n}     {n}       {n}
  2      {n}       {n}     {n}     {n}     {n}       {n}
  3      {n}       {n}     {n}     {n}     {n}       {n}

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

### What Was Checked

- **Accuracy:** File paths, code references, external dependencies verified against codebase
- **Structure:** Logical flow, phase dependencies, internal consistency
- **Hygiene:** Iteration artifacts, verbosity, terminology consistency, formatting

**Plan committed. Ready for implementation.**
```

**Present next step choice with `AskUserQuestion`:**

```
AskUserQuestion(
  questions: [{
    question: "Plan correctness check complete ({CURRENT_ROUND} rounds). Plan is now marked loop-ready — ac-loop will pick it up on the next run. Anything else?",
    header: "Next step",
    multiSelect: false,
    options: [
      { label: "Nothing — let the loop handle it (Recommended)", description: "ac-loop will beadify and ship this plan autonomously on its next run" },
      { label: "Beadify now", description: "Run /ac-beadify immediately — don't wait for the loop" },
      { label: "Done for now", description: "Plan saved as loop-ready — loop will pick it up" }
    ]
  }]
)
```

---

## Remember

- **This is a hygiene pass, not a rewrite** — targeted edits only, preserve the plan's intent
- **Consensus is the gating mechanism** — single-agent findings must be confirmed by recurrence or user approval
- **Cross-round consensus is novel** — deferred findings that recur in later rounds are high-signal
- **Honor the round floor — it is ABSOLUTE** — never finalize before MIN_ROUNDS=3, not even on two consecutive zero-finding rounds (the dry-panel exit is only reachable at round ≥3); ceiling MAX_ROUNDS=5. Cross-round consensus needs the later rounds to exist
- **Conductor triage before user** — remaining items get a final review: auto-implement clear technical improvements, only defer genuine design decisions (user-visible or development-transformative) and scope escalations to the user
- **Design decision gate every round** — choices that noticeably affect user experience or profoundly change development are deferred regardless of consensus
- **Sonnets are cost-effective** — accuracy/structure/hygiene checks don't need Opus-level reasoning
- **Findings files survive compaction** — always read from `$ARTIFACTS_DIR`, not memory
- **Consensus registry is compaction recovery** — parse it to know the deferred pool state

---

_Plan team: verify accuracy, audit structure, polish hygiene. Consensus-gated corrections across 1-3 rounds._
