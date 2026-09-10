# Docket queue lanes — collapse the flood, never the emergency

Extracted from the spine 2026-09-10. The spine carries the pointer; this file carries the
rule. A **queue lane** is one machine-filed batch of `human-gate` beads from a single
upstream source (today: `curator-escalation`, filed 80+ at a time). Detect it mechanically:
**any label carrying >5 open `human-gate` beads.**

## Three rules, in order

### 1. Collapse >5 to ONE line — presentation only

Render the lane as `lane · count · oldest age · its batch action` and **never itemize its
P2+ members**. Collapse is presentation, not deferral: the lane line **is work in this
sitting** — after independent P0/P1s, auto-advance into it.

### 2. P0/P1 are NEVER collapsed

Itemize P0/P1 members individually **above** the lane line, then **subtract them from its
count**. A lane label is a *filing* channel, not a statement of importance: the same label
lands both a bulk batch and the P0 that batch was filed to fix. Caught live: a naive
whole-label collapse would have hidden `bd-8yhvb` (**P0**, the frozen-lane bug) plus three
P1s inside an 82-bead flood — strictly worse than the flood itself.

```
• bd-8yhvb 4d P0 Curator escalations UNRELEASABLE — …   → decide   (P0/P1 stay itemized)
🔁 curator-escalation — 89 more queued (oldest 4d)      → work the queue
```

### 3. Elevated tap — SERVING POLICY (additive to rule 1, never a replacement)

Two thresholds answer different questions. `>5` decides whether the lane **collapses** to one
line. **`>=20` open members OR oldest member older than 21 days** decides whether that one
line is **elevated to a first-class tap** (Phase 4, above 🟢). A 30-bead lane is both
collapsed *and* elevated; a 7-bead lane is collapsed and plain. One threshold never rewrites
the other.

Over the line, render the elevated tap (`Run the curator sitting — {N} queued`) and nudge
**`bd-8yhvb`** — the supervised batch-sitting bead that owns working a curator lane down — so
the human taps into the supervised flow instead of grinding rows one at a time.

## Two lane-health checks

A flood hides its own defects — run both when you render the line:

- **Unreadable titles are a FILING DEFECT.** A docket bead whose title carries a raw
  uuid/hash instead of its human subject (`Legacy escalation: hold 6f390127-…`) cannot be
  triaged by a human at all. If >5 in a lane look like this, say so on the line and offer a
  re-title pass — the subject is usually recoverable from the body or the source system.
  **Fix the FILER too, not just the rows.**
- **A lane filed before a governing policy was ratified is STALE BY CONSTRUCTION.** If a
  rule landed after the lane was filed, some members are now auto-resolvable and do not
  belong on the docket. State the fraction expected to survive re-triage rather than
  presenting the raw count as all real human work.

## Why

A single supervised conversion took the docket from 61 to 143 in one command (2026-07-30).
Itemised, the ~15 real gates became unfindable. The beads were legitimate — they made
invisible work visible — so suppressing them is wrong and itemising them is also wrong.
**Collapsing is the only honest option.**
