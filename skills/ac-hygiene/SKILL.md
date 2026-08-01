---
name: ac-hygiene
description: 'Iterative codebase review — a 7-lens Opus panel (bug hunter, explorer, structural, adversary, failure engineer, promise keeper, test warden), minimum 3 rounds for cross-round consensus — surfaces correctness/security/resilience/contract/reuse cleanups. Fixes commit directly to `main` (trunk-direct); deferred findings become an epic of beads. Triggers: ''hygiene'', ''clean up the codebase'', ''iterative review'', ''tidy the code'', ''weekly hygiene run''.'
---


**You are the conductor.** A panel of reviewers hunts independently, each through a different
lens. You synthesize, fix, and iterate. Codebase-wide — not tied to any feature branch or diff.

Scaling tiers per `ac-pipeline/references/risk-classification.md`. <!-- net-growth-ok: ac-gcj.7 Pass C canon binding -->

Capability-starved runs: `ac-pipeline/references/degraded-mode.md`. <!-- net-growth-ok: ac-gcj.7 Pass C canon binding -->

The weekly quality pass for a repo (`PANEL=full`, 7 lenses), or a quick between-session
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
PANEL=full            # full = 7 lenses (weekly run) | light = 3 (quick pass, user asked for "light")
CURRENT_ROUND=1
MIN_ROUNDS=3          # ABSOLUTE floor — cross-round consensus needs recurrence opportunities; never finalize before this, even on consecutive zero-finding rounds
MAX_ROUNDS=5
# Mint RUN_ID if the orchestrator didn't hand one down (contract: ac-pipeline/references/run-id.md
# mint-if-absent rule) — keeps standalone and orchestrated runs on the same formula.
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"
ARTIFACTS_DIR=/tmp/hygiene-${RUN_ID}   # RUN_ID carries the PID → no same-second collision (ac-pipeline/references/run-id.md)
```

```bash
mkdir -p "$ARTIFACTS_DIR"
```

### Work Directly on Main (trunk-direct — no worktree, no hygiene branch)

Hygiene **conforms to trunk-direct**: there is no hygiene branch and no worktree. Auto-applied
fixes commit straight to `main` as pathspec commits under the **full H7 discipline** the
`ac-implement` Phase 0 spells out — the implementing-conductor concurrency rules apply to
hygiene whenever it is actively *fixing code* (hygiene is exempt from H7 **only** while purely
reading/filing beads, never while editing). The 7-lens panel below IS this run's pre-push
review — stronger than most batches get — so there is **no separate `ac-review` step** (branch
policy: `ac-pipeline` § Branch policy).

```bash
git checkout main 2>/dev/null || true
git pull --rebase
git branch --show-current   # confirm `main` before doing anything else
```

**Dirty-tree rule (trunk-direct — H7d):** a non-empty `git status --short` is EXPECTED and is
**NOT a blocker** — every session shares one checkout on `main`, so another session's in-flight,
not-yet-committed work may be sitting there. **Inventory it; do not touch it.** Only files YOU
changed enter YOUR commits (pathspec-mandatory, Phase 3): never `git add -A`, never
`git add .`, never `git commit -a`, and **never `git stash`** (a stray `stash pop` writes
conflict markers into unrelated files — H7d, `ac-pipeline/references/commit-discipline.md`). Use `git diff HEAD` if you
need to isolate uncommitted-vs-committed state. If the inventory shows a genuine red flag
(unexpected deletions, sensitive files, something orphaned rather than in-flight), surface it to
the user before proceeding — otherwise proceed past it.

### Initialize Consensus Registry <!-- if dcg rejects this write, do NOT bypass: the guard blocks a redirect whose target path is variable-built — sanctioned shapes (tee, the Write tool) in ac-pipeline/references/shell-guardrails.md -->

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
   frontmatter (`criticality`, `surfaces`; schema: `ac-pipeline/references/verification-gate.md`
   §Journey registry). A doc with no frontmatter defaults to `peripheral`.
3. **Untagged critical-looking surfaces become findings** — a derived surface
   with no matching journey doc, or one whose match reads `peripheral`/untagged
   while the surface name matches payment/auth/purchase/onboarding, files
   directly (skip the round/consensus machinery — this check is deterministic,
   not a judgment call): `br create -t task --labels hygiene-finding,journey-gap,unrefined
   -d "Coverage audit: <surface> has no journey-registry entry (or is
   under-tagged) — untagged critical surfaces are unprotected by the
   runtime-proof gates."`

If `CORE/journeys/` doesn't exist for this app, skip — nothing to audit. This
same derivation is the starting point for the initial all-apps journey-tagging
sweep; the audit and the sweep share one inventory method so tags come from
ground truth, never memory.

### Knip Dead-Code / Unused-Dep Lens (weekly cadence only — `PANEL=full`)

Mechanical, conductor-run, once per hygiene run (not per round, not an agent lens) — same
shape as the Coverage Audit above. This lens runs alongside, not instead of, the standing
`command` cron entry ("Code Hygiene - Weekly knip sweep", Sat 05:30, root
`infrastructure/jobs/weekly.json`: `cd neometa/software/body-compass-app && pnpm knip || true`)
— the cron job is a standalone tripwire; this lens is the conductor's own pass, wired into the
weekly panel run so findings feed the same triage/bead path as the other lenses.

1. **Run `pnpm knip`** from the app root. The committed `knip.json` (bd-pwt44.12) is this lens's
   provenance for what gets filtered — framework false-positives are excluded there; don't
   re-litigate its exclusions per run.
2. **Surface real findings** (dead exports, unused files, unused/unlisted deps) as hygiene
   findings — real dead code becomes cleanup findings/beads exactly like the other lenses'
   output: route through Phase 5 triage (`AUTO_IMPLEMENT` for unambiguous dead-code removal,
   `br create -t task --labels hygiene-finding,unrefined` for anything needing a human look —
   e.g. an export that *looks* dead but may be a public API surface).
3. **Weekly cadence only** — this lens runs on `PANEL=full`; skip it on `PANEL=light` (the
   quick between-session sweep).

If the app has no `knip.json` / no `knip` devDependency, skip — nothing to run.

### Stamp-Audit Lens (weekly cadence only — `PANEL=full`)

Mechanical, conductor-run, once per hygiene run (not per round, not an agent lens) — same
shape as the two lenses above. This is the integrity check on the proof gate itself
(`skill-builder/references/promotion-ladder.md` §The ladder — tier-1 promotion needs "N green
runs that EXERCISE it... / probe-verified fact / Craig sign-off"): a stamp is only as good as
the run history behind it, and nothing currently re-checks a stamp already resident in the tree
against reality.

1. **Grep every skill's SKILL.md/references for evidence stamps** — the
   `<!-- evidence: <N green runs | probe-fact | Craig sign-off> -->` form (`ac-review`'s
   doctrine-delta dimension checks this shape at diff-time; this lens re-audits stamps already
   landed, not just new ones).
2. **Spot-check each claim against actual run history** — CI run logs, `.claude/reviews/batch/`
   commits, or dream recurrence records that plausibly exercised the stamped mechanism. A stamp
   claiming a green-run count the record can't substantiate, or a probe-fact stamp whose probe
   script no longer exists, is a finding regardless of the stamp's age.
3. **File it same as any stale-content finding** — route via the Deletion Mandate (Phase 2): pull
   the false claim (demote/delete per promotion-ladder.md) or downgrade the content it guards back
   to `references/`/holding-pen if the proof no longer holds.
4. **Weekly cadence only** — this lens runs on `PANEL=full`; skip it on `PANEL=light`.

### Friction Cluster-Walk Lens (weekly cadence only — `PANEL=full`)

Mechanical, conductor-run, once per hygiene run (not per round, not an agent lens) — same
shape as the three lenses above. The organic-surfacing half of W4.6
(`skill-builder/references/friction-capture.md`): this repo's own weekly quality pass is a
second, hygiene-cadence backstop over the friction sensor logs, alongside — never instead
of — `dream` Phase 2's weekly weighting pass (`dream/SKILL.md` § Phase 2, W4.5).

1. **Walk the `related` graph across every `skills/*/FRICTIONS.md`** — the graph is a free
   byproduct of capture-time dedup judgment (`friction-capture.md` § Deduplication), not
   something this lens builds; it only reads it, grouping ids into clusters the same way
   W4.5 does.
2. **Reuse W4.5's weight/threshold verbatim — do not redefine them here:**
   `weight(id) = impact_num × frequency_num × recurrence`, threshold `weight >= 12`
   (`dream/SKILL.md` § Phase 2 is the single definition; cite it, don't fork it).
3. **An over-bar cluster files directly** as `br create -t task --labels
   hygiene-finding,skill-improvement,unrefined -d "Friction cluster-walk: <id(s)> —
   <cluster's proposed_fix(es)>. weight=<N>, skills=<list>."` — deduped via `br search`
   first, same as any other hygiene finding (Exhaust Rule). This is the direct,
   no-judge-round path; it does not replace dream's judged/gated proposal path, it
   catches the same signal on a different cadence so a cluster surfaces without anyone
   manually reading FRICTIONS.md.
4. **Weekly cadence only** — this lens runs on `PANEL=full`; skip it on `PANEL=light`.

If no skill in this repo has a `FRICTIONS.md` yet, skip — nothing to walk.

### Create Workflow Tasks (run ledger)

**One task per major section — the ledger exists for CLARITY + ACCOUNTABILITY**, so every
section you'd report on gets its own line (not a 3-phase skeleton). Create the fixed tasks
below at Phase 0; **ADD a "Round N" task at the start of each review round** (rounds are
dynamic — 3 floor, up to 5 — so the ledger grows to the real shape instead of pre-committing
to a round count or showing phantom rounds). `TaskUpdate` each to `in_progress` when you start
it and `completed` when done; put live detail in the description (per round: finding counts +
commit SHA), so a glance at the ledger shows exactly where the run is.

Ledger contract: `ac-pipeline/references/run-ledger.md` — one task per section, advance as you go; ledger = run position, never work items. <!-- net-growth-ok: ac-gcj.7 Pass C canon binding -->

```
# Fixed tasks — create upfront at Phase 0:
TaskCreate("Initialize — scope, confirm on main (trunk-direct), consensus registry, baseline gate")
TaskCreate("Coverage audit — surface inventory vs journey registry; file journey-gap beads")
TaskCreate("Triage deferred findings + file bead epic (Exhaust Rule)")
TaskCreate("Exhaustive quality gate — format → type-check → lint → full suite")
TaskCreate("Close ceremony — delegate to ac-batch-close")
TaskCreate("Refine the epic's beads in-session — ac-bead-refine")
TaskCreate("Report — hygiene summary + Slack (headless)")
TaskCreate("Cleanup / teardown — artifacts")

# Per-round task — create ONE as each round begins (not upfront):
TaskCreate("Round {N} — 7-lens panel → synthesize → auto-apply → gate → commit")
# On completion, TaskUpdate its description: "{C}/{H}/{M} findings, {n} auto-fixed, commit {sha}"
```

With a 3-round run that's 11 tasks; a 5-round run, 13. **TaskUpdate("Initialize", in_progress)**
now, and mark it `completed` at the end of Phase 0. Sub-skills invoked by the Ship and Refine
tasks (`ac-batch-close`, `ac-bead-refine`) run their OWN ledgers — do not duplicate their steps here;
this ledger tracks the hygiene run's top-level sections only.

---

## REVIEW LOOP: Phases 1-4

### Phase 1: Spawn the Panel (parallel)

**All panel agents in a single message for parallel execution.**

Spawn the panel per `PANEL` (full = Bug Hunter, Explorer, Structural, Adversary, Failure
Engineer, Promise Keeper, Test Warden; light = first three — all Opus) using the prompts in
**`references/reviewers.md`**, substituting `{SCOPE_CONTEXT}`, `{CURRENT_ROUND}`, and
`{ARTIFACTS_DIR}`. Each writes to `$ARTIFACTS_DIR/round-{CURRENT_ROUND}-{role}.md`.
**Between rounds**, add the "Files already reviewed: {list}. Look elsewhere." line to each
prompt (see Phase 4).

### Phase 2: Synthesize

**Read ALL findings files for the round.** This is your core job — do not delegate.

Synthesis principles:

- **Consensus is high-signal** — 2+ agents flagging the same area is almost certainly real.
  Lens-diverse consensus is *rarer and stronger* — don't lower the bar to compensate;
  single-agent findings are what the consensus registry and Phase 5 triage are for.
- **Evidence over opinion** — findings need file paths and line numbers
- **Don't pile on** — if explorer finds dead code, that's cleanup, not a bug
- **Critical/High first** — skip Medium unless trivial to fix
- **Deletion mandate** — a finding of stale/superseded/duplicated content is not flag-and-leave;
  REMOVAL/demotion ranks as a first-class disposition, equal to additions/fixes, and follows the
  same auto-apply rules (severity/consensus, Phase 3) as any other change. Route the removal per
  `skill-builder/references/promotion-ladder.md` §What routes through the holding zone: a
  **duplicate** (verbatim twin survives elsewhere) deletes outright; a still-needed **extract**
  moves straight to `references/` with a pointer; **unique** content with no surviving twin is the
  only case that must route through the skill's `MAINTENANCE.md` holding-pen (review-by date +
  default resolution) before it can be git-deleted.

Produce a numbered change list. For each: target file, what to change, auto-fixable or not.

### Phase 3: Apply Fixes

**Auto-apply a fix if ANY condition is met:**

1. **Severity-based:** The issue is Critical or High severity — these are defects, not preferences
2. **Same-round consensus:** 2+ agents independently flagged the same issue (regardless of severity) — multi-agent agreement is high-signal
3. **Cross-round consensus:** A single-agent finding from THIS round matches a deferred finding in the consensus registry from a PREVIOUS round — recurrence across rounds is high-signal

<!-- mirror: ac-pipeline/references/review-consensus.md §The auto-apply cascade — edit there first -->

**Design decision gate (applies before all auto-apply rules):** If a finding represents a choice with no objectively superior technical answer, resolve it yourself — pick the better option. Only tag as `DESIGN_DECISION` and defer if the decision would **noticeably affect the end-user experience** or **profoundly change the development approach**. Minor design choices (spacing values, naming conventions, implementation style) — just pick the better option and auto-apply.

<!-- mirror: ac-pipeline/references/review-consensus.md §Design-decision gate — edit there first -->

**Apply these immediately. Log them as "Auto-applied" in the progress file with the consensus type.**

After each batch of fixes — the **round gate** (incremental, per `ac-pipeline`
Invariant 2: incremental in the loop, exhaustive once at the boundary):

```bash
format (auto-fix, e.g. `pnpm format`) + type-check + lint + AFFECTED tests only   # BLOCKING
# Never run the full suite per round — it runs exactly once, at Phase 5, pre-merge.
```

Run **format FIRST and as an auto-fix** (`pnpm format` = `prettier --write .`, not
`format:check`) — CI checks formatting first over the *whole repo*, so one unformatted file
fails the entire gate ~10 min in; auto-fixing locally makes that impossible.
<!-- mirror: ac-pipeline/references/verification-gate.md §Format-first gate — edit there first -->

If checks fail, revert the breaking fix and note it as non-auto-fixable.

Then commit the round's fixes **directly to `main`** (trunk-direct — no hygiene branch;
small, revert-friendly, pathspec-limited commits) and **push immediately** (commit = push;
there is no branch holding the work safe in the interim):

```bash
git pull --rebase
git commit -m "chore(hygiene): round {CURRENT_ROUND} — {short summary}" -- <specific files>
git push --no-verify origin main
git rev-parse HEAD && git ls-remote origin main   # confirm the SHAs match after every push
```

> **Pathspec commits, never `git add -A`.** Use the `git commit -- <files>` form limited to the
> exact paths YOU changed (tracked from the implementer reports). Under trunk-direct another
> session's uncommitted WIP shares this checkout — a wildcard add sweeps that foreign work into
> your hygiene commit and misattributes it (`ac-implement` Phase 0 H7d; 2026-07-06 incident:
> `references/incidents.md`). New (untracked) files need `git add <file>` first, then the
> pathspec commit of exactly that path.

> **Commit WITHOUT `--no-verify`; push WITH it.** The pre-commit hook runs `lint-staged`
> (prettier `--write` + eslint `--fix`) on your staged files and re-stages them — the cheap
> auto-format net that stops formatting-class CI failures; never bypass it on a commit.
> `--no-verify` is for the **push** only — under trunk-direct the heavy pre-push `pnpm build`
> reads the whole working tree and another session's uncommitted WIP can false-positive it
> (swallowing the push), so real verification for state you don't own comes from the round gate
> above plus post-push CI. **Race handling:** if `git push` collides, `git pull --rebase` and
> re-push — never force-push over another session's committed work.

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

**Rule 2 (the round floor): the `MIN_ROUNDS=3` floor is ABSOLUTE** — cross-round consensus needs two later rounds for a deferral to recur in; see the config comment (Phase 0) and the first branch of the decision block below. Ceiling is `MAX_ROUNDS=5`.

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

<!-- mirror: ac-pipeline/references/review-consensus.md §Conductor triage — edit there first -->

**Apply all `AUTO_IMPLEMENT` items** using Edit tool. Log each with rationale.

### Present Decisions to User (if any)

**If no `DESIGN_DECISION` or `SCOPE_ESCALATION` items remain:** Skip — proceed to quality gate.

**Exhaust rule (see `skills/beads-standards/reference/bead-conventions.md`):** nothing actionable
leaves as prose. Out-of-scope confirmed issues → `br create -t bug --labels
hygiene-finding,unrefined`. Worth-chasing uncertainties → `-t investigation`. Genuine
taste/product forks in an autonomous run (user not present) → `-t decision
--labels human-gate` with a pre-staged memo, then continue — never stall the
sweep on a question. Dedupe per the canon's anchor-dedupe rule
(`beads-standards/reference/bead-conventions.md` § Anti-inflation); nits stay in the report <!-- net-growth-ok: ac-gzb P2 — canon citation replaces weaker local rule -->
(hygiene is the highest inflation risk — a bead is something you'd schedule).

> **`human-gate` is MANDATORY on every `decision`-typed / `DECISION:`/`DESIGN_DECISION:`-titled
> bead at filing, not optional** (memory `decision-beads-need-human-gate-label-at-filing`;
> `beads-standards` § human-gate). `issue_type=decision` alone gates nothing — the LABEL is
> what every label-keyed gate reads. Do not hand-roll a `br create -t decision` that omits it;
> a dropped `human-gate` leaves the bead silently workable/auto-closable around the human.
> `ac-bead-refine`'s Phase 5 title/label parity check (bd-7fqgi seam 2) backstops any that slip.

**Bead bodies follow the template at creation** (bead-conventions § Body
template): typed headers (`## Steps to Reproduce` for bugs, `## Acceptance
Criteria`, `## Test Scope` with grep-verified anchors, `## Success Criteria` on
the epic) plus a durable evidence pointer (the run's PR, not `$ARTIFACTS_DIR`
paths — those are deleted at Cleanup). Writing the full body now costs a minute vs a
full refine round later — the in-session refine step then verifies instead of authoring.

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

This is the single exhaustive local run of the workflow (rounds ran affected-only). Format runs
FIRST as auto-fix; if it rewrites files you did NOT author, commit the formatting as part of
this run (rule + why: `ac-pipeline/references/verification-gate.md` §Format-first gate). If any check fails,
fix before proceeding. Commit any Phase-5 fixes (user-approved + AUTO_IMPLEMENT triage items)
directly to `main` (pathspec, push immediately; **no `--no-verify` on the commit**, `--no-verify`
on the push only — same rule as Phase 3).

**Note:** the close ceremony below (`ac-batch-close`) dispatches Tier 1 CI on the final SHA —
so this Phase-5 local run is a pre-handoff sanity check, not the last word. Keep it: catching a
red gate here, before handing off, is cheaper than catching it inside the CI dispatch.

### Close Ceremony (delegate to ac-batch-close)

There is **no branch to ship** — every fix is already committed and pushed to `main` (Phase 3).
The close ceremony is therefore batch-close style, not a merge:

**No commits landed (findings only)?** Skip to Report — nothing to close, no version bump.

**Otherwise: invoke `ac-batch-close`.** Do not build a third bespoke close mechanism and do not
route through `ac-merge` (that path is for the branches that survive the migration — dependabot,
human PRs). `ac-batch-close` owns the trunk-direct close: version bump → Tier 1 CI dispatch +
fix-forward → tag → deploy verification. Delegation prompt:

> "Run ac-batch-close for this hygiene run's commits on `main`. Version bump = patch (existing
> hygiene-bumps-patch policy — accept without asking); the 7-lens panel already served as this
> batch's review — **pass the panel run report as the pre-supplied review artifact for Phase 1
> path (a)** (it carries an explicit `VERDICT:` line; stage it in `.claude/reviews/pending/` and
> carry it into `.claude/reviews/batch/` via your Act 3 commit — never write to `batch/` outside
> that single commit, bd-kudrb), so do NOT re-run `ac-review` on this same diff; uncertain CI feedback →
> decision beads (Exhaust Rule); no 'what's next?' after."

**Hand `ac-batch-close` the "Also carried (not hygiene fixes)" disclosure.** With no PR diff to
eyeball, foreign work that rode along is easy to miss — diff `main` since this run's first
hygiene commit (`git log --oneline <first-hygiene-sha>..HEAD`) and name any non-hygiene commit
(an `.env`/secret edit, a migration, another session's fix) as Also-carried content for the
batch-close report — do not silently drop it just because this run didn't author it.

- **Hygiene bumps `patch`** via `ac-batch-close` (unchanged policy — `ac-batch-close` is the
  trunk-direct bump owner, default patch unless explicitly frozen/skipped).
- **No CI on this repo:** `ac-batch-close`'s concern — it falls back to a local
  quality-gate-then-tag path when there's no `quality-gate.yml` dispatch to run.
- CI fails → `ac-batch-close` fixes forward on `main` and re-dispatches as part of its own
  triage loop; if unfixable this session it files a `qa-blocker`-style bead and reports it —
  never tag red.

### Refine the Run's Beads (in-session, after the close ceremony)

If this run created **≥1 bead**, run **`ac-bead-refine`** NOW — scoped to the epic if one
exists (2+ beads), to the single bead otherwise — before the report, not "later": the
conductor still holds every finding, verdict, and triage rationale in context; a deferred
refine session re-derives it from cold, or can't. Run-specific notes for the reviewer prompts:

- Bead descriptions were written mid-run — file/line references predate the merged fixes.
  Reviewers must re-verify every reference against merged `main` and correct drift.
- The refine reviewers work in the shared `main` checkout (there is no hygiene worktree under
  trunk-direct); fixes are already committed and pushed to `main`.
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

**Commit the run report to `.claude/reviews/` root** (the standalone/mid-batch review
destination — same rule as any non-batch-close `ac-review` invocation). *Hygiene itself* **must
NOT** write to `.claude/reviews/batch/`: <!-- net-growth-ok: bd-kudrb — hygiene is a third
potential writer of the review-mark path; the existing warning here explained only the
stale-mark risk, not the mid-ceremony under-scoping one. --> that directory is the review-mark, and under the
single-writer invariant (bd-kudrb) **only `ac-batch-close`'s Act 3 commit may touch it** — not
hygiene, not `ac-review`. A hygiene run on its own is not a batch close; writing there would
spuriously advance the review-mark and make the next standing-review-of-`main` skip real commits,
and a write landing mid-ceremony would be returned by the anchor probe as a commit inside its own
range (silent under-scoping). (When this run *did* land fixes and closes them through
`ac-batch-close`, the panel report is handed to that ceremony as its Phase 1 review artifact —
path (a) — staged in `.claude/reviews/pending/`, and `ac-batch-close`, not hygiene, carries it
into `.claude/reviews/batch/` in its Act 3 commit; advancing the mark is then correct, because a
batch genuinely shipped and was reviewed.)

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

**Standing weekly review of `main` (trunk-direct duty, C2).** Because fixes now land directly
on `main` with no PR diff to gate them, the weekly `PANEL=full` run doubles as the standing
review of `main`: **if no batch has shipped (no `.claude/reviews/batch/` commit) in >7 days,
the weekly hygiene run is the review of everything on `main` since the last `v*` tag** — it is
not optional in that window. This is the trunk-direct analogue of the pre-merge review a PR used
to force; when batches ship regularly, `ac-batch-close`'s own `ac-review` gate covers `main` and
this weekly pass is the ordinary quality sweep on top.

**Baseline pointer only — `ac-prove` `probe` mode (Consumer Roster row (e)).** The weekly
review-main run consumes the latest `ac-prove` receipt in **`probe` mode ONLY** — a read-only
freshness check against `publish-checkpoint-gate.mjs` (`ac-prove` Step 1). This is **never** a
dispatch: hygiene never calls `ensure` or `ensure --fix-forward`, never triggers a fresh CI run,
and never fixes CI forward — proving `main` is a ship-path concern, not a review-pass concern.
It is also **never proof-of-green**: `probe` mode checks freshness only (condition 1 of
`ac-prove`'s three-condition trust rule — Canonical Receipt Contract) — the referenced run's
actual conclusion is unchecked and may be RED. Treat the receipt strictly as a baseline pointer
("here's roughly how fresh `main`'s last full proof is"), never as evidence that the codebase
this run is reviewing is CI-green.

---

## Flexibility / Overrides

- **"light"** in the prompt → 3-lens panel (Bug Hunter, Explorer, Structural), same rounds/rules
- **"headless" / scheduled** → no `AskUserQuestion` anywhere; full codebase, full panel; Exhaust Rule owns all decisions; Slack report mandatory
- **Scope override** — "hygiene on features/auth" → Specific-directory scope, no question asked
- **Round override** — "single round" / "quick pass" → MIN_ROUNDS=1 (accept: cross-round consensus disabled; deferred singles go straight to Phase 5 triage)

## Troubleshooting

- **Push blocked / collides** → `git pull --rebase` and re-push (never force-push over another session's committed work); if the pre-push build false-positives on foreign WIP, push with `--no-verify` (the round gate + post-push CI are the real verification)
- **Dirty tree at Phase 0** → EXPECTED under trunk-direct, NOT a blocker — inventory the foreign WIP, don't touch it, and pathspec-commit only your own files (Phase 3); only a genuine red flag (unexpected deletions, sensitive files) surfaces to the user
- **Agent dies / returns nothing** → note the lens as absent for the round and continue with the rest of the panel; re-spawn once if 2+ die
- **Quality gate fails on a fix** → revert that fix, mark non-auto-fixable, add to registry; never ship a red gate
- **Compaction mid-run** → `$ARTIFACTS_DIR/progress.md` + consensus registry are the recovery state (see Phase 0); commits already pushed to `main` hold all applied fixes (there is no branch — never sit on local-only commits)

---

## Remember

- **Codebase-wide, not feature-scoped** — agents explore freely (unless user constrains)
- **Fresh eyes each round** — direct agents to unexplored files in subsequent rounds
- **Removal ranks equal to additions** — stale/superseded/duplicate findings get the Deletion
  Mandate's routing (dup deletes outright, extract → `references/`, unique → holding-pen), not a flag-and-leave
- **Stamp-audit lens (weekly)** — spot-check `<!-- evidence: ... -->` stamps against real run history; an unsubstantiated claim is a finding
- **Auto-apply Critical/High + same-round consensus + cross-round consensus — defer the rest**
- **Round floor = MIN_ROUNDS=3, ABSOLUTE** — never finalize before round 3 (see Phase 4); ceiling MAX_ROUNDS=5
- **Lens-diverse consensus is rarer and stronger** — don't lower the bar; the registry + Phase 5 triage absorb the singles
- **Fixes commit directly to `main`** (trunk-direct — no hygiene branch, no worktree) under full H7 discipline while editing; commit=push, pathspec-limited to your own files; the close ceremony is `ac-batch-close`'s, never `ac-merge`'s
- **Conductor triage before user** — auto-implement clear technical improvements; defer only genuine design decisions and scope escalations
- **Design decision gate every round** — UX-affecting or approach-transforming choices defer regardless of severity or consensus
- **Incremental in the loop, exhaustive at the boundary** — affected-only per round, full suite exactly once at Phase 5; format FIRST + auto-fix in both gates, commit WITHOUT `--no-verify` (§Format-first gate)
- **Deferred beads get an epic per run** (2+ beads); refine in-session after the close ceremony whenever ≥1 bead was created
- **Findings files + consensus registry survive compaction** — always read from `$ARTIFACTS_DIR`, not memory
- **Don't invent issues** — if the codebase is clean, say so and finish early

---

_Hygiene: the recurring codebase quality pass. For session closure: `/ac-land`._
