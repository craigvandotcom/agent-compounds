---
name: ac-hygiene
description: Iterative codebase review — 3 agents, multiple rounds until plateau — surfaces reuse/simplification/correctness cleanups. Triggers: 'hygiene', 'clean up the codebase', 'iterative review', 'tidy the code'.
---


**You are the conductor.** Three reviewers hunt independently. You synthesize, fix, and iterate. Codebase-wide — not tied to any feature branch or diff.

Run this after a few bead-work sessions, or daily for maintenance. For feature-scoped review, use `/ac-review` instead.

---

## I/O Contract

|                  |                                                                                            |
| ---------------- | ------------------------------------------------------------------------------------------ |
| **Input**        | Full codebase, recent commits, or specific directory (user-selected scope)                 |
| **Output**       | Fixed issues committed, health assessment report                                           |
| **Artifacts**    | Round findings in `$ARTIFACTS_DIR/round-{N}-{role}.md`, consensus registry                 |
| **Verification** | Quality gate (test, lint, type-check, build) all passing                                   |

## Phase 0: Initialize

### Select Scope

Ask user with `AskUserQuestion`:

```
question: "What should the review focus on?"
header: "Scope"
options:
  - label: "Full codebase (Recommended)"
    description: "Agents choose where to look — recent changes, hot paths, random exploration"
  - label: "Recent changes"
    description: "Focus on last N commits (asks how many)"
  - label: "Specific directory"
    description: "Constrain to a directory tree (asks which)"
```

If "Recent changes": ask for commit count, then `git log --oneline -N` to build scope context.
If "Specific directory": ask for path, then list source files in that directory to build scope context.

### Configuration

```
SCOPE=<user selection>
SCOPE_CONTEXT=<commit list or directory listing, if scoped>
CURRENT_ROUND=1
MAX_ROUNDS=4
ARTIFACTS_DIR=/tmp/hygiene-$(date +%Y%m%d-%H%M%S)
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

<!-- Format: | Round | Agent | Severity | File | Summary | -->
EOF
```

### Compaction Recovery

If `$ARTIFACTS_DIR/progress.md` exists, parse the last `### Round N` entry to recover `CURRENT_ROUND` (set to N+1). Previous rounds' fixes are already applied. If `$ARTIFACTS_DIR/consensus-registry.md` exists, read it to recover the deferred findings pool for cross-round consensus detection.

### Gather Codebase Context

Build a brief context snapshot for the agents:

```bash
# Recent activity
git log --oneline -20

# Project structure (discover source directories)
ls -d */ | head -20

# Current test health — run project test command (see AGENTS.md > Project Commands)
# Example: pnpm test, pytest, cargo test

# Any existing lint/type issues — run project lint/type-check (see AGENTS.md > Project Commands)
```

Save this as `CODEBASE_CONTEXT` for agent prompts.

### Skill Routing

Scan codebase for domain keywords. Check `AGENTS.md > Available Skills` for relevant skills. Include skill paths in reviewer prompts where applicable.

### Create Workflow Tasks

```
TaskCreate(subject: "Phase 0: Initialize hygiene review", description: "Select scope, gather context, create consensus registry", activeForm: "Initializing hygiene review...")
TaskCreate(subject: "Phases 1-4: Review loop", description: "3 Opus agents per round, synthesize, apply fixes, convergence check. Up to MAX_ROUNDS.", activeForm: "Running hygiene review...")
TaskCreate(subject: "Phase 5: Finalize", description: "Present no-consensus findings, quality gate, commit, report", activeForm: "Finalizing hygiene review...")
```

**TaskUpdate(task: "Phase 0", status: "completed")**

---

## REVIEW LOOP: Phases 1-4

### Phase 1: Spawn 3 Reviewers (parallel)

**All 3 agents in a single message for parallel execution.**

Spawn the three reviewers (Bug Hunter, Explorer, Structural — all Opus) using the prompts in **`references/reviewers.md`**, substituting `{SCOPE_CONTEXT}`, `{CURRENT_ROUND}`, and `{ARTIFACTS_DIR}`. Each writes to `$ARTIFACTS_DIR/round-{CURRENT_ROUND}-{role}.md`. **Between rounds**, add the "Files already reviewed: {list}. Look elsewhere." line to each prompt (see Phase 4).

### Phase 2: Synthesize

**Read all 3 findings files.** This is your core job — do not delegate.

Synthesis principles:

- **Consensus is high-signal** — 2+ agents flagging the same area is almost certainly real
- **Evidence over opinion** — findings need file paths and line numbers
- **Don't pile on** — if explorer finds dead code, that's cleanup, not a bug
- **Critical/High first** — skip Medium unless trivial to fix

Produce a numbered change list. For each: target file, what to change, auto-fixable or not.

### Phase 3: Apply Fixes

**Auto-apply a fix if ANY condition is met:**

1. **Severity-based:** The issue is Critical or High severity — these are defects, not preferences
2. **Same-round consensus:** 2+ agents independently flagged the same issue (regardless of severity) — multi-agent agreement is high-signal
3. **Cross-round consensus:** A single-agent finding from THIS round matches a deferred finding in the consensus registry from a PREVIOUS round — recurrence across rounds is high-signal

**Design decision gate (applies before all auto-apply rules):** If a finding represents a choice with no objectively superior technical answer, resolve it yourself — pick the better option. Only tag as `DESIGN_DECISION` and defer if the decision would **noticeably affect the end-user experience** or **profoundly change the development approach**. Minor design choices (spacing values, naming conventions, implementation style) — just pick the better option and auto-apply.

**Apply these immediately. Log them as "Auto-applied" in the progress file with the consensus type.**

After each batch of fixes:

```bash
Run project quality checks (see AGENTS.md > Project Commands > Quality gate)
```

If checks fail, revert the breaking fix and note it as non-auto-fixable.

**Defer remaining findings (DO NOT ask user per-round):**

After auto-applying, any remaining changes (Medium/Low severity AND only flagged by a single agent with no cross-round match) are added to the consensus registry — NOT presented to the user.

For each deferred finding, append to `$ARTIFACTS_DIR/consensus-registry.md`:

```markdown
| {CURRENT_ROUND} | {agent role} | {severity} | {file:line} | {one-line summary} |
```

**`DESIGN_DECISION` items** (choices that noticeably affect user experience or profoundly change development approach) are deferred regardless of severity or consensus — these skip the registry and go directly to the user in Phase 5.

### Phase 4: Convergence Check + Progress

Append to `$ARTIFACTS_DIR/progress.md`:

```markdown
### Round {CURRENT_ROUND}

- **Findings:** {count} total ({Critical} Critical, {High} High, {Medium} Medium)
- **Auto-fixed:** {count}
- **Deferred:** {count} (need judgment)
- **Consensus areas:** {where agents agreed}
- **Trajectory:** {assessment}
```

**Rule: if this round's agents found ANY Critical or High issues, you MUST run another round after applying fixes.** Fixes are unverified until the next round's agents confirm no new Critical/High issues emerge. Only finalize after a round where all findings are Medium or lower.

```
IF agents found any Critical or High issues -> apply fixes, continue (increment CURRENT_ROUND)
IF only Medium or no new issues -> finalize (proceed to Phase 5)
IF CURRENT_ROUND >= MAX_ROUNDS -> force finalize (note unverified fixes)
IF this round found same issues as last round -> force finalize (agents are circling)
```

**Between rounds:** Each agent explores DIFFERENT files in the next round. Include in the next prompt: "Files already reviewed: {list from previous round findings}. Look elsewhere."

---

## Phase 5: Finalize

### Conductor Final Review (Triage)

Read the consensus registry. Collect all remaining items:

1. **No-consensus findings:** Single-agent findings that never recurred across rounds
2. **DESIGN_DECISION items:** Findings deferred during rounds as genuine design decisions

**If nothing remains:** Skip — proceed to quality gate.

**Classify each remaining no-consensus finding:**

| Category | Criteria | Action |
|---|---|---|
| `AUTO_IMPLEMENT` | There is a clearly superior technical answer — better correctness, robustness, performance, or maintainability. The improvement is unambiguous. | Implement it now. |
| `DESIGN_DECISION` | No objectively superior answer AND the choice would **noticeably affect the end-user experience** or **profoundly change the development approach**. Minor design choices (spacing, naming, style) — just pick the better option and classify as `AUTO_IMPLEMENT`. | Defer to user. |
| `SCOPE_ESCALATION` | A technically superior option exists but requires profound structural change that constitutes a strategic commitment. | Defer to user with scope context. |

**Default bias: `AUTO_IMPLEMENT`.** Most findings have a correct answer — pick it.

**Apply all `AUTO_IMPLEMENT` items** using Edit tool. Log each with rationale.

### Present Decisions to User (if any)

**If no `DESIGN_DECISION` or `SCOPE_ESCALATION` items remain:** Skip — proceed to quality gate.

**Exhaust rule (see `skills/_shared/bead-conventions.md`):** nothing actionable
leaves as prose. Out-of-scope confirmed issues → `br create -t bug --labels
hygiene-finding`. Worth-chasing uncertainties → `-t investigation`. Genuine
taste/product forks in an autonomous run (user not present) → `-t decision
--labels human-gate` with a pre-staged memo, then continue — never stall the
sweep on a question. Dedupe via `br search` first; nits stay in the report
(hygiene is the highest inflation risk — a bead is something you'd schedule).

**If items remain (user present):**

```
AskUserQuestion(
  questions: [{
    question: "Auto-applied {N} fixes (severity + consensus + technical triage). {M} items need your decision:",
    header: "Decisions",
    multiSelect: true,
    options: [
      { label: "Fix X: <title>", description: "DESIGN_DECISION — Round {R}, {severity} — {agent}: {file} — {one-line summary}" },
      { label: "Fix Y: <title>", description: "SCOPE_ESCALATION — {severity} — {agent}: {file} — {one-line summary}. Scope: {what it entails}" }
    ]
  }]
)
```

**If more than 4 items:** Split across multiple `AskUserQuestion` calls.

**Apply any user-approved fixes** using Edit tool.

### Quality Gate

```bash
Run full project quality gate (see AGENTS.md > Project Commands > Quality gate)
```

If any fail, fix before proceeding.

### Commit Fixes

Only commit if there are actual code changes (not just findings):

```bash
git add <specific files>
git commit -m "chore: hygiene review - {N} issues fixed across {M} files

Round(s): {CURRENT_ROUND}
Scope: {SCOPE}

Co-Authored-By: Claude <noreply@anthropic.com>"
git push
```

### Report

Produce the summary using the template in **`references/report-template.md`** (convergence table, resolution breakdown, areas reviewed, health assessment).

**Present next step choice with `AskUserQuestion`:**

```
AskUserQuestion(
  questions: [{
    question: "Hygiene review complete ({CURRENT_ROUND} rounds, {fixed} fixed, {deferred} deferred). What's next?",
    header: "Next step",
    multiSelect: false,
    options: [
      { label: "Done", description: "Review complete — no further action needed" },
      { label: "Run again", description: "Another hygiene pass — agents explore different files" },
      { label: "Address deferred items", description: "Work through the items that needed judgment" }
    ]
  }]
)
```

### Cleanup

Remove the temp artifacts directory (safe — always under /tmp):

```bash
find "$ARTIFACTS_DIR" -mindepth 1 -delete && rmdir "$ARTIFACTS_DIR" 2>/dev/null || true
```

---

## When to Use This

Use `/ac-hygiene` for general codebase health between sessions or as a daily maintenance pass. For feature-specific review before merge, consider a scoped review focused on the feature branch diff.

---

## Remember

- **Codebase-wide, not feature-scoped** — agents explore freely (unless user constrains)
- **Fresh eyes each round** — direct agents to unexplored files in subsequent rounds
- **Auto-apply Critical/High + same-round consensus + cross-round consensus — defer the rest**
- **Cross-round consensus:** single-agent findings that recur in later rounds are high-signal — auto-apply on match
- **Conductor triage before user** — remaining items get a final review: auto-implement clear technical improvements, only defer genuine design decisions (user-visible or development-transformative) and scope escalations to the user
- **Design decision gate every round** — choices that noticeably affect user experience or profoundly change development are deferred regardless of severity or consensus
- **Quality gate before commit** — type-check + lint + test + build must pass
- **Findings files + consensus registry survive compaction** — always read from `$ARTIFACTS_DIR`, not memory
- **Don't invent issues** — if the codebase is clean, say so and finish early

---

_Hygiene: iterative codebase review for daily maintenance. For session closure: `/ac-land`._
