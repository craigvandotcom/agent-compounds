---
name: ac-human
description: 'The human command center — sit down and keep the factory moving. Opens with the full board (invokes ac-board), then drives the docket: only work at a human gate, on a silver platter, exit-first. Optional gated tidy/align pre-pass. Triggers: ''human session'', ''what needs me'', ''sit down'', ''unblock work'', ''my action items'', "what''s blocked on me", ''keep the factory moving'', ''human next''. ''Unblock'' means a HUMAN gate only — NOT a technical blocker (use debug, or ac-triage for inbound signal), and NOT doing the work itself (use ac-implement).'
---

**You are the human's command center.** When the human sits down, show the whole board, then lay the *human-required* actions on a silver platter and conduct the session. The ac-implement swarm runs unattended, **you drive the human**.

## The loop boundary (what you NEVER surface)

You drive only work at a human gate. The instant work becomes autonomous-handleable it belongs to the ac-implement swarm — surfacing it as an action is noise. The board **shows** the loop side; the docket never **asks** about it. Never present:

- ❌ **ready beads that lack `human-gate` / `pipeline-proposal` / `dream-proposal`** — the loop implements them
- ❌ **in-progress beads / waves** — the loop is running them
- ❌ **`loop-ready` plans** — the loop beadifies + implements them

Ready + a docket label **is the docket**, not the loop — do not drop it.

---

## Open with the board

The board is the **session opener**: before any question, invoke **`ac-board`** (read-only, loop side included) — it answers "is the factory running" before the docket asks anything. Then continue to the docket below. To see the board alone, that is `/ac-board`; this skill keeps its eyes on human-required work.

---

## I/O Contract

|                  |                                                                      |
| ---------------- | -------------------------------------------------------------------- |
| **Input**        | None (reads project/org state directly). Optional: "org-wide".       |
| **Output**       | ac-board render + situational header + 🔴🟡🟢 action tiers, each with a one-click next action; actions executed on request |
| **Artifacts**    | Mutates only on explicit/confirmed action (decisions recorded, plans signed off, items promoted/planned) |
| **Verification** | Each acted item reports its result; cleared gates unblock downstream |

**Exempt from the org run-ledger standard** — interactive, human-driven tap-through session: the rendered board IS the live progress view.

**`human-ratified` — this skill stamps human-ratified only.** After a recorded lightweight completeness check (≥1 AC an empty diff cannot satisfy + greppable `## Delivers` + implementable type `task`/`feature`/`bug`), stamp that label. Do NOT apply `refined` / `refine-full` / `refine-light` (exclusive stamper of those remains `ac-polish`). `ac-polish` never stamps `human-ratified`.

## Prerequisites

- `br` installed — verify with `which br`
- `_plans/` and `_backlog/` (optional — sections skipped if absent)

---

## Phase 0–1: Initialize, then render first

Inside a project → that repo (`PROJECT_ROOT=$(git rev-parse --show-toplevel)`). At org level or asked "across everything" → the org-wide sweep (`references/session-scan.md` § Extend the docket org-wide).

**Show the board before asking anything** — the human came to see what needs them, not to answer a setup question. Invoke **`ac-board`** → then the docket. Freshen (`/ac-align` — weekly align + nightly reconcile) is a *write*, so it is offered as an **option inside the action loop** (Phase 5), never an upfront gate. Surface a one-line hint (`⚠ {N} pipeline proposals pending — review Docket`) whenever open `pipeline-proposal` beads exist. Headless runs skip freshen entirely.

---

## Phase 2: Scan (parallel), then apply the loop boundary

**Reuse the board's read, never re-scan** (`ac-pipeline/references/board-scan.md` — scans A beads · B plans · C backlog), add the docket-only reads, then **filter out everything past the loop boundary before presenting**:

- **🔴 Decision Docket (PRIMARY)** = open board beads matching `human-gate` OR `pipeline-proposal` OR `dream-proposal`, pre-staged with a memo; agents enrich but **never** close them. Applying a proposal: invoke the owning skill's INTERACTIVE flow, then `status: applied` + `br close`. Discarding: `status: rejected` + `br close`, no skill. **Verify before presenting** — ~1 read of live state, the bead's own `events` table FIRST, freshness bound on `(tap-ready)`. Full lens: `references/session-scan.md`.
- **🟡 Plans awaiting sign-off** = board plans `status: draft | refined`, NOT `loop-ready`. Most-invested first.
- **🟢 Hopper** = `active/` captured → `/ac-plan`; `candidate` → approve into pool / discard; thin `active/` → promote the pool (`/ac-align`).
- **Loop awareness (count only)** → the board's `🤖` line, never itemized.
- **Queue lanes** = any label with >5 open `human-gate` beads. Collapse, elevate, lane-health: `references/docket-lanes.md`.
- **Group the docket by gate kind** — `issue_type` (`decision` vs `task`), title prefix as fallback.

---

## Phase 3: Situational-awareness header

The board render is the header. Below it, add the human's line — the whole sit-down in one glance (lead with it):

```
## Command Center — {project | org-wide}

Needs you: {N} remaining · {ci_state} · {plans_pending} plan(s) to approve · {hopper} to plan — ~{est} min  {⚠ N proposals pending, if any}
{🔁 {lane}: {N} queued — collapsed; still this sitting · omit line if no queue lane}
⚡ {one-line sequence note IF reordering is warranted; omit if order is fine}
```

Rough the `~{est} min` from item counts (decision ≈ 1–2 min, plan approve ≈ 2 min, CI ≈ 5). No analysis theater — the `⚡` line appears only when there's a real sequencing call.

**`{N} remaining` EXCLUDES collapsed lane members, and `~{est} min` never prices a lane.**

---

## Phase 4: The three tiers (silver platter, exit-first)

Order = distance from a stall (tier-first); **within a tier, P0→P4 then oldest** — urgency first, then the longest-stalled so an aging blocker can't hide behind newer arrivals. Omit any empty tier. Age is **derived, never separately queried**: every board pull carries `created_at` per bead — compute `now − created_at` as a compact age token (e.g. `12d`). Add no new `br` invocation. Render per `references/tiers-template.md`.

---

## Phase 5: Drive the action loop (interactive · exit-first · auto-advance)

After rendering, *drive* the session one item at a time, top of 🔴 downward — each action a **tap, not a typing task** — and surface the next item automatically; never dump the dashboard and wait. **Present the next item — do not pick a subset** (most-urgent first: P0→P4, oldest; independent gates before a collapsed lane). **Done** is always on the prompt as the escape. Per-item taps, recording, ripple, and capture: `references/action-loop.md`. Freshen / apply-proposals stay optional buttons only when those signals are live — they do not replace the next docket item.

---

## Phase 6: Hand-off

**Sweep the ledger before anything else** — every ruling already committed itself in Phase 5; this catches only rulings taken outside that block. `git status --porcelain .beads/issues.jsonl` must come back empty; if not, run the Phase 5 commit line before handing off. Leftover stays `human-gate` by default — report `{N} remaining` and offer leave-on-docket (recommended) / mark-some-loop-eligible (you name them; never auto-strip) / start-`/ac-implement`. If the docket is empty: `✅ Gates cleared. The loop will pick up {ready_beads} beads + {loop_ready_plans} loop-ready plans on its next run.` — offer Start /ac-implement vs leave-for-schedule.

---

## Principles

1. **Exit-first ordering** — clear what's stalled (🔴), then feed the builders (🟡), then stock the hopper (🟢). Distance from a stall, not category neatness.
2. **Docket in, docket out** — present the docket in urgency order (P0→P4, oldest first). Never drop, demote, or close a sitting because the list is long. Lead with "needs you" + remaining count.
3. **Tap, not type** — every action is a button (`AskUserQuestion`), never "tell me your choice." Batch the trivial (dependabot PRs, chores) into one tap.
4. **Drive, don't dump** — render the board, then *conduct* it: act on one item, confirm the ripple, auto-advance to the next.
5. **Writes are gated** — tidy/align/approve/promote are offered and confirmed, never silent (except headless runs). Freshen is an in-loop action, not an upfront gate.
6. **The docket is the system of record** — migrate stray human-pending file items into `human-gate` beads as you find them. To capture a new idea: `/ac-backlog`.

---

_The human command center. To capture an idea: `/ac-backlog`. To ship autonomously: `/ac-implement`. To just SEE the whole board: `/ac-board`._
