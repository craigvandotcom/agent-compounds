
## Workflow Position

**Use when:**

- You have a plan that needs multi-perspective validation
- You want to catch architectural blind spots
- You need diverse AI insights on technical decisions
- You're uncertain if your plan is optimal

## I/O Contract

|                  |                                                                                            |
| ---------------- | ------------------------------------------------------------------------------------------ |
| **Input**        | Plan file (from `/ac-plan-init` or `/ac-plan-refine-internal`)                                   |
| **Output**       | Refined plan (in-place edit), `REFINEMENT-LOG.md` in `_plans/research/`             |
Consensus + auto-apply cascade per `ac-pipeline/references/review-consensus.md` (cite, never fork). <!-- net-growth-ok: ac-gcj.7 Pass C canon binding -->

| **Artifacts**    | Model responses in `$WORK_DIR/`, consensus registry                                        |
| **Verification** | Convergence trend, plan committed                                                          |

**This is plan refinement through iteration.** Multiple AI models review in parallel, you (Claude Code orchestrator) synthesize improvements, repeat until convergence. Not for trivial plans - for important architectural decisions.

**You are the conductor, not the musician.** You coordinate the process and do the synthesis work. You delegate model calls to the OpenRouter tool via bash.

---

## Phase 0: Initialize

**MANDATORY FIRST STEP: declare the run ledger (`ac-pipeline/references/run-ledger.md` — one task per section, advance as you go) with TaskCreate BEFORE starting.**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

### Identify Plan File

**Ask user or detect:**

```
PLAN_FILE: [Path to plan.md]
```

If not provided, check common locations:

- `PLAN.md` in project root
- `_plans/*.md`
- User-specified path

### Check for Project Context

**Look for AGENTS.md:**

```bash
if [ -f "AGENTS.md" ]; then
    echo "Found AGENTS.md - will include in review context"
    AGENTS_FILE="AGENTS.md"
else
    echo "No AGENTS.md found - proceeding without project context"
    AGENTS_FILE=""
fi
```

### Skill Routing

Scan the plan for domain keywords. Check `AGENTS.md > Available Skills` for relevant skills. Include skill content in model prompts where applicable.

### Model Set

**Models (4 total, as of Feb 2026):**

```bash
MODELS=(gemini-3.1 gpt kimi glm)
```

**Why these models:**

- `gemini` - Diverse perspective, Google's latest reasoning
- `gpt` - Industry standard, broad knowledge
- `kimi` - Long context, structured analysis
- `glm` - Strong reasoning, Chinese AI perspective

**Aliases resolve via openrouter tool** (run `openrouter --list-models` for available aliases).

### Create Working Directory

```bash
WORK_DIR="/tmp/plan-refine-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$WORK_DIR"
echo "Working directory: $WORK_DIR"
```

### Initialize Consensus Registry

Create the cross-round tracking file for single-model findings:

> **If `dcg` rejects any file-write below, do NOT bypass it** — the guard blocks a redirect whose
> target path is variable-built. Sanctioned shapes (`tee`, the Write tool): `ac-pipeline/references/shell-guardrails.md`.
> This file carries 13 such writes; it is the densest instance in the registry.

```bash
cat > "$WORK_DIR/consensus-registry.md" <<'EOF'
# Consensus Registry

Tracks single-model findings across rounds. If a finding recurs in a later round, it achieves cross-round consensus and is auto-applied.

## Deferred Findings

<!-- Format: | Round | Model | Scope | Summary | Section | -->
EOF
```

### Checkpoint Original Plan

Commit the original plan to git before any modifications, so there's always a clean baseline to diff against or revert to.

Git discipline: `ac-pipeline/references/commit-discipline.md` — pathspec-only commits, no wildcard adds / stash, commit=push, deletion check. <!-- net-growth-ok: ac-gcj.7 Pass C canon binding -->

```bash
git add "$PLAN_FILE"
git commit -m "$(cat <<'EOF'
docs(plan): checkpoint before plan-refine

Saving original plan state before multi-model refinement begins.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
echo "Original plan committed as baseline"
```

If the plan file has no changes (already committed), git will report "nothing to commit" — that's fine, just note it and continue.

### Configuration

```bash
MIN_ROUNDS=2          # ABSOLUTE floor (Craig's call, 2026-07-07) — never finalize before round 2,
                      # even on an incremental round 1; each round runs ~4 external models (~$2),
                      # so the floor costs ~$4 minimum — deliberate, to bound external-review spend.
MAX_ROUNDS=5
CURRENT_ROUND=1
```

### Create Workflow Tasks (run ledger)

**One task per major section — the ledger exists for CLARITY + ACCOUNTABILITY**, so every
section you'd report on gets its own line (not a 3-phase skeleton mutated in place). Create
the fixed tasks below at Phase 0; **ADD a "Round N" task at the start of each round** (rounds
are dynamic — 2 floor, up to `MAX_ROUNDS=5` — so the ledger grows to the real shape instead of
pre-committing to a round count or showing phantom rounds, and instead of overwriting one
task's description round after round). `TaskUpdate` each to `in_progress` when you start it
and `completed` when done; put live detail in the description (per round: model count +
scope classification + synthesis result), so a glance at the ledger shows exactly where the
run is.

```
# Fixed tasks — create upfront at Phase 0:
TaskCreate("Initialize + select external models — plan file, AGENTS.md context, working dir, consensus registry, model set")
TaskCreate("Conductor triage — classify remaining no-consensus findings (AUTO_IMPLEMENT / DESIGN_DECISION / SCOPE_ESCALATION)")
TaskCreate("Present decisions — surface DESIGN_DECISION/SCOPE_ESCALATION items to the user")
TaskCreate("Apply + update plan + commit — copy final plan, master changelog, commit + push")
TaskCreate("Report — refinement summary + loop-ready prompt")

# Per-round task — create ONE as each round begins (not upfront):
TaskCreate("Round {N} — {MODEL_COUNT} external models (parallel) → synthesize")
# On completion, TaskUpdate its description: "{scope} scope, {n} auto-applied, {model} highlights"
```

With a 2-round run (the floor) that's 7 tasks; a 5-round run, 10. **TaskUpdate("Initialize +
select external models", in_progress)** now, and mark it `completed` at the end of Phase 0.

### Present Configuration Summary

```markdown
## Plan Refinement Workflow

**Plan:** [PLAN_FILE]
**Context:** [AGENTS_FILE or "None"]
**Working directory:** [WORK_DIR]
**Max rounds:** [MAX_ROUNDS]
**Models:** Gemini Pro 3.1, GPT 5.2, Kimi K2.5, GLM-5

### Process:

1. Prepare review prompt (Phase 1)
2. Multi-model review in parallel (Phase 2)
3. Synthesize improvements (Phase 3)
4. Check convergence (Phase 4)
5. → LOOP back to Phase 1 OR finalize (Phase 5)

Starting refinement loop...
```

**TaskUpdate(subject: "Initialize + select external models", status: "completed")**

---

## REFINEMENT LOOP: Phases 1→2→3→4

**CRITICAL: This is an ITERATIVE loop. Phases 1-4 repeat until `MIN_ROUNDS` is cleared and
convergence is reached, up to `MAX_ROUNDS` times.**

**Loop flow:**

```
[Create "Round {CURRENT_ROUND} — {MODEL_COUNT} external models (parallel) → synthesize" task]
    ↓
Phase 1: Prepare Review Prompt
    ↓
Phase 2: Multi-Model Review (parallel)
    ↓
Phase 3: Synthesize Improvements
    ↓
Phase 4: Convergence Check
    ↓
[Decision: Continue OR Finalize?]
    ↓ Continue
[Complete the round task, increment CURRENT_ROUND, loop back — create the NEXT round's task]
    ↓ Finalize
Phase 5: Finalize
```

**At the start of each round:** `TaskCreate("Round {CURRENT_ROUND} — {MODEL_COUNT} external models (parallel) → synthesize")`, then `TaskUpdate(status: "in_progress", description: "Preparing review...")` on that round's task — never reuse a previous round's task.

---

## Phase 1: Prepare Review Prompt

**Current round:** `{CURRENT_ROUND}`

### Build Combined Prompt

**Create review prompt file combining:**

1. AGENTS.md context (if exists)
2. Jeffrey's review prompt template (proven)
3. Current plan content

```bash
# Build the review prompt for this round
cat > "$WORK_DIR/review-prompt-round-$CURRENT_ROUND.md" <<'PROMPT_END'
# Project Context

$( [ -n "$AGENTS_FILE" ] && cat "$AGENTS_FILE" || echo "No AGENTS.md available" )

---

# Review Task

Carefully review this entire plan for me and come up with your best
revisions in terms of better architecture, new features, changed
features, etc. to make it better, more robust/reliable, more performant,
more compelling/useful, etc. For each proposed change, give me your
detailed analysis and rationale/justification for why it would make the
project better along with the git-diff style changes relative to the
original markdown plan shown below:

---

# Current Plan

$( cat "$PLAN_FILE" )

PROMPT_END

echo "Review prompt created for round $CURRENT_ROUND"
```

**Prompt stored at:** `$WORK_DIR/review-prompt-round-{CURRENT_ROUND}.md`

---

## Phase 2: Multi-Model Review

**TaskUpdate on the round's task** (`"Round {CURRENT_ROUND} — ..."`, description: "Sending to {MODEL_COUNT} models in parallel...")

### Send to Models in Parallel

**Launch all model review calls simultaneously using bash background jobs:**

```bash
# Detect openrouter tool from PATH
OPENROUTER=$(which openrouter 2>/dev/null || echo "")
if [ -z "$OPENROUTER" ]; then
    echo "ERROR: openrouter not found in PATH. Install it or add to PATH."
    exit 1
fi

echo "Sending plan to ${#MODELS[@]} models in parallel..."

# IMPORTANT: Use --no-stream and stdout redirect (NOT -o/--output flag).
# The -o flag produces empty files for some models. Redirect stdout instead.
# Use 2>/dev/null to suppress reasoning chain stderr from thinking models.

# Launch all models in parallel (background jobs)
for model in "${MODELS[@]}"; do
    echo "  - Launching $model..."
    $OPENROUTER --model "$model" \
        --file "$WORK_DIR/review-prompt-round-$CURRENT_ROUND.md" \
        --no-stream \
        2>/dev/null > "$WORK_DIR/round-$CURRENT_ROUND-$model.md" &
done

# Wait for ALL background jobs to complete
wait
echo "All model reviews complete for round $CURRENT_ROUND"
```

**Why parallel:**

- Typical runtime: 2-4 minutes (4 models in parallel)
- Sequential would take 8-16 minutes
- No dependencies between model calls

### Verify Outputs

```bash
# Check all outputs exist and have content
# Some models may return empty files in parallel — retry individually if needed
RETRY_MODELS=()
for model in "${MODELS[@]}"; do
    output_file="$WORK_DIR/round-$CURRENT_ROUND-$model.md"
    if [ ! -f "$output_file" ] || [ ! -s "$output_file" ]; then
        echo "  ⚠ $model: empty or missing — will retry"
        RETRY_MODELS+=("$model")
    else
        word_count=$(wc -w < "$output_file")
        echo "  ✓ $model: $word_count words"
    fi
done

# Retry failed models sequentially (more reliable than parallel for flaky models)
for model in "${RETRY_MODELS[@]}"; do
    echo "  - Retrying $model sequentially..."
    $OPENROUTER --model "$model" \
        --file "$WORK_DIR/review-prompt-round-$CURRENT_ROUND.md" \
        --no-stream \
        2>/dev/null > "$WORK_DIR/round-$CURRENT_ROUND-$model.md"
    word_count=$(wc -w < "$WORK_DIR/round-$CURRENT_ROUND-$model.md")
    echo "  ✓ $model (retry): $word_count words"
done
```

---

## Phase 3: Synthesize Improvements

**TaskUpdate on the round's task** (`"Round {CURRENT_ROUND} — ..."`, description: "Synthesizing improvements...")

### Read All Model Outputs

**Load each model's feedback into context:**

```bash
for model in "${MODELS[@]}"; do
    echo "=== Reading $model Review ==="
    cat "$WORK_DIR/round-$CURRENT_ROUND-$model.md"
    echo ""
done
```

### Apply Jeffrey's Synthesis Framework

**THIS IS YOUR REASONING WORK (Claude Code orchestrator).**

**Do NOT delegate this to bash - this is your internal synthesis process:**

```
I asked 3-4 competing LLMs to do the exact same thing and they came up
with pretty different suggestions which I've read above. I will now
REALLY carefully analyze their suggestions with an open mind and be
intellectually honest about what they suggested that's better than the
current plan. Then I will come up with the best possible revisions that
artfully and skillfully blend the "best of all worlds" to create a true,
ultimate, superior hybrid version of the plan.
```

**Key synthesis principles:**

1. **Look for consensus** - If 2+ models agree, it's high-signal — auto-apply
2. **Consider unique insights** - One model might catch something others missed
3. **Preserve original intent** - Don't lose the plan's purpose
4. **Avoid complexity creep** - Don't add features without clear value
5. **Prioritize structural improvements** - Architecture > wording
6. **Be intellectually honest** - If models found weaknesses, acknowledge them

**Mental checklist while synthesizing:**

- [ ] Did multiple models identify the same gap?
- [ ] Are proposed changes addressing real weaknesses?
- [ ] Does this change improve robustness/performance/usability?
- [ ] Is the complexity justified by the benefit?
- [ ] Am I maintaining the plan's core goals?
- [ ] Are there conflicting suggestions? How do I resolve them?

### Create Updated Plan

**After completing your synthesis reasoning above, produce a numbered change list. Then apply each change via a sequential Haiku subagent.**

#### Step 1: Produce Change List

Output a numbered list. Each item must have:

- **Target section:** The exact heading or location in the plan
- **What to change:** Description and rationale
- **New content:** The concrete replacement text or addition

Example format:

```
1. Target section: "## Phase 2: Multi-Model Review"
   What to change: Add missing error handling for network timeouts (consensus from 3+ models)
   New content: [exact new/modified text]

2. Target section: "## Configuration"
   What to change: ...
```

#### Step 1b: Auto-Apply with Cross-Round Consensus

**Auto-apply a change if ANY condition is met:**

1. **Scope-based:** The change is Structural or Significant — these are substantive improvements, not preferences
2. **Same-round consensus:** 2+ models independently suggested the same improvement (regardless of scope) — multi-model agreement is high-signal
3. **Cross-round consensus:** A single-model finding from THIS round matches a deferred finding in the consensus registry from a PREVIOUS round — recurrence across rounds is high-signal

**Apply these immediately. Log them in the changelog as "Auto-applied" with the consensus type.**

#### Step 1c: Defer Remaining Findings (DO NOT ask user per-round)

After auto-applying, any remaining changes (Incremental scope AND only suggested by a single model with no cross-round match) are added to the consensus registry — NOT presented to the user.

For each deferred finding, append to `$WORK_DIR/consensus-registry.md`:

```markdown
| {CURRENT_ROUND} | {model name} | {scope} | {one-line summary} | {plan section} |
```

These deferred findings serve two purposes:
- **Cross-round consensus detection:** If a later round's model suggests the same improvement, it auto-applies
- **Final presentation:** Any findings that never achieve consensus are presented to the user once in Phase 5

#### Step 2: Apply Approved Changes via Sequential Haiku Subagents

<!-- mirror: ac-pipeline/references/delegation-contract.md § Child-spawn preamble -- edit there first -->

**Conductor: paste the block below VERBATIM at the head of EACH of the one `Task(...)`
prompt in this file, above its `First: read AGENTS.md` line, substituting the child's
minted `AGENT_NAME`.** It is the child-side environment contract and a pointer to it is
explicitly insufficient (canon § Child-spawn preamble) — a preamble that stays in this
header and never enters the constructed prompt has not been delivered to any child.

ENVIRONMENT CONTRACT (non-negotiable):
- WAIT for your own long-running commands in-shell (foreground, generous Bash
  timeout, or a foreground until-loop). Never arm a Monitor on your own command
  and end your turn — if a completion event already fired, read it and CONTINUE.
- Agent Mail: CHECK whether you hold `mcp__mcp-agent-mail__*` tools — assume neither way.
  Usually you do NOT: then don't try to register, and your conductor owns reservations.
  Either way, export the `AGENT_NAME` it gave you in each commit's own shell.
- Touching beads (`br`/`bv`)? The canon is `beads-standards` (+ its
  reference/bead-conventions.md for pipeline contracts) — read before inventing usage.
- After every push: verify origin SHA == local HEAD before proceeding.
- A guard block (dcg / pre-commit) means CHANGE APPROACH, never bypass. To DISCARD
  a change: `git checkout HEAD -- <path>` AND unscoped `git stash` are both blocked —
  use scoped `git stash push -- <paths>`; to read a pristine file, `git show <ref>:<path>`.
  Destructive commands (rm / find -delete) take FULLY-LITERAL paths: resolve
  first (`ls -d`), then paste literals — never `$VAR`, `$( )`, or a loop var.
  /tmp literals + distinctive /tmp globs are allowed; home/repo `rm -rf` never
  is — `git rm` if tracked, else gitignore-and-flag or ask the human.
- Shared checkout: commit your bead's files (pathspec-scoped) the INSTANT its
  ACs verify — minimal working-tree dwell; run `br` from the bead-board repo root.
- Autonomous run: never AskUserQuestion — Exhaust Rule.
- Return a structured `friction:` block (stage/cost/lesson/class; `[]` if clean).

**CRITICAL: Spawn one Haiku per change, sequentially (not in parallel).** Each edit shifts the file content, so subsequent edits must read the post-edit state.

For each item in the change list, spawn a Haiku subagent with this prompt:

```
You are making a single targeted edit to a plan document.

**File:** {PLAN_FILE}
**Section to modify:** {target section from change list item}
**Change:** {what to change and why}
**New content:** {the specific new/modified content}

Instructions:
1. Read the plan file
2. Find the section specified above
3. Use the Edit tool to make ONLY this change
4. Do NOT modify any other part of the document
5. Report what you changed (one sentence)
```

Spawn sequentially:

```
Task(subagent_type: "general-purpose", model: "sonnet", description: "Edit: {change title}")
→ Wait for completion
→ Spawn next Task for next change
→ Repeat until all changes applied
```

#### Step 3: Snapshot Round Output

After all Haiku edits are applied, copy the updated plan to the working directory:

```bash
cp "$PLAN_FILE" "$WORK_DIR/plan-round-$CURRENT_ROUND.md"
echo "Round $CURRENT_ROUND snapshot saved"
```

### Document Changes

**Create changelog for this round:**

```bash
cat > "$WORK_DIR/changelog-round-$CURRENT_ROUND.md" <<CHANGELOG_END
# Round $CURRENT_ROUND Changes

**Date:** $(date +%Y-%m-%d\ %H:%M)

---

## Summary

[High-level description of what changed this round]

---

## Key Improvements

### From [model name]

- [Improvement 1 with rationale]
- [Improvement 2 with rationale]

### From [model name]

- [Improvement 3 with rationale]

### Cross-Model Consensus

[Improvements that 3+ models agreed on - these are high-signal]

- [Consensus improvement 1]
- [Consensus improvement 2]

---

## Sections Modified

- **[Section Name]:** [What changed and why]
- **[Section Name]:** [What changed and why]

---

## Impact Assessment

**Scope:** [Structural | Significant | Incremental]

- **Structural:** New major sections, architecture changes, major features added/removed
- **Significant:** Enhanced existing sections substantially, added important details
- **Incremental:** Wording improvements, minor clarifications, polish

**Confidence:** [High | Medium | Low]

**Rationale for scope assessment:** [Why you classified it this way]

CHANGELOG_END
```

---

## Phase 4: Convergence Check

**TaskUpdate on the round's task** (`"Round {CURRENT_ROUND} — ..."`, description: "Checking convergence...")

### Assess Scope of Changes

**Read the changelog and determine change magnitude:**

```bash
# Read changelog to assess scope
CHANGELOG_FILE="$WORK_DIR/changelog-round-$CURRENT_ROUND.md"
cat "$CHANGELOG_FILE"
```

**Classification criteria:**

**Structural changes:**

- New major sections added
- Architectural approach fundamentally changed
- Major features added or removed
- Complete redesigns of key components

**Significant changes:**

- Existing sections enhanced substantially
- Important details/considerations added
- Architecture refined meaningfully
- Non-trivial improvements throughout

**Incremental changes:**

- Wording improvements
- Minor clarifications
- Small additions to existing content
- Polish and refinement

**Determine scope:**

```bash
# Based on changelog analysis, set:
CHANGE_SCOPE="[Structural|Significant|Incremental]"
```

### Decision Logic

**Rule 1 (scope gate): structural/significant changes always continue.**

Structural or significant changes mean the plan was materially altered. These fixes are unverified until the next round's models confirm no new issues emerged. Only finalize after a round where changes are incremental (all major issues resolved).

```bash
if [ "$CHANGE_SCOPE" = "Structural" ]; then
    echo "Changes are STRUCTURAL - fixes unverified, continuing to round $((CURRENT_ROUND + 1))"
    CONTINUE_REFINING=true

elif [ "$CHANGE_SCOPE" = "Significant" ]; then
    echo "Changes are SIGNIFICANT - fixes unverified, continuing to round $((CURRENT_ROUND + 1))"
    CONTINUE_REFINING=true
fi
```

**Rule 2 (the round floor): the `MIN_ROUNDS=2` floor is ABSOLUTE.** Each round runs ~4 external
models in parallel (~$2/round), so the floor costs ~$4 minimum — deliberate, Craig set it that
way to bound spend while still buying real cross-round signal. An incremental round 1 is not
evidence of convergence; it is evidence one round can't tell. **Never even ask the user to
finalize before `CURRENT_ROUND >= MIN_ROUNDS`** — on an incremental round short of the floor,
continue automatically without prompting. The "ask to finalize" branch is only reachable once
the floor is cleared.

```bash
# The floor is checked FIRST and is absolute — nothing exits before MIN_ROUNDS=2.
if [ "$CURRENT_ROUND" -lt "$MIN_ROUNDS" ]; then
    echo "Round $CURRENT_ROUND < MIN_ROUNDS=$MIN_ROUNDS — continuing automatically, even on an Incremental round"
    CONTINUE_REFINING=true
elif [ "$CHANGE_SCOPE" = "Incremental" ]; then
    # Floor cleared (CURRENT_ROUND >= MIN_ROUNDS) — ask user whether to finalize
    :
fi
```

**Ask user for incremental changes (only once `CURRENT_ROUND >= MIN_ROUNDS`):**

When changes become incremental AND the floor is cleared, convergence may be approaching. Use **AskUserQuestion tool** (NOT bash `read`):

```
AskUserQuestion(
    question: "Round {CURRENT_ROUND} changes are becoming incremental (minor refinements only). Continue refinement or finalize now?",
    options: [
        "Continue - Run another round (up to MAX_ROUNDS)",
        "Finalize - Accept current plan as final"
    ]
)
```

**Store user choice:**

```bash
if [ "$USER_CHOICE" = "Continue - Run another round (up to MAX_ROUNDS)" ]; then
    CONTINUE_REFINING=true
else
    CONTINUE_REFINING=false
fi
```

### Iterate or Finalize

```bash
if [ "$CONTINUE_REFINING" = true ] && [ "$CURRENT_ROUND" -lt "$MAX_ROUNDS" ]; then
    # Copy current round output to become input for next iteration
    cp "$WORK_DIR/plan-round-$CURRENT_ROUND.md" "$PLAN_FILE"
    CURRENT_ROUND=$((CURRENT_ROUND + 1))

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Continuing to round $CURRENT_ROUND..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # LOOP BACK TO PHASE 1
    # Next iteration will:
    # - Phase 1: Build new review prompt with updated plan
    # - Phase 2: Send to models again in parallel
    # - Phase 3: Synthesize new round of improvements
    # - Phase 4: Check convergence again

    # Complete THIS round's task, then TaskCreate the NEXT round's task at the top of the loop
    # TaskUpdate("Round {CURRENT_ROUND-1} — ...", status: "completed", description: "{scope} scope, {n} auto-applied")
    # [Loop continues...]

else
    # EXIT LOOP - Proceed to Phase 5 (Finalize)
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Refinement complete after $CURRENT_ROUND rounds"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Complete this round's dynamic task
    # TaskUpdate("Round {CURRENT_ROUND} — ...", status: "completed", description: "{scope} scope, {n} auto-applied")

    # Proceed to finalization
    echo "Proceeding to Phase 5: Finalize..."
fi
```

**Note:** The loop continues until either:

1. Changes become incremental AND user chooses to finalize
2. MAX_ROUNDS is reached
3. User manually stops process

---

## Phase 5: Finalize

### Conductor Triage

**TaskUpdate("Conductor triage", status: "in_progress")**

Read the consensus registry. Collect all remaining single-model findings that never achieved cross-round consensus.

**If nothing remains:** Skip — mark this task `completed` and proceed to Present Decisions (which will also skip).

**Classify each remaining no-consensus finding:**

| Category | Criteria | Action |
|---|---|---|
| `AUTO_IMPLEMENT` | There is a clearly superior answer — better correctness, robustness, or completeness. The improvement is unambiguous. | Apply now via a sequential Haiku subagent (same pattern as Step 2). |
| `DESIGN_DECISION` | No objectively superior answer AND the choice would **noticeably affect the end-user experience** or **profoundly change the development approach**. | Defer to user. |
| `SCOPE_ESCALATION` | A technically superior option exists but requires profound structural change that constitutes a strategic commitment. | Defer to user with scope context. |

**Default bias: `AUTO_IMPLEMENT`.** Most single-model suggestions that never recurred still have a correct answer — pick it.

**Apply all `AUTO_IMPLEMENT` items now, via sequential Haiku subagents (same pattern as Step 2). Log each with rationale.**

**TaskUpdate("Conductor triage", status: "completed", description: "{n} auto-implemented, {m} deferred to user")**

### Present Decisions

**TaskUpdate("Present decisions", status: "in_progress")**

**If no `DESIGN_DECISION` or `SCOPE_ESCALATION` items remain:** Skip — mark this task `completed` and proceed to Apply + update plan + commit.

**If items remain:**

```
AskUserQuestion(
  questions: [{
    question: "Auto-implemented {N} clear improvements across {CURRENT_ROUND} rounds. {M} items need your decision:",
    header: "Decisions",
    multiSelect: true,
    options: [
      { label: "Change X: <title>", description: "DESIGN_DECISION — Round {R}, {model}: {section} — <one-line summary>" },
      { label: "Change Y: <title>", description: "SCOPE_ESCALATION — {model}: {section} — <one-line summary>. Scope: {what it entails}" }
    ]
  }]
)
```

**If more than 4 items:** Split across multiple `AskUserQuestion` calls.

**Apply any user-approved findings via sequential Haiku subagents (same pattern as Step 2).**

**TaskUpdate("Present decisions", status: "completed")**

### Apply + Update Plan + Commit

**TaskUpdate("Apply + update plan + commit", status: "in_progress")**

#### Copy Final Plan

```bash
# Copy final refined plan to original location
FINAL_PLAN="$WORK_DIR/plan-round-$CURRENT_ROUND.md"
cp "$FINAL_PLAN" "$PLAN_FILE"
echo "✓ Final plan written to: $PLAN_FILE"
```

#### Create Master Changelog

**Combine all round changelogs into comprehensive log:**

```bash
cat > "$WORK_DIR/REFINEMENT-LOG.md" <<MASTER_LOG
# Plan Refinement Log

**Plan:** $PLAN_FILE
**Date:** $(date +%Y-%m-%d)
**Rounds completed:** $CURRENT_ROUND
**Models used:** ${MODELS[@]}

---

MASTER_LOG

# Append each round's changelog
for round in $(seq 1 $CURRENT_ROUND); do
    echo "" >> "$WORK_DIR/REFINEMENT-LOG.md"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$WORK_DIR/REFINEMENT-LOG.md"
    echo "" >> "$WORK_DIR/REFINEMENT-LOG.md"
    cat "$WORK_DIR/changelog-round-$round.md" >> "$WORK_DIR/REFINEMENT-LOG.md"
done

# Add model contribution analysis
cat >> "$WORK_DIR/REFINEMENT-LOG.md" <<'ANALYSIS'

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Model Contribution Summary

ANALYSIS

# Analyze which models contributed most value
# Read all changelogs and synthesize model performance

cat >> "$WORK_DIR/REFINEMENT-LOG.md" <<BREAKDOWN

## High-Value Contributions by Model

**Gemini:**
[Summary of Gemini's best contributions across rounds]

**GPT:**
[Summary of GPT's best contributions across rounds]

**Kimi:**
[Summary of Kimi's best contributions across rounds]

**GLM:**
[Summary of GLM's best contributions across rounds]

---

## Cross-Model Consensus Improvements

[List improvements that 3+ models agreed on - highest signal]

1. [Consensus improvement 1]
2. [Consensus improvement 2]
3. [Consensus improvement 3]

---

## Evolution Summary

**Round 1 → Round $CURRENT_ROUND:**

- Structural changes: [count]
- Significant enhancements: [count]
- Incremental refinements: [count]
- **Total improvements integrated:** [X]

---

## Artifacts

All refinement artifacts saved to: $WORK_DIR

- \`review-prompt-round-N.md\` - Prompts sent to models each round
- \`round-N-[model].md\` - Raw model responses
- \`plan-round-N.md\` - Plan state after each round
- \`changelog-round-N.md\` - Changes documented per round
- \`REFINEMENT-LOG.md\` - This master log

BREAKDOWN

echo "✓ Master changelog created: $WORK_DIR/REFINEMENT-LOG.md"
```

#### Safety Check & Commit

```bash
git status --short
```

**Review output:**

- **If ANY deletions (D):** STOP and ask user "You're about to delete X files. Is this intentional?"
- Wait for confirmation before proceeding if deletions present

#### Commit Refinement Artifacts

```bash
# Copy refinement log to project for version control
cp "$WORK_DIR/REFINEMENT-LOG.md" _plans/research/ 2>/dev/null || true

# Commit refined plan + log
git add "$PLAN_FILE"
git add _plans/research/REFINEMENT-LOG.md 2>/dev/null || true

# Create commit with detailed message
git commit -m "$(cat <<EOF
docs(plan): multi-model refinement - $CURRENT_ROUND rounds complete

Plan: $PLAN_FILE
Models: ${MODELS[@]}
Rounds: $CURRENT_ROUND
Improvements: [X total - Y structural, Z significant]

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
git push

git status
```

**TaskUpdate("Apply + update plan + commit", status: "completed")**

### Report

**TaskUpdate("Report", status: "in_progress")**

#### Present Final Summary

```markdown
## Plan Refinement Complete (External)

**Plan:** {PLAN_FILE}
**Models:** {MODELS list}
**Rounds:** {CURRENT_ROUND}
**Refinement log:** {WORK_DIR}/REFINEMENT-LOG.md

### Convergence

Round  Struct  Signif  Increm  Total  Applied  Deferred
  1      {n}     {n}     {n}    {n}     {n}       {n}
  2      {n}     {n}     {n}    {n}     {n}       {n}
  ...

R1  {▓▓▓░░░░████}  {total}
R2  {░░████}       {total}  {-N%}
R3  {████}         {total}  {-N%}

▓ Structural  ░ Significant  █ Incremental

### Resolution

Found: {total} across {CURRENT_ROUND} rounds
  ├─ Auto-applied (scope):         {n}  {bars}
  ├─ Auto-applied (same-round):    {n}  {bars}
  ├─ Auto-applied (cross-round):   {n}  {bars}
  ├─ User-approved:                {n}  {bars}
  └─ Discarded (no consensus):     {n}  {bars}

### Model Contributions

- **{model}:** {key contribution pattern}
- **{model}:** {key contribution pattern}

**Stop reason:** {incremental convergence | MAX_ROUNDS | user decision}

### Artifacts

- `round-N-[model].md` — raw model responses
- `plan-round-N.md` — plan state after each round
- `changelog-round-N.md` — changes per round
- `REFINEMENT-LOG.md` — full refinement narrative
```

**Present next step choice with `AskUserQuestion`:**

```
AskUserQuestion(
  questions: [{
    question: "Multi-model refinement complete ({CURRENT_ROUND} rounds). Mark as loop-ready?",
    header: "Loop-ready?",
    multiSelect: false,
    options: [
      { label: "Loop-ready — run plan-clean first (Recommended)", description: "Run /ac-plan-clean correctness check, then mark loop-ready so ac-loop picks it up" },
      { label: "Loop-ready — skip clean", description: "Mark loop-ready now — ac-loop will beadify and ship it autonomously" },
      { label: "Enhance further", description: "Run /ac-plan-lab (alien mode) — paradigm-breaking alternative perspectives before deciding" },
      { label: "Done for now", description: "Plan saved — mark loop-ready later when you're ready" }
    ]
  }]
)
```

**If user chose either loop-ready option:** update the plan frontmatter and commit:

```bash
# Update status to loop-ready (signals ac-loop to pick this plan up)
# Edit the plan file's YAML frontmatter: status: loop-ready
git add "$PLAN_FILE"
git commit -m "docs(plan): mark loop-ready

Co-Authored-By: Claude <noreply@anthropic.com>"
```

**TaskUpdate("Report", status: "completed")**

---

## Flexibility & Overrides

### User Can Adjust Process

**`MIN_ROUNDS=2` is NOT user-adjustable** — it's an absolute floor (Craig's call, 2026-07-07).
Every override below adjusts `MAX_ROUNDS` only; the floor still applies underneath it.

**"Quick refinement (3 rounds max)"**
→ Set `MAX_ROUNDS=3` before starting

**"Thorough refinement (7 rounds)"**
→ Set `MAX_ROUNDS=7` for deep iteration

**"Use fewer models (faster/cheaper)"**
→ Adjust: `MODELS=(gemini gpt)` - Cuts cost/time in half

**"Focus on [specific aspect]"**
→ Add focus section to review prompt:

```bash
cat >> "$WORK_DIR/review-prompt-round-$CURRENT_ROUND.md" <<'FOCUS'

**Special focus areas for this review:**
- [Performance optimization]
- [Security considerations]
- [User experience]

FOCUS
```

**"Skip convergence check (auto-run all rounds)"**
→ Remove user prompts in Phase 4, always continue until MAX_ROUNDS

**"Resume from specific round"**
→ If interrupted, set `CURRENT_ROUND=3` and `WORK_DIR` to existing location

**Trust user's judgment on customization.**

---

## Token/Cost Usage

**Expected per round (typical plan ~2000 words):**

| Model  | Input Tokens | Output Tokens | Cost/Round |
| ------ | ------------ | ------------- | ---------- |
| Gemini | ~3000        | ~2000         | $0.08      |
| GPT    | ~3000        | ~2000         | $0.12      |
| Kimi   | ~3000        | ~2000         | $0.06      |
| GLM    | ~3000        | ~2000         | $0.05      |

**Total costs (4 models):**

- **3 rounds:** ~$0.93
- **5 rounds:** ~$1.55
- **7 rounds:** ~$2.17

**Quick mode (2 models, 3 rounds):** ~$0.45

**Actual cost depends on plan length and rounds needed for convergence.**

---

## Domain Flexibility

**This workflow works across domains:**

**Software/Architecture:**

- API design documents
- System architecture plans
- Technical specification refinement

**Product/Business:**

- Feature requirements
- Product strategy documents
- Business model plans

**Content/Research:**

- Editorial plans
- Research proposals
- Content strategy documents

**The multi-model review methodology is domain-agnostic. Models provide perspective regardless of subject matter.**

---

## Integration with Other Workflows

**Works well BEFORE:**

- `/ac-plan-lab` (alien mode) - Paradigm-breaking alternative perspectives
- Implementation - Start building from validated plan

**Works well AFTER:**

- Initial brainstorming / ideation
- Manual drafting - Get initial plan down, then refine

**Example workflow:**

1. **Brainstorm** → Explore approaches (ideation)
2. **Draft** → Manual initial plan based on brainstorm recommendation
3. **Refine** → `/ac-plan-refine-external` (this command) - Multi-model refinement
4. **Enhance** → `/ac-plan-lab` (alien mode) - Alien perspective
5. **Implement** → Execute refined plan

**Complementary commands:**

- `plan-review-genius.md` - Single-model deep forensic review
- `plan-transcender-alien.md` - Paradigm-breaking alternatives
- `idea-review-genius.md` - Review specific ideas from plan

---

## Technical Notes

### Model Selection

**Models (4 total) — defined here, this file is source of truth:**

- `gemini` → `google/gemini-3.1-pro-preview` (diverse reasoning, Google's latest)
- `gpt` → `openai/gpt-5.2` (industry standard, broad training)
- `kimi` → `moonshotai/kimi-k2.5` (long context, structured analysis)
- `glm` → `z-ai/glm-5` (strong reasoning, Chinese AI perspective)

**Note:** Model IDs are OpenRouter identifiers. Verify availability with `openrouter --list-models` before running.

**Update process:** Edit this section when changing models. Aliases defined in openrouter.md.

### Reasoning Flag

```bash
--reasoning high
```

Enables deeper analysis on supported models. Kimi K2.5 and GLM-5 benefit significantly from this flag.

### Parallel Execution

**Why parallel matters:**

- Sequential: 8-16 minutes per round (4 models × 2-4 min each)
- Parallel: 2-4 minutes per round (all models simultaneously)
- **4x speedup** with no quality tradeoff

**Implementation:** Bash background jobs (`&` and `wait`)

### OpenRouter Integration

**Tool location:** `openrouter` (must be in PATH)

**Working invocation pattern:**

```bash
openrouter --model MODEL_ID --file /path/to/prompt.md --no-stream 2>/dev/null > /path/to/output.md
```

**Flags used:**

- `--model` / `-m` - Model selection (OpenRouter model ID)
- `--file` - Send file content as prompt
- `--no-stream` - **REQUIRED for file output** (streaming mode breaks redirects)

**CRITICAL: Known issues (learned from real usage):**

- **DO NOT use `-o` / `--output` flag** — produces empty files for many models. Always use stdout redirect (`>`) instead.
- **DO NOT omit `--no-stream`** — streaming mode outputs chunks that corrupt file redirects.
- **Always use `2>/dev/null`** — some models (especially thinking/reasoning models) emit reasoning chains to stderr which pollute output.
- **Some models fail silently in parallel** — verify output file size after parallel runs. If a file is empty (0 bytes), retry that model sequentially.
- **Kimi K2.5 can stall** on long prompts — set a timeout or be prepared to kill and use partial output.

**Environment:** Requires `OPENROUTER_API_KEY` in `.env`

---

## Troubleshooting

**Problem:** Model output file empty (0 bytes) or missing after Phase 2
**Solution:**

- **Most common cause:** Using `-o`/`--output` flag instead of stdout redirect. Fix: `--no-stream 2>/dev/null > output.md`
- If parallel run produced empty files, retry failed models sequentially (one at a time)
- Check OpenRouter API key in `.env`
- Verify network connection
- Run single model manually to debug: `openrouter --model MODEL_ID --file prompt.md --no-stream 2>/dev/null`

**Problem:** Changes not converging (stuck in loop)
**Solution:**

- Lower `MAX_ROUNDS` to force exit
- Manually review changelogs - convergence may have been reached
- Check if models are giving conflicting advice (synthesis challenge)

**Problem:** Models giving contradictory suggestions
**Solution:**

- Focus on consensus (3+ models agree = high signal)
- Use synthesis to resolve conflicts logically
- Consider if conflict reveals legitimate tradeoff

**Problem:** Plan getting too long/complex
**Solution:**

- Focus synthesis on structural improvements only
- Skip minor wording changes
- Prefer removing complexity over adding features

**Problem:** Synthesis taking too long
**Solution:**

- Synthesize incrementally (section by section)
- Focus on top 3-5 improvements per model
- Skip consensus items that are obvious

---

## Remember

**You are the conductor, not the musician:**

✅ YOU coordinate the workflow and track progress
✅ YOU synthesize model feedback using your reasoning
✅ YOU make decisions about convergence
✅ BASH executes OpenRouter calls in parallel
✅ MODELS provide diverse perspectives
✅ YOU blend the "best of all worlds" into superior plan

**Multi-model refinement principles:**

✅ Parallel execution is fast and cost-effective (4x speedup)
✅ Convergence detection prevents over-refinement
✅ Same-round consensus across models is high-signal (trust it)
✅ Cross-round consensus — single-model findings that recur in later rounds are high-signal, auto-apply on match
✅ One human touchpoint — remaining no-consensus items presented once in Phase 5, not per-round
✅ Synthesis step is where value comes from (your reasoning work)
✅ Full audit trail shows evolution (useful for future reference)
✅ Iterative refinement catches blind spots no single model would see
✅ Consensus registry in WORK_DIR persists through compaction — always read from files, not memory

**Common mistakes to avoid:**

❌ Don't skip synthesis - copying one model verbatim is worse than current plan
❌ Don't refine endlessly - watch for incremental changes (convergence)
❌ Don't ignore consensus - if 3+ models agree, probably correct
❌ Don't add complexity without justification - scrutinize new features
❌ Don't forget to review the log - understand WHY changes were made
❌ Don't proceed without committing artifacts - preserve the refinement history

---

_Inspired by Jeffrey Emanuel's APR (Automated Plan Reviser Pro). Adapted for Claude Code + OpenRouter._
