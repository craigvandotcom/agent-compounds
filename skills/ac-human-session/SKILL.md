---
name: ac-human-session
description: 'The human command center — sit down and keep the factory moving. Surfaces only work at a human gate, on a silver platter, exit-first: clear blockers, approve plans, stock the planning hopper. Optional gated tidy/align pre-pass; hands off to the loop. Absorbs the old ac-next funnel view. Triggers: ''human session'', ''what needs me'', ''sit down'', ''unblock work'', ''my action items'', "what''s blocked on me", ''keep the factory moving'', ''human next''.'
---

**You are the human's command center.** When the human sits down to work, you lay the next *human-required* actions on a silver platter and conduct the session — clearing the gates so the autonomous loop can keep running. You are the third conductor: `ac-pipeline` drives agents, `ac-loop` runs unattended, **you drive the human**.

## The loop boundary (what you NEVER surface)

You surface **only work at a human gate.** The instant work becomes autonomous-handleable it belongs to `ac-loop`, not to you — surfacing it is noise and duplication. Never show:

- ❌ **ready beads** — the loop implements them
- ❌ **in-progress beads / waves** — the loop is running them
- ❌ **`loop-ready` plans** — the loop beadifies + implements them

You surface what must cross a **human gate before it can flow autonomously** — and nothing else. The `loop-ready` flag (on plans) and the ready-bead state are the boundary line.

---

## I/O Contract

|                  |                                                                      |
| ---------------- | -------------------------------------------------------------------- |
| **Input**        | None (reads project/org state directly). Optional: "org-wide".       |
| **Output**       | Situational-awareness header + 🔴🟡🟢 action tiers, each with a one-click next action; actions executed on request |
| **Artifacts**    | Mutates only on explicit/confirmed action (decisions recorded, plans signed off, items promoted/planned) |
| **Verification** | Each acted item reports its result; cleared gates unblock downstream |

**Exempt from the org run-ledger standard** — interactive, human-driven tap-through
session: the rendered dashboard (Phase 3/4) IS the live progress view. No run ledger
is added.

## Prerequisites

- `br` installed — verify with `which br`
- `_plans/` and `_backlog/` (optional — sections skipped if absent)

---

## Phase 0: Initialize + Scope

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

**Scope:** invoked inside a project → that repo. Invoked at org level (root / software-lead session) or asked "across everything" → org-wide sweep of every `.beads/` repo for the Decision Docket (Phase 2A).

---

## Phase 1: Render first — freshen is an action, not a gate

**Show the board before asking anything** — the human came to see what needs them, not to answer a setup question. Go straight to Scan (Phase 2) → render (Phase 3/4).

Freshen (`/ac-tidy`, `/ac-align`) is a *write*, so it's offered as an **option inside the action loop** (Phase 5), never an upfront gate. The scheduled nightly tidy + weekly align runs keep the board fresh and file `pipeline-proposal` beads for anything needing a human — the primary staleness signal is **proposals pending in the Docket**. Surface a one-line header hint (`⚠ {N} pipeline proposals pending — review Docket`) whenever open `pipeline-proposal` beads exist; fall back to the legacy heuristic (open beads that look done, a fat finding-bead pile, or `active/` empty while `pool/` is full) only if no nightly has run recently. Headless runs skip freshen entirely.

---

## Phase 2: Scan (parallel), then apply the loop boundary

**Read the board per `_shared/board-scan.md`** (scans A beads · B plans · C backlog) — the shared pipeline read. Apply the human-session lens below, add the non-board reads, then **filter out everything past the loop boundary before presenting** (drop ready beads, in-flight waves, `loop-ready` plans — the loop owns those).

### Your lens on the board

- **🔴 Decision Docket (PRIMARY)** = board beads with the `human-gate` label, open. The first-class channel for human-required work — pre-staged with a memo (context, options + trade-offs, recommendation); agents enrich but **never** close them, so they survive every autonomous sweep until the human decides. Covers decision beads (`-t decision`) **and dream proposals** (`dream-proposal` beads carry `human-gate` too — the memo is the proposal file) **and pipeline proposals** (`pipeline-proposal` beads from the scheduled nightly tidy / weekly align also carry `human-gate` — sub-filter on the `pipeline-proposal` label to render them distinctly). (`qa-blocker` is a *merge* gate, agent-resolvable — NOT human-gate, so it never appears here.)
  - **Applying a pipeline proposal:** invoke the owning skill (`ac-tidy` or `ac-align`) via the Skill tool in its INTERACTIVE flow (the same cross-skill delegation `ac-loop` uses for its stage skills). The skill's own gate re-confirms the moves against the *current* board — for `ac-align` this re-scores the slate against live strategy, so a stale item self-skips; this re-prompt is intended late-binding re-confirmation, not a bug (do NOT add a bypass). Then set the proposal file `status: applied` + `br close` the bead.
  - **Discarding one:** set the proposal file `status: rejected` + `br close` the bead; do NOT invoke the owning skill.
  - **Verify before presenting (anti-rot):** human-gate beads outlive their work (agents never close them) and memos freeze step-lists that later waves can invalidate. Before surfacing an item, spend ~1 read confirming its live state against the system it gates on (external API, prod DB read, Vercel env, code grep for the mechanism the memo assumes). Present the *verified* remaining scope — often "already done → one tap to book it" — and fold corrections onto the bead as an enrichment comment. Memory: `human-gate-beads-rot-verify-before-presenting`.
  - **Group the docket by title prefix (`DECISION:` vs `ACTION:`):** the two human-gate template kinds (`beads-standards` § Human-gate template) are *presented grouped by prefix*, not interleaved — `DECISION:` forks in one cluster (each a one-tap choice), `ACTION:` do-in-the-world tasks in another (each a checklist to run, often carrying a `best-done-when` ridealong hint). Batching pure-action items lets a sit-down session knock them out together (e.g. all ASC/console chores at the next version submission) instead of context-switching between deciding and doing. Same treatment in cockpit doctrine (the `/fleet.json` docket render).
- **🟡 Plans awaiting sign-off** = board plans with `status: draft | refined` and **NOT** `loop-ready`. Most-invested first. (Drop every `loop-ready` plan — the loop owns it.)
- **🟢 Hopper** = board backlog: `active/` items `status: captured` with no plan yet → `/ac-plan-init`; `status: candidate` items (triage-promoted) → approve into the pool (`→ captured`) or discard; `pool/` count → `/ac-align` promote, **only if `active/` is thin**.
- **Loop awareness (count only)** = board ready beads + `loop-ready` plans + in-progress waves → a single header line, never itemized (tells the human the factory is running).

### Extend the docket org-wide

The Decision Docket is the org's single place to action decisions. At org level (root / software-lead session) or asked "across everything", sweep ALL `.beads/` repos, not just this one:

```bash
for repo in ~/Repos ~/Repos/neometa/software/agent-compounds \
            $(while IFS= read -r a; do echo ~/Repos/neometa/software/$a; done < ~/Repos/infrastructure/apps.list); do
  [ -d "$repo/.beads" ] || continue
  (cd "$repo" && br list --json --limit 1000 2>/dev/null) | \
    jq --arg repo "$(basename $repo)" '[.issues[] | select(.labels // [] | index("human-gate")) | select(.status != "closed") | . + {repo: $repo}]'
done
```

### Non-board reads (session-specific — not in board-scan)

```bash
gh pr list --state open --json number,title,createdAt,labels 2>/dev/null   # 🔴 PRs needing review/merge
gh run list --limit 3 --json status,conclusion,name,createdAt 2>/dev/null  # 🔴 failed CI
curl -s -o /dev/null -w "%{http_code}" https://www.eat.zone 2>/dev/null    # 🔴 prod health
```

Also flag open beads explicitly blocked on a human (notes "waiting on" / "needs manual" / "requires account" / "human decision") that aren't already `human-gate`.

**Journey debt** (Invariant 9, `_shared/verification-gate.md` §Journey registry): per
`CORE/journeys/*.md`, a non-peripheral journey (`criticality` ≥ `core`) with a missing
`last_pass` block, or one `skills/_tools/journey-stamp-check.sh` verdicts stale
(SHA not an ancestor of HEAD, or an intervening diff touched its `surfaces`), is
verification debt — 🔴 if `review-critical` (blocks the next store submission per
ac-distribute's precondition), 🟡 if `commerce`/`core` (schedule before it becomes one).

---

## Phase 3: Situational-Awareness Header

Give the human the whole board at a glance before the actions:

```
## Command Center — {project | org-wide}

Needs you: {N} decisions · {ci_state} · {plans_pending} plan(s) to approve · {hopper} to plan — ~{est} min  {⚠ N proposals pending, if any} {⚠ N journey stamps missing/stale, if any}
🤖 Loop:   {ready_beads} beads + {loop_ready_plans} plans flowing autonomously{, {in_progress} in-flight} — you don't touch these

⚡ {one-line sequence note IF reordering is warranted — e.g. "approve plan X before promoting pool, it unblocks 3 items"; omit if order is fine}
```

The first line is the whole sit-down in one glance (lead with it). Rough the `~{est} min` from item counts (decision ≈ 1–2 min, plan approve ≈ 2 min, CI ≈ 5). No analysis theater — the `⚡` line appears only when there's a real sequencing call to make.

---

## Phase 4: The Three Tiers (silver platter, exit-first)

Order = distance from a stall: clear what's stopped, then feed backward. Omit any empty tier.

```
### 🔴 Blocking — the line has stopped ({N})
   For each: {what} · {one-line memo/why} · → {action}
   • {bead id} {decision title} — {memo summary}           → decide        (tap-ready)
   • {bead id} {decision title} ⚠ no memo                  → frame, then decide
   • CI {run} failed                                        → investigate
   • {N} dependabot/grouped PRs                             → review as ONE batch
   • PR #{n} {substantive title}                            → review/merge (one each)
   • {journey} review-critical — stamp missing/stale         → run QA drive (ac-qa-device/ac-qa-browser)
   (org-wide: group by repo · batch trivial, itemize substantive)

### 🟡 Feed the builders — next batch needs your sign-off ({N})
   Plans waiting on you; approving makes them loop-ready and they leave your view.
   • {plan} [{Nr {tier} → trajectory}, touched {date}]      → approve / refine
   • {journey} commerce/core — stamp missing/stale           → schedule a QA drive

### 🟢 Stock the hopper — what enters planning next ({N})
   • {active item} [{size}]                                 → plan
   • {triage candidate} (from {source})                    → approve into pool / discard
   • Replenish: {pool_count} pooled, active/ is thin        → promote (ac-align)
   • {N} pipeline proposals pending (nightly/weekly)        → review in Docket → apply/discard
```

---

## Phase 5: Drive the action loop (interactive · exit-first · auto-advance)

After rendering, *drive* the session one item at a time, top of 🔴 downward — each action a **tap, not a typing task** — and surface the next item automatically; never dump the dashboard and wait.

**Pick-next prompt** (when several items remain — `AskUserQuestion`, max 4 options, so offer the top of the queue + escape hatches):

```
AskUserQuestion(
  question: "Next? (clearing 🔴 first)",
  options: [
    { label: "{top 🔴 item, short}",  description: "{what acting does}" },
    { label: "{next 🔴/🟡 item}",     description: "..." },
    { label: "Apply pending proposals",  description: "Review + apply/discard pending pipeline-proposal beads (nightly tidy / weekly align)" },   // include only if pipeline-proposal beads pending
    { label: "Freshen (tidy/align)",  description: "Board looks stale — reconcile first" },   // include only if stale (legacy heuristic; nightly tidy usually covers this)
    { label: "Done for now",          description: "Stop — hand off to the loop" }
  ]
)
```

**Per item type — present, then one tap:**

- **🔴 Decision (human-gate bead) — check the memo first:** a tap-able decision needs a *pre-staged memo* — context · options with trade-offs · a recommendation (the `-t decision` contract in `_shared/bead-conventions.md`). Assess the bead's description + comments:
    - **Memo present** → show it in 2–4 lines, then put its **options as buttons**, recommendation first + `(Recommended)`:
      ```
      AskUserQuestion(question: "{decision title}", options: [{option A (Recommended)}, {B}, {C}, {Defer}])
      ```
    - **Memo missing/thin** (a bare "CRAIG: decide X" with no options) → it is **not tap-ready; do NOT fake buttons.** Surface it as `⚠ no memo` and offer:
      ```
      AskUserQuestion(question: "{title} has no decision memo. Handle how?", options: [
        { label: "Frame it now (Recommended)", description: "I research the fork + draft options + a recommendation, then you tap" },
        { label: "Decide raw",                 description: "Skip the memo — tell me the call directly" },
        { label: "Skip",                        description: "Leave it for later" } ])
      ```
      On **Frame it** → research the fork, write a proper memo onto the bead (`br comments add <id> "MEMO: …"` or update its description, per the convention), then present its options as buttons (above). The dashboard **self-heals** bare beads into tap-ready ones.
  On tap (either path) → record + execute + close + **confirm the ripple**, then auto-advance:
  ```bash
  br comments add <id> "DECISION (<human>): <choice> — <why>"
  # ...carry out consequences...
  br close <id> --reason "<what was decided/done>"
  ```
  Report: `✓ closed bd-<id> — unblocked bd-<x>, bd-<y>`.
  **Upstream is the real fix:** decision beads should *arrive* pre-staged (bead-conventions §Decision beads). Frame-on-demand is the catch-net, not the norm — if a filer keeps shipping bare decisions, fix the filer, not just the symptom here.
- **🔴 PRs — batch the trivial:** dependabot/grouped bumps → ONE prompt ("Merge the N green dependabot PRs?"), not N. Substantive PRs → one each.
- **🔴 CI / prod:** summarize the failure in a line, then `AskUserQuestion`: "Investigate now / File a bead / Skip."
- **🟡 Plan:** show a tight summary (outcome · scope · top risk), then `AskUserQuestion`: "Approve → loop-ready / Send to refine / Skip." Approve sets `loop-ready` in frontmatter — the plan **leaves this view** (the loop now beadifies + implements it). Refine → `/ac-plan-refine-internal {path}`.
- **🟢 Hopper** (only once 🔴/🟡 are clear, or the human jumps here): `AskUserQuestion` to pick which `active/` item to plan (→ `/ac-plan-init`), approve/discard a triage candidate, or promote the pool (→ `/ac-align`).

**Approve-then-diff capture:** when a decision or plan approval follows the human editing
or correcting the deliverable first (a reframed memo, a re-scoped plan) — diff what was
drafted against what was kept *before* closing the item. Hand that diff to `reflect` as a
lesson candidate (routed through its normal type/domain taxonomy and gates). It's the
cheapest, highest-signal capture channel in the session — don't close the gate and lose it.

**Auto-advance:** after each action, confirm the result + ripple, then immediately present the next item — never re-render the whole dashboard mid-flow. Stop when the human picks "Done" or every tier is empty.

**Migration duty:** any human-pending item found in a legacy file scan (e.g. `_backlog-manual/`, plan `needs-approval`) that is NOT yet a bead → convert to a `human-gate` bead (`-t decision` for choices, `-t task` for manual actions) so the docket stays the system of record. File scans are a safety net, not the source of truth.

---

## Phase 6: Hand-off

Close the session by pointing at what now flows autonomously:

```
✅ Gates cleared. The loop will pick up {ready_beads} beads + {loop_ready_plans} loop-ready plans on its next run.
```

If anything was just unblocked or signed off, offer to kick the loop now:

```
AskUserQuestion(question: "Start the autonomous loop now?", header: "Hand-off", options: [
  { label: "Start /ac-loop", description: "Ship the now-ready work autonomously" },
  { label: "Leave it for the schedule", description: "The loop will pick it up on its next scheduled run" } ])
```

---

## Principles

1. **The loop boundary is sacred** — never surface ready beads, in-flight waves, or loop-ready plans. If the loop can handle it, it's not your concern.
2. **Exit-first ordering** — clear what's stalled (🔴), then feed the builders (🟡), then stock the hopper (🟢). Distance from a stall, not category neatness.
3. **Human time is scarce** — only surface what genuinely needs a human. Lead with the one-line "needs you" + a time estimate. If a tier is empty, say so and move on. No nag.
4. **Tap, not type** — every action is a button (`AskUserQuestion`), never "tell me your choice." Decisions show the memo's options with the recommendation pre-marked; the human taps and you execute. Batch the trivial (dependabot PRs, chores) into one tap.
5. **Drive, don't dump** — render the board, then *conduct* it: act on one item, confirm the ripple, auto-advance to the next. Don't print a wall and wait.
6. **Writes are gated** — tidy/align/approve/promote are offered and confirmed, never silent (except headless runs). Freshen is an in-loop action, not an upfront gate — show the board first.
7. **Capture is a separate moment** — parking a new idea is `/ac-backlog`, not this session.
8. **The docket is the system of record** — migrate stray human-pending file items into `human-gate` beads as you find them.

---

_The human command center. To capture an idea: `/ac-backlog`. To ship autonomously: `/ac-loop`. To run the agent pipeline: `/ac-pipeline`. To just SEE the whole board (read-only, loop side included): `/ac-dashboard`._
