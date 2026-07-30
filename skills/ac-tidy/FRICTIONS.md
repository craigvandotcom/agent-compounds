---
skill: ac-tidy
created: 2026-07-30
last_pass: 2026-07-30
entries: 3
---

# ac-tidy — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

## raw-count-escalated-as-if-it-were-debt
- skills: [ac-tidy]
- impact: L
- frequency: frequent
- recurrence: 1
- related: [class-harm-escalated-without-verifying-any-consumer]
- first_seen: 2026-07-22
- last_seen: 2026-07-30
- stage: ac-tidy
- status: promoted
- proposed_fix: never escalate a bare total — report the lane's age distribution and escalate ONLY the actionable subset; empty subset means one line and no bead.
- narrative: the Phase-4 finding-bead prune escalated the raw open count of the finding lane
  across four consecutive nightlies (55 to 73 to 72 to 102) and produced ZERO action in eight
  days. A count answers no question a human can act on, so each escalation was pure docket
  residence, and a number that only rises trains the reader to ignore the lane — strictly worse
  than not reporting it. Compounding it, the memo's premise was false: measured, only 1 of 102
  open findings carried any evidence of a merged fix, so the "stale bookkeeping to be pruned"
  framing was wrong and an auto-pruner would have had nothing to close. Fixed in
  agent-compounds 4d8ec80 after Craig ruled A+D on bd-8ms5t.

## class-harm-escalated-without-verifying-any-consumer
- skills: [ac-tidy]
- impact: L
- frequency: occasional
- recurrence: 1
- related: [raw-count-escalated-as-if-it-were-debt]
- first_seen: 2026-07-20
- last_seen: 2026-07-30
- stage: ac-tidy
- status: promoted
- proposed_fix: before escalating a structural-lint class to the human docket, grep for what actually CONSUMES the property and state what breaks if nothing is done — no consumer means report-only, never a human-gate proposal.
- narrative: the I1 parentage-gap orphan detector emitted a `human-gate,pipeline-proposal` bead
  claiming orphans "fall out of epic roll-ups, child-completion ratios, and loop orient/triage —
  they drift unscheduled." Measured 2026-07-30: parentage has exactly ONE consumer in the whole
  skill tree (ac-tidy's own Epic-Close Proposals). It does not affect `br ready`,
  `bv --robot-triage`, scheduling, or priority, and a named orphan from the proposal's own list
  (bd-w782g) was sitting in the loop's ready set the entire time. So the stated harm was FALSE,
  and the class cost 11 days of docket residence plus four drift comments for damage that did
  not exist. The real harm is the inverse and smaller (an unlinked child lets an epic be
  proposed for close prematurely) with zero live instances. Made report-only in
  agent-compounds 4d8ec80.

## contradicting-clauses-resolved-silently-three-runs-running
- skills: [ac-tidy]
- impact: M
- frequency: occasional
- recurrence: 3
- related: []
- first_seen: 2026-07-26
- last_seen: 2026-07-30
- stage: ac-tidy
- status: resolved
- proposed_fix: when two clauses of this skill give opposite answers on the same input, escalate for a ruling on the FIRST occurrence — do not resolve it silently and repeat.
- narrative: Tier 1 sanctioned stripping a stale `unrefined` label from "any CLOSED bead", while
  the NIGHTLY guardrails said "never touch human-gate or qa-blocker beads". On a closed bead
  carrying both, the two clauses answered oppositely. Three consecutive nightly runs (07-26,
  07-27, 07-29 — bd-zko08 twice, then bd-d8rct.1) resolved it the same way silently, each
  touching only 1-2 beads so the erosion was invisible per run. Agreement by three unratified
  repeats is not doctrine. Escalating on the third rather than deciding silently a fourth time
  was the right move and is the behaviour worth keeping. Ratified fork (A) in agent-compounds
  7987960: the guardrail is now scoped to OPEN gated beads, and the Tier-1 carve-out is explicit
  at both ends so the contradiction cannot be re-derived from either side.
