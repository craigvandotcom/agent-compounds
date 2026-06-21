---
name: ac-human-session
description: The human command center — sit down and keep the factory moving. Surfaces only work at a human gate, on a silver platter, exit-first: clear blockers, approve plans, stock the planning hopper. Optional gated tidy/align pre-pass; hands off to the loop. Absorbs the old ac-next funnel view. Triggers: 'human session', 'what needs me', 'sit down', 'unblock work', 'my action items', "what's blocked on me", 'keep the factory moving', 'human next'.
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

## Phase 1: Freshen the Board (gated, optional)

A stale or off-strategy board makes the docket noisy and the hopper wrong. Offer to freshen first — **these are writes, so confirm; never run them silently** (exception: headless/scheduled runs skip the offer and go straight to Phase 2 read-only):

```
AskUserQuestion(
  questions: [{
    question: "Freshen the board before we start?",
    header: "Pre-pass",
    multiSelect: true,
    options: [
      { label: "Tidy (Recommended)", description: "/ac-tidy — archive done items, reconcile pipeline state" },
      { label: "Align", description: "/ac-align — reconcile to strategy + promote pool → active if active is thin" },
      { label: "Skip — straight to the board", description: "Scan as-is" }
    ]
  }]
)
```

Run the chosen pre-passes (tidy before align), then proceed.

---

## Phase 2: Scan (parallel), then apply the loop boundary

**Read the board per `_shared/board-scan.md`** (scans A beads · B plans · C backlog) — the shared pipeline read. Apply the human-session lens below, add the non-board reads, then **filter out everything past the loop boundary before presenting** (drop ready beads, in-flight waves, `loop-ready` plans — the loop owns those).

### Your lens on the board

- **🔴 Decision Docket (PRIMARY)** = board beads with the `human-gate` label, open. The first-class channel for human-required work — pre-staged with a memo (context, options + trade-offs, recommendation); agents enrich but **never** close them, so they survive every autonomous sweep until the human decides. Covers decision beads (`-t decision`) **and dream proposals** (`dream-proposal` beads carry `human-gate` too — the memo is the proposal file). (`qa-blocker` is a *merge* gate, agent-resolvable — NOT human-gate, so it never appears here.)
- **🟡 Plans awaiting sign-off** = board plans with `status: draft | refined` and **NOT** `loop-ready`. Most-invested first. (Drop every `loop-ready` plan — the loop owns it.)
- **🟢 Hopper** = board backlog: `active/` items `status: captured` with no plan yet → `/ac-plan-init`; `status: candidate` items (triage-promoted) → approve into the pool (`→ captured`) or discard; `pool/` count → `/ac-align` promote, **only if `active/` is thin**.
- **Loop awareness (count only)** = board ready beads + `loop-ready` plans + in-progress waves → a single header line, never itemized (tells the human the factory is running).

### Extend the docket org-wide

The Decision Docket is the org's single place to action decisions. At org level (root / software-lead session) or asked "across everything", sweep ALL `.beads/` repos, not just this one:

```bash
for repo in ~/Repos ~/Repos/neometa/software/agent-compounds \
            $(while IFS= read -r a; do echo ~/Repos/neometa/software/$a; done < ~/Repos/infrastructure/apps.list); do
  [ -d "$repo/.beads" ] || continue
  (cd "$repo" && br list --json 2>/dev/null) | \
    jq --arg repo "$(basename $repo)" '[.[] | select(.labels // [] | index("human-gate")) | select(.status != "closed") | . + {repo: $repo}]'
done
```

### Non-board reads (session-specific — not in board-scan)

```bash
gh pr list --state open --json number,title,createdAt,labels 2>/dev/null   # 🔴 PRs needing review/merge
gh run list --limit 3 --json status,conclusion,name,createdAt 2>/dev/null  # 🔴 failed CI
curl -s -o /dev/null -w "%{http_code}" https://www.eat.zone 2>/dev/null    # 🔴 prod health
```

Also flag open beads explicitly blocked on a human (notes "waiting on" / "needs manual" / "requires account" / "human decision") that aren't already `human-gate`.

---

## Phase 3: Situational-Awareness Header

Salvaged from the old `ac-next` funnel view — give the human the whole board at a glance before the actions:

```
## Command Center — {project | org-wide}

Funnel:  {active_ready} ready-to-plan · {plans_pending} plans awaiting you · {pool} pooled · {docket} decisions
🤖 Loop:  {ready_beads} beads + {loop_ready_plans} plans flowing autonomously{, {in_progress} in-flight}

⚡ {one-line sequence note IF reordering is warranted — e.g. "approve plan X before promoting pool, it unblocks 3 items"; omit if order is fine}
```

No analysis theater. The `⚡` line appears only when there's a real sequencing call to make.

---

## Phase 4: The Three Tiers (silver platter, exit-first)

Order = distance from a stall: clear what's stopped, then feed backward. Omit any empty tier.

```
### 🔴 Blocking — the line has stopped ({N})
   For each: {what} · {one-line memo/why} · → {action}
   • {bead id} {decision title} — {memo summary}           → decide
   • PR #{n} {title}                                        → review/merge
   • CI {run} failed                                        → investigate
   (org-wide: group by repo)

### 🟡 Feed the builders — next batch needs your sign-off ({N})
   Plans waiting on you; approving makes them loop-ready and they leave your view.
   • {plan} [{Nr {tier} → trajectory}, touched {date}]      → approve / refine

### 🟢 Stock the hopper — what enters planning next ({N})
   • {active item} [{size}]                                 → plan
   • {triage candidate} (from {source})                    → approve into pool / discard
   • Replenish: {pool_count} pooled, active/ is thin        → promote (ac-align)
```

---

## Phase 5: Act (walk the platter)

For the chosen item, execute its silver-platter action:

- **🔴 Decision (human-gate bead):** present the memo → human states the decision → record it → execute consequences → close the bead; downstream blocked beads unblock automatically.
  ```bash
  br comments add <id> "DECISION (<human>): <choice> — <why>"
  # ...carry out consequences...
  br close <id> --reason "<what was decided/done>"
  ```
- **🔴 PR / CI / prod:** review & merge the PR, investigate the failed run, or escalate the outage.
- **🟡 Plan — approve:** present a tight summary → on approval set `loop-ready` in frontmatter (the explicit hand-off signal; the plan now leaves this view and the loop will beadify + implement it). On "needs work" → `/ac-plan-refine-internal {path}` (or `/ac-plan-clean`).
- **🟢 Hopper:** active item → `/ac-plan-init` (reference `_backlog/active/{file}`); replenish → `/ac-align` (promote `pool → active`); triage candidate → approve into the pool (keep) or discard.

**Migration duty:** any human-pending item found in a legacy file scan (e.g. `_backlog-manual/`, plan `needs-approval`) that is NOT yet a bead → convert to a `human-gate` bead (`-t decision` for choices, `-t task` for manual actions) so the docket stays the system of record. File scans are a safety net, not the source of truth.

---

## Phase 6: Hand-off

Close the session by pointing at what now flows autonomously:

```
✅ Gates cleared. The loop will pick up {ready_beads} beads + {loop_ready_plans} loop-ready plans on its next run.
```

If anything was just unblocked or signed off, offer to kick the loop now:

```
AskUserQuestion(
  questions: [{
    question: "Start the autonomous loop now?",
    header: "Hand-off",
    options: [
      { label: "Start /ac-loop", description: "Ship the now-ready work autonomously" },
      { label: "Leave it for the schedule", description: "The loop will pick it up on its next scheduled run" }
    ]
  }]
)
```

---

## Principles

1. **The loop boundary is sacred** — never surface ready beads, in-flight waves, or loop-ready plans. If the loop can handle it, it's not your concern.
2. **Exit-first ordering** — clear what's stalled (🔴), then feed the builders (🟡), then stock the hopper (🟢). Distance from a stall, not category neatness.
3. **Human time is scarce** — only surface what genuinely needs a human. If a tier is empty, say so and move on. No nag.
4. **Silver platter** — every item carries its one-click next action; the human decides, you execute.
5. **Writes are gated** — tidy/align/approve/promote are offered and confirmed, never silent (except headless runs).
6. **Capture is a separate moment** — parking a new idea is `/ac-backlog`, not this session.
7. **The docket is the system of record** — migrate stray human-pending file items into `human-gate` beads as you find them.

---

_The human command center. To capture an idea: `/ac-backlog`. To ship autonomously: `/ac-loop`. To run the agent pipeline: `/ac-pipeline`._
