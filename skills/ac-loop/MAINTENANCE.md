---
skill: ac-loop
archetype: orchestrator
last_pass: 2026-07-20
spine_lines: 977 / target ≤500 orch (legitimately long — enforcement spine; more shape trim queued)
---

# ac-loop — maintenance ledger

## Health
Over the line target but an orchestrator (length is largely enforcement). First diet done
(−109 lines). 2 shape items open (below); 2 behavior beads filed — `br list -l skill:ac-loop`
(ac-uip stale version-bump delegation, ac-plv double-review). Near-dup scan flags `ac-loop ~
ac-implement` (283 shingles) — the delegation-prompt overlap the first Inbox item addresses.

## Inbox — shape signal awaiting triage
<!-- Behavior-changing signal does NOT go here — it goes to a skill:ac-loop skill-improvement bead. -->
- [2026-07-20 · src:audit] Delegation prompts (ac-implement / ac-review / ac-batch-close / ac-land)
  are repeated inline across Phase 1 & Phase 2 — extraction candidate → `_shared/delegation-prompts.md`.
  **Orchestrator-trap case:** these are pasted into freshly-spawned children, so they may only move
  if the spine keeps a "read + paste verbatim before spawning" guardrail at each spawn site
  (structure-standard § The orchestrator trap). Deferred from pass 1 as delicate; do next.
- [2026-07-20 · src:audit] Beads-closed-gate block is duplicated near-verbatim between Phase 1 and
  Phase 2 (~26 lines, differing only by batch→wave synonym swap — near-dup, not caught by exact-line
  scan). Dedup: keep the Phase 1 copy, replace Phase 2's with "same gate as Phase 1 step 6, substitute
  this wave's IDs" + the retargeted bash invocation.

## Holding pen — content pulled from SKILL.md, disposition undecided
(none this pass — the extraction was a clean move, nothing parked)

## Cut-log — append-only audit trail (feeds the churn detector)
- [2026-07-20] EXTRACTED § Ceremony batching pool mechanics (state store, flock RMW, fire
  opportunities, selected-set/drain policy, report-ack, failure re-merge, risk override, bug-lane,
  guard-rail, §5 fixtures) → `_shared/ceremony-batching-pool.md` (shared with ac-batch-close). Kept
  intro + hookpoints + engagement pointer inline. −109 lines (1086 → 977). Repointed ac-batch-close
  L538 to `_shared/ceremony-batching-pool.md § Drain sequence`. `--diff` clean (no enforcement lost).
