---
name: ac-hygiene
disable-model-invocation: true
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
MIN_ROUNDS=3          # ABSOLUTE floor — cross-round consensus needs recurrence opportunities; never finalize before this, even on consecutive zero-finding rounds
MAX_ROUNDS=5
ARTIFACTS_DIR=/tmp/hygiene-$(date +%Y%m%d-%H%M%S)
```

```bash
mkdir -p "$ARTIFACTS_DIR"
```

### Isolate in a Worktree, then Create the Hygiene Branch

**Run in a git worktree.** A full run holds HEAD on its branch for *hours*; in a shared repo a
human or a scheduled agent (triage/loop) will commit to the same checkout and their commits
land on the hygiene branch, entangling the PR. A worktree gives the run its own checkout so
that can't happen. (Learned the hard way 2026-07-06: a run's branch absorbed 4 concurrent
human commits.)

```bash
# Scoped dirty-tree check — only SOURCE paths block; harness/memory/state files are always dirty
git status --porcelain -- '*.ts' '*.tsx' '*.js' '*.sql' '*.css' package.json   # must be clean, else STOP (blocking)
```

All auto-applied fixes ride a run branch, never main directly (branch policy:
`ac-pipeline-builder` § Branch policy). Create it in an isolated worktree:

```bash
git worktree add -b hygiene/$(date +%Y%m%d) ../hygiene-run origin/main   # isolated checkout off fresh main
cd ../hygiene-run
```

If the harness supplies worktree isolation directly, use that instead. If the branch already
exists (re-run same day): append `-2`, `-3`, ….

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

### Coverage Audit (standing doctrine — projects with `CORE/journeys/`)

Mechanical, conductor-run, once per hygiene run (not per round, not an agent
lens) — the enumeration hole is that an untagged surface is silently
unprotected, which is the original failure one level up, so this can't be a
sampled hunt:

1. **RE-DERIVE the app's surface inventory from ground truth** — grep the live
   tree for routes (`app/**/page.tsx` or platform equivalent), nav entries,
   FABs, deep-link handlers, push-notification entry points. Never recall this
   from memory or a prior run's notes — derive it fresh from the current tree
   every time.
2. **Diff against the journey registry** — parse `CORE/journeys/*.md`
   frontmatter (`criticality`, `surfaces`; schema: `_shared/verification-gate.md`
   §Journey registry). A doc with no frontmatter defaults to `peripheral`.
3. **Untagged critical-looking surfaces become findings** — a derived surface
   with no matching journey doc, or one whose match reads `peripheral`/untagged
   while the surface name matches payment/auth/purchase/onboarding, files
   directly (skip the round/consensus machinery — this check is deterministic,
   not a judgment call): `br create -t bug --labels hygiene-finding,journey-gap,unrefined
   -d "Coverage audit: <surface> has no journey-registry entry (or is
   under-tagged) — untagged critical surfaces are unprotected by the
   runtime-proof gates."`

If `CORE/journeys/` doesn't exist for this app, skip — nothing to audit. This
same derivation is the starting point for the initial all-apps journey-tagging
sweep; the audit and the sweep share one inventory method so tags come from
ground truth, never memory.

### Create Workflow Tasks (run ledger)

**One task per major section — the ledger exists for CLARITY + ACCOUNTABILITY**, so every
section you'd report on gets its own line (not a 3-phase skeleton). Create the fixed tasks
below at Phase 0; **ADD a "Round N" task at the start of each review round** (rounds are
dynamic — 3 floor, up to 5 — so the ledger grows to the real shape instead of pre-committing
to a round count or showing phantom rounds). `TaskUpdate` each to `in_progress` when you start
it and `completed` when done; put live detail in the description (per round: finding counts +
commit SHA), so a glance at the ledger shows exactly where the run is.

```
# Fixed tasks — create upfront at Phase 0:
TaskCreate("Initialize — scope, worktree + hygiene branch, consensus registry, baseline gate")
TaskCreate("Coverage audit — surface inventory vs journey registry; file journey-gap beads")
TaskCreate("Triage deferred findings + file bead epic (Exhaust Rule)")
TaskCreate("Exhaustive quality gate — format → type-check → lint → full suite")
TaskCreate("Ship the branch — delegate to ac-merge")
TaskCreate("Refine the epic's beads in-session — ac-bead-refine")
TaskCreate("Report — hygiene summary + Slack (headless)")
TaskCreate("Cleanup / teardown — artifacts + worktree")

# Per-round task — create ONE as each round begins (not upfront):
TaskCreate("Round {N} — 6-lens panel → synthesize → auto-apply → gate → commit")
# On completion, TaskUpdate its description: "{C}/{H}/{M} findings, {n} auto-fixed, commit {sha}"
```

With a 3-round run that's 11 tasks; a 5-round run, 13. **TaskUpdate("Initialize", in_progress)**
now, and mark it `completed` at the end of Phase 0. Sub-skills invoked by the Ship and Refine
tasks (`ac-merge`, `ac-bead-refine`) run their OWN ledgers — do not duplicate their steps here;
this ledger tracks the hygiene run's top-level sections only.

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
format (auto-fix, e.g. `pnpm format`) + type-check + lint + AFFECTED tests only   # BLOCKING
# Never run the full suite per round — it runs exactly once, at Phase 5, pre-merge.
```

Run **format FIRST and as an auto-fix** (`pnpm format` = `prettier --write .`, not
`format:check`). CI's Quality Gate runs `prettier --check .` as its *first* step over the
*whole repo*, so a single unformatted file — including one you didn't touch that was already
rotting on `main` — fails the entire gate ~10 min into CI. Auto-fixing locally makes that
impossible. Sub-second cost; never let CI be the thing that catches formatting.

If checks fail, revert the breaking fix and note it as non-auto-fixable.

Then commit the round's fixes on the hygiene branch (small, revert-friendly commits):

```bash
git add <specific files>   # NEVER `git add -A` / `git add .` — it sweeps untracked orphans
git commit -m "chore(hygiene): round {CURRENT_ROUND} — {short summary}"
```

> **Commit WITHOUT `--no-verify`.** The pre-commit hook runs `lint-staged` (prettier `--write`
> + eslint `--fix`) on your staged files and re-stages them — it is the cheap auto-format
> safety net, exactly the check that stops formatting-class CI failures. `--no-verify` is for
> the **push** only (it skips the heavy pre-push `pnpm build` that swallows backgrounded
> pushes), NEVER for a commit. Bypassing the commit hook is how an unformatted file reaches CI.

> **Stage the exact files you changed — never `git add -A`.** A run may sit next to untracked
> orphans (a stale `.next.stale-*` build dir, scratch output); `git add -A` commits them. On
> 2026-07-06 that swept a 2.4 GB build dir into a commit and broke the Turbopack build. Track
> your changed paths (from the implementer reports) and stage those explicitly.

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

**Rule 2 (the round floor): the `MIN_ROUNDS=3` floor is ABSOLUTE.** Cross-round consensus —
the rule that promotes recurring single-agent findings — needs at least two later rounds in
which a deferral can recur. A clean round 1 is not evidence the codebase is clean; it is
evidence one round isn't enough. **Two rounds is not sufficient** — even two consecutive
zero-finding rounds do NOT finalize before round 3; the dry-panel early exit is only reachable
once `CURRENT_ROUND >= MIN_ROUNDS`. Ceiling is `MAX_ROUNDS=5`.

```
# The floor is checked FIRST and is absolute — nothing exits before round 3.
IF CURRENT_ROUND < MIN_ROUNDS -> apply fixes, continue (increment CURRENT_ROUND)   # even on back-to-back zero-finding rounds
IF two consecutive rounds found ZERO findings (only reachable at CURRENT_ROUND >= MIN_ROUNDS) -> finalize early (panel is dry — stop burning agents)
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

**Bead bodies follow the template at creation** (bead-conventions § Body
template): typed headers (`## Steps to Reproduce` for bugs, `## Acceptance
Criteria`, `## Test Scope` with grep-verified anchors, `## Success Criteria` on
the epic) plus a durable evidence pointer (the run's PR, not `$ARTIFACTS_DIR`
paths — those are deleted at Cleanup). You hold the finding's evidence RIGHT NOW;
writing the full body costs a minute here and a full refine round later. The
in-session refine step then verifies instead of authoring.

**Per-run epic:** if this run created 2+ beads, group them under one epic
(`br create -t epic "Hygiene <date> — deferred findings"`, children linked) so the
batch is refined together in-session (see "Refine the Run's Beads" below) and
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

### Quality Gate (exhaustive — pre-handoff sanity check)

```bash
# Order MIRRORS CI's Quality Gate exactly — format is the FIRST thing CI checks.
format (auto-fix, e.g. `pnpm format`) + type-check + lint + full test suite   # BLOCKING
```

This is the single exhaustive run of the workflow (rounds ran affected-only). Run
`pnpm format` (`prettier --write .`) FIRST — it mirrors and pre-empts CI's `prettier --check .`
first step (whole-repo). If it rewrites files you did NOT author (pre-existing rot already red
on `main`), that is expected: commit the formatting as part of this run's ship — you are
repairing a gate CI was already failing, not sweeping unrelated changes. If any check fails,
fix before proceeding. Commit any Phase-5 fixes (user-approved + AUTO_IMPLEMENT triage items)
on the hygiene branch (again, **no `--no-verify` on the commit**).

**Note:** `ac-merge`'s own post-rebase Quality Gate runs this same full gate again at merge
time (on the rebased state that actually merges) — so this Phase-5 run is now a pre-handoff
sanity check, not the last word. Keep it: catching a red gate here, before handing off, is
cheaper than catching it inside `ac-merge`'s PR flow.

### Ship the Branch (delegate to ac-merge)

No commits landed (findings only)? Delete the branch, return to main, skip to Report.
Otherwise: **invoke `ac-merge` on the current hygiene branch.** ac-merge is now the single
merge-to-main path for any branch — wave or chore/hygiene — and handles push → PR → CI poll
+ feedback triage → merge → patch version bump → tag → verify → land, all in one skill.
Delegation prompt:

> "Run ac-merge on the current hygiene branch. This is a chore/hygiene merge: version bump =
> patch (default), accept without asking; uncertain PR feedback → decision beads (Exhaust
> Rule); no 'what's next?' after merge."

**Hand ac-merge what it needs to build the PR body:** this run's fix list (round table +
per-round summary + deferred count) and the **"Also carried (not hygiene fixes)"** line —
a concurrent session or scheduled job may have committed onto this hygiene branch (it was
the checked-out branch), and the branch is the merge unit (pipeline-builder Invariant 8): those
foreign commits ship too, by design, but must be named, not silently dropped. Diff the full
branch against main (`git diff --stat main...HEAD` and `git log --oneline main..HEAD`) and
pass any non-hygiene commit/change (an `.env`/secret edit, a migration, another session's fix)
to ac-merge as the Also-carried content — do not exclude it just because this run didn't
author it. ac-merge builds the actual PR body; this run supplies the hygiene-specific content.

- **Hygiene merges bump `patch` via `ac-merge`** (changed 2026-07-07 — previously hygiene
  merges took no version bump; ac-merge is now the single bump owner for every branch kind,
  and the default for every merge, feature or chore, is patch unless explicitly frozen/skipped).
- **No remote / no CI on this repo:** this is ac-merge's concern now — it falls back to a
  local quality-gate-then-merge path when there's no PR flow to run.
- CI fails → ac-merge fixes on the branch and re-pushes as part of its own triage loop; if
  unfixable this session, it leaves the PR open, files a `qa-blocker`-style bead, and reports
  it — never merge red, never delete unmerged work.

### Refine the Run's Beads (in-session, after the merge)

If this run created **≥1 bead**, run **`ac-bead-refine`** NOW — scoped to the epic if one
exists (2+ beads), to the single bead otherwise — before the report, not "later." The
conductor still holds every finding, verdict, and triage rationale in context; that is
exactly what refinement needs, and a deferred refine session re-derives it from cold (or
worse, can't). Two run-specific notes for the reviewer prompts:

- Bead descriptions were written mid-run — file/line references predate the merged fixes.
  Reviewers must re-verify every reference against merged `main` and correct drift.
- The refine reviewers work in the MAIN checkout (post-merge), not the hygiene worktree
  (already removed by now).
- Give reviewers the evidence, not just the beads: `$ARTIFACTS_DIR` still exists (Cleanup
  runs later) — point the refine reviewers at the round findings files and consensus
  registry so they verify beads against the ORIGINAL evidence and severity rationale,
  not only against code.

Headless runs included — refinement is agent-satisfiable (genuine design forks already went
through this run's decision gates or carry `human-gate`). 0 beads → skip (nothing to
converge). Hygiene never stamps `refined` itself — that label comes from **this
`ac-bead-refine` invocation**, on its own convergence, exactly like any other bead; hygiene's
role is to run it in-session while context is hot, not to earn the stamp on its behalf. On
convergence the `unrefined` labels come off and `refined` goes on, leaving the epic
implement-ready for the loop.

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
- **Honor the round floor — it is ABSOLUTE** — never finalize before MIN_ROUNDS=3, not even on two consecutive zero-finding rounds (the dry-panel exit is only reachable at round ≥3); ceiling MAX_ROUNDS=5. Cross-round consensus needs the later rounds to exist
- **Lens-diverse consensus is rarer and stronger** — don't lower the bar because six lenses overlap less than three same-lens hunters; the registry + Phase 5 triage absorb the singles
- **Fixes ride the hygiene branch** — per-round commits; PR creation, CI/feedback triage, and the actual merge are delegated to `ac-merge` at the end; never straight to main, never merge red
- **Conductor triage before user** — remaining items get a final review: auto-implement clear technical improvements, only defer genuine design decisions (user-visible or development-transformative) and scope escalations to the user
- **Design decision gate every round** — choices that noticeably affect user experience or profoundly change development are deferred regardless of severity or consensus
- **Incremental in the loop, exhaustive at the boundary** — rounds gate on format(auto-fix) + type-check + lint + affected tests; the FULL suite runs exactly once, at Phase 5 pre-merge (BLOCKING). Format is FIRST + auto-fix in both gates (mirrors CI's `prettier --check .` first step); commit WITHOUT `--no-verify` so the pre-commit lint-staged hook auto-formats — never let CI catch a formatting miss.
- **Deferred beads get an epic per run** (2+ beads); refined in-session post-merge whenever **≥1 bead** was created (epic-scoped or single-bead-scoped) — `ac-bead-refine` while the findings are still in context, shipped as orphans by the loop
- **Findings files + consensus registry survive compaction** — always read from `$ARTIFACTS_DIR`, not memory
- **Don't invent issues** — if the codebase is clean, say so and finish early

---

_Hygiene: the recurring codebase quality pass. For session closure: `/ac-land`._
