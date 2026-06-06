---
name: land
description: Session closure with retrospective learning and system compounding — land work, capture lessons, update skills/commands. Triggers: 'land the session', 'bead land', 'close out', 'capture learnings', 'wrap up session'.
disable-model-invocation: true
---


**You are the conductor closing a bead-work session.** Land the plane, extract learnings, propose system upgrades, hand off cleanly.

Run this after `/bead-work` completes its target beads.

---

## Phase 0: Initialize

### Gather Session Context

Resolve `ARTIFACTS_DIR` — solo sessions use `/tmp/bead-work`, parallel sessions use a session-unique `/tmp/bead-work-$$`. Detect which one:

```bash
# Prefer the parallel-session dir if it exists; fall back to solo
if [ -f /tmp/bead-work/progress.md ] && ! ls /tmp/bead-work-*/progress.md >/dev/null 2>&1; then
  ARTIFACTS_DIR=/tmp/bead-work
else
  # Newest parallel-session dir wins (this session)
  ARTIFACTS_DIR=$(ls -1dt /tmp/bead-work-*/ 2>/dev/null | head -1 | sed 's:/$::')
  [ -z "$ARTIFACTS_DIR" ] && ARTIFACTS_DIR=/tmp/bead-work
fi
echo "ARTIFACTS_DIR=$ARTIFACTS_DIR"
```

**You MUST substitute the resolved `$ARTIFACTS_DIR` into all sub-agent prompts below.** The literal string `/tmp/bead-work` in this file is a placeholder — for parallel sessions you write the actual resolved path (e.g., `/tmp/bead-work-2939805`) into each spawned agent's prompt. Do NOT pass the variable name; sub-agents don't share the parent shell.

Read `$ARTIFACTS_DIR/progress.md` — this is the record of what was accomplished. If it doesn't exist, STOP: "No bead-work progress found. Run `/bead-work` first."

Also gather:

```bash
# What beads were completed this session
br list --json

# Recent commits (the session's work)
git log --oneline -20

# Current state
git status
git diff --stat
```

---

## Phase 1: Land the Plane

**NON-NEGOTIABLE. No work stranded locally.**

### 1a. File Remaining Work

- Check for any started-but-unclosed beads: `br list --json` — look for claimed/in-progress items
- For each: either close it (if done) or add a comment documenting where you left off
- Create new beads for any loose ends discovered during the session:
  ```bash
  br create "Follow-up: <description>" --priority P1 --description "Discovered during bead-work session. Context: ..."
  ```

### 1b. Quality Gates

```bash
# Format / lint / type-check run fast — terminal-only output is fine.
pnpm format && pnpm lint && pnpm type-check

# pnpm test:all takes ~10 min on this project; tee to a log so failure detail
# survives the tail-truncation that destroys diagnostic context.
pnpm test:all 2>&1 | tee "$ARTIFACTS_DIR/test-all.log" | tail -30

# Build check (fast — terminal-only).
pnpm build:check
```

> **Why `tee`, not bare `tail`:** vitest's reporter buffers nontrivially and the final summary doesn't necessarily land in the last 20 lines if failures occurred earlier. A bare `pnpm test:all 2>&1 | tail -15` discards mid-run failure detail and forces a second 10-minute re-run to diagnose. Concrete cost (wave/app-first-feel 2026-05-19 bead-land): conductor ran `tail -15` first, lost the failure detail, had to re-run with output redirected to a file — ~10 min wasted. The full log at `$ARTIFACTS_DIR/test-all.log` is grep-addressable for `FAIL`, `❯`, `×`, `AssertionError`, etc.

If any fail:

- **Fixable in <5 min:** Fix them now, commit the fix
- **Larger issues:** Create a P0 bead, document the failure, continue landing

**Repo-wide format sweep (separate commit).** Bead-work enforces per-bead formatter scope so individual bead diffs stay clean. Bead-land is where the whole-repo formatter runs once, in its own commit, so each bead's PR-level diff remains scope-focused while the tree still ends up consistently formatted. Run it here:

```bash
pnpm format   # or equivalent repo-wide prettier --write .
git diff --stat
```

If the sweep modified any file, commit it on its own:

```bash
git add -A
git commit -m "chore: format sweep (prettier)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

If nothing changed (tree was already formatted), skip the commit.

### 1c. UI Validation Suite

After code quality gates pass, run UI validation for any session that changed runtime code.

**Skip ONLY if:**
- Session was purely docs/config with zero runtime code changes (no .tsx/.ts in app/, features/, lib/, components/)

**Run if ANY runtime code was changed** (API routes, UI components, hooks, utils).

#### Step 1: Verify Browser Testing Availability (MANDATORY)

You MUST check both paths before concluding browser testing is unavailable:

```bash
# Check 1: CLI tool
which agent-browser 2>/dev/null && echo "AVAILABLE" || echo "NOT FOUND"
```

```
# Check 2: Agent type (always available in Claude Code)
# The `browser-tester` agent type is built-in — check available agent types in your system prompt
```

```bash
# Check 3: Journey definitions
ls .claude/skills/browser-testing/journeys/ 2>/dev/null
```

**All three must fail** before skipping. If `agent-browser` CLI exists OR `browser-tester` agent type is available, proceed with UI validation. Do NOT assume unavailability without running these checks.

#### Step 1b: Pre-Warm Dev Server (before spawning browser agents)

Cold Next.js / Turbopack pages trigger a full compile on first hit. If a browser-tester agent is the first to touch a journey's starting URL, the compile can stall the browser connection long enough that the `agent-browser` daemon hangs (5 minute+ retries, then daemon-busy errors). Pre-warm with curl first:

```bash
# Hit each journey's starting URL once — forces the compile to complete before agents connect
curl -s -o /dev/null -w "%{url}: %{http_code} (%{time_total}s)\n" --max-time 60 http://localhost:3000/
curl -s -o /dev/null -w "%{url}: %{http_code} (%{time_total}s)\n" --max-time 60 http://localhost:3000/login
# Add curls for any other URLs the journeys will visit (food entry, dashboard, etc.)
```

A 200/307/308 in <2s means the page is warm. If a curl hangs >30s, that's a real problem to debug before spawning agents. Auth-gated pages (e.g. `/app`) returning 307 to `/login` is fine — testers handle their own auth.

**Why this matters:** During the bd-3utx wave, skipping this cost ~10-15 minutes — first browser-tester agent hung waiting for cold compile, daemon went unresponsive, second agent had to be killed and restarted with manual pre-warm. Cheap to do, expensive to skip.

#### Step 2: Route to Relevant Journeys

Use `git diff --stat` against the session's first commit to determine which areas were changed. Cross-reference with project journey definitions (if any) to identify relevant UI tests.

#### Step 3: Spawn Testers

**One tester per matched journey, all in parallel.** If 2+ journeys match, send all Task calls in a single message for concurrent execution.

````
Task(subagent_type: "browser-tester", prompt: """
You are a browser tester. Your job: run a UI journey happy path and report results. You test and report — never edit code.

## Your Task
Run the <journey-name> journey happy path. This is session closure smoke testing.

### Setup
1. Dev server is already running
2. Open the journey's starting URL using the project's browser testing tool

### Test

Run Happy Path steps from the journey definition. Focus on:

- Elements render correctly
- Interactions work (clicks, form fills, navigation)
- No console errors
- Correct data flow (saves, displays, updates)

### Output

Write report to <ARTIFACTS_DIR>/ui-suite-<journey-name>.md
Include screenshots for any failures.
Happy path only — skip edge cases.
""")
````

> Substitute `<ARTIFACTS_DIR>` with the resolved path from Phase 0 (e.g., `/tmp/bead-work-2939805` for parallel mode, `/tmp/bead-work` for solo).

#### Step 4: Review Results

Read all report files from `<ARTIFACTS_DIR>/ui-suite-*.md` (use the resolved path from Phase 0).

- **All PASS:** Continue to git operations
- **Any FAIL:** Fix the issue, re-run only the failing journey's tester, then continue
- **Skipped:** Note "UI validation skipped (no browser tool / no journeys defined)"

### 1d. Git Operations

```bash
git add <specific files>
git commit -m "chore: bead-work session cleanup

Co-Authored-By: Claude <noreply@anthropic.com>"
```

Only commit if there are uncommitted changes (cleanup, format fixes, etc.).

```bash
git pull --rebase
git push
git status   # Must show "up to date with origin"
```

**If push fails:** Resolve and retry. Do not proceed until pushed.

---

## Phase 2: Learn (Retrospective)

**Goal:** With complete information, identify what worked, what didn't, and what friction occurred.

### Spawn Retrospective Sub-Agent

```
Task(subagent_type: "general-purpose", model: "sonnet", prompt: """
You are a retrospective analyst reviewing a completed bead-work session.

## Session Artifacts

Read these files:
1. <ARTIFACTS_DIR>/progress.md — beads completed, commits, files changed
2. Any <ARTIFACTS_DIR>/bead-*-result.md files — engineer implementation reports
3. AGENTS.md — current project context, conventions, and coding standards

## Workflow & Skill Files

Read the command files that ran during this session so you can identify workflow friction:
- `.claude/commands/ac/bead-work.md` — the implementation workflow
- `.claude/commands/ac/bead-land.md` — this landing workflow

Scan the full skill inventory (AGENTS.md > Available Skills) against the beads implemented. Look for:
- Skill files referenced by beads — read these for domain pattern violations
- Skills that SHOULD have been used but weren't — e.g., a migration bead that didn't leverage the supabase skill, or a component bead that ignored the design-system skill. Flag these as upgrade opportunities.

## Git Context

Run these commands to understand the session's work:
- `git log --oneline -20` — recent commits
- `git diff HEAD~N..HEAD --stat` (where N = number of session commits) — files changed

## Your Analysis

Write your findings to <ARTIFACTS_DIR>/retrospective.md with these sections:

### What Worked
- Patterns that produced clean, fast results
- Bead specs that led to good implementations
- Tools/commands that worked smoothly

### What Didn't Work
- Beads that needed multiple engineer attempts (and why)
- Quality gate failures and their causes
- Friction points in the workflow

### Patterns Observed
- Recurring code patterns across beads
- Common test patterns
- Dependency patterns

### System Upgrade Opportunities

Look across ALL system files — not just MEMORY.md. Each target type has a purpose:

| Target | What belongs here | Example |
|--------|------------------|---------|
| `.claude/commands/*.md` | Workflow steps that caused friction, missing instructions, unclear prompts | "bead-work Phase 1c should remind conductor to scope test runs" |
| `.claude/skills/*.md` | Domain patterns discovered or violated during implementation | "testing skill should document the dotenv-worker quirk" |
| `AGENTS.md` | New conventions, quality gate changes, project-wide rules | "Add convention: never hardcode secrets in test files" |
| `MEMORY.md` | Gotchas and quirks that don't fit the above — last resort, not default | "supabase gen types outputs debug line" |

**MINIMUM BAR for proposing an upgrade:** The issue must have caused measurable waste THIS session — lost time, wasted tokens, incorrect output, or a mistake that had to be fixed. "Sounds like a good idea" or "might help someday" is NOT sufficient. The information must be non-obvious (an experienced engineer wouldn't know it without hitting the problem), and having it documented from the start would have saved real time or resources.

If nothing caused real waste this session, propose zero upgrades. Empty is better than bloat.

For each opportunity that clears the bar, provide:
- **Target:** The specific file path to update
- **Change:** What specifically to add, modify, or remove
- **What it cost us:** Concrete time/resource waste from this session (e.g., "engineer touched 12 unrelated files, conductor spent 10 minutes selectively staging")
- **Evidence:** Specific examples from this session

Prioritize command/skill improvements over MEMORY.md additions. If a learning improves a workflow step, put it in the command file. If it documents a domain pattern, put it in the skill file. MEMORY.md is for one-off quirks only.

Context bloat is the enemy. Prefer refining existing content over adding new content.
If nothing caused real waste, say so — don't invent learnings to fill the report.
""")
```

### Conductor Reviews Retrospective

Read `<ARTIFACTS_DIR>/retrospective.md` (use the resolved path from Phase 0). Apply the minimum bar: did this issue cause real waste THIS session? Drop anything that's "interesting but theoretical." Keep only items where you can point to a specific moment where time or resources were lost because the information wasn't available upfront.

---

## Phase 3: Compound (System Upgrades)

**Goal:** Turn learnings into system improvements. User decides what ships.

**NO AUTO-APPLY.** Unlike review commands (`plan-clean`, `hygiene`, `work-review`, `bead-refine`) which auto-apply consensus findings, bead-land presents ALL upgrade proposals to the user. System compounding changes identity and workflow — every change needs explicit approval.

### Present Upgrades to User

First, output each upgrade opportunity so the user can see the details:

```
## Upgrade N: <title>
**Severity:** Critical | High | Medium | Low
**Target:** <file path>
**Evidence:** <what happened this session>
**Proposed Change:**
<exact diff or content to add/modify/remove>
```

Group by severity (Critical first, Low last). Present ALL of them.

Then use `AskUserQuestion` with `multiSelect: true` to let the user pick interactively:

```
AskUserQuestion(
  questions: [{
    question: "Which system upgrades should I apply?",
    header: "Compound",
    multiSelect: true,
    options: [
      { label: "Upgrade 1: <title>", description: "Critical — <one-line summary>" },
      { label: "Upgrade 2: <title>", description: "High — <one-line summary>" },
      { label: "Upgrade 3: <title>", description: "Medium — <one-line summary>" },
      ...up to 4 options per question (AskUserQuestion limit)
    ]
  }]
)
```

**If more than 4 upgrades:** Split across multiple `AskUserQuestion` calls grouped by severity. Critical+High in the first question, Medium+Low in the second. The user can always select "Other" to provide custom input (skip all, apply all, etc.).

### Apply Approved Upgrades

For each approved upgrade, apply the edit directly. Common targets:

| Target                              | What Gets Updated                      |
| ----------------------------------- | -------------------------------------- |
| `AGENTS.md`                         | Workflow improvements, new conventions |
| `CLAUDE.md`                         | Orchestrator context updates           |
| `.claude/commands/*.md`             | Command improvements based on friction |
| `MEMORY.md`                         | New patterns, gotchas, workflow notes  |

### Commit Compound Changes

```bash
git add <specific files>
git commit -m "chore: compound learnings from bead-work session

Applied N system upgrades from retrospective.

Co-Authored-By: Claude <noreply@anthropic.com>"
git push
```

---

## Phase 4: Hand Off

### Session Summary

Output for the user and next session:

```markdown
## Bead-Work Session Summary

**Beads Completed:** N (list IDs + titles)
**Beads Remaining:** M (from `br ready --json`)
**Commits:** K commits pushed

**Quality Gates:** All passing | Issues filed (list)
**UI Validation:** All PASS | Failures fixed (list) | Skipped (docs/config only)

**Learnings Applied:** X upgrades (list targets)

**Open Issues:**

- (any filed beads or blockers)
```

**Present next session choice with `AskUserQuestion`:**

```
AskUserQuestion(
  questions: [{
    question: "Session landed. What's next?",
    header: "Next step",
    multiSelect: false,
    options: [
      { label: "Review & merge (Recommended)", description: "Run /work-review then /wave-merge — review code, create PR, ship to main" },
      { label: "Continue bead-work", description: "Run /bead-work — {M} beads remaining" },
      { label: "Refine remaining beads", description: "Run /bead-refine — revise remaining beads before implementing" },
      { label: "Done for now", description: "Close session — pick up later" }
    ]
  }]
)
```

### Cleanup Temp Files

Remove session artifacts (they've been consumed by retrospective). Run each separately to avoid shell chaining that triggers safety hooks:

```bash
rm -rf /tmp/bead-work
rm -rf /tmp/bead-work-*
rm -rf /tmp/plan-refine-internal-*
rm -rf /tmp/plan-refine-*
rm -rf /tmp/plan-clean-*
rm -rf /tmp/bead-refine-*
rm -rf /tmp/beadify-*
rm -rf /tmp/hygiene-*
rm -rf /tmp/work-review-*
```

### Final Verification

```bash
git status          # Clean working tree
git log --oneline -1  # Latest commit pushed
br ready --json     # What's left
```

---

## Remember

- **Land is NON-NEGOTIABLE** — push before learning
- **Learn from evidence, not speculation** — every finding needs a concrete example from this session
- **Compound aggressively but ALWAYS user-gated** — no auto-apply, every upgrade needs explicit approval (unlike review commands)
- **Context bloat is the enemy** — refine existing content, don't just append
- **Temp files are the source of truth** — read from `$ARTIFACTS_DIR`, not memory
- **This is what makes the flywheel accelerate** — each session improves the next

---

_Bead land: close clean, learn deep, compound forward. The flywheel spins faster every session._
