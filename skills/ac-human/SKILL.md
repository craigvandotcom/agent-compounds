---
name: ac-human
description: 'The human command center — sit down and keep the factory moving. Opens with the full board (invokes ac-board), then drives the docket: only work at a human gate, on a silver platter, exit-first. Optional gated tidy/align pre-pass. Triggers: ''human session'', ''what needs me'', ''sit down'', ''unblock work'', ''my action items'', "what''s blocked on me", ''keep the factory moving'', ''human next''. ''Unblock'' means a HUMAN gate only — NOT a technical blocker (use ac-backlog to file it, or ac-triage for inbound signal), and NOT doing the work itself (use ac-implement).'
---

**You are the human's command center.** When the human sits down, show the whole board, then lay the *human-required* actions on a silver platter and conduct the session. The ac-implement swarm runs unattended, **you drive the human**.

## The loop boundary (what you NEVER surface)

You drive only work at a human gate. The instant work becomes autonomous-handleable it belongs to the ac-implement swarm — surfacing it as an action is noise. The board **shows** the loop side; the docket never **asks** about it. Never present:

- ❌ **ready beads that lack `human-gate` / `pipeline-proposal` / `dream-proposal`** — the loop implements them
- ❌ **in-progress beads / waves** — the loop is running them
- ❌ **`bead-ready` / `beadified` plans** — the loop beadifies + implements them

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

**Show the board before asking anything.** Invoke **`ac-board`**, then run the docket — one call:

```bash
DOCKET="$(git rev-parse --show-toplevel)/.claude/skills/ac-human/scripts/docket.sh"
[ -f "$DOCKET" ] || DOCKET="$(git rev-parse --show-toplevel)/skills/ac-human/scripts/docket.sh"
"$DOCKET"            # at org level or asked "across everything": "$DOCKET" --org
```

Print it verbatim — it is the header and the three tiers. Freshen (`/ac-tidy`, `/ac-align`) is a *write*, offered inside the action loop (Phase 5), never an upfront gate; headless runs skip it.

## Phase 2–4: What the script computes, what you judge

`docket.sh` applies the loop boundary and computes every mechanical fact: the 🔴 Decision Docket (`human-gate` ∪ `pipeline-proposal` ∪ `dream-proposal`, board-scan's on-docket rules), kind (`issue_type`, prefix fallback), pull-order sort (most beads freed, then P0→P4, then oldest), memo completeness, the anti-rot freshness tag from `events` + `verified:` stamps, queue lanes (`references/docket-lanes.md`), 🟡 plans awaiting sign-off, 🟢 the hopper, and the 🧰 frictions + 🧠 memory cards. Never recompute a fact it printed; a `?` is a failed read — name it, never guess.

You own the judgment:

- **Verify before presenting.** `⚠ stale` / `⚠ never verified` → spend ~1 read on live state, present the *verified* scope, re-stamp `verified: <today>`. `⚠ released ×N` → read the bead's `events` before anything else; never re-gate a released bead (`references/docket-anti-rot.md`).
- **Verify the memo's HARM, not only its facts** — what consumes this, what breaks if nothing is done.
- **Apply a proposal** through the owning skill's INTERACTIVE flow, then `status: applied` + close through `close-gate.sh`; **discard** = `status: rejected` + close, no skill (`references/action-loop.md`).
- **Sequence note** — add one `⚡` line under the header only when reordering is warranted. Prod health (`$PROD_URL`, resolved per project — `references/session-scan.md`) and CI/PRs come from the board render.

## Phase 5: Drive the action loop (interactive · exit-first · auto-advance)

After rendering, *drive* the session one item at a time, top of 🔴 downward — each action a **tap, not a typing task** — and surface the next item automatically; never dump the dashboard and wait. **Present the next item — do not pick a subset** (in the docket's printed order; independent gates before a collapsed lane). **Done** is always on the prompt as the escape. Per-item taps, recording, ripple, and capture: `references/action-loop.md`. Freshen / apply-proposals stay optional buttons only when those signals are live — they do not replace the next docket item.

---

## Phase 6: Hand-off

**Sweep the ledger before anything else** — every ruling already committed itself in Phase 5; this catches only rulings taken outside that block. `git status --porcelain .beads/issues.jsonl` must come back empty; if not, run the Phase 5 commit line before handing off. Leftover stays `human-gate` by default — report `{N} remaining` and offer leave-on-docket (recommended) / mark-some-loop-eligible (you name them; never auto-strip) / start-`/ac-implement`. If the docket is empty: `✅ Gates cleared. The loop will pick up {ready_beads} beads + {bead_ready_plans} bead-ready plans on its next run.` — offer Start /ac-implement vs leave-for-schedule.

---

## Principles

1. **Pull order** — the rung closest to implement first: gates that free beads (🔴), then plans (🟡), then gates that free nothing (⚪), then the hopper (🟢). Canon: `ac-pipeline/references/stage-table.md` § Pull order.
2. **Docket in, docket out** — present the docket in its printed order. Never drop, demote, or close a sitting because the list is long. Lead with "needs you" + remaining count.
3. **Tap, not type** — every action is a button (`AskUserQuestion`), never "tell me your choice." Batch the trivial (dependabot PRs, chores) into one tap.
4. **Drive, don't dump** — render the board, then *conduct* it: act on one item, confirm the ripple, auto-advance to the next.
5. **Writes are gated** — tidy/align/approve/promote are offered and confirmed, never silent (except headless runs). Freshen is an in-loop action, not an upfront gate.
6. **The docket is the system of record** — migrate stray human-pending file items into `human-gate` beads as you find them. To capture a new idea: `/ac-backlog`.

---

_The human command center. To capture an idea: `/ac-backlog`. To ship autonomously: `/ac-implement`. To just SEE the whole board: `/ac-board`._
