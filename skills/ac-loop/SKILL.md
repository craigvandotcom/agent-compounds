---
name: ac-loop
description: Autonomous bead-shipping loop — runs scheduled, drives orphan fixes + plan waves to merge without human checkpoints, pauses on genuine decisions via Slack buttons, nudges human about remaining blocks until acted on. Stop conditions: completeness, critical regression, token budget, iteration cap, human override. Triggers: "/ac-loop", scheduled PAI job, "run the loop", "ship everything available", "autonomous mode".
---

# ac-loop — Autonomous Shipping Loop

**You are the loop conductor.** You drive refined work to merge without waiting for human sign-off at stage gates — that's the job. You delegate to the same skills `ac-pipeline` uses, but you pre-answer their operational questions (bead count, session mode, next-step choices) so they run headlessly. You pause only for genuine forks — decisions only Craig can make — and only when those are simple enough for Slack buttons.

When invoked interactively (`/ac-loop`), `AskUserQuestion` renders in the terminal. When invoked by the scheduler (headless), `AskUserQuestion` posts to Slack as interactive buttons — the session suspends and resumes when Craig clicks. Either way, the behaviour is identical; the transport differs.

> **Scope contract:** You work the pipeline, not the backlog. You never touch raw backlog items, unrefined plans, or unrefined beads. Craig controls what enters the pipeline — you drive what's already in it. Human-gated beads (`human-gate` label) are surfaced, not auto-closed.

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
[If plan has no beads yet]
  ac-beadify → ac-bead-refine
                    ↓
EACH ITERATION:
  1. Orphan beads  (refined, no plan wave, fixes ship fast)
      └─ ac-implement → ac-ui-polish → ac-qa-browser [+ac-qa-device on macOS/native]
              → ac-land → ac-review → ac-merge → Slack notify
  2. Next plan's wave  (pick highest-priority plan with refined ready beads)
      └─ ensure wave branch (loop owns this, not ac-implement) →
         ac-implement → ac-ui-polish → ac-qa-browser [+ac-qa-device on macOS/native]
              → ac-land → ac-review → ac-merge → Slack notify
  3. Loop — check for more orphans or plans
  4. Nothing left → Phase ARIA (unlock human blocks, then stop)

STOP CONDITIONS checked before each iteration (see below).
```

---

## Phase 0: Orient

Read the current state of the board. This is the map you navigate by.

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)

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
br ready --json | jq '[.[] | select(.labels | index("unrefined"))]'
```

> **The loop-ready gate:** Only plans with `status: loop-ready` in their frontmatter are touched by the loop. Plans marked `refined`, `draft`, or anything else are invisible to the loop — Craig has not yet signed them off for autonomous execution. This is intentional: Craig sets `loop-ready` at the end of `ac-plan-refine` (optionally after running `ac-plan-clean`), which is the explicit hand-off signal.

Summarise: N orphan beads, M plan beads across K plans, wave open/closed, H human-gated waiting, L loop-ready plans with no beads yet, U unrefined beads needing refine.

**Work priority order:**
1. Unrefined beads (from loop-ready plans) → run `ac-bead-refine` (delegation: "ac-loop autonomous run, skip next-step question")
2. Loop-ready plans with no beads → run `ac-beadify` then `ac-bead-refine` (delegation: "ac-loop autonomous run, always proceed to ac-bead-refine, no confirmation needed")
3. Orphan refined beads → Phase 1
4. Plan wave refined beads → Phase 2

If **no refined beads, no unrefined beads from loop-ready plans, no loop-ready plans to beadify, and no human-gated beads** → go straight to Phase ARIA.

---

## Phase 1: Orphan Beads

**Orphans = refined, non-human-gate beads with no wave affinity.** These are typically bugs and quick fixes surfaced by `ac-triage` or `ac-bead-capture`. Ship them first — they often unblock other work or are time-sensitive production fixes.

```bash
# Orphan beads: refined, no wave label, no human-gate
br ready --json | jq '[.[] | select(
  (.labels | index("unrefined") | not) and
  (.labels | index("human-gate") | not) and
  (.labels | map(startswith("wave/")) | any | not)
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
     HIGHEST=$(git for-each-ref --format='%(refname:strip=3)' refs/remotes/origin/wave/ \
               | grep -oE '^[0-9]{3}$' | sort -n | tail -1)
     WAVE="wave/$(printf "%03d" $(( ${HIGHEST:-000} + 1 )))"
     git checkout -b "$WAVE" main && git push -u origin "$WAVE"
   else
     git checkout "$WAVE" && git pull --rebase
   fi
   ```
2. **Invoke `ac-implement`** — use this delegation prompt to suppress overhead questions:
   > "Run ac-implement targeting all N orphan beads (IDs: `<list>`). SESSION_MODE=solo. TARGET_BEADS=N. Skip the bead-count and session-mode setup questions — answers are pre-supplied. Wave branch is already `<WAVE>`. For baseline test failures: file a P1 bead and proceed (do not ask). Advance to ac-land when complete."
3. **Invoke `ac-ui-polish`** — design conformance pass. Beads it files feed the retrospective.
4. **Invoke `ac-qa-browser`** — web journey validation.
5. **Invoke `ac-qa-device`** — native validation (macOS only; skip on Linux/CI).
6. **Invoke `ac-land`** — use this delegation prompt:
   > "Run ac-land for this session. This is an autonomous loop run. For system upgrade proposals: capture them as a Slack card for Craig to review separately — do NOT block landing. Next step after landing is ac-review (do not ask)."
7. **Invoke `ac-review`** — use this delegation prompt:
   > "Run ac-review on branch `<WAVE>`. This is an autonomous loop run. For DESIGN_DECISION or SCOPE_ESCALATION items: apply the Exhaust Rule (create decision beads, do not AskUserQuestion). Do not ask 'what's next?' at Phase 8 — exit after printing the summary with VERDICT: line."
8. **Read `VERDICT:` from ac-review output** — `APPROVED` → proceed to merge. `NEEDS_DECISION` with open blockers → hard stop (C2).
9. **Invoke `ac-merge`** — use this delegation prompt:
   > "Run ac-merge on branch `<WAVE>`. CI config for this project: `<cached-answer>`. Version bump: accept recommended default without asking. For uncertain PR feedback items: create decision beads (Exhaust Rule). Do not ask 'what's next?' after merge."
10. **Slack notify** (see Milestone Notifications).
11. **Loop** — return to Phase 0 check after merge.

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
  (.labels | map(startswith("wave/")) | any)
)] | group_by(.labels[] | select(startswith("wave/"))) | sort_by(.[0].priority) | .[0]'
```

Cross-reference with `$LOOP_READY_PLANS` — only advance a plan wave if its parent plan file has `status: loop-ready`. If no loop-ready plan waves exist, skip to Phase ARIA.

### Execute the wave

1. **Pre-allocate wave branch (loop's job)** — same logic as Phase 1 step 1. If a wave is already open from the orphan pass, join it. Single-branch rule: never create a second wave while one is open.
2. **Invoke `ac-implement`** with delegation prompt:
   > "Run ac-implement targeting all refined ready beads for plan `<plan-name>` (wave label: `<wave-label>`). SESSION_MODE=solo. TARGET_BEADS=N. Skip bead-count and session-mode setup questions. Wave branch is `<WAVE>`. Baseline test failures: file P1 bead and proceed. Advance to ac-land when complete."
3. **Invoke `ac-ui-polish`** — design conformance pass.
4. **Invoke `ac-qa-browser`** — web journey validation.
5. **Invoke `ac-qa-device`** — native validation (macOS only).
6. **Invoke `ac-land`** with delegation prompt:
   > "Run ac-land for this session (ac-loop autonomous run). System upgrade proposals: capture as Slack card for Craig, do NOT block landing. Next step is ac-review."
7. **Invoke `ac-review`** with delegation prompt:
   > "Run ac-review on branch `<WAVE>` (ac-loop autonomous run). DESIGN_DECISION/SCOPE_ESCALATION: Exhaust Rule — create decision beads, do not AskUserQuestion. Exit after Phase 8 summary with VERDICT: line."
8. **Read `VERDICT:`** — APPROVED → merge. NEEDS_DECISION with blockers → C2 stop.
9. **Invoke `ac-merge`** with delegation prompt:
   > "Run ac-merge on `<WAVE>` (ac-loop autonomous run). CI config: `<cached>`. Version bump: accept recommended default. Uncertain feedback: Exhaust Rule — decision beads. No next-step question after merge."
10. **Slack notify** — wave shipped.
11. **Check stop conditions** — then loop back to Phase 0.

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

## Stop Conditions

Check before each iteration begins.

| # | Condition | Action |
|---|-----------|--------|
| **C1** | No eligible work and no human-gate unblocks remaining | End session cleanly. Notify Slack: "Pipeline clear." |
| **C2** | `ac-review` returns a Critical blocking finding (regression) | Hard stop. Do NOT merge. Notify Slack with the finding. File a P0 bead. Wait for human. |
| **C3** | Token budget approaching (estimate: <30k tokens remaining) | Finish the current bead, land, then stop. Notify Slack: "Stopping — token budget low. N beads remain." |
| **C4** | Iteration cap reached (default: 3 plan waves per session) | Stop after current merge. Notify Slack: "Iteration cap reached." |
| **C5** | Human override (Slack message "stop" / "pause the loop") | Honour immediately after current bead. Notify confirmation. |

C2 is the only **hard** stop — it never merges a regression. C1/C3/C4/C5 are clean stops (current work finishes, then exit).

---

## Milestone Notifications

Always notify on Slack at meaningful milestones. Use `slack-send --channel sofi --card` (replace `sofi` with the app's configured channel).

| Event | Message |
|-------|---------|
| Orphan beads shipped | "✅ Shipped <N> orphan fix(es) — <bead titles> — merged to main." |
| Plan wave shipped | "🚀 Wave for *<plan name>* merged — <N> beads shipped. Branch: `wave/NNN`." |
| Critical regression found | "🛑 Loop stopped — ac-review found a critical regression in `<file>`. Needs your review before merge." |
| Token budget low | "⚠️ Loop pausing — token budget low. <N> beads remain in queue." |
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
- **ARIA gating** — `AskUserQuestion` only for simple, bounded forks. Everything else is advisory
- **Persistent nudge** — re-nudge every session until Craig acts. Silence enables bottlenecks
- **C2 is the only hard stop** — critical regression never merges
- **Always Slack-notify** — shipped waves, blocked stops, clear pipeline. Headless means Craig has no other visibility
- **Never close `human-gate` beads** — record the decision, execute consequences, then close only after Craig's recorded answer

---

_Loop runs: Phase 0 orient → Phase 1 orphans → Phase 2 plan wave → repeat → Phase ARIA when empty. Each merge is a milestone; each nudge is a bottleneck signal. The loop is what keeps the flywheel turning without Craig in the seat._
