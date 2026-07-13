---
name: ac-land
description: "The closing ritual — runs LAST, after merge. To land = leave it clean AND wiser: TEARDOWN (kill spawned tasks, sweep orphaned waiters, release+deregister Agent Mail, clear temp, clean tree) plus LEARN (retrospective + reflect + system compounding). Triggers: 'land the session', 'bead land', 'close out the bead work', 'wrap up session', loop exit. NOT for standalone lesson capture without bead-work context (that is reflect)."
---

**You are the conductor closing a bead-work session.** Land the plane, extract learnings, propose system upgrades, hand off cleanly.

Run this LAST, after merge — invoked at loop-exit (post-merge, on `main`, wave branch gone) or manually once a wave has shipped. See Phase 0 below for how it resolves session context in that post-merge state.

---

## Phase 0: Initialize

### Gather Session Context

Resolve `ARTIFACTS_DIR` **deterministically**, per `_shared/run-id.md`. ac-land runs at
loop-exit (post-merge/batch-close, on `main`) — it never claimed a batch itself, so it CANNOT
mint or independently recompute a claim id; the orchestrator hands it the key. Never glob as
the primary path. There is no branch-based fallback in this chain: trunk-direct means `main` is
always there, so a "standalone session still sitting on the wave branch" case can no longer
occur — that dead fallback is removed outright, not left dormant.

```bash
# 0. Loop-exit: RUN_ID set → ALL this run's dirs (scoped glob is SAFE — RUN_ID excludes
#    foreign/stale dirs). The retrospective spans every batch this run shipped; teardown sweeps
#    them all.
# 1. Handed ARTIFACTS_DIR (single bead-work session, no RUN_ID) → use verbatim.
# 2. Last resort → newest dir, with a logged warning (it was guessed).
if [ -n "$RUN_ID" ]; then
  ARTIFACTS_DIRS=$(ls -1dt /tmp/bead-work-*-"$RUN_ID"/ 2>/dev/null | sed 's:/$::')
  ARTIFACTS_DIR=$(printf '%s\n' "$ARTIFACTS_DIRS" | head -1)   # primary (newest batch) for single-dir steps
  [ -z "$ARTIFACTS_DIR" ] && ARTIFACTS_DIR=/tmp/bead-work     # run shipped nothing landable
elif [ -n "$ARTIFACTS_DIR" ]; then
  :                                                   # handed by orchestrator — use verbatim
else
  ARTIFACTS_DIR=$(ls -1dt /tmp/bead-work-*/ 2>/dev/null | head -1 | sed 's:/$::')
  [ -z "$ARTIFACTS_DIR" ] && ARTIFACTS_DIR=/tmp/bead-work
  echo "WARN: ARTIFACTS_DIR not handed and no RUN_ID scope — GUESSED $ARTIFACTS_DIR" >&2
fi
echo "ARTIFACTS_DIR=$ARTIFACTS_DIR"
[ -n "$ARTIFACTS_DIRS" ] && echo "ARTIFACTS_DIRS (all batches this run, retrospective spans all): $ARTIFACTS_DIRS"
```

**You MUST substitute the resolved `$ARTIFACTS_DIR` into all sub-agent prompts below.** The literal string `/tmp/bead-work` in this file is a placeholder — for parallel sessions you write the actual resolved path (e.g., `/tmp/bead-work-2939805`) into each spawned agent's prompt. Do NOT pass the variable name; sub-agents don't share the parent shell.

Read `$ARTIFACTS_DIR/progress.md` — this is the record of what was accomplished. If it doesn't exist, STOP: "No bead-work progress found. Run `/ac-implement` first."

**Also read the loop-retro friction carrier** — `/tmp/loop-retro-<RUN_ID>.md` (resolve `<RUN_ID>`
from the `RUN_ID` passed in; the ac-loop conductor writes it before Exit-Land, one `## <stage>`
section per stage that hit friction — see ac-loop § "Friction aggregation"). Hold the parsed
per-stage friction items **with their `stage`/`cost`/`lesson`/`class` typing intact** — they feed
`reflect` directly in Phase 3 Step 0 (do NOT route them through the Phase 2 prose analyst, which
would reword them and destroy the structural key D4/D5 depend on). **Graceful degrade:** if the
carrier is absent or empty (a standalone / clean-run land), skip it entirely and proceed exactly
as today — reflect then receives only the Phase 2 findings.

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
  5. Git ops — commit + push (1d)          pending
  6. Learn (retrospective)                 pending
  7. Compound (system upgrades)            pending
  8. Hand off                              pending
  9. Teardown                              pending
```

`TaskUpdate` each to `in_progress` when you start it and `completed` when done — the section
headers below (`1a.` … `1d.`, then Phase 2 → Phase 4, then Teardown) map to these tasks 1:1;
mark task 1 `completed` now. `progress.md` remains the artifact-of-record for _what was
accomplished_; the ledger tracks _where the run is_ — so a compacted conductor knows whether
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

> **Tiered-testing model (parallel-execution doctrine §5, bd-pwt44).** Wave merges now run
> **affected-only** CI, so at land time there is no fresh _full_ `test:all` for HEAD. Do NOT run a
> blocking local `test:all` here — it's the exact full run the doctrine keeps OFF the loop's
> critical path, and it starves the shared self-hosted runner. **Phase 1d no longer fires a
> full-suite CI run** — the between-publish full-suite proof is obtained at PUBLISH START instead:
> `ac-publish` calls `ac-prove ensure --fix-forward`, which runs the exhaustive gate SHA-pinned to
> the commit being published, before release. A nightly idle-time full run (`ac-prove`/
> `workflows/scheduled.md`) is planned but DEFERRED/unwired — until it ships, the publish-start run
> is the only full-suite checkpoint. Run a local `test:all` here ONLY for a standalone landing with
> no CI path.

> **`in_progress` ≠ stuck — COMPUTE elapsed before flagging, never eyeball.** At land time, the
> just-merged commit's own CI Quality Gate for HEAD is frequently STILL RUNNING (the merge step
> fires it and landing follows immediately after) — an `in_progress` run is the EXPECTED state, not
> an anomaly. **Never report a
> run as "stuck"/"hung"/"wedged" from its status alone or with a duration you did not measure.** A run
> is stuck ONLY if its _computed_ elapsed time far exceeds the suite's norm: derive it from
> `gh run view <id> --json createdAt,jobs` (or the job's `startedAt`) vs `date -u` now, and flag only
> when elapsed > ~2× typical (this suite is ~15-20 min → threshold ~40 min+). Under the threshold →
> report "CI in-progress, on track (Nm elapsed)" and move on; do NOT alarm, do NOT block landing.
> Asserting an unmeasured duration is a **fabricated finding** — cost: the RUN_ID 20260708-191557
> land falsely flagged `e77abbae` "stuck in_progress 2+ hours" when its gate was 15 min old and
> passed clean, sending the conductor on a false-alarm CI hunt. If you flag a run, paste the two
> timestamps + the arithmetic; a flag without the math is not allowed.

```bash
# Format / lint / type-check run fast — terminal-only output is fine.
pnpm format && pnpm lint && pnpm type-check

# Build check (fast — terminal-only).
pnpm build:check
```

> **STANDALONE ONLY — else SKIP.** Only run the block below if this is a standalone landing with
> no full-suite CI path (no `quality-gate.yml` workflow in this repo, or a manual land with no
> Phase 1d to follow). In the normal loop/tiered close, SKIP entirely: Phase 1d no longer fires any
> full-suite CI run (that proof now happens at publish start via `ac-prove`), and a blocking local
> full run here is the exact run §5 moves off the critical path.
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

**No full-suite CI fire here (retired, bd-pwt44).** ac-land used to kick off an async full
`test:all` on CI at close; that role has moved to PUBLISH START instead — `ac-publish` calls
`ac-prove ensure --fix-forward`, which runs the exhaustive gate SHA-pinned to the commit being
published, before release. ac-land's job here is done once `main` is pushed and up to date: no
CI dispatch, nothing to wait on. (A nightly idle-time full run via `ac-prove`/
`workflows/scheduled.md` is planned but DEFERRED/unwired — until it ships, the publish-start run
is the only full-suite checkpoint. Historical full-run receipts already on the evidence-log
ancestry chain remain valid regardless — this doesn't touch them.)

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

**NO AUTO-APPLY.** Unlike review skills (`ac-plan-clean`, `ac-hygiene`, `ac-review`, `ac-beadify`) which auto-apply consensus findings, bead-land never applies system-file upgrades itself. The difference is not caution vs confidence — it's downstream gates: a review finding rides a branch through tests/CI/review/merge (auto isn't final), while a skill/doctrine edit is live agent policy the next scheduled run simply obeys. Full three-way rule (AUTO / HUMAN / DISREGARD): **`_shared/disposition.md`**.

### Loop-retro friction disposition (D3) — runs FIRST, before Step 0

**ac-land Phase 3 is the SOLE tier router.** When Phase 0 read a non-empty loop-retro carrier,
classify **each** friction item into one of three tiers BEFORE the Step 0 `reflect` delegation
below, and execute T1/T2 here directly — `reflect` never re-decides a tier (it only writes the
T3 subset this router hands it). This is a **citing specialization** of `_shared/disposition.md`'s
core three-way rule (DISREGARD / AUTO / HUMAN — that page § "The three-way rule", §1/§2/§3): it
MAPS the tiers onto that fork and ADDS gates; it never redefines the fork.

| Tier | disposition.md route | What ac-land does here | Extra gate |
|---|---|---|---|
| **T1 bug/defect** | AUTO (rides a bead→CI gate; auto isn't final — §2) | `br create -t bug` immediately, no filter | none — **never rate-limited** (matches the Rule-0 bug lane); the T2 cap does NOT apply to bugs |
| **T2 high-impact improvement** | HUMAN (ungated policy change — §3) | `br create -t decision … -l human-gate,skill-improvement` via the existing mechanism below | **objective bar** + **one-per-land cap** |
| **T3 everything else** | AUTO additive-knowledge (§2), else DISREGARD (§1) | tag for the Step 0 reflect call → keyed observation (bd-jv33f.5), or drop if zero evidence | reversible memory observation only |

**T2 objective bar** — an improvement clears iff EITHER:
- **recurrence evidenced** — a matching observation/lesson already exists in the substrate
  (`qmd search` hit), OR a matching open `skill-improvement` bead exists (the Save-for-later
  dedupe check, disposition.md § Save-for-later); OR
- **material per-run cost** — a named this-run cost: a confirmed defect, or a friction item
  marked `cost: material` (optional Craig-set minutes floor).

**Per-land cap = 1.** If more than one candidate clears the bar, file the **highest-cost** one as
the single T2 improvement bead and **demote the rest to T3 observations** — their recurrence
still accrues for `dream`'s full-corpus ranking (nothing lost, just deferred). T1 bugs are exempt
from the cap.

**Ordering (preserves bd-jv33f.3's "sole reflect call" invariant):** (1) classify every carrier
item into T1/T2/T3 here; (2) create T1 bug beads + the ≤1 T2 decision bead here, now — no
`reflect` involvement; (3) hand only the pre-classified **T3 subset** to the single Step 0
`reflect` invocation below — do NOT add a second `reflect` call. Absent/empty carrier → no
tiering, Step 0 behaves exactly as a standalone land.

### Step 0: Capture durable lessons via `reflect`

Before proposing system-file upgrades, invoke the **`reflect`** skill to capture this
session's durable learnings (facts / decisions / recipes) into the typed, domain-routed,
git-tracked memory substrate. `reflect` handles `{type, domain}` routing + dedupe-over-append:
it writes low-risk lessons directly and **gates** any skill-improvement for approval (same
discipline as below). This closes the write loop — a lesson learned here becomes retrievable
from a different app/machine next week instead of being stranded in this transcript. Pass it
the retrospective findings from Phase 2 as the candidate lessons — **AND the pre-classified
T3-subset friction items from the Loop-retro friction disposition above** (the T1/T2 items were
already turned into beads there; do NOT re-capture them here), each carrying its
`stage`/`cost`/`lesson`/`class` (the `class` is a re-adjudicated HINT, not authoritative). Pass
the T3 items structurally, never re-derived from prose — this is what preserves the D4/D5
structural key, which reflect writes as keyed observations (bd-jv33f.5). This is the **sole**
`reflect` invocation; do not add a second one. (Absent/empty carrier → no tiering ran, reflect
gets only the Phase 2 findings, exactly as before.)

Then continue with the system-file upgrade proposals below.

### Disposition — classify, then route by mode

Classify each surviving proposal per `_shared/disposition.md`:

- **DISREGARD** — no concrete, named waste this session → drop silently (most proposals).
- **AUTO** — pure knowledge (fact / rule / decision / recipe) → already captured by
  `reflect` in Step 0; nothing further here.
- **HUMAN** — system-file change (skills, AGENTS.md, CLAUDE.md, CORE, hooks, workflows) →
  route by mode below.

**Interactive session** → present + `AskUserQuestion` (next two subsections).

**Headless (loop-driven land)** → NEVER `AskUserQuestion` and **NEVER post proposals to
Slack** — a Slack card is not a decision's storage; Slack stays notification-only. File each
HUMAN item as a decision bead per `_shared/disposition.md` § Save-for-later, **dedupe
first** (same target file + gist as an open `skill-improvement` bead → comment on it
instead), then skip ahead to Commit Compound Changes:

```bash
br create -t decision -p 3 "Proposal: <title> (<target file>)" -l human-gate,skill-improvement \
  -d "## Decision memo
**Target:** <file path>
**Evidence (this session):** <what happened + concrete cost>
**Proposed change:**
<exact diff or content>
**Recommendation:** <apply / apply-modified / drop>"
```

It surfaces on the `ac-human-session` docket; Craig decides there.

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

| Target                | What Gets Updated                      |
| --------------------- | -------------------------------------- |
| `AGENTS.md`           | Workflow improvements, new conventions |
| `CLAUDE.md`           | Orchestrator context updates           |
| `.claude/skills/*.md` | Command improvements based on friction |
| `MEMORY.md`           | New patterns, gotchas, workflow notes  |

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

Remove session artifacts (they've been consumed by retrospective). Run each block separately to avoid shell chaining that triggers safety hooks.

**Concurrency-safe, two-tier teardown.** Under the homogeneous-width doctrine two ac-loop runs can overlap in time, so a blind `rm -rf /tmp/<prefix>-*` would delete a concurrently-LIVE run's in-flight artifact dirs. A naive "just suffix every glob with `$RUN_ID`" fix is *unimplementable*, because only 7 of the producer prefixes actually embed the handed loop RUN_ID in their dir name (`bead-work`, `plan-init`, `plan-refine-internal`, `plan-clean`, `bead-refine`, `beadify`, `hygiene`); the others (`work-review` → bare timestamp, `batch-close` → commit-SHA anchor, `plan-refine` external → bare timestamp, and the fixed-name `/tmp/bead-work`) never do, so a RUN_ID glob would silently no-op on them. Two tiers, covering all 11 targets (10 glob prefixes + the bare literal `/tmp/bead-work`):

- **Tier 1 — universal content-aware age-gate (LOAD-BEARING).** A dir is stale ONLY if nothing inside it — nor the dir itself — was modified within `STALE_MIN` minutes: `find "$d" -mmin -$STALE_MIN -print -quit` returning non-empty means something is fresh ⇒ LIVE ⇒ keep; empty output ⇒ demonstrably abandoned ⇒ delete. Do NOT gate on the parent dir's own mtime: in-place rewrites of files like `progress.md` do NOT bump the containing dir's mtime, so a dir-mtime gate would reap a live long-running run. Each loop is keyed to its exact `/tmp/<prefix>-*/` glob (or the literal `/tmp/bead-work`) — nothing can reach unrelated `/tmp` content.
- **Tier 2 — RUN_ID exact-match (optimization; the 7 embedding prefixes ONLY).** Immediately delete THIS run's own dirs so it cleans up after itself without waiting out the age gate. The `[ -n "$RUN_ID" ]` guard on every line is MANDATORY: with `RUN_ID` unset or empty, the unguarded glob degenerates right back to the original unscoped bug. `work-review-*`, `batch-close-*`, external `plan-refine-*`, and bare `/tmp/bead-work` get NO tier-2 line — a RUN_ID glob never matches them, and a silent no-op masquerading as cleanup is worse than no line — they rely on the age gate alone.

`STALE_MIN=1440` (24h) rationale: the bound is the maximum plausible gap between WRITES inside a live run — NOT total run duration. A live run that writes any file at least once per 24h stays safe even if it runs for days; the pathological tail this file cites (a ~16.5h zombie waiter) still fits under 24h.

Every deletion — tier 1 and tier 2 — is logged (path echoed before the `rm`), so a wrongful sweep is diagnosable post-hoc. The external `plan-refine-*` glob also matches `plan-refine-internal-*` dirs — harmless idempotent double-handling; both prefixes stay listed for clarity.

**Residual risk (accepted, bounded by STALE_MIN):** a live FOREIGN run that writes NOTHING for >24h can still be reaped by the age gate. Accepted — no healthy run goes 24h between artifact writes. (Follow-up, not required here: thread the loop RUN_ID into `ac-review` / `ac-plan-refine-external` / `ac-batch-close` dir naming so every prefix gains a tier-2 line and the age gate becomes belt-and-suspenders.)

**Explicitly out of scope** (considered, deliberately left): Phase 0's read-only fallback `ls` (a guess for the retrospective, not a delete) and the `ps … grep` waiter-kill below (already identity-scoped with a confirm-before-kill step). Neither deletes artifact dirs; if hardening is wanted there, file a separate bead.

```bash
STALE_MIN=1440   # 24h — max plausible gap between WRITES in a live run (NOT a bound on total run duration)

# Tier 1 — universal content-aware age-gate. Non-empty find ⇒ something fresh inside ⇒ LIVE ⇒ keep.
# Bare /tmp/bead-work (literal name — no glob), treated identically to the globs:
for d in /tmp/bead-work/; do
  [ -d "$d" ] || continue
  [ -z "$(find "$d" -mmin -$STALE_MIN -print -quit 2>/dev/null)" ] && echo "teardown: removing stale $d" && rm -rf "$d"
done
for d in /tmp/bead-work-*/; do
  [ -d "$d" ] || continue
  [ -z "$(find "$d" -mmin -$STALE_MIN -print -quit 2>/dev/null)" ] && echo "teardown: removing stale $d" && rm -rf "$d"
done
for d in /tmp/plan-init-*/; do
  [ -d "$d" ] || continue
  [ -z "$(find "$d" -mmin -$STALE_MIN -print -quit 2>/dev/null)" ] && echo "teardown: removing stale $d" && rm -rf "$d"
done
for d in /tmp/batch-close-*/; do
  [ -d "$d" ] || continue
  [ -z "$(find "$d" -mmin -$STALE_MIN -print -quit 2>/dev/null)" ] && echo "teardown: removing stale $d" && rm -rf "$d"
done
for d in /tmp/plan-refine-internal-*/; do
  [ -d "$d" ] || continue
  [ -z "$(find "$d" -mmin -$STALE_MIN -print -quit 2>/dev/null)" ] && echo "teardown: removing stale $d" && rm -rf "$d"
done
for d in /tmp/plan-refine-*/; do
  [ -d "$d" ] || continue
  [ -z "$(find "$d" -mmin -$STALE_MIN -print -quit 2>/dev/null)" ] && echo "teardown: removing stale $d" && rm -rf "$d"
done
for d in /tmp/plan-clean-*/; do
  [ -d "$d" ] || continue
  [ -z "$(find "$d" -mmin -$STALE_MIN -print -quit 2>/dev/null)" ] && echo "teardown: removing stale $d" && rm -rf "$d"
done
for d in /tmp/bead-refine-*/; do
  [ -d "$d" ] || continue
  [ -z "$(find "$d" -mmin -$STALE_MIN -print -quit 2>/dev/null)" ] && echo "teardown: removing stale $d" && rm -rf "$d"
done
for d in /tmp/beadify-*/; do
  [ -d "$d" ] || continue
  [ -z "$(find "$d" -mmin -$STALE_MIN -print -quit 2>/dev/null)" ] && echo "teardown: removing stale $d" && rm -rf "$d"
done
for d in /tmp/hygiene-*/; do
  [ -d "$d" ] || continue
  [ -z "$(find "$d" -mmin -$STALE_MIN -print -quit 2>/dev/null)" ] && echo "teardown: removing stale $d" && rm -rf "$d"
done
for d in /tmp/work-review-*/; do
  [ -d "$d" ] || continue
  [ -z "$(find "$d" -mmin -$STALE_MIN -print -quit 2>/dev/null)" ] && echo "teardown: removing stale $d" && rm -rf "$d"
done

# Tier 2 — immediate self-cleanup by exact RUN_ID match. Guard MANDATORY on every line
# (unset RUN_ID would degenerate the glob to the original unscoped bug). 7 embedding prefixes only.
if [ -n "$RUN_ID" ]; then for d in /tmp/bead-work-*-"$RUN_ID"/; do [ -d "$d" ] && echo "teardown: removing own $d" && rm -rf "$d"; done; fi
if [ -n "$RUN_ID" ]; then for d in /tmp/plan-init-*-"$RUN_ID"/; do [ -d "$d" ] && echo "teardown: removing own $d" && rm -rf "$d"; done; fi
if [ -n "$RUN_ID" ]; then for d in /tmp/plan-refine-internal-*-"$RUN_ID"/; do [ -d "$d" ] && echo "teardown: removing own $d" && rm -rf "$d"; done; fi
if [ -n "$RUN_ID" ]; then for d in /tmp/plan-clean-*-"$RUN_ID"/; do [ -d "$d" ] && echo "teardown: removing own $d" && rm -rf "$d"; done; fi
if [ -n "$RUN_ID" ]; then for d in /tmp/bead-refine-*-"$RUN_ID"/; do [ -d "$d" ] && echo "teardown: removing own $d" && rm -rf "$d"; done; fi
if [ -n "$RUN_ID" ]; then for d in /tmp/beadify-*-"$RUN_ID"/; do [ -d "$d" ] && echo "teardown: removing own $d" && rm -rf "$d"; done; fi
if [ -n "$RUN_ID" ]; then for d in /tmp/hygiene-*-"$RUN_ID"/; do [ -d "$d" ] && echo "teardown: removing own $d" && rm -rf "$d"; done; fi
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
   - **Prevention** (the _Fail safe; leave no live debris_ law — `ac-pipeline-builder`
     through-threads): every waiter you create needs a hard cap (`for i in $(seq 1 N)` /
     `timeout`), never an unbounded `until`. A waiter that can't time out is a future zombie —
     and the rule binds when you _write_ the loop, not just when teardown sweeps for it here.
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
