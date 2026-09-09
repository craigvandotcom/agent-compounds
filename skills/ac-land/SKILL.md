---
name: ac-land
description: "The closing ritual — runs LAST, after merge. To land = leave it clean AND wiser: TEARDOWN (kill spawned tasks, sweep orphaned waiters, release+deregister Agent Mail, clear temp, clean tree) plus LEARN (retrospective + reflect + system compounding). Triggers: 'land the session', 'bead land', 'close out the bead work', 'wrap up session', loop exit. NOT for standalone lesson capture without bead-work context (that is reflect)."
---

**You are the conductor closing a bead-work session.** Land the plane, extract learnings, propose system upgrades, hand off cleanly.

Run this LAST — the final stage of the pipeline (`ac-pipeline/references/stage-table.md`); invoked at loop-exit (on `main`, wave branch gone) or manually once a wave has shipped. See Phase 0 below for how it resolves session context in that post-merge state. Closing order is cited from the stage table, never restated.

---

## Phase 0: Initialize

### Gather Session Context

Resolve `ARTIFACTS_DIR` deterministically per `ac-pipeline/references/run-id.md` — ac-land never claimed a batch itself, so it CANNOT mint a claim id; the orchestrator hands it the key, or the newest dir is a logged guess. Mechanics: `references/initialize.md`.

Substitute the resolved `$ARTIFACTS_DIR` into every sub-agent prompt below — never pass the variable name (sub-agents don't share the parent shell).

Read `$ARTIFACTS_DIR/progress.md` — the record of what was accomplished. If it doesn't exist, STOP: "No bead-work progress found. Run `/ac-implement` first."

**Also read the loop-retro friction carrier** — `/tmp/loop-retro-<RUN_ID>.md`, one `## <stage>` section per stage that hit friction. Hold the parsed items with `stage`/`cost`/`lesson`/`class` typing intact — they feed `reflect` directly in Phase 3 Step 0 (never through the Phase 2 prose analyst, which would destroy the structural key). Graceful degrade: carrier absent → skip and proceed as today.

Also gather: `br list --json`, `git log --oneline -20`, `git status`, `git diff --stat`.

### Declare the Run Ledger

ac-land runs LAST and can compact mid-flight — teardown that never runs leaves zombies. Declare the run ledger per `ac-pipeline/references/run-ledger.md`, with each of Phase 1's three sub-steps as its own task so a resume never skips teardown. TaskCreate unavailable → track the same sections inline in `$ARTIFACTS_DIR/progress.md`. Mechanics: `references/initialize.md`.

---

## Phase 1: Land the Plane

**NON-NEGOTIABLE. No work stranded locally.** Mechanics for all three sub-steps: `references/land-phase1.md`.

### 1a. File Remaining Work

Close or comment started-but-unclosed beads; file loose ends per `beads-standards/reference/bead-conventions.md` (types, unrefined-at-creation, anchor-dedupe, body template), origin `ac-land,followup,unrefined`.

### 1b. Quality Gates

Format / lint / type-check always run; never a blocking local full-suite run here (two named exceptions: an already-green full pass for HEAD → note-and-skip; a standalone land with no CI path → run `test:all` once). **`in_progress` ≠ stuck — COMPUTE elapsed before flagging, never eyeball** (the just-merged commit's own CI is frequently still running; flag only when computed elapsed > ~2× typical, with the two timestamps + arithmetic pasted).

### 1c. Git Operations

Commit specific files, push, verify up to date. **No full-suite CI fire here.** The repo-wide format sweep is a separate commit of ONLY sweep-touched files — never `git add -A` (H7d, `ac-pipeline/references/commit-discipline.md`).

Mark ledger tasks 2–4 completed as each sub-step lands.

---

## Phase 2: Learn (Retrospective)

**Goal:** with complete information, identify what worked, what didn't, what friction occurred.

Spawn the retrospective analyst per `ac-pipeline/references/delegation-contract.md` (verbatim preamble, bounded waits) using the prompt in **`references/retrospective-prompt.md`**. Loop-exit multi-wave: substitute ALL of `$ARTIFACTS_DIRS` so the retrospective spans the whole loop session.

Conductor reviews `<ARTIFACTS_DIR>/retrospective.md` against the minimum bar: did this issue cause real waste THIS session? Drop "interesting but theoretical." Mechanics: `references/learn.md`.

---

## Phase 3: Compound (System Upgrades)

**Goal:** turn learnings into system improvements. User decides what ships.

**NO AUTO-APPLY.** bead-land never applies system-file upgrades itself. Full three-way rule (AUTO / HUMAN / DISREGARD): `ac-pipeline/references/disposition.md`.

### Loop-retro friction disposition (D3) — runs FIRST, before Step 0

**ac-land Phase 3 is the SOLE tier router.** Classify each carrier item into T1/T2/T3 BEFORE Step 0's `reflect` delegation — `reflect` never re-decides a tier. This is a citing specialization of disposition.md's three-way rule: it MAPS the tiers onto that fork and ADDS gates; it never redefines it. Mechanics + the full tier table: `references/compound.md`.

| Tier | disposition.md route | What ac-land does here | Extra gate |
|---|---|---|---|
| **T1 bug/defect** | AUTO | `br create -t bug` immediately, dedupe-first | none — never rate-limited |
| **T2 high-impact improvement** | HUMAN | `br create -t decision` via the existing mechanism | objective bar + **one-per-land cap** |
| **T3 everything else** | AUTO additive-knowledge, else DISREGARD | tag for the Step 0 reflect call → keyed observation | reversible memory observation only |

**Deletion mandate — supersession ranks equally with addition** (promotion-ladder.md: removal routes through the skill's MAINTENANCE.md holding-pen, never an outright delete; verbatim duplicates may hard-delete).

**T2 objective bar** — EITHER recurrence evidenced (`qmd search` hit or an open matching `skill-improvement` bead) OR material per-run cost (a confirmed defect or `cost: material`). **Per-land cap = 1** — over the bar, file the highest-cost one; demote the rest to T3.

**Ordering (the sole-reflect-call rule):** classify every item; create T1 + the ≤1 T2 bead here; loop-driven → skip Step 0, return the pre-classified T3 subset in your summary; standalone → hand the T3 subset to the single Step 0 `reflect` invocation. **One reflect per run, never two.**

### Step 0: Capture durable lessons via `reflect`

Invoke **`reflect`** — the sole call, never a second — to capture this session's durable learnings into the typed, domain-routed, git-tracked substrate. Pass it the Phase 2 findings AND the pre-classified T3-subset items (each with `stage`/`cost`/`lesson`/`class`), structurally, never re-derived from prose. reflect gates any skill-improvement for approval.

### Disposition — classify, then route by mode

Classify each surviving proposal per disposition.md: DISREGARD (no named waste → drop), AUTO (pure knowledge → already captured by reflect), HUMAN (system-file change → route by mode). **Interactive** → present + `AskUserQuestion`. **Headless** → never ask, never post to Slack (notification-only); file each HUMAN item as a decision bead, dedupe first, then skip to Commit Compound Changes. Mechanics + commit-prefix contract (`skill-hotfix:` for the approved-upgrade case, `chore:` for routine-only): `references/compound.md`.

---

## Phase 4: Hand Off

### Session Summary

Output the summary (beads completed/remaining, commits, gates, learnings, open issues) and, interactive only, `AskUserQuestion` for next step. Headless → just emit. Mechanics + summary template: `references/handoff.md`.

### Preserve the raw friction carrier (before teardown discards /tmp)

Copy `/tmp/loop-retro-<RUN_ID>.md` into `.claude/reviews/loop-retro/` and commit it FIRST — `stage`/`cost`/`lesson`/`class` typing intact.

### Cleanup Temp Files + Teardown (operational — part of landing)

**Landing means leaving NO live debris** — run regardless of how the session reached land (clean finish, iteration cap, regression stop, human "stop", or error). Concurrency-safe two-tier teardown (content-aware age gate + RUN_ID exact-match), Agent Mail release + roster sweep, pre-commit guard condition, tracked-hook integrity, working tree resolution. Mechanics — full detail: `references/teardown.md`.

### Final Verification

`git status` clean · `git log --oneline -1` pushed · `br ready --json` what's left. Mark ledger task 8 completed — the run is landed.