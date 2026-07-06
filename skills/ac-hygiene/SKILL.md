---
name: ac-hygiene
description: 'Iterative codebase review — a 6-lens Opus panel (bug hunter, explorer, structural, adversary, failure engineer, promise keeper), minimum 3 rounds for cross-round consensus — surfaces correctness/security/resilience/contract/reuse cleanups. Fixes ride a hygiene branch → PR; deferred findings become an epic of beads. Triggers: ''hygiene'', ''clean up the codebase'', ''iterative review'', ''tidy the code'', ''weekly hygiene run''.'
---


**You are the conductor.** A panel of reviewers hunts independently, each through a different
lens. You synthesize, fix, and iterate. Codebase-wide — not tied to any feature branch or diff.

The weekly quality pass for a repo (`PANEL=full`, 6 lenses), or a quick between-session
sweep (`PANEL=light`, 3 lenses). For feature-scoped review, use `/ac-review` instead.

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

**Interactive run** — ask user with `AskUserQuestion`:

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

**Headless run** (scheduled job, or user said "run unattended"): skip the question —
`SCOPE=Full codebase`, `PANEL=full`, and every later `AskUserQuestion` in this workflow is
skipped too (the Exhaust Rule routes what would have been asked into beads).

### Configuration

```
SCOPE=<user selection or Full codebase>
SCOPE_CONTEXT=<commit list or directory listing, if scoped>
PANEL=full            # full = 6 lenses (weekly run) | light = 3 (quick pass, user asked for "light")
CURRENT_ROUND=1
MIN_ROUNDS=3          # floor — cross-round consensus needs recurrence opportunities
MAX_ROUNDS=4
ARTIFACTS_DIR=/tmp/hygiene-$(date +%Y%m%d-%H%M%S)
```

```bash
mkdir -p "$ARTIFACTS_DIR"
```

### Create the Hygiene Branch

All auto-applied fixes ride a run branch, never main directly (branch policy:
`ac-pipeline-builder` § Branch policy):

```bash
git status --porcelain   # must be clean — if not, STOP and surface to user (blocking)
git switch -c hygiene/$(date +%Y%m%d)
```

If the branch already exists (re-run same day): append `-2`, `-3`, ….

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

### Create Workflow Tasks (run ledger)

```
TaskCreate(subject: "Phase 0: Initialize hygiene review", description: "Select scope, gather context, create branch + consensus registry", activeForm: "Initializing hygiene review...")
TaskCreate(subject: "Phases 1-4: Review loop", description: "Panel of Opus agents per round, synthesize, apply fixes, convergence check. MIN_ROUNDS floor, up to MAX_ROUNDS.", activeForm: "Running hygiene review...")
TaskCreate(subject: "Phase 5: Finalize", description: "Conductor triage, quality gate, PR + merge, deferred-findings epic, report", activeForm: "Finalizing hygiene review...")
```

**TaskUpdate(task: "Phase 0", status: "completed")**

---

## REVIEW LOOP: Phases 1-4

### Phase 1: Spawn the Panel (parallel)

**All panel agents in a single message for parallel execution.**

Spawn the panel per `PANEL` (full = Bug Hunter, Explorer, Structural, Adversary, Failure
Engineer, Promise Keeper; light = first three — all Opus) using the prompts in
**`references/reviewers.md`**, substituting `{SCOPE_CONTEXT}`, `{CURRENT_ROUND}`, and
`{ARTIFACTS_DIR}`. Each writes to `$ARTIFACTS_DIR/round-{CURRENT_ROUND}-{role}.md`.
**Between rounds**, add the "Files already reviewed: {list}. Look elsewhere." line to each
prompt (see Phase 4).

### Phase 2: Synthesize

**Read ALL findings files for the round.** This is your core job — do not delegate.

Synthesis principles:

- **Consensus is high-signal** — 2+ agents flagging the same area is almost certainly real.
  With lens-diverse agents, expect consensus to be *rarer and stronger*: two different
  disciplines converging on the same file is the best signal this workflow produces. More
  findings will be single-agent — that is what the consensus registry and Phase 5 triage
  are for; don't lower the bar to compensate.
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

After each batch of fixes — the **round gate** (incremental, per `ac-pipeline-builder`
Invariant 2: incremental in the loop, exhaustive once at the boundary):

```bash
type-check + lint + AFFECTED tests only (project affected runner, e.g. `pnpm test`)   # BLOCKING
# Never run the full suite per round — it runs exactly once, at Phase 5, pre-merge.
```

If checks fail, revert the breaking fix and note it as non-auto-fixable.

Then commit the round's fixes on the hygiene branch (small, revert-friendly commits):

```bash
git add <specific files>
git commit -m "chore(hygiene): round {CURRENT_ROUND} — {short summary}"
```

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

**Rule 1: if this round's agents found ANY Critical or High issues, you MUST run another round after applying fixes.** Fixes are unverified until the next round's agents confirm no new Critical/High issues emerge.

**Rule 2 (the round floor): never finalize before `MIN_ROUNDS`.** Cross-round consensus —
the rule that promotes recurring single-agent findings — needs at least two later rounds in
which a deferral can recur. A clean round 1 is not evidence the codebase is clean; it is
evidence one round isn't enough. The only early exit: **two consecutive rounds with zero
findings** (panel is dry — stop burning agents).

```
IF two consecutive rounds found ZERO findings -> finalize early (codebase clean)
IF CURRENT_ROUND < MIN_ROUNDS -> apply fixes, continue (increment CURRENT_ROUND)
IF agents found any Critical or High issues -> apply fixes, continue (increment CURRENT_ROUND)
IF only Medium or no new issues -> finalize (proceed to Phase 5)
IF CURRENT_ROUND >= MAX_ROUNDS -> force finalize (note unverified fixes)
IF this round found same issues as last round AND CURRENT_ROUND >= MIN_ROUNDS -> force finalize (agents are circling)
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
hygiene-finding,unrefined`. Worth-chasing uncertainties → `-t investigation`. Genuine
taste/product forks in an autonomous run (user not present) → `-t decision
--labels human-gate` with a pre-staged memo, then continue — never stall the
sweep on a question. Dedupe via `br search` first; nits stay in the report
(hygiene is the highest inflation risk — a bead is something you'd schedule).

**Per-run epic:** if this run created 2+ beads, group them under one epic
(`br create -t epic "Hygiene <date> — deferred findings"`, children linked) so the
batch is refined together later (`ac-bead-refine` drops the `unrefined` labels) and
shipped by the loop as orphan fixes. 0–1 beads → no epic (don't inflate).

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

### Quality Gate (exhaustive — the ONCE-per-run full gate)

```bash
Run the FULL project quality gate: type-check + lint + full test suite (see AGENTS.md > Project Commands)   # BLOCKING
```

This is the single exhaustive run of the workflow (rounds ran affected-only). If any
fail, fix before proceeding. Commit any Phase-5 fixes (user-approved + AUTO_IMPLEMENT
triage items) on the hygiene branch.

### Ship the Branch (PR → merge)

No commits landed (findings only)? Delete the branch, return to main, skip to Report.
Otherwise:

**The branch is the merge unit — include by default, surface the extras** (pipeline-builder
Invariant 8). A concurrent session or a scheduled job may have committed onto this hygiene branch
(it was the checked-out branch). The squash-merge carries those changes to main by design —
that's correct, **do not exclude a foreign commit just because this run didn't author it**. But
your PR body is built from the round table + fix list, which won't mention them, so they'd ship
*unsurfaced*. Before creating the PR, diff the full branch against main
(`git diff --stat main...HEAD` and `git log --oneline main..HEAD`) and add an **"Also carried
(not hygiene fixes)"** line to the body naming any non-hygiene commit/change (an `.env`/secret
edit, a migration, another session's fix). CI runs on the whole branch, so the full diff is
gated regardless of author. Exclude only on a real signal (`WIP`/`DO-NOT-MERGE`, CI failure,
gitleaks hit) — and note the exclusion in the body; never a silent drop.

```bash
git push -u origin hygiene/{date}
gh pr create --title "chore(hygiene): {N} fixes — {date}" --body "<round table + fix list + deferred count + Also-carried line>"
# Wait for CI with a HARD CAP (never unbounded): poll checks, e.g. for i in $(seq 1 20); do ... sleep 30; done
gh pr merge --squash --delete-branch
git switch main && git pull
```

- **No version bump** — bump ownership is `ac-merge`'s, for feature waves; hygiene merges are chores.
- **No remote / no CI on this repo:** run the full local quality gate (above), then merge
  locally (`git switch main && git merge --ff-only hygiene/{date}`) and delete the branch.
- CI fails → fix on the branch and re-push; if unfixable this session, leave the PR open,
  file a `qa-blocker`-style bead, and report it — never merge red, never delete unmerged work.

### Report

Produce the summary using the template in **`references/report-template.md`** (convergence table, resolution breakdown, areas reviewed, health assessment).

**Headless run:** post the summary via `slack-send` — this is a MANDATORY step, not optional
polish (confirm exit 0) — then skip the question below and proceed to Cleanup.

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

Use `/ac-hygiene` as the weekly quality pass per repo (`PANEL=full`) or a quick
between-session sweep (`PANEL=light`). For feature-specific review before merge, use
`/ac-review` on the feature branch diff.

---

## Flexibility / Overrides

- **"light"** in the prompt → 3-lens panel (Bug Hunter, Explorer, Structural), same rounds/rules
- **"headless" / scheduled** → no `AskUserQuestion` anywhere; full codebase, full panel; Exhaust Rule owns all decisions; Slack report mandatory
- **Scope override** — "hygiene on features/auth" → Specific-directory scope, no question asked
- **Round override** — "single round" / "quick pass" → MIN_ROUNDS=1 (accept: cross-round consensus disabled; deferred singles go straight to Phase 5 triage)

## Troubleshooting

- **Branch creation blocked** (git write perms) → surface to user; never fall back to committing on main
- **Dirty tree at Phase 0** → STOP (blocking); a hygiene run must start from a clean state it can safely revert within
- **Agent dies / returns nothing** → note the lens as absent for the round and continue with the rest of the panel; re-spawn once if 2+ die
- **Quality gate fails on a fix** → revert that fix, mark non-auto-fixable, add to registry; never ship a red gate
- **Compaction mid-run** → `$ARTIFACTS_DIR/progress.md` + consensus registry are the recovery state (see Phase 0); the hygiene branch holds all applied fixes

---

## Remember

- **Codebase-wide, not feature-scoped** — agents explore freely (unless user constrains)
- **Fresh eyes each round** — direct agents to unexplored files in subsequent rounds
- **Auto-apply Critical/High + same-round consensus + cross-round consensus — defer the rest**
- **Honor the round floor** — never finalize before MIN_ROUNDS (except two consecutive zero-finding rounds); cross-round consensus needs the later rounds to exist
- **Lens-diverse consensus is rarer and stronger** — don't lower the bar because six lenses overlap less than three same-lens hunters; the registry + Phase 5 triage absorb the singles
- **Fixes ride the hygiene branch** — per-round commits, PR + CI at the end; never straight to main, never merge red
- **Conductor triage before user** — remaining items get a final review: auto-implement clear technical improvements, only defer genuine design decisions (user-visible or development-transformative) and scope escalations to the user
- **Design decision gate every round** — choices that noticeably affect user experience or profoundly change development are deferred regardless of severity or consensus
- **Incremental in the loop, exhaustive at the boundary** — rounds gate on type-check + lint + affected tests; the FULL suite runs exactly once, at Phase 5 pre-merge (BLOCKING)
- **Deferred beads get an epic per run** (2+ beads) — batch-refined later, shipped as orphans by the loop
- **Findings files + consensus registry survive compaction** — always read from `$ARTIFACTS_DIR`, not memory
- **Don't invent issues** — if the codebase is clean, say so and finish early

---

_Hygiene: the recurring codebase quality pass. For session closure: `/ac-land`._
