---
name: ac-human
description: 'The human command center — sit down and keep the factory moving. Renders the full board first (both sides of the loop boundary), then drives the docket: only work at a human gate, on a silver platter, exit-first. Optional gated tidy/align pre-pass. `board` mode stops after the render (read-only). Triggers: ''human session'', ''what needs me'', ''sit down'', ''unblock work'', ''my action items'', "what''s blocked on me", ''keep the factory moving'', ''human next'', ''dashboard'', ''show the board'', ''state of the pipeline'', ''pipeline status'', "what''s the factory doing", ''WIP status'', ''board overview'', ''full board''. ''Unblock'' means a HUMAN gate only — NOT a technical blocker (use debug, or ac-triage for inbound signal), and NOT doing the work itself (use ac-implement).'
---

**You are the human's command center.** When the human sits down, show the whole board, then lay the *human-required* actions on a silver platter and conduct the session. The ac-implement swarm runs unattended, **you drive the human**.

## The loop boundary (what you NEVER surface)

You drive only work at a human gate. The instant work becomes autonomous-handleable it belongs to the ac-implement swarm — surfacing it as an action is noise. The board **shows** the loop side; the docket never **asks** about it. Never present:

- ❌ **ready beads that lack `human-gate` / `pipeline-proposal` / `dream-proposal`** — the loop implements them
- ❌ **in-progress beads / waves** — the loop is running them
- ❌ **`loop-ready` plans** — the loop beadifies + implements them

Ready + a docket label **is the docket**, not the loop — do not drop it.

---

## Board mode (the dashboard — the loop boundary off)

The board is the **session opener**: before any question, render the full board per `workflows/board.md` — loop side included, read-only, no filter. It answers "is the factory running" before the docket asks anything.

Invoked as `board` (triggers: `dashboard`, `show the board`, `board overview`, `full board`, …) → render it and **stop**; it is the whole response. Invoked as a session (default) → render it, then continue to the docket below.

---

## I/O Contract

|                  |                                                                      |
| ---------------- | -------------------------------------------------------------------- |
| **Input**        | None (reads project/org state directly). Optional: "org-wide".       |
| **Output**       | Board render + situational header + 🔴🟡🟢 action tiers, each with a one-click next action; actions executed on request |
| **Artifacts**    | Mutates only on explicit/confirmed action (decisions recorded, plans signed off, items promoted/planned) |
| **Verification** | Each acted item reports its result; cleared gates unblock downstream |

**Exempt from the org run-ledger standard** — interactive, human-driven tap-through session: the rendered board IS the live progress view.

**`human-ratified` — this skill stamps human-ratified only.** After a recorded lightweight completeness check (≥1 AC an empty diff cannot satisfy + greppable `## Delivers` + implementable type `task`/`feature`/`bug`), stamp that label. Do NOT apply `refined` / `refine-full` / `refine-light` (exclusive stamper of those remains `ac-polish`). `ac-polish` never stamps `human-ratified`.

## Prerequisites

- `br` installed — verify with `which br`
- `_plans/` and `_backlog/` (optional — sections skipped if absent)

---

## Phase 0: Initialize + Scope

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

Inside a project → that repo. At org level (root / software-lead session) or asked "across everything" → org-wide sweep of every `.beads/` repo for the Decision Docket (Phase 2).

---

## Phase 1: Render first — freshen is an action, not a gate

**Show the board before asking anything** — the human came to see what needs them, not to answer a setup question. Go straight to the board render (`workflows/board.md`) → then the docket.

Freshen (`/ac-align` — weekly align + nightly reconcile) is a *write*, so it is offered as an **option inside the action loop** (Phase 5), never an upfront gate. The scheduled nightly/weekly runs file `pipeline-proposal` beads for anything needing a human — the primary staleness signal is **proposals pending in the Docket**. Surface a one-line hint (`⚠ {N} pipeline proposals pending — review Docket`) whenever open `pipeline-proposal` beads exist. Headless runs skip freshen entirely.

---

## Phase 2: Scan (parallel), then apply the loop boundary

**Read the board per `ac-pipeline/references/board-scan.md`** (scans A beads · B plans · C backlog) — the shared pipeline read. Phase 1 already did this read; **reuse it, never re-scan.** Apply the human-session lens below, add the docket-only reads, then **filter out everything past the loop boundary before presenting** (drop ready beads that lack a docket label, in-flight waves, `loop-ready` plans — the loop owns those).

### Your lens on the board

- **🔴 Decision Docket (PRIMARY)** = board beads matching `human-gate` OR `pipeline-proposal` OR `dream-proposal`, open. The first-class channel for human-required work — pre-staged with a memo (context, options + trade-offs, recommendation); agents enrich but **never** close them, so they survive every autonomous sweep until the human decides. The collector is the union, not a pairing — proposal beads do not need `human-gate` to appear. (`qa-blocker` is a *merge* gate, agent-resolvable — NOT human-gate, so it never appears here.)
  - **Applying a pipeline proposal:** invoke the owning skill (`ac-align`) in its INTERACTIVE flow. The skill's own gate re-confirms the moves against the *current* board (this late-binding re-prompt is intended, not a bug — do NOT add a bypass), then set the proposal file `status: applied` + `br close` the bead. **Verify the memo's HARM, not only its facts** — ask "what consumes this, and what breaks if I do nothing?" before working the list. A memo is an argument, not a finding.
  - **Discarding one:** set the proposal file `status: rejected` + `br close` the bead; do NOT invoke the owning skill.
  - **Verify before presenting (anti-rot):** human-gate beads outlive their work and memos freeze step-lists later waves can invalidate. Before surfacing an item, spend ~1 read confirming its live state. Present the *verified* remaining scope — often "already done → one tap to book it" — and fold corrections onto the bead as an enrichment comment. Memory: `human-gate-beads-rot-verify-before-presenting`.
    - **MANDATORY FIRST READ — the bead's own `events` table, before any other verification.** `sqlite3 .beads/beads.db "SELECT created_at,event_type,comment FROM events WHERE issue_id='<id>' ORDER BY created_at;"`. **A comment is a CLAIM; `events` is the RECORD.** `label_removed human-gate` followed by a DECISION/RULING/RELEASE comment means the bead was RELEASED — do not re-gate it, and NEVER re-gate one released more than once. Evidence: `references/docket-anti-rot.md`.
    - **FRESHNESS BOUND on `(tap-ready)` — DATE precision, three branches.** The nightly stamps a surviving gate with a `verified: <YYYY-MM-DD>` comment (`ac-align/workflows/nightly-reconcile.md`); read the newest stamp and render exactly one of three ways:
      - dated **TODAY** → `(tap-ready)`;
      - dated **earlier** → `⚠ stale — reverify` (do the ~1-read verification, re-stamp, then it is tappable);
      - **no stamp at all** → `⚠ never verified — reverify`. Absence is not freshness — never let an unstamped gate inherit `(tap-ready)`.
      "Today" is the **local calendar date** of the machine running the session. The day boundary is deliberately loose and that is not a bug: a false "stale" costs one read, the cheap direction to be wrong in.
- **🟡 Plans awaiting sign-off** = board plans with `status: draft | refined` and **NOT** `loop-ready`. Most-invested first. (Drop every `loop-ready` plan — the loop owns it.)
- **🟢 Hopper** = board backlog: `active/` items `status: captured` with no plan yet → `/ac-plan`; `status: candidate` items (triage-promoted) → approve into the pool (`→ captured`) or discard; `pool/` count → `/ac-align` promote, **only if `active/` is thin**.
- **Loop awareness (count only)** = ready beads that lack a docket label + `loop-ready` plans + in-progress waves → the board's `🤖` line, never itemized.
- **Queue lanes** — a machine-filed batch (any label with >5 open `human-gate` beads). Collapse, elevate, and lane-health policy: `references/docket-lanes.md`. Prefer a fresh `(tap-ready)` gate first, but the lane is still this sitting.
- **Group the docket by title prefix (`DECISION:` vs `ACTION:`):** the two human-gate template kinds (`beads-standards` § Human-gate template) are presented grouped — forks in one cluster (one-tap choices), do-in-the-world tasks in another (checklists to run, often with a `best-done-when` hint).

### Extend the docket org-wide

At org level or asked "across everything", sweep ALL `.beads/` repos, not just this one:

```bash
for repo in ~/Repos ~/Repos/neometa/software/agent-compounds \
            $(while IFS= read -r a; do echo ~/Repos/neometa/software/$a; done < ~/Repos/infrastructure/apps.list); do
  [ -d "$repo/.beads" ] || continue
  (cd "$repo" && br list --json --limit 0 2>/dev/null) | \
    jq --arg repo "$(basename $repo)" '[.issues[] | select((.labels // []) | (index("human-gate") or index("pipeline-proposal") or index("dream-proposal"))) | select(.status != "closed") | . + {repo: $repo}]'
done
```

### Non-board reads (session-specific — not in board-scan)

```bash
curl -s -o /dev/null -w "%{http_code}" "$PROD_URL" 2>/dev/null             # prod health
```

PRs and CI come from the board render (Phase 1) — do not re-probe them here.

**`$PROD_URL` is per-project — resolve it, never hardcode.** Read the project's live domain from its `AGENTS.md` / CORE, or the deployed alias. (BCA = `https://bodycompass.app`.) A **retired** domain must not be probed: a 🔴 that is always red trains the human to ignore the 🔴 tier (bd-vp7fw).

Also flag open beads explicitly blocked on a human (notes "waiting on" / "needs manual" / "requires account" / "human decision") that aren't already `human-gate`.

---

## Phase 3: Situational-Awareness Header

The board render is the header. Below it, add the human's line — the whole sit-down in one glance (lead with it):

```
## Command Center — {project | org-wide}

Needs you: {N} remaining · {ci_state} · {plans_pending} plan(s) to approve · {hopper} to plan — ~{est} min  {⚠ N proposals pending, if any}
{🔁 {lane}: {N} queued — collapsed; still this sitting · omit line if no queue lane}
⚡ {one-line sequence note IF reordering is warranted; omit if order is fine}
```

Rough the `~{est} min` from item counts (decision ≈ 1–2 min, plan approve ≈ 2 min, CI ≈ 5). No analysis theater — the `⚡` line appears only when there's a real sequencing call.

**`{N} remaining` EXCLUDES collapsed lane members, and `~{est} min` never prices a lane.** A 143-gate docket of which 82 are one lane reads as **"Needs you: 61 remaining"** plus `🔁 curator-escalation: 82 queued`.

---

## Phase 4: The Three Tiers (silver platter, exit-first)

Order = distance from a stall (tier-first); **within a tier, P0→P4 then oldest** — urgency first, then the longest-stalled so an aging blocker can't hide behind newer arrivals. Omit any empty tier.

Age is **derived, never separately queried**: every board pull carries `created_at` per bead — compute `now − created_at` and render it as a compact age token (e.g. `12d`). Add no new `br` invocation.

```
### 🔴 Blocking — the line has stopped ({N})
   For each: {what} · {one-line memo/why} · → {action}
   • 🔁 {lane label} — {N} queued (oldest {age})            → work the queue
   • 🔁 Run the curator sitting — {N} queued (oldest {age}) → tap into the supervised sitting (bd-8yhvb)
     (the SAME lane line, ELEVATED — renders INSTEAD of the one above once >=20 queued or oldest >21 days; never both)
   • {bead id} {age} {decision title} — {memo summary}      → decide        (tap-ready)
   • {bead id} {age} {decision title} — {memo summary}      ⚠ stale — reverify
   • {bead id} {age} {decision title} — {memo summary}      ⚠ never verified — reverify
   • {bead id} {age} {decision title} ⚠ no memo             → frame, then decide
   • CI {run} failed                                        → investigate
   • {N} dependabot/grouped PRs                             → review as ONE batch
   • PR #{n} {substantive title}                            → review/merge (one each)
   • {journey} review-critical — stamp missing/stale         → run QA drive (ac-qa/ac-qa)
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

**Present the next item — do not pick a subset.** Open the single most-urgent remaining item (P0→P4, oldest first; independent gates before a collapsed lane). Put **Done** on its prompt as the escape (`Stop — leftover stays on the docket`). Never build a 4-option "which would you like" menu that omits the rest of the docket. Freshen / apply-proposals stay as optional buttons only when those signals are live — they do not replace the next docket item.

**Per item type — present, then one tap:**

- **🔴 Decision (human-gate bead) — check the memo first:** a tap-able decision needs a *pre-staged memo* — context · options with trade-offs · a recommendation (the `-t decision` contract in `beads-standards/reference/bead-conventions.md`):
    - **Fork card incomplete — BOUNCE, never present:** a `DECISION:` card lacking any of `evidence:` / `consequence:` / `recommendation:` is refused at the tap — label `gate-incomplete`, comment naming the missing line, `human-gate` kept — and it renders `⚠ gate-incomplete`.
    - **Memo present** → show it in 2–4 lines, then put its **options as buttons**, recommendation first + `(Recommended)`:
      ```
      AskUserQuestion(question: "{decision title}", options: [{option A (Recommended)}, {B}, {C}, {Defer}, {Done}])
      ```
    - **Memo missing/thin** (a bare "CRAIG: decide X" with no options) → it is **not tap-ready; do NOT fake buttons.** Surface it as `⚠ no memo` and offer: `Frame it now` (research + write the memo onto the bead, then present options) / `Decide raw` / `Skip` / `Done`. The dashboard **self-heals** bare beads into tap-ready ones.
  On tap (either path) → record + execute + close + **confirm the ripple**, then auto-advance:
  ```bash
  br comments add <id> "DECISION (<human>): <choice> — <why>"
  # ...carry out consequences...
  br close <id> --reason "<what was decided/done>"
  br sync --flush-only && git add .beads/issues.jsonl \
    && git commit -m "chore(beads): human ruling on <id> [no-bead]" && git push
  ```
  **Commit the ledger on the same tap that records the ruling** — an uncommitted ledger is not a durable decision, and a later job reading `origin/main` will overwrite it (`beads-standards` § Working cadence). Push failure is not a stall: the local commit is durable, report it and carry on.
  Report: `✓ closed bd-<id> — unblocked bd-<x>, bd-<y>`.
  **Upstream is the real fix:** decision beads should *arrive* pre-staged. If a filer keeps shipping bare decisions, fix the filer, not just the symptom here.
- **🔴 Curator lane, ELEVATED — auto-advance INTO the sitting:** once the lane crosses the serving policy (`references/docket-lanes.md`), it is a first-class item, right after its own itemized P0/P1s. One tap: `AskUserQuestion(question: "Curator lane: {N} queued (oldest {age}). Run the supervised sitting?", options: ["Run it now (Recommended)", "Work the top {n} only", "Skip"])`. On tap → drive `bd-8yhvb`'s supervised batch flow, then resume auto-advance.
- **🔴 PRs — batch the trivial:** dependabot/grouped bumps → ONE prompt ("Merge the N green dependabot PRs?"), not N. Substantive PRs → one each.
- **🔴 CI / prod:** summarize the failure in a line, then `AskUserQuestion`: "Investigate now / File a bead / Skip."
- **🟡 Plan:** show a tight summary (outcome · scope · top risk), then `AskUserQuestion`: "Approve → loop-ready / Send to refine / Skip." Approve writes any answer the human gave in the tap into the plan as `DECISION (<human>): …` before running `skills/_tools/plan-approve.sh <plan-path>` — the ONE writer of approval, never a hand edit of the frontmatter; the plan **leaves this view**. Refine → `/ac-polish {path}`.
- **🟢 Hopper** (only once 🔴/🟡 are clear, or the human jumps here): `AskUserQuestion` to pick which `active/` item to plan (→ `/ac-plan`), approve/discard a triage candidate, or promote the pool (→ `/ac-align`).

**Approve-then-diff capture:** when a decision or plan approval follows the human first editing/correcting the deliverable, diff drafted vs kept *before* closing and hand it to `reflect` as a lesson candidate — the cheapest high-signal capture in the session.

**Auto-advance:** after each action, confirm the result + ripple + `{N} remaining`, then immediately present the next most-urgent item — never re-render the whole dashboard mid-flow, never offer a subset picker. Stop only when the human picks "Done" or every tier is empty.

**Migration duty:** any human-pending item found in a legacy file scan (e.g. `_backlog-manual/`, plan `needs-approval`) that is NOT yet a bead → convert to a `human-gate` bead (`-t decision` for choices, `-t task` for manual actions) so the docket stays the system of record. File scans are a safety net, not the source of truth.

---

## Phase 6: Hand-off

**Sweep the ledger before anything else** — every ruling already committed itself in Phase 5; this catches only rulings taken outside that block. `git status --porcelain .beads/issues.jsonl` must come back empty; if not, run the Phase 5 commit line before handing off.

When the human taps **Done** and docket items remain: leftover stays `human-gate` by default. Report `{N} remaining`. Offer:

```
AskUserQuestion(question: "{N} remaining on the docket.", header: "Hand-off", options: [
  { label: "Leave on docket (Recommended)", description: "Next sitting sees the same list, shorter" },
  { label: "Mark some loop-eligible", description: "You name them; I strip human-gate — never auto-strip" },
  { label: "Start /ac-implement", description: "Ship whatever is already loop-side" } ])
```

If the docket is empty, point at what now flows autonomously: `✅ Gates cleared. The loop will pick up {ready_beads} beads + {loop_ready_plans} loop-ready plans on its next run.` and offer Start /ac-implement vs leave-for-schedule.

---

## Principles

1. **The loop boundary is sacred** — never surface as an *action* a ready bead that lacks a docket label, an in-flight wave, or a loop-ready plan. The board shows them; the docket drives only human gates.
2. **Exit-first ordering** — clear what's stalled (🔴), then feed the builders (🟡), then stock the hopper (🟢). Distance from a stall, not category neatness.
3. **Docket in, docket out** — present the docket in urgency order (P0→P4, oldest first). Never drop, demote, or close a sitting because the list is long. Lead with "needs you" + remaining count.
4. **Tap, not type** — every action is a button (`AskUserQuestion`), never "tell me your choice." Batch the trivial (dependabot PRs, chores) into one tap.
5. **Drive, don't dump** — render the board, then *conduct* it: act on one item, confirm the ripple, auto-advance to the next.
6. **Writes are gated** — tidy/align/approve/promote are offered and confirmed, never silent (except headless runs). Freshen is an in-loop action, not an upfront gate.
7. **The docket is the system of record** — migrate stray human-pending file items into `human-gate` beads as you find them. To capture a new idea: `/ac-backlog`.

---

_The human command center. To capture an idea: `/ac-backlog`. To ship autonomously: `/ac-implement`. To just SEE the whole board: `board` mode._
