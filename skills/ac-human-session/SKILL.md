---
name: ac-human-session
description: 'The human command center — sit down and keep the factory moving. Surfaces only work at a human gate, on a silver platter, exit-first: clear blockers, approve plans, stock the planning hopper. Optional gated tidy/align pre-pass; hands off to the loop. Absorbs the old ac-next funnel view. Triggers: ''human session'', ''what needs me'', ''sit down'', ''unblock work'', ''my action items'', "what''s blocked on me", ''keep the factory moving'', ''human next''. ''Unblock'' here means a HUMAN gate only — NOT a technical blocker (use debug, or ac-triage for inbound signal), NOT the full board including loop-side work (use ac-dashboard), and NOT doing the work itself (use ac-implement / ac-loop).'
---

**You are the human's command center.** When the human sits down to work, you lay the next *human-required* actions on a silver platter and conduct the session — clearing the gates so the autonomous loop can keep running. `ac-loop` runs unattended, **you drive the human**.

## The loop boundary (what you NEVER surface)

You surface **only work at a human gate.** The instant work becomes autonomous-handleable it belongs to `ac-loop`, not to you — surfacing it is noise and duplication. Never show:

- ❌ **ready beads that lack `human-gate` / `pipeline-proposal` / `dream-proposal`** — the loop implements them
- ❌ **in-progress beads / waves** — the loop is running them
- ❌ **`loop-ready` plans** — the loop beadifies + implements them

Ready + a docket label **is the docket**, not the loop — do not drop it. You surface what must cross a **human gate before it can flow autonomously** — and nothing else.

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

**`human-ratified` — this skill stamps human-ratified only.** After a recorded
lightweight completeness check (≥1 AC an empty diff cannot satisfy + greppable
`## Delivers` + implementable type `task`/`feature`/`bug`), stamp that label.
Do NOT apply `refined` / `refine-full` / `refine-light` (exclusive stamper of
those remains `ac-bead-refine`). `ac-bead-refine` never stamps `human-ratified`.

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

**Read the board per `ac-pipeline/references/board-scan.md`** (scans A beads · B plans · C backlog) — the shared pipeline read. Apply the human-session lens below, add the non-board reads, then **filter out everything past the loop boundary before presenting** (drop ready beads that lack a docket label, in-flight waves, `loop-ready` plans — the loop owns those).

### Your lens on the board

- **🔴 Decision Docket (PRIMARY)** = board beads matching `human-gate` OR `pipeline-proposal` OR `dream-proposal`, open. The first-class channel for human-required work — pre-staged with a memo (context, options + trade-offs, recommendation); agents enrich but **never** close them, so they survive every autonomous sweep until the human decides. Covers decision beads (`-t decision`) **and dream proposals** (`dream-proposal` — render as their own docket tier; the memo is the proposal file) **and pipeline proposals** (`pipeline-proposal` beads from the scheduled nightly tidy / weekly align — render as their own docket tier; sub-filter on the `pipeline-proposal` label). The collector is the union, not a pairing — proposal beads do not need `human-gate` to appear. (`qa-blocker` is a *merge* gate, agent-resolvable — NOT human-gate, so it never appears here.)
  - **Applying a pipeline proposal:** invoke the owning skill (`ac-tidy` or `ac-align`) via the Skill tool in its INTERACTIVE flow (the same cross-skill delegation `ac-loop` uses for its stage skills). The skill's own gate re-confirms the moves against the *current* board — for `ac-align` this re-scores the slate against live strategy, so a stale item self-skips; this re-prompt is intended late-binding re-confirmation, not a bug (do NOT add a bypass). Then set the proposal file `status: applied` + `br close` the bead. **Verify the memo's HARM, not only its facts** — the TOCTOU guards re-check whether the numbers went stale, and nothing checks whether the stated damage was ever real. Ask "what consumes this, and what breaks if I do nothing?" before working the list. 2026-07-30, 2 of 8: bd-zugqh claimed 91 orphans "drift unscheduled" — grep found parentage has ONE consumer (epic-close) and a named orphan sat in the loop's ready set throughout; bd-8ms5t assumed 102 findings were stale bookkeeping — only 1 had merged-fix evidence, so the auto-pruner proposed for it would have had nothing to close and would have had to loosen into laundering. Both measurements INVERTED the fix. A memo is an argument, not a finding.
  - **Discarding one:** set the proposal file `status: rejected` + `br close` the bead; do NOT invoke the owning skill.
  - **Verify before presenting (anti-rot):** human-gate beads outlive their work (agents never close them) and memos freeze step-lists that later waves can invalidate. Before surfacing an item, spend ~1 read confirming its live state against the system it gates on (external API, prod DB read, Vercel env, code grep for the mechanism the memo assumes). Present the *verified* remaining scope — often "already done → one tap to book it" — and fold corrections onto the bead as an enrichment comment. Memory: `human-gate-beads-rot-verify-before-presenting`.
    - **MANDATORY FIRST READ — the bead's own `events` table, before any other verification.** A docket bead most often gates on its OWN history, and comments do not reliably record it: `sqlite3 .beads/beads.db "SELECT created_at,event_type,comment FROM events WHERE issue_id='<id>' ORDER BY created_at;"`. **A comment is a CLAIM; `events` is the RECORD.** `label_removed human-gate` followed by a DECISION/RULING/RELEASE comment means the bead was RELEASED — do not re-gate it, and NEVER re-gate one released more than once. Evidence + why this is a step, not a memory note: `references/docket-anti-rot.md`.
    - **FRESHNESS BOUND on `(tap-ready)` — DATE precision, three branches.** The nightly stamps a surviving gate with a `verified: <YYYY-MM-DD>` comment (`ac-tidy/workflows/nightly.md`) — a DATE with no time component, so this bound is a date comparison and nothing finer. Read the newest `verified:` stamp on the bead and render exactly one of three ways:
      - stamp dated **TODAY** → the gate renders `(tap-ready)`;
      - stamp dated **earlier** → it renders `⚠ stale — reverify` (do the ~1-read verification above, re-stamp, then it is tappable);
      - **no `verified:` stamp at all** → it renders `⚠ never verified — reverify`. Absence is not freshness — never let an unstamped gate inherit `(tap-ready)`.
      **"Today" is the LOCAL calendar date of the machine running the session** — the same clock the nightly stamped in (both run on Craig's machine, and the stamp carries no timezone marker, so there is nothing else to compare against). **The day boundary is deliberately loose and that is not a bug:** a stamp written 00:45 local reads fresh until 23:59 that same day (~23h of trust), while one written 23:50 reads stale twenty minutes later. `(tap-ready)` is a presentation hint about whether the human can trust the memo without re-reading it, not an SLA — a false "stale" costs one read, which is the cheap direction to be wrong in.
  - **Collapse QUEUE LANES before grouping — a flood must never bury the genuine gates.** Some `human-gate` beads arrive as a machine-generated BATCH from one upstream source (today: `curator-escalation`, filed 80+ at a time by `escalate-to-bead --legacy`). Detect a lane mechanically: **any label carrying >5 open `human-gate` beads**. Render it as ONE line — lane · count · oldest age · its batch action — and **never itemize its P2+ members in the tier**. Collapse is presentation only: the lane line **is work in this sitting**, not a "come back later." After independent P0/P1s, auto-advance into the lane. Apply this BEFORE the prefix grouping below.
    **P0 and P1 members are NEVER collapsed — itemize them individually ABOVE the lane line, and subtract them from its count.** A lane label is a *filing* channel, not a statement of importance: the same label lands both a bulk machine batch and the P0 that batch was filed to fix. Caught live on the run that created this rule — a naive whole-label collapse would have hidden `bd-8yhvb` (**P0**, the frozen-lane bug) plus three P1s inside an 82-bead `curator-escalation` flood, which is a strictly worse failure than the flood itself. Collapse the queue, never the emergency.
    ```
    • bd-8yhvb 4d P0 Curator escalations UNRELEASABLE — …   → decide   (P0/P1 lane members stay itemized)
    🔁 curator-escalation — 89 more queued (oldest 4d)      → work the queue
    ```
    Rationale (2026-07-30, the run that forced this rule): a single supervised conversion took the docket from 61 to 143 in one command. Itemised, the ~15 real gates became unfindable. The beads were legitimate — they made previously-invisible work visible — so suppressing them is wrong and itemising them is also wrong; **collapsing is the only honest option**.
    Two lane-health checks to run when you render the line, because a flood hides its own defects:
    - **Unreadable titles are a FILING DEFECT, report them.** A docket bead whose title carries a raw uuid/hash instead of its human subject (`Legacy escalation: hold 6f390127-2960-…`) cannot be triaged by a human at all. If >5 in a lane look like this, say so on the line and offer a re-title pass — the subject is almost always recoverable from the body or by joining back to the source system. Fix the FILER too, not just the rows.
    - **A lane filed before a governing policy was ratified is STALE BY CONSTRUCTION.** If a rule/policy landed after the lane was filed, some members are now auto-resolvable and should not be on the docket at all. Say what fraction is expected to survive re-triage rather than presenting the raw count as if it were all real human work.
    - **SERVING POLICY — when a lane is too big to serve row-by-row, ELEVATE it to a tap.** This threshold is **ADDITIVE to the `>5` collapse rule above, never a replacement for it** — the two answer different questions: **`>5` decides whether the lane COLLAPSES** to one line, **`>=20` open members OR an oldest member older than 21 days decides whether that one line is ELEVATED to a first-class tap** (rendered in Phase 4, above 🟢). A 30-bead lane is both collapsed *and* elevated; a 7-bead lane is collapsed and plain. Never let one threshold rewrite the other. Over the line, render the elevated tap (`Run the curator sitting — {N} queued`) and nudge **`bd-8yhvb`** — the supervised batch-sitting bead that owns working a curator lane down — by name, so the human taps into the supervised flow instead of grinding rows one at a time.
  - **Group the docket by title prefix (`DECISION:` vs `ACTION:`):** the two human-gate template kinds (`beads-standards` § Human-gate template) are *presented grouped by prefix*, not interleaved — `DECISION:` forks in one cluster (each a one-tap choice), `ACTION:` do-in-the-world tasks in another (each a checklist to run, often carrying a `best-done-when` ridealong hint). Batching pure-action items lets a sit-down session knock them out together (e.g. all ASC/console chores at the next version submission) instead of context-switching between deciding and doing. Same treatment in cockpit doctrine (the `/fleet.json` docket render).
- **🟡 Plans awaiting sign-off** = board plans with `status: draft | refined` and **NOT** `loop-ready`. Most-invested first. (Drop every `loop-ready` plan — the loop owns it.)
- **🟢 Hopper** = board backlog: `active/` items `status: captured` with no plan yet → `/ac-plan-init`; `status: candidate` items (triage-promoted) → approve into the pool (`→ captured`) or discard; `pool/` count → `/ac-align` promote, **only if `active/` is thin**.
- **Loop awareness (count only)** = ready beads that lack a docket label + `loop-ready` plans + in-progress waves → a single header line, never itemized (tells the human the factory is running).

### Extend the docket org-wide

The Decision Docket is the org's single place to action decisions. At org level (root / software-lead session) or asked "across everything", sweep ALL `.beads/` repos, not just this one:

```bash
for repo in ~/Repos ~/Repos/neometa/software/agent-compounds \
            $(while IFS= read -r a; do echo ~/Repos/neometa/software/$a; done < ~/Repos/infrastructure/apps.list); do
  [ -d "$repo/.beads" ] || continue
  (cd "$repo" && br list --json --limit 1000 2>/dev/null) | \
    jq --arg repo "$(basename $repo)" '[.issues[] | select((.labels // []) | (index("human-gate") or index("pipeline-proposal") or index("dream-proposal"))) | select(.status != "closed") | . + {repo: $repo}]'
done
```

### Non-board reads (session-specific — not in board-scan)

```bash
gh pr list --state open --json number,title,createdAt,labels 2>/dev/null   # 🔴 PRs needing review/merge
gh run list --limit 3 --json status,conclusion,name,createdAt 2>/dev/null  # 🔴 failed CI
curl -s -o /dev/null -w "%{http_code}" "$PROD_URL" 2>/dev/null             # 🔴 prod health
```

**`$PROD_URL` is per-project — resolve it, never hardcode one here.** This skill is
shared across every app in the registry, so a literal domain is wrong for all but one of
them. Read the project's live domain from its `AGENTS.md` / CORE, or from the deployed
alias, before probing. (BCA = `https://bodycompass.app`.)

A **retired** domain must not be probed at all. Until 2026-07-26 this line curled
`www.eat.zone` — BCA's pre-rebrand domain, decommissioned long before — so every run
reported prod as `404` while prod was in fact healthy. A 🔴 that is always red trains the
human to ignore the 🔴 tier, which is worse than not probing. If a probe is red, confirm
the URL is still the real prod surface before reporting it (bd-vp7fw).

Also flag open beads explicitly blocked on a human (notes "waiting on" / "needs manual" / "requires account" / "human decision") that aren't already `human-gate`.

**Journey debt** (Invariant 9, `ac-pipeline/references/verification-gate.md` §Journey registry): per
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

Needs you: {N} remaining · {ci_state} · {plans_pending} plan(s) to approve · {hopper} to plan — ~{est} min  {⚠ N proposals pending, if any} {⚠ N journey stamps missing/stale, if any}
{🔁 {lane}: {N} queued — collapsed; still this sitting · omit line if no queue lane}
🤖 Loop:   {ready_beads} beads + {loop_ready_plans} plans flowing autonomously{, {in_progress} in-flight} — you don't touch these

⚡ {one-line sequence note IF reordering is warranted — e.g. "approve plan X before promoting pool, it unblocks 3 items"; omit if order is fine}
```

The first line is the whole sit-down in one glance (lead with it). Rough the `~{est} min` from item counts (decision ≈ 1–2 min, plan approve ≈ 2 min, CI ≈ 5). No analysis theater — the `⚡` line appears only when there's a real sequencing call to make.

**`{N} remaining` EXCLUDES collapsed lane members, and `~{est} min` never prices a lane.** Folding 82 curator rows into the headline makes the sit-down look unsurvivable; count them on the `🔁` line instead. The lane is still this sitting — after independent P0/P1s, drive it. Concretely: 143 open `human-gate` of which 82 are one lane reads as **"Needs you: 61 remaining"** plus `🔁 curator-escalation: 82 queued`.

---

## Phase 4: The Three Tiers (silver platter, exit-first)

Order = distance from a stall (tier-first); **within a tier, P0→P4 then oldest** — urgency first, then the longest-stalled item so an aging blocker can't hide behind newer arrivals. Clear what's stopped, then feed backward. Omit any empty tier.

Age is **derived, never separately queried**: every board pull this skill already makes carries `created_at` per bead — the org-wide sweep above (`br list --json --limit 1000`) AND the default single-project board pull (via `ac-pipeline/references/board-scan.md`). Compute `now − created_at` from whichever pull feeds the docket and render it as a compact age token (e.g. `12d`) on each bead line — add no new `br` invocation.

```
### 🔴 Blocking — the line has stopped ({N})
   For each: {what} · {one-line memo/why} · → {action}
   • 🔁 {lane label} — {N} queued (oldest {age})            → work the queue
     (queue lanes collapse to ONE line — never itemize; still this sitting)
   • 🔁 Run the curator sitting — {N} queued (oldest {age}) → tap into the supervised sitting (bd-8yhvb)
     (the SAME lane line, ELEVATED — renders INSTEAD of the one above once >=20 queued or oldest >21 days; never both)
   • {bead id} {age} {decision title} — {memo summary}      → decide        (tap-ready)
     (verified: {today} — stamp dated today, so the memo is trusted as-is)
   • {bead id} {age} {decision title} — {memo summary}      ⚠ stale — reverify
     (verified: {2026-08-14}, today is {2026-08-17} — re-read the live state, re-stamp, then decide)
   • {bead id} {age} {decision title} — {memo summary}      ⚠ never verified — reverify
     (no verified: stamp on the bead at all — absence is not freshness)
   • {bead id} {age} {decision title} ⚠ no memo             → frame, then decide
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

**Present the next item — do not pick a subset.** Immediately open the single most-urgent remaining item (P0→P4, oldest first; independent gates before a collapsed lane). Put **Done** on that item's prompt as the escape (`Stop — leftover stays on the docket`). Never build a 4-option "which would you like" menu that omits the rest of the docket. Freshen / apply-proposals stay as optional buttons on the item prompt only when those signals are live — they do not replace the next docket item.

**Per item type — present, then one tap:**

- **🔴 Decision (human-gate bead) — check the memo first:** a tap-able decision needs a *pre-staged memo* — context · options with trade-offs · a recommendation (the `-t decision` contract in `beads-standards/reference/bead-conventions.md`). Assess the bead's description + comments:
    - **Memo present** → show it in 2–4 lines, then put its **options as buttons**, recommendation first + `(Recommended)`:
      ```
      AskUserQuestion(question: "{decision title}", options: [{option A (Recommended)}, {B}, {C}, {Defer}, {Done}])
      ```
    - **Memo missing/thin** (a bare "CRAIG: decide X" with no options) → it is **not tap-ready; do NOT fake buttons.** Surface it as `⚠ no memo` and offer:
      ```
      AskUserQuestion(question: "{title} has no decision memo. Handle how?", options: [
        { label: "Frame it now (Recommended)", description: "I research the fork + draft options + a recommendation, then you tap" },
        { label: "Decide raw",                 description: "Skip the memo — tell me the call directly" },
        { label: "Skip",                        description: "Leave it for later" },
        { label: "Done",                        description: "Stop — leftover stays on the docket" } ])
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
- **🔴 Curator lane, ELEVATED — auto-advance INTO the sitting, don't merely render it:** once the lane crosses the serving policy (`>=20` queued or oldest >21 days), `Run the curator sitting — {N} queued` is a first-class item in this auto-advance order, taken in position right after the lane's own itemized P0/P1s — not a footnote left on the board. One tap: `AskUserQuestion(question: "Curator lane: {N} queued (oldest {age}). Run the supervised sitting?", options: ["Run it now (Recommended)", "Work the top {n} only", "Skip"])`. On tap → drive `bd-8yhvb`'s supervised batch flow, then resume auto-advance with `{N} remaining` recomputed. A rendered tap the loop never reaches is the exact failure this line exists to prevent.
- **🔴 PRs — batch the trivial:** dependabot/grouped bumps → ONE prompt ("Merge the N green dependabot PRs?"), not N. Substantive PRs → one each.
- **🔴 CI / prod:** summarize the failure in a line, then `AskUserQuestion`: "Investigate now / File a bead / Skip."
- **🟡 Plan:** show a tight summary (outcome · scope · top risk), then `AskUserQuestion`: "Approve → loop-ready / Send to refine / Skip." Approve sets `loop-ready` in frontmatter — the plan **leaves this view** (the loop now beadifies + implements it). Refine → `/ac-plan-refine-internal {path}`.
- **🟢 Hopper** (only once 🔴/🟡 are clear, or the human jumps here): `AskUserQuestion` to pick which `active/` item to plan (→ `/ac-plan-init`), approve/discard a triage candidate, or promote the pool (→ `/ac-align`).

**Approve-then-diff capture:** when a decision or plan approval follows the human editing
or correcting the deliverable first (a reframed memo, a re-scoped plan) — diff what was
drafted against what was kept *before* closing the item. Hand that diff to `reflect` as a
lesson candidate (routed through its normal type/domain taxonomy and gates). It's the
cheapest, highest-signal capture channel in the session — don't close the gate and lose it.

**Auto-advance:** after each action, confirm the result + ripple + `{N} remaining`, then immediately present the next most-urgent item — never re-render the whole dashboard mid-flow, never offer a subset picker. Stop only when the human picks "Done" or every tier is empty.

**Migration duty:** any human-pending item found in a legacy file scan (e.g. `_backlog-manual/`, plan `needs-approval`) that is NOT yet a bead → convert to a `human-gate` bead (`-t decision` for choices, `-t task` for manual actions) so the docket stays the system of record. File scans are a safety net, not the source of truth.

---

## Phase 6: Hand-off

When the human taps **Done** and docket items remain: leftover stays `human-gate` by default. Report `{N} remaining`. Offer:

```
AskUserQuestion(question: "{N} remaining on the docket.", header: "Hand-off", options: [
  { label: "Leave on docket (Recommended)", description: "Next sitting sees the same list, shorter" },
  { label: "Mark some loop-eligible", description: "You name them; I strip human-gate — never auto-strip" },
  { label: "Start /ac-loop", description: "Ship whatever is already loop-side" } ])
```

If the docket is empty, point at what now flows autonomously:

```
✅ Gates cleared. The loop will pick up {ready_beads} beads + {loop_ready_plans} loop-ready plans on its next run.
```

and offer Start /ac-loop vs leave-for-schedule.

---

## Principles

1. **The loop boundary is sacred** — never surface ready beads that lack a docket label, in-flight waves, or loop-ready plans. Ready + a docket label stays here.
2. **Exit-first ordering** — clear what's stalled (🔴), then feed the builders (🟡), then stock the hopper (🟢). Distance from a stall, not category neatness.
3. **Docket in, docket out** — if it is on the docket, present it in urgency order (P0→P4, oldest first). The human decides act / defer / send-to-loop. Never drop, demote, or close a sitting because the list is long. Lead with "needs you" + remaining count. If a tier is empty, say so and move on.
4. **Tap, not type** — every action is a button (`AskUserQuestion`), never "tell me your choice." Decisions show the memo's options with the recommendation pre-marked; the human taps and you execute. Batch the trivial (dependabot PRs, chores) into one tap.
5. **Drive, don't dump** — render the board, then *conduct* it: act on one item, confirm the ripple, auto-advance to the next. Don't print a wall and wait.
6. **Writes are gated** — tidy/align/approve/promote are offered and confirmed, never silent (except headless runs). Freshen is an in-loop action, not an upfront gate — show the board first.
7. **Capture is a separate moment** — parking a new idea is `/ac-backlog`, not this session.
8. **The docket is the system of record** — migrate stray human-pending file items into `human-gate` beads as you find them.

---

_The human command center. To capture an idea: `/ac-backlog`. To ship autonomously: `/ac-loop`. To just SEE the whole board (read-only, loop side included): `/ac-dashboard`._
