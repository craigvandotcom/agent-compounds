---
name: ac-land
description: 'The closing ritual — runs LAST, after merge. To land = leave it clean AND wiser: TEARDOWN (kill spawned tasks, sweep orphaned waiters, release+deregister Agent Mail, clear temp, clean tree) plus LEARN (retrospective + reflect + system compounding). Triggers: ''land the session'', ''bead land'', ''close out the bead work'', ''wrap up session'', loop exit. NOT for standalone lesson capture without bead-work context (that is reflect).'
---


**You are the conductor closing a bead-work session.** Land the plane, extract learnings, propose system upgrades, hand off cleanly.

Run this LAST, after merge — invoked at loop-exit (post-merge, on `main`, wave branch gone) or manually once a wave has shipped. See Phase 0 below for how it resolves session context in that post-merge state.

---

## Phase 0: Initialize

### Gather Session Context

Resolve `ARTIFACTS_DIR` **deterministically**, per `_shared/run-id.md`. ac-land runs at
loop-exit (post-merge, on `main`, wave branch gone), so it CANNOT derive the wave slug itself —
the orchestrator hands it the key. Never glob as the primary path.

```bash
# 0. Loop-exit: RUN_ID set → ALL this run's wave dirs (scoped glob is SAFE — RUN_ID excludes
#    foreign/stale dirs). The retrospective spans every wave; teardown sweeps them all.
# 1. Handed ARTIFACTS_DIR (single bead-work session) → use verbatim.
# 2. Standalone on a wave branch → derive.
# 3. Last resort → newest dir, with a logged warning (it was guessed).
if [ -n "$RUN_ID" ]; then
  ARTIFACTS_DIRS=$(ls -1dt /tmp/bead-work-*-"$RUN_ID"/ 2>/dev/null | sed 's:/$::')
  ARTIFACTS_DIR=$(printf '%s\n' "$ARTIFACTS_DIRS" | head -1)   # primary (newest wave) for single-dir steps
  [ -z "$ARTIFACTS_DIR" ] && ARTIFACTS_DIR=/tmp/bead-work     # run shipped nothing landable
elif [ -n "$ARTIFACTS_DIR" ]; then
  :                                                   # handed by orchestrator — use verbatim
elif git rev-parse --abbrev-ref HEAD 2>/dev/null | grep -q '^wave/'; then
  ARTIFACTS_DIR="/tmp/bead-work-$(git branch --show-current | tr '/' '-')"
else
  ARTIFACTS_DIR=$(ls -1dt /tmp/bead-work-*/ 2>/dev/null | head -1 | sed 's:/$::')
  [ -z "$ARTIFACTS_DIR" ] && ARTIFACTS_DIR=/tmp/bead-work
  echo "WARN: ARTIFACTS_DIR not handed and not on a wave branch — GUESSED $ARTIFACTS_DIR" >&2
fi
echo "ARTIFACTS_DIR=$ARTIFACTS_DIR"
[ -n "$ARTIFACTS_DIRS" ] && echo "ARTIFACTS_DIRS (all waves this run, retrospective spans all): $ARTIFACTS_DIRS"
```

**You MUST substitute the resolved `$ARTIFACTS_DIR` into all sub-agent prompts below.** The literal string `/tmp/bead-work` in this file is a placeholder — for parallel sessions you write the actual resolved path (e.g., `/tmp/bead-work-2939805`) into each spawned agent's prompt. Do NOT pass the variable name; sub-agents don't share the parent shell.

Read `$ARTIFACTS_DIR/progress.md` — this is the record of what was accomplished. If it doesn't exist, STOP: "No bead-work progress found. Run `/ac-implement` first."

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

### Declare the Run Ledger

ac-land runs LAST and can compact mid-flight — Phase 1 alone carries two named compaction
risks (a slow standalone-fallback `test:all` in 1b, a hung browser-tester in 1c) — and
teardown that never runs leaves zombies. Declare a run ledger with **one task per major
section, including each of Phase 1's four sub-steps**, so a resumed session re-enters at the
exact sub-step instead of re-running quality gates or, worse, skipping teardown:

```
TaskCreate (one per section, in run order):
  1. Initialize                            in_progress
  2. File remaining work (1a)              pending
  3. Quality gates (1b)                    pending
  4. UI validation suite (1c)              pending
  5. Git ops + fire async CI (1d)          pending
  6. Learn (retrospective)                 pending
  7. Compound (system upgrades)            pending
  8. Hand off                              pending
  9. Teardown                              pending
```

`TaskUpdate` each to `in_progress` when you start it and `completed` when done — the section
headers below (`1a.` … `1d.`, then Phase 2 → Phase 4, then Teardown) map to these tasks 1:1;
mark task 1 `completed` now. `progress.md` remains the artifact-of-record for *what was
accomplished*; the ledger tracks *where the run is* — so a compacted conductor knows whether
teardown (task 9) still owes work. The ledger tracks the RUN; beads stay the work atom.

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

Mark ledger task 2 `completed`; `TaskUpdate` task 3 `in_progress`.

### 1b. Quality Gates

> **Skip-if-fresh (loop / post-merge context).** If a GREEN `test:all` / CI Quality Gate
> already exists for the current HEAD — e.g. `ac-merge` just shipped it — **note-and-skip**
> the `test:all` + `build:check` re-run here; they are redundant and cost ~45-50 min on the
> shared self-hosted runner. Re-run them ONLY when no fresh pass exists (standalone landing,
> or local changes since the gate). Format / lint / type-check are cheap — always run.
> (Mirrors `ac-merge`'s QA-gate skip-if-fresh; don't validate the same HEAD twice.)

> **Tiered-testing model (parallel-execution doctrine §5).** Wave merges now run **affected-only**
> CI, so at loop-close there is no fresh *full* `test:all` for HEAD. Do NOT run a blocking local
> `test:all` here — it's the exact full run the doctrine keeps OFF the loop's critical path, and it
> starves the shared self-hosted runner. Instead **Phase 1d fires the async loop-close full run on
> CI** (`gh workflow run quality-gate.yml -f reason=loop-close`), non-blocking; a red result
> auto-files a bead (§5) and blocks `publish`. Run a local `test:all` here ONLY for a standalone
> landing with no CI path.

```bash
# Format / lint / type-check run fast — terminal-only output is fine.
pnpm format && pnpm lint && pnpm type-check

# Build check (fast — terminal-only).
pnpm build:check
```

> **STANDALONE ONLY — else SKIP.** Only run the block below if this is a standalone landing with
> no loop-close CI path (no `quality-gate.yml` workflow in this repo, or a manual land with no
> Phase 1d to follow). In the normal loop/tiered close, SKIP entirely: Phase 1d fires the async
> loop-close CI run, and a blocking local full run here is the exact run §5 moves off the critical
> path.
>
> ```bash
> # tee to a log so failure detail survives tail-truncation.
> pnpm test:all 2>&1 | tee "$ARTIFACTS_DIR/test-all.log" | tail -30
> ```

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

Mark ledger task 3 `completed`; `TaskUpdate` task 4 `in_progress`.

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
ls .claude/skills/CORE/journeys/ 2>/dev/null
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

Classify the session diff with the **shared classifier in `_shared/verification-gate.md`**
(Step 1) — the same `CLASS_WEBUI` / `CLASS_WEBRT` greps `ac-merge` and the Verify gate use.
Don't re-derive the classification in prose here; single-sourcing it keeps ac-land from
over-testing non-UI `.ts` changes (e.g. a `lib/` util) that the gate would skip:

- `CLASS_WEBUI` or `CLASS_WEBRT` set → route to the matched journeys below.
- Neither set (backend/logic-only or docs) → skip UI validation, note why.

Cross-reference the set classes with the project's journey definitions to pick which testers to run.

#### Step 3: Spawn Testers

**One tester per matched journey, all in parallel.** If 2+ journeys match, send all Task calls in a single message for concurrent execution.

Use the prompt in **`references/ui-tester-prompt.md`** (substitute the resolved `<ARTIFACTS_DIR>` from Phase 0).

> Substitute `<ARTIFACTS_DIR>` with the resolved path from Phase 0 (e.g., `/tmp/bead-work-2939805` for parallel mode, `/tmp/bead-work` for solo).

#### Step 4: Review Results

Read all report files from `<ARTIFACTS_DIR>/ui-suite-*.md` (use the resolved path from Phase 0).

- **All PASS:** Continue to git operations
- **Any FAIL:** Fix the issue, re-run only the failing journey's tester, then continue
- **Skipped:** Note "UI validation skipped (no browser tool / no journeys defined)"

Mark ledger task 4 `completed`; `TaskUpdate` task 5 `in_progress`.

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

**Fire the loop-close integration run (tiered testing, doctrine §5).** With `main` pushed and up to
date, kick off the full `test:all` on CI for this exact HEAD — **non-blocking**; continue to Phase 2
without waiting. **Guard first** — only body-compass-app has this workflow today; if
`quality-gate.yml` doesn't exist in this repo, fall back to a local full run as the loop-close gate:

```bash
if gh workflow list --json name --jq '.[].name' 2>/dev/null | grep -qi quality-gate; then
  gh workflow run quality-gate.yml -f reason=loop-close   # async full-suite integration gate that publish reads (§6)
else
  echo "No quality-gate.yml workflow — running local full suite as the loop-close gate instead."
  pnpm test:all 2>&1 | tee "$ARTIFACTS_DIR/test-all.log" | tail -30
fi
```

Affected-only ran per wave; this one full run is the doctrine's single loop-close `test:all`
(§5 Tier 2), covering everything the loop merged. Red → auto-file a P1 bead (first pick for the next
`ac-loop` run) and it blocks `publish`. Skip only for a standalone landing with no CI path.

Mark ledger task 5 `completed`; `TaskUpdate` task 6 `in_progress`.

---

## Phase 2: Learn (Retrospective)

**Goal:** With complete information, identify what worked, what didn't, and what friction occurred.

### Spawn Retrospective Sub-Agent

Spawn the retrospective analyst using the prompt in **`references/retrospective-prompt.md`** (substitute the resolved `<ARTIFACTS_DIR>`). It reads session artifacts + the workflow/skill files, reports what worked / what did not / patterns, and proposes evidence-backed system-upgrade opportunities under a strict minimum-waste bar.

> **Loop-exit (multi-wave):** when `$ARTIFACTS_DIRS` is set (Phase 0 found several wave dirs for this `RUN_ID`), substitute **all** of them so the retrospective spans the whole loop session — every wave's `progress.md` — not just the last wave. A single-wave land has one dir and behaves as before.

### Conductor Reviews Retrospective

Read `<ARTIFACTS_DIR>/retrospective.md` (use the resolved path from Phase 0). Apply the minimum bar: did this issue cause real waste THIS session? Drop anything that's "interesting but theoretical." Keep only items where you can point to a specific moment where time or resources were lost because the information wasn't available upfront.

Mark ledger task 6 `completed`; `TaskUpdate` task 7 `in_progress`.

---

## Phase 3: Compound (System Upgrades)

**Goal:** Turn learnings into system improvements. User decides what ships.

**NO AUTO-APPLY.** Unlike review skills (`ac-plan-clean`, `ac-hygiene`, `ac-review`, `ac-beadify`) which auto-apply consensus findings, bead-land presents ALL upgrade proposals to the user. System compounding changes identity and workflow — every change needs explicit approval.

### Step 0: Capture durable lessons via `reflect`

Before proposing system-file upgrades, invoke the **`reflect`** skill to capture this
session's durable learnings (facts / decisions / recipes) into the typed, domain-routed,
git-tracked memory substrate. `reflect` handles `{type, domain}` routing + dedupe-over-append:
it writes low-risk lessons directly and **gates** any skill-improvement for approval (same
discipline as below). This closes the write loop — a lesson learned here becomes retrievable
from a different app/machine next week instead of being stranded in this transcript. Pass it
the retrospective findings from Phase 2 as the candidate lessons.

Then continue with the system-file upgrade proposals below.

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
| `.claude/skills/*.md`             | Command improvements based on friction |
| `MEMORY.md`                         | New patterns, gotchas, workflow notes  |

### Commit Compound Changes

```bash
git add <specific files>
git commit -m "chore: compound learnings from bead-work session

Applied N system upgrades from retrospective.

Co-Authored-By: Claude <noreply@anthropic.com>"
git push
```

Mark ledger task 7 `completed`; `TaskUpdate` task 8 `in_progress`.

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

Note: `ac-land` runs **LAST** — after `ac-review` AND `ac-merge`. Review and merge are the work; landing brings it to rest (clean + wiser). When driven by `ac-loop`, land is the **guaranteed exit step for every stop path**, so the loop is never "done" until it has landed. By the time landing runs, THIS wave has already merged to main — there is nothing left to review or merge for it. The only next steps are starting the next wave or stopping.

```
AskUserQuestion(
  questions: [{
    question: "Session landed. What's next?",
    header: "Next step",
    multiSelect: false,
    options: [
      { label: "Start next wave", description: "Run /ac-plan-init or /ac-implement — {M} beads remaining, pick up the next wave" },
      { label: "Refine remaining beads", description: "Run /ac-bead-refine — revise remaining beads before implementing the next wave" },
      { label: "Done for now", description: "Session over — nothing more to do until the next wave is picked up" }
    ]
  }]
)
```

### Cleanup Temp Files

Remove session artifacts (they've been consumed by retrospective). Run each separately to avoid shell chaining that triggers safety hooks:

```bash
rm -rf /tmp/bead-work
rm -rf /tmp/bead-work-*
rm -rf /tmp/plan-init-*
rm -rf /tmp/wave-merge-*
rm -rf /tmp/plan-refine-internal-*
rm -rf /tmp/plan-refine-*
rm -rf /tmp/plan-clean-*
rm -rf /tmp/bead-refine-*
rm -rf /tmp/beadify-*
rm -rf /tmp/hygiene-*
rm -rf /tmp/work-review-*
```

Mark ledger task 8 `completed`; `TaskUpdate` task 9 `in_progress`.

### Teardown (operational — part of landing)

Landing means leaving NO live debris. Run this regardless of how the session reached land
(clean finish, iteration cap, regression stop, human "stop", or error):

1. **Kill spawned background tasks/waiters.** Long-running poll/wait loops are the classic
   zombie — a `until cond; do sleep N; done` whose condition never fires runs forever (a
   prior session left one alive ~16.5h). Stop them by IDENTITY, not a broad sweep:
   - For harness-tracked background tasks: `TaskStop` each one you started this session.
   - For stray shells, list candidates and confirm each is yours before killing — match the
     specific command, never a blanket pattern:
     ```bash
     ps -Ao pid,etime,command | grep -iE "until .*sleep|seq 1 .*gh (run|pr)|pnpm test:all" | grep -v grep
     # kill -TERM <pid> ONLY for loops you recognize as this session's. Do NOT kill the
     # self-hosted Actions runner, the dev server someone else owns, or unrelated jobs.
     ```
   - Then confirm none survive: re-run the `ps … grep` → expect empty.
   - **Prevention** (the *Fail safe; leave no live debris* law — `ac-pipeline-builder`
     through-threads): every waiter you create needs a hard cap (`for i in $(seq 1 N)` /
     `timeout`), never an unbounded `until`. A waiter that can't time out is a future zombie —
     and the rule binds when you *write* the loop, not just when teardown sweeps for it here.
2. **Agent Mail:** `release_file_reservations` (all paths for your agent), then
   `deregister_agent` (or `retire_agent`). Don't leave reservations to TTL-expire.
3. **Working tree:** resolve or EXPLICITLY flag non-wave junk. A dirty tree the next session
   trips over is a teardown failure. If concurrent-session files are present and not yours
   (unmerged `UU`, stray staged files), surface them in the summary — don't silently leave
   them, and don't blindly discard another agent's uncommitted work.

### Final Verification

```bash
git status          # Clean working tree
git log --oneline -1  # Latest commit pushed
br ready --json     # What's left
```

Mark ledger task 9 `completed` — the run is landed.

---

## Remember

- **Land is NON-NEGOTIABLE and runs LAST** — after merge; it is `ac-loop`'s guaranteed exit
- **To land = clean AND wise** — teardown (no live processes, no leaked Agent Mail reservations, clean tree, temp cleared) is as much "landing" as the retrospective. A session that leaves zombies running did not land, no matter how much it shipped
- **Learn from evidence, not speculation** — every finding needs a concrete example from this session
- **Compound aggressively but ALWAYS user-gated** — no auto-apply, every upgrade needs explicit approval (unlike review commands)
- **Context bloat is the enemy** — refine existing content, don't just append
- **Temp files are the source of truth** — read from `$ARTIFACTS_DIR`, not memory
- **This is what makes the flywheel accelerate** — each session improves the next

---

_Bead land: close clean, learn deep, compound forward. The flywheel spins faster every session._
