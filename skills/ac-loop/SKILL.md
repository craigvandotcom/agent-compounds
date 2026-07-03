---
name: ac-loop
description: Autonomous bead-shipping loop — runs scheduled, drives orphan fixes + plan waves to merge without human checkpoints, pauses on genuine decisions via Slack buttons, nudges human about remaining blocks until acted on. Multi-item queue clearance, no per-stage human gates; for a single named goal with checkpoints use ac-pipeline. Stop conditions: completeness, critical regression, iteration cap, human override. Triggers: "/ac-loop", scheduled PAI job, "run the loop", "ship everything available", "autonomous mode".
---

# ac-loop — Autonomous Shipping Loop

**You are the loop conductor.** You drive refined work to merge without waiting for human sign-off at stage gates — that's the job. You delegate to the same skills `ac-pipeline` uses, but you pre-answer their operational questions (bead count, session mode, next-step choices) so they run headlessly. You pause only for genuine forks — decisions only Craig can make — and only when those are simple enough for Slack buttons.

When invoked interactively (`/ac-loop`), `AskUserQuestion` renders in the terminal. When invoked by the scheduler (headless), `AskUserQuestion` posts to Slack as interactive buttons — the session suspends and resumes when Craig clicks. Either way, the behaviour is identical; the transport differs.

> **Scope contract:** You work the pipeline, not the backlog. You never touch raw backlog items or unrefined *plans*. But unrefined **beads** that are already *in* the pipeline — beadified epics (parent+children) or beads traceable to a plan (`_plans/` or `_plans/_done/`) — you DO refine-and-finish; only a truly raw lone capture stays gated. Craig controls what *enters* the pipeline (via beadify/plan sign-off); you drive everything already in it to merge, furthest-advanced first. Human-gated beads (`human-gate` label) are surfaced, not auto-closed.

---

## I/O Contract

| | |
|---|---|
| **Input** | Refined plans in `_plans/`, beads in `br` (any state from unrefined onward), current wave branch (if any) |
| **Output** | Merged PRs, closed beads, Slack notifications per milestone |
| **Not in scope** | Backlog capture, plan init (`ac-plan-init`), unrefined plans, human decisions |

---

## Execution Order

```
EACH ITERATION:
  1. Orphan beads  (refined, no plan wave — the "maintenance wave"; ships FIRST)
      └─ ac-implement → VERIFY-GATE → ac-review → ac-merge → Slack notify
  2. Next plan's wave  (highest-priority loop-ready plan with refined ready beads)
      ├─ [if plan has no beads yet] ac-beadify → ac-bead-refine
      │      (prep — only now, AFTER the maintenance wave has shipped)
      └─ ensure wave branch (loop owns this, not ac-implement) →
         ac-implement → VERIFY-GATE → ac-review → ac-merge → Slack notify

  VERIFY-GATE = consult _shared/verification-gate.md → run only the selected
                passes (ui-polish / qa-browser / qa-device) at the selected depth.
  3. Loop — check for more orphans or plans
  4. Nothing left → Phase ARIA (unlock human blocks, then stop)

STOP CONDITIONS checked before each iteration (see below).

ON EXIT — ALWAYS, every stop path (C1/C2/C3/C4, Phase ARIA, or an error):
  run ac-land. Land is the loop's single closing ritual — it TEARS DOWN (kills
  spawned tasks, sweeps orphaned waiters, releases+deregisters Agent Mail, clears
  temp, asserts a clean tree) AND LEARNS (reflect + system upgrades). ac-land runs
  LAST, after the final wave's merge — not per-wave (it was wrongly in the per-wave
  path before). The loop is NOT done until it has landed: a run that ships waves but
  never lands leaves zombies + strands every lesson in the transcript.
```

> The run's progress through these phases is tracked in the Phase 0 **run ledger**
> (`TaskCreate`) — update it at each phase boundary; it is the anti-early-exit anchor
> and the resume point after compaction.

---

## Phase 0: Orient

### Register Loop Identity

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

Register a unique identity for this loop run — gives the conductor a readable name in the agent registry and pre-commit attribution:

```
mcp__mcp-agent-mail__macro_start_session(
  project_key: CANONICAL_PROJECT_KEY,   // the app's canonical Agent Mail key from its session-start.md (pattern: "neometa/<app-dir>", e.g. "neometa/body-compass-app") — NEVER an absolute path: abs paths fork a per-machine mailbox (split-brain)
  program: "claude-code",
  model: "claude-opus-4-8"
)
```

Capture the returned `name` field:

```bash
export WORKTREES_ENABLED=1
export AGENT_NAME=<returned-name>   # e.g. "BlueLake" — unique per loop run
export RUN_ID="$(date +%Y%m%d-%H%M%S)-$$"   # scopes THIS run's /tmp scratch dirs; passed to every spawned stage (_shared/run-id.md)
```

Sub-skills invoked by the loop (ac-implement, ac-land, etc.) start their own fresh sessions and self-register independently — the loop's `AGENT_NAME` is not inherited.

### Read Current Board State

Read the current state of the board. This is the map you navigate by.

```bash

# All refined, ready, non-human-gated beads
br ready --json | jq '[.[] | select(
  (.labels | index("unrefined") | not) and
  (.labels | index("human-gate") | not)
)]'

# All human-gated ready beads (for Phase ARIA)
br ready --json | jq '[.[] | select(.labels | index("human-gate"))]'

# Current wave branch (if any)
git branch --list 'wave/*' --format='%(refname:short)' | head -1
git branch -r --list 'origin/wave/*' --format='%(refname:lstrip=3)' | head -1

# Plans with refined beads
ls _plans/ 2>/dev/null
```

Also check for loop-ready plans and unrefined beads:

```bash
# Plans marked loop-ready (Craig's explicit gate — only these enter the loop)
grep -l "status: loop-ready" _plans/*.md 2>/dev/null

# Unrefined beads from loop-ready plans (need ac-bead-refine before implement)
br ready --json | jq '[.[] | select(
  (.labels | index("unrefined")) and
  (.labels | map(test("^wave-[0-9]+$")) | any)
)]'

# Unrefined beads with NO wave-NNN marker label — split by pipeline depth (see classification below):
#   (a) part of a beadified EPIC or a plan-traceable group → AUTO-REFINE (signed-off work)
#   (b) truly RAW lone captures (no parent, no epic group, no source plan) → ARIA gate
br ready --json | jq '[.[] | select(
  (.labels | index("unrefined")) and
  (.labels | map(test("^wave-[0-9]+$")) | any | not)
)]'
# Then classify each: does it have a parent-child dep (epic child), children (epic parent),
# or ≥1 label-sibling under a shared non-wave epic label (e.g. "tailwind-v4")? → (a) auto-refine.
# A lone unrefined bead with no parent, no children, no epic-label siblings → (b) raw capture, gate.
# Cross-check (a) against _plans/ AND _plans/_done/ — an archived source plan IS the sign-off.
```

> **"Unrefined orphan" ≠ "raw capture" — classify by pipeline depth, not just the missing
> `wave-NNN` marker label.** A bead that has been *beadified into an epic* (parent + children, or a shared
> epic label) is signed-off **by construction** — Craig deliberately beadified it — and is
> *further down the pipeline* than an un-beadified loop-ready plan. **Auto-refine-and-finish it.**
> Its source plan is often already archived in `_plans/_done/` (that's the sign-off), so the
> "no plan-level sign-off" gate must check `_done/` too, not just live plans. Only a **truly raw
> lone capture** (single bead, no parent, no epic-label siblings, no traceable plan — the
> `ac-bead-capture` quick-idea case) stays gated. Pushing the *furthest-advanced* work to merge
> first means refinement state counts: a beadified epic outranks an un-beadified plan.

> **The loop-ready gate:** Only plans with `status: loop-ready` in their frontmatter are touched by the loop. Plans marked `refined`, `draft`, or anything else are invisible to the loop — Craig has not yet signed them off for autonomous execution. This is intentional: Craig sets `loop-ready` at the end of `ac-plan-refine` (optionally after running `ac-plan-clean`), which is the explicit hand-off signal.

Summarise: N orphan beads, M plan beads across K plans, wave open/closed, H human-gated waiting, L loop-ready plans with no beads yet, U unrefined **signed-off** beads needing refine (plan-beads + beadified epics + plan-traceable groups → auto-refine), O **truly-raw** unrefined captures (lone, no epic/plan → ARIA gate only).

**Work priority order** — ship ready maintenance first, then drive the *furthest-advanced* refinement work before pulling new raw work in:
1. Orphan refined beads → Phase 1 (the maintenance wave — ready-to-ship fixes go first: cheapest, safest, often time-sensitive)
2. Unrefined beads that are **signed-off pipeline work** — from a loop-ready plan (`wave-NNN` marker label), OR part of a **beadified epic** (parent+children / shared epic label), OR traceable to a plan in `_plans/` *or* `_plans/_done/` → run `ac-bead-refine` then drive to merge (delegation: "ac-loop autonomous run, skip next-step question"). **Do NOT stop to ask** — these are already in the pipeline; refine-and-finish them. A beadified epic outranks #3 (it's further along).
3. Loop-ready plans with no beads → run `ac-beadify` then `ac-bead-refine` (prep) (delegation: "ac-loop autonomous run, always proceed to ac-bead-refine, no confirmation needed")
4. Plan wave refined beads → Phase 2

> **Why orphans before prep:** `ac-beadify` + `ac-bead-refine` is the loop's most expensive prep step, and a feature wave is a long haul. Ship the cheap, ready, often time-sensitive orphan fixes FIRST so a session that ends early (compaction, human override, iteration cap) has still delivered the ready work. Maintenance wave first; prep for the next feature wave second.

### Create the Run Ledger

Once you've oriented and know what's queued, lay down a **run-level task list** with `TaskCreate` — the loop's own progress, made legible and resumable. This is the anti-early-exit anchor and the "where is the loop right now" view a headless operator otherwise lacks.

```
TaskCreate — one task per run phase; add a Plan-wave task per queued loop-ready wave (up to the iteration cap):
  1. Orient + read board                  → in_progress  (this pass)
  2. Orphan / maintenance wave → merge     → pending      (omit if no orphans)
  3. Plan wave: <plan-name> → merge        → pending      (one per queued wave, cap 3)
  4. Phase ARIA + ac-land                  → pending
```

`TaskUpdate` each task to `in_progress` when its phase starts and `completed` at its merge/exit; mark task 1 `completed` when this orient pass finishes. If the board is empty, the ledger is just task 1 + task 4.

> **The ledger tracks the RUN, never the work.** It holds *phases and iterations* — orient, which wave, ARIA/land — and nothing else. Work items stay **beads**: the bead board is the single source of truth for *what* ships (`ac-pipeline-builder` axiom 1, *the bead is the atom*). The ledger is a navigation aid over the run, not a second copy of the queue — never put bead IDs or per-bead state in it, or the two will drift.

> **On resume (compaction / restart):** read the ledger first — it's your resume *anchor* (which phase you were in). Then reconcile against live board state, which remains ground truth: a wave the ledger calls `in_progress` may have merged in the moments before compaction. Trust the **board** for work state; trust the **ledger** for run position.

If **no refined beads, no unrefined beads from loop-ready plans, no loop-ready plans to beadify, and no human-gated beads** → go straight to Phase ARIA.

---

## Phase 1: Orphan Beads

**Orphans = refined, non-human-gate beads with no wave affinity.** These are typically bugs and quick fixes surfaced by `ac-triage` or `ac-bead-capture`. Ship them first — they often unblock other work or are time-sensitive production fixes.

```bash
# Orphan beads: refined, no wave-NNN marker label, no human-gate
br ready --json | jq '[.[] | select(
  (.labels | index("unrefined") | not) and
  (.labels | index("human-gate") | not) and
  (.labels | map(test("^wave-[0-9]+$")) | any | not)
)]'
```

> If no wave is open, all refined ready beads are orphans.

If orphans exist:
1. **Pre-allocate wave branch (loop's job, not ac-implement's)** — check for an existing open wave first. If none, create `wave/NNN`:
   ```bash
   LOCAL_WAVE=$(git branch --list 'wave/*' --format='%(refname:short)' | head -1)
   REMOTE_WAVE=$(git branch -r --list 'origin/wave/*' --format='%(refname:lstrip=3)' | head -1)
   WAVE=${LOCAL_WAVE:-$REMOTE_WAVE}
   if [ -z "$WAVE" ]; then
     # Highest-EVER wave number: live refs ∪ merge messages on main ∪ tags — not refs alone.
     # `git fetch --prune` drops merged waves' refs, so a refs-only scan reuses a shipped
     # number (hit 2026-06-26, produced a triple wave/001 collision).
     HIGHEST=$( { git for-each-ref --format='%(refname:strip=3)' refs/remotes/origin/wave/;
                  git log origin/main --oneline | grep -oE 'wave/[0-9]{3}' | cut -d/ -f2;
                  git tag -l 'wave/*' | cut -d/ -f2; } \
               | grep -oE '^[0-9]{3}$' | sort -n | tail -1)
     WAVE="wave/$(printf "%03d" $(( ${HIGHEST:-000} + 1 )))"
     # Guard: never reuse a number that ever existed in history.
     git log origin/main --oneline | grep -q "$WAVE" && { echo "collision: $WAVE already in history"; exit 1; }
     git checkout -b "$WAVE" main && git push -u origin "$WAVE"
   else
     git checkout "$WAVE" && git pull --rebase
   fi
   ```
2. **Invoke `ac-implement`** — use this delegation prompt to suppress overhead questions:
   > "Run ac-implement targeting all N orphan beads (IDs: `<list>`). TARGET_BEADS=N. `RUN_ID=<RUN_ID>` (scopes the bead-work dir — `_shared/run-id.md`). Skip the bead-count setup question — answer is pre-supplied. Wave branch is already `<WAVE>`. For baseline test failures: file a P1 bead and proceed (do not ask). Report when complete — the loop advances to verify → review → merge."
3. **Verify (gated)** — consult **`_shared/verification-gate.md`**: classify the wave diff, run **only** the selected passes (`ac-ui-polish` / `ac-qa-browser` / `ac-qa-device`) at the selected depth. Do NOT run all three unconditionally. Emit the gate's decision line into the Slack notify (which ran, which skipped + why). Beads any pass files feed the retrospective; an open `qa-blocker` bead stops at merge.
4. **Invoke `ac-review`** — use this delegation prompt:
   > "Run ac-review on branch `<WAVE>`. This is an autonomous loop run. For DESIGN_DECISION or SCOPE_ESCALATION items: apply the Exhaust Rule (create decision beads, do not AskUserQuestion). Do not ask 'what's next?' at Phase 8 — exit after printing the summary with VERDICT: line."
5. **Read `VERDICT:` from ac-review output** — `APPROVED` → proceed to merge. `NEEDS_DECISION` with open blockers → hard stop (C2).
6. **Invoke `ac-merge`** — use this delegation prompt:
   > "Run ac-merge on branch `<WAVE>`. CI config for this project: `<cached-answer>`. Version bump: accept recommended default without asking. For uncertain PR feedback items: create decision beads (Exhaust Rule). Do not ask 'what's next?' after merge."
7. **Slack notify** (see Milestone Notifications).
8. **Loop** — return to Phase 0 check after merge. **`ac-land` does NOT run per-wave** — it runs ONCE at loop exit (see ON EXIT / Exit-Land); per-wave landing was the leftover the "land runs LAST" reconciliation retired.

If `ac-review` surfaces a **Critical regression** → hard stop (see Stop Conditions §C2).

---

## Phase 2: Plan Wave

After orphans are clear (or if no orphans), advance the highest-priority plan with refined ready beads.

### Pick the next plan

```bash
# Loop-ready plans (Craig's explicit gate)
LOOP_READY_PLANS=$(grep -l "status: loop-ready" _plans/*.md 2>/dev/null)

# Of those, find which have refined, non-human-gate ready beads
br ready --json | jq '[.[] | select(
  (.labels | index("unrefined") | not) and
  (.labels | index("human-gate") | not) and
  (.labels | map(test("^wave-[0-9]+$")) | any)
)] | group_by(.labels[] | select(test("^wave-[0-9]+$"))) | sort_by(.[0].priority) | .[0]'
```

Cross-reference with `$LOOP_READY_PLANS` — only advance a plan wave if its parent plan file has `status: loop-ready`. If no loop-ready plan waves exist, skip to Phase ARIA.

### Execute the wave

1. **Pre-allocate wave branch (loop's job)** — same logic as Phase 1 step 1. If a wave is already open from the orphan pass, join it. Single-branch rule: never create a second wave while one is open.
2. **Invoke `ac-implement`** with delegation prompt:
   > "Run ac-implement targeting all refined ready beads for plan `<plan-name>` (wave label: `<wave-label>`). TARGET_BEADS=N. `RUN_ID=<RUN_ID>` (`_shared/run-id.md`). Skip bead-count setup question. Wave branch is `<WAVE>`. Baseline test failures: file P1 bead and proceed. Report when complete — the loop advances to verify → review → merge."
3. **Verify (gated)** — consult **`_shared/verification-gate.md`**: classify the wave diff, run **only** the selected passes at the selected depth (never all three unconditionally). Emit the decision line into the Slack notify. Open `qa-blocker` bead → stops at merge.
4. **Invoke `ac-review`** with delegation prompt:
   > "Run ac-review on branch `<WAVE>` (ac-loop autonomous run). DESIGN_DECISION/SCOPE_ESCALATION: Exhaust Rule — create decision beads, do not AskUserQuestion. Exit after Phase 8 summary with VERDICT: line."
5. **Read `VERDICT:`** — APPROVED → merge. NEEDS_DECISION with blockers → C2 stop.
6. **Invoke `ac-merge`** with delegation prompt:
   > "Run ac-merge on `<WAVE>` (ac-loop autonomous run). CI config: `<cached>`. Version bump: accept recommended default. Uncertain feedback: Exhaust Rule — decision beads. No next-step question after merge."
7. **Slack notify** — wave shipped.
8. **Check stop conditions** — then loop back to Phase 0. (No per-wave `ac-land`; it lands once at exit.)

If `ac-review` surfaces a **Critical regression** → hard stop (see Stop Conditions §C2).

---

## Phase ARIA: Human Unlock

> **ARIA = Autonomy-Regulated Intelligent Assistance.** Fire only when there is no more eligible work to implement — the loop is idle because of human gates, not because the agent gave up.

This phase persists. The loop does not exit after a nudge — it re-checks at interval and nudges again until Craig acts. Bottlenecks need pressure, not a single polite mention.

### Decision Matrix

| Signal | Action |
|--------|--------|
| `human-gate` bead with ≤3 options, question answerable in ≤10 words | `AskUserQuestion` (Slack buttons) → session pauses → resumes on click |
| `human-gate` bead with complex/open-ended answer | Advisory Slack nudge (card) — do NOT pause |
| Plan exists but all beads are `unrefined` | Advisory nudge: "Plan X has N beads awaiting refinement — run `/ac-bead-refine`" |
| **Truly raw** unrefined bead (lone — no parent, no epic-label siblings, no plan in `_plans/` or `_plans/_done/`) | Advisory nudge: "N captured idea(s) awaiting refinement — run `/ac-bead-refine` or attach to a plan." The loop will NOT auto-refine a raw capture (no sign-off); surface, don't touch. **NOTE:** a beadified epic or plan-traceable unrefined bead is NOT this — it's signed-off pipeline work → auto-refine-and-finish per Work priority #2, don't nudge. |
| Refined plans exist but no beads yet | Advisory nudge: "Plan X is ready for `/ac-beadify`" |
| Backlog items (raw ideas, not plans) | Advisory nudge ONLY — Craig decides what enters the pipeline |
| Nothing at all (no backlog, no plans, no beads) | Session-end notify: "Pipeline clear — nothing waiting" |

### Advisory nudge format

Post via `slack-send --channel sofi --card` (or the app's channel):

```
🔒 *Pipeline blocked — your input needed*

<N> items waiting for you:
• <bead title> — <one-line decision needed>
• Plan "<name>" — N unrefined beads waiting for /ac-bead-refine
...

Run the relevant skill or click a bead to unblock.
```

### AskUserQuestion (simple forks only)

For `human-gate` beads with clear options:

```
AskUserQuestion(
  questions: [{
    question: "<the decision question from the bead spec>",
    header: "<bead title, ≤12 chars>",
    multiSelect: false,
    options: [
      { label: "<option A>", description: "<bead's option A description>" },
      { label: "<option B>", description: "<bead's option B description>" },
      ...
    ]
  }]
)
```

On answer: record the decision in the bead (`br comments add <id> "DECISION (Craig): <choice> — <answer text>"`), execute the consequence (remove `human-gate` label, unblock dependents), then continue the loop.

### Re-nudge cadence

After a nudge, re-check on the next scheduled loop fire. If the block persists: send another nudge (do not suppress). The nudge IS the signal — Craig needs to feel the bottleneck until he clears it.

---

## Efficiency & Validators (cost discipline)

The loop is expensive when validators run too often, at the wrong boundary, or while
fighting the machine. Hold these:

**Pushing**
- Push loop commits with `git push --no-verify`. The husky pre-push `pnpm build` is
  redundant with CI and, in a backgrounded/piped shell, **silently swallows the push** —
  the commit lands locally, origin never moves, and `… | tail` masks the real exit code.
  After EVERY push assert `git rev-parse origin/<branch>` == local HEAD before moving on.
  (See memory `prepush-build-hook-swallows-background-pushes`.)

**Validators — each fires ONCE, at its correct boundary**
- Per-bead correctness → `pnpm test` (the affected runner). NEVER `test:all` per bead.
- `test:all` runs **exactly once per wave**: after the LAST code change, before handing to
  `ac-merge`/CI. Not during implementation (affected runner covers that), not to "prove" a flake.
- "Is this a flake?" is a CHEAP question → re-run the ONE failing file in isolation. Never
  answer it with a full-suite re-run — that's the heaviest tool on the cheapest question.
- The wave-level `ac-review` is scoped to **cross-bead integration** (per-bead conductor
  reviews already cover each bead's internals). If a dedicated pass already cleared a
  dimension on a bead (e.g. a `security-reviewer` on a privacy keystone), the wave review
  **skips that dimension** instead of re-deriving the same verdict.

**Pacing & contention**
- Match the wakeup to the wait. A known ~5-min job → poll ~270s (stay in the prompt-cache
  window); reserve 1200–1800s for genuinely idle ticks. Don't sleep 20 min on a 5-min job.
- **The CI runner IS this Mac** (self-hosted). Do NOT run local `test:all`/builds while a
  CI job is live on the runner — you starve your own runner and triple every duration
  (a ~21-min suite became ~50 min at load-68). See `bca-ci-and-ios-build-ops`.

**Parallelism (judgment, not a blanket rule)**
- When ≥2 ready beads have NO dependency between them, spawn their engineers concurrently.
  When a chain exists (A blocks B), stay sequential. Pull heavy sub-steps (e2e / prod-build)
  OUT of the implementer into their own gated step so they're visible and pace-able — don't
  let one bead's engineer run 100+ min hidden inside a sub-agent.

---

## Stop Conditions

Check before each iteration begins.

| # | Condition | Action |
|---|-----------|--------|
| **C1** | No eligible work and no human-gate unblocks remaining | End session cleanly. Notify Slack: "Pipeline clear." |
| **C2** | `ac-review` returns a Critical blocking finding (regression) | Hard stop. Do NOT merge. Notify Slack with the finding. File a P0 bead. Wait for human. |
| **C3** | Iteration cap reached (default: 3 plan waves per session) | Stop after current merge. Notify Slack: "Iteration cap reached." |
| **C4** | Human override (Slack message "stop" / "pause the loop") | Honour immediately after current bead. Notify confirmation. |

C2 is the only **hard** stop — it never merges a regression. C1/C3/C4 are clean stops (current work finishes, then exit).

**Every stop path ends in `ac-land`** (the teardown + learn close) — including C2's hard stop. A regression stop still tears down spawned processes, releases Agent Mail, and reflects the lesson before halting. "Stopped" without landing = not stopped, just abandoned.

### Exit-Land — the loop's single closing invocation

ac-land runs **once here**, not per-wave. The loop shipped one or more waves, each writing
`/tmp/bead-work-<wave-slug>-<RUN_ID>`; land closes the whole **session**. Pass `RUN_ID` so land
scopes to *this run's* dirs (never a stale or foreign one) and learns from **every** wave shipped:

> "Run ac-land to close this loop session (autonomous run). `RUN_ID=<RUN_ID>`. Land the WHOLE
> session, not one wave: the retrospective reads every `/tmp/bead-work-*-<RUN_ID>/progress.md`
> (all waves this run shipped — `RUN_ID` scopes them safely), and teardown sweeps all of them.
> You are post-merge on `main`. System-upgrade proposals: Slack card for Craig, do NOT block.
> This is the loop's final step — exit after landing." (`_shared/run-id.md`)

> **No token-budget stop.** A "running low on tokens" condition was removed deliberately:
> the loop cannot reliably measure its own remaining budget, and with no explicit target
> there is nothing to bound against — so it only ever became a vague excuse to quit early.
> The loop is bounded by the **measurable** conditions instead: it stops when the pipeline
> is empty (C1) or the iteration cap is hit (C3). Context-window pressure is handled by
> compaction (the loop survives it — see Compaction Recovery), not by guessing at a token
> count. If a run needs a hard ceiling, give it one explicitly (an iteration cap or a
> stated goal) — don't infer it from an unreadable budget.

---

## Milestone Notifications

Always notify on Slack at meaningful milestones. Use `slack-send --channel sofi --card` (replace `sofi` with the app's configured channel).

| Event | Message |
|-------|---------|
| Orphan beads shipped | "✅ Shipped <N> orphan fix(es) — <bead titles> — merged to main." |
| Plan wave shipped | "🚀 Wave for *<plan name>* merged — <N> beads shipped. Branch: `wave/NNN`." |
| Critical regression found | "🛑 Loop stopped — ac-review found a critical regression in `<file>`. Needs your review before merge." |
| Iteration cap | "⏹️ Iteration cap reached (<N> waves this session). Remaining work queued for next run." |
| Pipeline clear | "✓ Pipeline clear — no eligible work remaining. <H> human-gate items waiting if you want to review." |
| ARIA nudge | See Phase ARIA advisory format above. |

---

## Scheduling

ac-loop is designed to run as a scheduled PAI job (headless). Configure in `infrastructure/jobs/<app>.json`:

```json
{
  "name": "ac-loop-<app>",
  "prompt": "Load the ac-loop skill and run the autonomous shipping loop for <app>. Working directory: <app-path>.",
  "schedule": "0 */4 * * *",
  "enabled_on": ["<hostname>"],
  "pauseable": true,
  "channel": "<slack-channel-id>"
}
```

`pauseable: true` is required — without it, `AskUserQuestion` events are dropped and simple decisions fall through to advisory nudges. The channel ID is used by the scheduler to post the AskUserQuestion card and thread updates.

Run `ac-triage` as a **separate** scheduled job before `ac-loop` (e.g., 30 min earlier). Triage feeds beads into the board; the loop ships them. Keep them decoupled so triage failures don't block shipping.

---

## What Craig Controls (Never Automated)

| Item | Why |
|------|-----|
| Moving backlog → plan | Product/priority decision |
| Unrefined plans | Scope and intent need human sign-off before beadify |
| Closing `human-gate` decision beads | Domain/taste/risk — agent prepares, human decides |
| ac-bead-refine runs | Agent proposes; Craig approves spec before implementation |

The loop never touches these. It nudges Craig when they're bottlenecks.

---

## Remember

- **Orphans first** — fixes and production bugs ship before new feature waves
- **Single-branch rule** — join the open wave, never create a second
- **Delegate, don't re-implement** — call `ac-implement`, `ac-land`, `ac-review`, `ac-merge`
- **Keep the run ledger current** — `TaskUpdate` at every phase/wave boundary; it's the anti-early-exit anchor and the compaction resume point. Beads stay the work atom; the ledger tracks only the run
- **ARIA gating** — `AskUserQuestion` only for simple, bounded forks. Everything else is advisory
- **Persistent nudge** — re-nudge every session until Craig acts. Silence enables bottlenecks
- **C2 is the only hard stop** — critical regression never merges
- **Always Slack-notify** — shipped waves, blocked stops, clear pipeline. Headless means Craig has no other visibility
- **Never close `human-gate` beads** — record the decision, execute consequences, then close only after Craig's recorded answer

---

_Loop runs: Phase 0 orient → Phase 1 orphans → Phase 2 plan wave → repeat → Phase ARIA when empty. Each merge is a milestone; each nudge is a bottleneck signal. The loop is what keeps the flywheel turning without Craig in the seat._
