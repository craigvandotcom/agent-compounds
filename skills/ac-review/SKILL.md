---
name: ac-review
description: 'Feature-branch code review — parallel reviewers (correctness/security/perf/architecture), severity-based auto-fix + escalation. Triggers: ''review the branch'', ''work review'', ''code review this feature'', ''pre-merge review''.'
---


**You are the conductor.** Four reviewers hunt independently. You synthesize, auto-fix, and escalate. Feature-branch scoped — run after implementation, before merge.

For codebase-wide health checks, use `/ac-hygiene` instead.

---

## I/O Contract

|                  |                                                                                                            |
| ---------------- | ---------------------------------------------------------------------------------------------------------- |
| **Input**        | Feature branch with implementation commits (from `/ac-implement` or manual coding)                  |
| **Output**       | Review report in `.claude/reviews/`, auto-fixed issues committed, NEEDS_DECISION items presented           |
| **Artifacts**    | Reviewer findings in `$ARTIFACTS_DIR/round-1-*.json`, consensus in `consensus-round-1.json` + `consensus-registry.json`, progress in `progress.md` |
| **Verification** | All project checks pass (test, lint, type-check), fixes committed, decisions resolved or documented        |

## Prerequisites

- On a feature branch (not main/master)
- Implementation committed and pushed
- Project test/lint/type-check commands runnable

---

## Phase 0: Initialize

**MANDATORY FIRST STEP: Create task list with TaskCreate BEFORE starting.**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

### Configuration

```
ARTIFACTS_DIR=/tmp/work-review-$(date +%Y%m%d-%H%M%S)
```

```bash
mkdir -p "$ARTIFACTS_DIR"
```

### Discover Project Commands

Read `AGENTS.md > Project Commands` for the project's toolchain. Map to workflow variables:

| Variable        | Source                              |
| --------------- | ----------------------------------- |
| `CMD_TEST`      | AGENTS.md > Project Commands > Test |
| `CMD_LINT`      | AGENTS.md > Project Commands > Lint |
| `CMD_TYPECHECK` | AGENTS.md > Project Commands > Type-check |
| `CMD_BUILD`     | AGENTS.md > Project Commands > Build |
| `CMD_FORMAT`    | AGENTS.md > Project Commands > Format |
| `CMD_QUALITY`   | AGENTS.md > Project Commands > Quality gate |

If AGENTS.md doesn't exist or is incomplete, fall back to auto-detection:

```bash
if [ -f "package.json" ]; then
  if [ -f "pnpm-lock.yaml" ]; then PKG="pnpm"
  elif [ -f "yarn.lock" ]; then PKG="yarn"
  elif [ -f "bun.lockb" ]; then PKG="bun"
  else PKG="npm"; fi
  echo "Available scripts:"
  grep -E '^\s+"[^"]+":' package.json | head -20
fi

if [ -f "Cargo.toml" ]; then echo "Rust: cargo test, cargo clippy, cargo build"; fi
if [ -f "Makefile" ]; then echo "Makefile targets:"; grep -E '^[a-zA-Z_-]+:' Makefile | head -10; fi
if [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then echo "Python project"; fi
if [ -f "go.mod" ]; then echo "Go: go test ./..., go vet, go build"; fi
```

If a command doesn't exist for this project, set it to empty and skip in validation phases.

### Create Workflow Tasks

```
TaskCreate(subject: "Phase 0: Initialize", description: "Discover commands, create tasks", activeForm: "Initializing review...")

TaskCreate(subject: "Phase 1: Gather context", description: "Branch safety, diff scope, plan context, baseline check", activeForm: "Gathering context...")

TaskCreate(subject: "Phase 2: Parallel review", description: "Spawn 4 reviewers (security, performance, architecture, correctness)", activeForm: "Running parallel reviews...")

TaskCreate(subject: "Phase 3: Synthesize findings", description: "Dedup, consensus detection, severity-based auto-apply rules", activeForm: "Synthesizing findings...")

TaskCreate(subject: "Phase 4: Auto-fix", description: "Engineer sub-agent applies fixes, runs project tests", activeForm: "Applying auto-fixes...")

TaskCreate(subject: "Phase 5: Validation gate", description: "Run all discovered project checks", activeForm: "Running validation...")

TaskCreate(subject: "Phase 6: Commit report & fixes", description: "Generate review report, safety check, commit, push", activeForm: "Committing review...")

TaskCreate(subject: "Phase 7: Present decisions", description: "NEEDS_DECISION items via AskUserQuestion", activeForm: "Preparing decisions...")

TaskCreate(subject: "Phase 8: Final report + hand-off", description: "Summary, next step choice, cleanup", activeForm: "Generating final report...")
```

### Consensus Registry — owned by the script

No manual init. The Phase-3 consensus script (`scripts/consensus.py`) creates and maintains
`$ARTIFACTS_DIR/consensus-registry.json` — the cross-round memory of deferred single-reviewer
findings. Don't hand-keep a markdown table; the JSON registry is the source of truth.

### Compaction Recovery

If `$ARTIFACTS_DIR/progress.md` exists, parse its `### Phase N` entries to recover state. If
reviewer findings files (`round-*-*.json`) exist, skip to Phase 3 and (re-)run the consensus
script. `consensus-registry.json`, if present, already holds the deferred pool for cross-round
detection — the script reads it automatically.

**TaskUpdate(task: "Phase 0", status: "completed")**

---

## Phase 1: Gather Context

**TaskUpdate(task: "Phase 1", status: "in_progress")**

### Branch Safety Check (CRITICAL)

```bash
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"
```

**If on main or master:** STOP. "You must be on a feature branch for review. Create one first: `git checkout -b fix/<name>`"

### Detect Review Scope

```bash
# Determine base branch
BASE_BRANCH=$(git merge-base --fork-point main HEAD 2>/dev/null && echo "main" || echo "master")

# Diff against base
git diff "$BASE_BRANCH"...HEAD --stat
git diff "$BASE_BRANCH"...HEAD --name-only
```

### Uncommitted Implementation Check

```bash
UNCOMMITTED=$(git diff --name-only | grep -v "^\.claude/" || true)

if [ -n "$UNCOMMITTED" ]; then
  echo "WARNING: Uncommitted implementation files detected!"
  echo "$UNCOMMITTED"
fi
```

If uncommitted files exist, ask user whether to commit them first or proceed reviewing only committed work.

### Load Plan Context (if exists)

```bash
ls -la _plans/*.md 2>/dev/null | head -5
```

If a plan exists, read it for success criteria, test specifications, and original requirements.

### Skill Routing

Scan changed files for domain keywords. Check `AGENTS.md > Available Skills` for relevant skills to include in reviewer prompts:

- DB/SQL/migrations -> database skills
- UI components/styling -> design-system skills
- React hooks/perf -> performance skills
- Security/auth -> security skills
- Tests -> testing skills

Include relevant skill paths in each reviewer prompt: `"Read .claude/skills/<skill>/SKILL.md for domain patterns."`

### Journey-Doc Sync Check (projects with CORE/journeys/)

If `.claude/skills/CORE/journeys/README.md` exists, compare the branch's
changed files against its "Mapping Changes to Journeys" table. For every
mapped path that changed, the matching journey doc should have been updated
in the same wave (journey docs are test artifacts — the QA agent validates
against them). Mapped UI change + untouched journey doc = a **finding**
(severity: medium), same class as a missing test update.

### Save Context

Append to `$ARTIFACTS_DIR/progress.md`:

```markdown
### Phase 1: Context

- **Branch:** {CURRENT_BRANCH}
- **Base:** {BASE_BRANCH}
- **Changed files:** {count} files, {lines} lines
- **Plan:** {path or "none"}
- **Project commands:** {CMD_TEST}, {CMD_LINT}, {CMD_TYPECHECK}
- **Skills routed:** {list or "none"}
```

**TaskUpdate(task: "Phase 1", status: "completed")**

---

## Phase 2: Parallel Review

**TaskUpdate(task: "Phase 2", status: "in_progress")**

### Get Diff

```bash
git diff "$BASE_BRANCH"...HEAD
```

### Diff Size Check

```bash
git diff "$BASE_BRANCH"...HEAD --stat | tail -1
```

**If diff is very large (>2000 lines):** Ask user with `AskUserQuestion`:

```
question: "Large diff detected ({X} files, {Y} lines). How to proceed?"
header: "Scope"
options:
  - label: "Full review (Recommended)"
    description: "Review everything — may take longer"
  - label: "Key files only"
    description: "Review only the most critical files — suggest list"
  - label: "By directory"
    description: "Split into focused reviews per directory"
```

### Gather Project Context

Read project config files and `AGENTS.md` to build context for reviewers. Extract: framework, key dependencies, test framework, patterns used, language settings, architecture overview.

### Spawn All 4 Reviewers Simultaneously

**CRITICAL: All 4 agents run IN PARALLEL using a single message with 4 Task calls.**

Build each reviewer's prompt from **`references/reviewer-prompt-template.md`**, filling the placeholders from that dimension's row in **`references/review-dimensions.md`** (security, performance, architecture, correctness). Substitute `{DIFF}` (the Phase-2 diff), `{ARTIFACTS_DIR}`, and `{ROUND}` (`1` here) into each.

- Each agent writes **JSON** to `$ARTIFACTS_DIR/round-1-{role}.json` (`round-1-security.json`, …) — machine-read by the Phase-3 consensus script, so the schema in the template is load-bearing.
- Include a dimension's `SKILL_HINT` line only if Phase-1 skill routing found a relevant skill.
- Competitive framing, the finding format, and limits (top 7, skip Low, <600 words) are baked into the template — don't restate them.

**Wait for all 4 reviewers to complete.**

**TaskUpdate(task: "Phase 2", status: "completed")**

---

## Phase 3: Synthesize

**TaskUpdate(task: "Phase 3", status: "in_progress")**

**THIS IS YOUR CORE WORK. Do not delegate synthesis.**

### Run Deterministic Consensus

The mechanical synthesis — dedup, same-round + cross-round consensus, the severity/consensus
auto-apply cascade, and partial-failure detection — runs in **code**, not prose, so consensus
can't be hallucinated over markdown. It implements `_shared/review-consensus.md`:

```bash
CONSENSUS="$(git rev-parse --show-toplevel)/.claude/skills/ac-review/scripts/consensus.py"
python3 "$CONSENSUS" --artifacts-dir "$ARTIFACTS_DIR" --round 1   # --round 2 for a Phase-5.5 round
```

It reads the `round-1-{role}.json` reviewer files, writes `consensus-round-1.json` + updates
`consensus-registry.json` (the cross-round memory — no manual table-keeping), and prints a
summary. Harness-agnostic: plain `python3`, stdlib only.

**Read the result (`consensus-round-1.json`) and act on each field:**

- **`reviewers_missing` non-empty → partial failure.** A missing dimension is the silent-PASS
  trap — never auto-fix-and-approve around it. **Retry once:** re-spawn the missing reviewer(s)
  (Phase 2, same `{ROUND}`) and re-run consensus. **If still missing:**
  - *Autonomous (`ac-loop`) run:* this is a **blocker** — `br create -t bug --labels qa-blocker`
    for the un-reviewed dimension, and emit **`VERDICT: NEEDS_DECISION`** (never `APPROVED`).
    The loop must not merge a wave a review dimension never saw.
  - *Interactive run:* surface the gap and let the user decide whether to proceed.

  A reviewer that emits malformed JSON degrades to this same path (the script's per-file
  parse-guard counts it as missing) — so ignoring the schema can never silently pass.
- **`auto_fix`** — the cascade is already applied (severity Critical/High, same-round consensus,
  or cross-round consensus). These go to Phase 4 as-is — with ONE conductor check:
  a **performance** finding rated Critical/High whose evidence carries no quantified
  impact estimate (N × unit cost weighed against the operation's real budget) is
  DOWNGRADED to Medium and re-routed through the deferred/design-decision gate, with
  the downgrade noted in the report. Perf severities are the least grounded — reviewers
  pattern-match allocation/loop shapes without estimating magnitude (observed
  2026-07-04: "Critical" on a ~sub-millisecond map copy whose own cited numbers
  contradicted the rating, riding the cascade unchallenged). Correctness/security
  severities are not subject to this check.
- **`deferred`** — single-reviewer Medium/Low, no consensus; the script has already carried them
  into `consensus-registry.json` for cross-round matching. **Apply the design-decision gate
  yourself** — the one judgment the script can't make: a choice with no objectively superior
  answer → pick the better option and move it into the change list; defer as `DESIGN_DECISION`
  (→ user in Phase 7) only if it **noticeably affects end-user experience** or **profoundly
  changes the development approach**. Minor choices (spacing, naming, style) → just pick the better one.

### Produce Numbered Change List

From the script's `auto_fix` plus any `deferred` items you resolved: target file, what to
change, severity, which reviewers flagged it (`reviewers`), auto-fixable or not. This is Phase 4's input.

Append to `$ARTIFACTS_DIR/progress.md`:

```markdown
### Phase 3: Synthesis

- **Total findings:** {count} ({Critical} Critical, {High} High, {Medium} Medium)
- **After dedup:** {count}
- **AUTO_FIX:** {count} (severity-based: {N}, consensus-based: {M})
- **NEEDS_DECISION:** {count}
- **Consensus areas:** {where reviewers agreed}
```

**TaskUpdate(task: "Phase 3", status: "completed")**

---

## Phase 4: Auto-Fix

**TaskUpdate(task: "Phase 4", status: "in_progress")**

### If No AUTO_FIX Items

Skip to Phase 5.

### If AUTO_FIX Items Exist

Spawn engineer with the AUTO_FIX list, using the prompt in **`references/engineer-fix-prompt.md`** with the Phase-4 `INTENT` ("Apply these fixes exactly as specified. Do NOT modify NEEDS_DECISION items.") and the `## Output` block kept (the result file is read back below).

### Verify Fixes

Read the engineer's result file. Confirm:
1. All AUTO_FIX items applied (or documented why not)
2. Project checks pass
3. No unintended side effects (review diff)

**If checks fail:** Revert the breaking fix and move that item to NEEDS_DECISION.

**TaskUpdate(task: "Phase 4", status: "completed")**

---

## Phase 5: Validation Gate

**TaskUpdate(task: "Phase 5", status: "in_progress")**

Run the cheap checks always; scale the **expensive** ones (full test, build) to the diff's
risk using the shared classifier in `_shared/verification-gate.md` (Step 1). ac-review is a
branch review, **not** the green-main boundary — the exhaustive run is the loop-close CI full
`test:all` (parallel-execution doctrine §5) — so running a full FORMAT+LINT+TYPECHECK+TEST+BUILD
battery on every wave (including docs-only ones) violates *proportional effort: incremental in
the loop, exhaustive at the boundary*.

```bash
{CMD_FORMAT}    # always (cheap)
{CMD_LINT}      # always (cheap)
{CMD_TYPECHECK} # always (cheap)
```

Then, by diff class (from the classifier):
- **`CLASS_RUNTIME` unset** (docs / tests / CI only) → skip `{CMD_TEST}` and `{CMD_BUILD}`; cheap checks suffice.
- **Runtime code, normal risk** → `{CMD_TEST}` (affected/standard); skip `{CMD_BUILD}` unless the wave touches build config or `CLASS_WEBUI`.
- **High-risk** (migration/`.sql`, auth, payments, release/version — the gate's high-risk row) → `{CMD_TEST}` scoped to the risk surface (never the full suite — that's the loop-close CI run) + `{CMD_BUILD}`.

**If all selected checks pass:** Continue to Phase 6.

**If any fail:**
- Fix the issue (small fixes directly, larger ones via engineer sub-agent)
- Re-run the failing command
- Only proceed after all pass OR user explicitly says "skip validation"

**TaskUpdate(task: "Phase 5", status: "completed")**

---

## Phase 5.5: Optional Convergence Round

**Only offer this if auto-fixes touched Critical or High issues.** Fixes are unverified until fresh reviewers confirm no new issues emerged.

```
AskUserQuestion(
  questions: [{
    question: "Auto-fixes touched {N} Critical/High issues. Run a verification round?",
    header: "Convergence",
    multiSelect: false,
    options: [
      { label: "Run verification round (Recommended)", description: "Spawn reviewers again to confirm fixes didn't introduce new issues" },
      { label: "Skip — trust the fixes", description: "Proceed to commit without re-review" }
    ]
  }]
)
```

**If verification round:** Re-run Phase 2-5 with the updated diff, spawning reviewers with `{ROUND}` = `2` so they write `round-2-{role}.json`. Include in reviewer prompts: "Previous round found and fixed: {list}. Check if fixes are correct and look for NEW issues only." Max 2 total rounds. In Phase 3, run `consensus.py --round 2` — it reads `consensus-registry.json` and auto-applies any finding that matches a prior-round deferred entry (cross-round consensus), with no manual registry-checking.

---

## Phase 6: Commit Report & Fixes

**TaskUpdate(task: "Phase 6", status: "in_progress")**

### Generate Review Report

Create `.claude/reviews/YYYY-MM-DD-HHMM-[feature].md` using the template in **`references/report-template.md`** (summary table by category + auto-fixed + needs-decision + all findings).

### Safety Check

```bash
git status --short
```

**If ANY deletions (D):** STOP and ask "About to delete {N} files. Is this intentional?" Wait for confirmation.

### Commit

```bash
git add .claude/reviews/YYYY-MM-DD-HHMM-[feature].md
git add <files modified by auto-fixes>
git commit -m "$(cat <<'EOF'
review: [feature] - {N} issues fixed, {M} need decision

Auto-fixed: {count} ({Critical} Critical, {High} High, {consensus} consensus)
Needs decision: {count}

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
git push
```

**TaskUpdate(task: "Phase 6", status: "completed")**

---

## Phase 7: Present Decisions

**TaskUpdate(task: "Phase 7", status: "in_progress")**

### Collect All Remaining Items

Combine two categories:

1. **NEEDS_DECISION items:** Non-auto-fixable findings that need judgment
2. **No-consensus findings:** Read the consensus registry — single-reviewer findings that never achieved cross-round consensus

### If Nothing Remains

Report auto-fix results and skip to Phase 8.

### Conductor Final Review (Triage)

**You (the conductor) now review each remaining item and classify it:**

| Category | Criteria | Action |
|---|---|---|
| `AUTO_IMPLEMENT` | There is a clearly superior technical answer — better correctness, robustness, performance, or maintainability. The improvement is unambiguous. | Implement it now. |
| `DESIGN_DECISION` | No objectively superior answer AND the choice would **noticeably affect the end-user experience** or **profoundly change the development approach**. Minor design choices (spacing, naming, style) — just pick the better option and classify as `AUTO_IMPLEMENT`. | Defer to user. |
| `SCOPE_ESCALATION` | A technically superior option exists but requires profound structural change (new abstractions, large refactors, architectural pivots) that constitutes a strategic commitment. | Defer to user with scope context. |

**Default bias: `AUTO_IMPLEMENT`.** Most findings have a correct answer — pick it. Only classify as `DESIGN_DECISION` when you genuinely cannot determine a superior option on engineering merit AND the impact is user-visible or development-transformative. Only classify as `SCOPE_ESCALATION` when the blast radius is transformative, not merely "more work."

### Apply AUTO_IMPLEMENT Items

Spawn engineer for all `AUTO_IMPLEMENT` items using **`references/engineer-fix-prompt.md`** with the AUTO_IMPLEMENT `INTENT` ("each has been validated by the conductor as a clear technical improvement"). The `## Output` block is optional here — the conductor commits directly below.

Log each with rationale: why this is a clear technical improvement, not a design choice.

### Present Decisions to User (if any)

**If no DESIGN_DECISION or SCOPE_ESCALATION items remain:** Skip to commit.

**Exhaust rule (see `skills/_shared/bead-conventions.md`):** nothing actionable
leaves this phase as prose. Before (or instead of) asking:

- Confirmed defect, out of this wave's scope → `br create -t bug --labels review-finding`
- Plausible-but-unverified concern an agent could chase → `br create -t investigation --labels review-finding`
- Genuine taste/product/risk fork AND the user is not interactively present
  (autonomous run) → `br create -t decision --labels human-gate` with a
  pre-staged memo (context, options + trade-offs, recommendation), block any
  dependent beads on it, and continue. AskUserQuestion is only for
  synchronous forks with the user present.

Apply the anti-inflation rules: dedupe via `br search` first; nits stay in
the report.

**Default (including all autonomous/headless runs): apply the Exhaust Rule.** Create a `decision` bead for each remaining item — do NOT ask:

```bash
br create -t decision --labels "human-gate,review-finding" \
  -t "DESIGN_DECISION: <title>" \
  --description "Context: <finding>\nOptions: <A vs B>\nRecommendation: <agent pick>"
# Block any downstream wave beads on it:
br dep add <downstream-bead-id> <decision-bead-id>
```

Then continue to Phase 8 — the loop runs on, the decision bead surfaces via `ac-human-session` when Craig reviews the docket.

**Only use AskUserQuestion when explicitly in an interactive session** (human is present at the terminal, NOT a scheduled or headless run):

```
AskUserQuestion(
  questions: [{
    question: "Auto-applied {N} fixes (severity + consensus + technical triage). {M} items need your decision:",
    header: "Decisions",
    multiSelect: true,
    options: [
      { label: "Fix A: <title>", description: "DESIGN_DECISION — {severity} — {reviewer}: {file}: {one-line summary}" },
      { label: "Fix B: <title>", description: "SCOPE_ESCALATION — {severity} — {reviewer}: {file}: {one-line summary}. Scope: {what the change entails}" }
    ]
  }]
)
```

**If more than 4 items:** Split across multiple `AskUserQuestion` calls (interactive only).

### Apply User-Approved Fixes

Spawn engineer for approved items using **`references/engineer-fix-prompt.md`** with the user-approved `INTENT` ("Apply these changes based on user decisions").

### Commit All Fixes

```bash
git add <specific files>
git commit -m "$(cat <<'EOF'
review: implement fixes + decisions for [feature]

Auto-implemented (conductor triage): {count}
User decisions applied: {count}

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
git push
```

**TaskUpdate(task: "Phase 7", status: "completed")**

---

## Phase 8: Final Report + Hand-Off

**TaskUpdate(task: "Phase 8", status: "in_progress")**

> **VERDICT gate.** Emit `VERDICT: APPROVED` only if **every** holds: the last consensus run had
> `reviewers_missing` empty (all four dimensions reviewed, after at most one retry), all `auto_fix`
> items were applied and the validation gate passed, and no open `qa-blocker`/blocking decision
> bead remains. Otherwise emit `VERDICT: NEEDS_DECISION` — `ac-loop` stops instead of merging.

### Summary

```markdown
## Review Complete: [Feature]

**VERDICT:** APPROVED
**Status:** APPROVED
**Report:** `.claude/reviews/YYYY-MM-DD-HHMM-[feature].md`
**Rounds:** {count}

### Convergence

Round  Security  Performance  Architecture  Correctness  Total  Applied  Deferred
  1      {n}       {n}          {n}           {n}         {n}     {n}       {n}
  2      {n}       {n}          {n}           {n}         {n}     {n}       {n}

R1  {▓▓░░░████}  {total}
R2  {░████}      {total}  {-N%}

▓ Critical  ░ High  █ Medium

### Resolution

Found: {total} across {count} rounds
  ├─ Auto-applied (severity):      {n}  {bars}
  ├─ Auto-applied (same-round):    {n}  {bars}
  ├─ Auto-applied (cross-round):   {n}  {bars}
  ├─ Auto-implemented (conductor):  {n}  {bars}
  ├─ User-approved:                {n}  {bars}
  └─ Discarded (no consensus):     {n}  {bars}

### Changes Made

- {list key auto-fixes}

### Decisions Made

- {list decisions and outcomes, or "none needed"}

**All project checks passing.**
```

### Next Step

**If called from `ac-loop` (autonomous run):** Skip — exit after the summary. The loop reads `VERDICT:` from the output and chains to `ac-merge` (APPROVED) or stops (NEEDS_DECISION with open blockers).

**If called interactively (human present):**

```
AskUserQuestion(
  questions: [{
    question: "Review complete ({N} fixed, {M} decisions resolved). What's next?",
    header: "Next step",
    multiSelect: false,
    options: [
      { label: "Merge (Recommended)", description: "Run /ac-merge — create PR, triage CI/agent feedback, ship to main" },
      { label: "Another review pass", description: "Run /ac-review again — fresh eyes on the updated code" },
      { label: "Manual review", description: "Done with automated review — you'll review manually" },
      { label: "Done for now", description: "Review saved — pick up later" }
    ]
  }]
)
```

### Cleanup

```bash
rm -rf "$ARTIFACTS_DIR"
```

**TaskUpdate(task: "Phase 8", status: "completed")**

---

## Flexibility & Overrides

**"Quick review"**
-> Spawn single comprehensive reviewer (Opus) instead of 4 specialized ones

**"Just report, don't fix"**
-> Skip Phase 4 (auto-fix), present all findings as report only

**"Review these files only: [list]"**
-> Scope diff to specified files instead of full branch diff

**"Skip validation"**
-> Bypass Phase 5 validation gate

**"Skip convergence"**
-> Never offer Phase 5.5 verification round

---

## When to Use This vs /ac-hygiene

|            | `/ac-review`                            | `/ac-hygiene`                             |
| ---------- | ----------------------------------------- | -------------------------------------- |
| **Scope**  | Feature branch diff                       | Whole codebase                         |
| **When**   | After `/ac-implement` or manual coding              | Between sessions, daily maintenance    |
| **Agents** | 4 specialized Sonnet reviewers, 1-2 rounds | 3 Opus explorers, multi-round          |
| **Fixes**  | Engineer sub-agent                        | Conductor applies directly             |
| **Focus**  | Security, perf, arch, correctness         | Bugs, dead code, drift, health         |

Use both: `ac-review` for pre-merge validation, `hygiene` for general health.

---

## Remember

- **YOU synthesize, engineers fix** — reviewers analyze, you decide what's real, engineer applies
- **Auto-apply Critical/High + same-round consensus + cross-round consensus** — defer the rest to registry
- **Cross-round consensus:** single-reviewer findings that recur in verification rounds are high-signal — auto-apply on match
- **One human touchpoint:** remaining no-consensus + NEEDS_DECISION items presented once in Phase 7, not per-round
- **Findings files + consensus registry survive compaction** — always read from `$ARTIFACTS_DIR`, not memory
- **Progress file is compaction recovery** — parse it on restart for phase state
- **Project commands come from AGENTS.md** — detect from config files only as fallback
- **Skill routing is dynamic** — check AGENTS.md > Available Skills, don't hardcode paths
- **Conductor triage before user** — remaining items get a final review: auto-implement clear technical improvements, only defer genuine design decisions and profound scope changes to the user
- **Convergence is optional** — only offer verification round for Critical/High auto-fixes

---

_Work review: parallel reviewers, severity-based auto-fix, user-gated decisions. For codebase health: `/ac-hygiene`. For implementation: `/ac-implement`._
