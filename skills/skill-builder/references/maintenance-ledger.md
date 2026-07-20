# The per-skill MAINTENANCE.md ledger

## ToC
- What it is / is NOT (the risk-tier boundary)
- The four sections + template
- Lifecycle (who writes, who reads, forcing functions)
- Placement, cost, guards

## What it is — and the boundary that keeps it legitimate

`skills/<name>/MAINTENANCE.md` is a per-skill **shape-hygiene work-surface**: the home for the
low-risk, long-tail signal about a skill's *structure* that no existing store owns well. It is a
sidecar — **never loaded with SKILL.md** (zero standing token cost; read only during a hygiene pass
or when depositing signal).

It exists because skill signal splits into two risk tiers, and the two need different channels:

| Tier | What it is | Channel | Gate |
|---|---|---|---|
| **Behavior / enforcement** | changes what the skill DOES — a new gate, a changed branch, a contract fix | `skill-improvement` **bead** (reflect's existing route), labelled `skill:<name>` | **human merge** (unchanged) |
| **Shape / structure** | changes how the skill is SHAPED — dedup, sediment, extraction, buried triggers, near-dups, content-in-limbo | **this file** | **deterministic** — agent-applied under `validate-skill.sh` `--diff`/pointer + the validator survival-gate; NO human gate |

**This is NOT:** a knowledge store (lessons still route to the memory substrate via `reflect` /
`context-engineering`), a behavior-change queue (that is beads + the human gate), or a diary. If a
would-be entry changes what the skill *does*, it is mis-filed — route it to a `skill:<name>`
`skill-improvement` bead instead. The discriminator is always **behavior vs shape.**

## The four sections (+ template)

```markdown
---
skill: <name>
archetype: orchestrator | knowledge | hybrid
last_pass: <YYYY-MM-DD or "never">
spine_lines: <n> / target <≤500 orch | ≤400 knowledge>
---

# <name> — maintenance ledger

## Health
<one line: on-target / over by N / N open shape items / M open skill:<name> behavior beads (see `br list -l skill:<name>`)>

## Inbox — shape signal awaiting triage
<!-- Behavior-changing signal does NOT go here — it goes to a skill:<name> skill-improvement bead. -->
- [YYYY-MM-DD · src:loop RUN_ID | audit | reflect | human] <the shape observation>

## Holding pen — content pulled from SKILL.md, disposition undecided
- [pulled YYYY-MM-DD · from §X · review-by YYYY-MM-DD · default: delete|extract→ref|reinstate]
  <the verbatim content>
  — uncertainty: <why it's parked>

## Cut-log — append-only audit trail (feeds the churn detector)
- [YYYY-MM-DD] CUT "<snippet>" — reason: <sediment|dead|stale> — <hard-delete | relocated→references/incidents.md | relocated→memory:<key>>
- [YYYY-MM-DD] EXTRACTED §X → references/<y>.md (or _shared/<y>.md)
- [YYYY-MM-DD] REINSTATED "<snippet>" — churn: added/removed <N>× — resolution: promoted→enforcement | _shared
```

- **Inbox** is the next pass's agenda (shape only). Its behavior-tier counterpart lives in beads —
  the Health line links to it, this file never copies it.
- **Holding pen** is **tier 3 of the promotion ladder** (`references/promotion-ladder.md`) — the
  timed quarantine that unique content passes through before deletion, so knowledge is never silently
  lost. Every item carries a `review-by` date + a `default` resolution (`promote`|`delete`). A pass
  that finds an expired item MUST resolve it: reclaimed/re-added → it churns back up per the ladder's
  proof rules; unclaimed past `review-by` with no churn → **git-delete with a Cut-log entry** (the
  conservation record). Genuine behavior forks escalate to a `skill:<name>` decision bead instead.
- **Cut-log** is the prose "why" that git history can't express; `git log -S` supplies the "how many
  times." Together they are the churn detector.

## Lifecycle & forcing functions (why it won't rot)

- **Signal in:** `reflect` (and the loop's friction carrier), when a session produces skill signal,
  risk-triages it — behavior → `skill:<name>` skill-improvement bead (as today); **shape → append to
  this Inbox.** Low ceremony (one line), co-located with the shared skill so it travels across every
  app (fixes the cross-repo blindness of the bead-only route).
- **Signal triaged:** a `hygiene-pass` MUST read all four sections as input, and **emptying the Inbox
  is part of its definition-of-done** — every item resolved (applied / extracted / deleted /
  relocated) or explicitly deferred with a reason. Outcomes append to the Cut-log.
- **Auto-apply is bounded to the shape tier:** the pass may agent-apply Inbox/holding-pen items
  WITHOUT a human gate ONLY after `validate-skill.sh --diff <ref>` proves no enforcement line
  vanished and the validator survival-gate passes. Anything the pass judges behavioral gets kicked to
  a bead, not applied.

## Placement, cost, guards

- **Lives in** `agent-compounds/skills/<name>/MAINTENANCE.md` (canonical, versioned with the skill,
  shared across apps). App-specific frictions still land here — they are signal about the shared skill.
- **Lazy creation** — created on first deposited signal or first hygiene pass; skills with no signal
  have no ledger (no empty-file sprawl).
- **Excluded from the pointer graph** — it is intentionally not pointed-to from SKILL.md;
  `validate-skill.sh`'s orphan check skips `MAINTENANCE.md` by name.
- **Never loaded with SKILL.md** — not referenced from the spine; it is a maintenance sidecar, not a
  reference the skill's runtime consumes.
