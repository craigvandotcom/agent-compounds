---
skill: ac-loop-2
archetype: orchestrator
last_pass: 2026-08-09 (pre-ratification review)
spine_lines: 601 / target ≤500 orch (orchestrator — length is enforcement spine)
---

# ac-loop-2 — maintenance ledger

## Health
New skill, no pass yet. Over the ≤500 orchestrator target by 85 lines; under the
standard-tier ceiling and smaller than ac-loop, whose I/O contract and closing ritual it
adapts. Behaviour beads: `br list -l skill:ac-loop-2`. Near-dup scan will flag
`ac-loop ~ ac-loop-2` heavily — expected while both exist; the shared blocks are the
identity/land/deregister spine and are deliberately NOT centralised until v2 is ratified
(centralising a spine that one of the two skills is about to change is premature).

## Inbox — shape signal awaiting triage
<!-- Behavior-changing signal does NOT go here — it goes to a skill:ac-loop-2 skill-improvement bead. -->
(empty)

## Holding pen — content pulled from SKILL.md, disposition undecided
(none)

## Cut-log — append-only audit trail (feeds the churn detector)
- Native contract support. Schema moved to bead-conventions § Implementation
  contract (incl. test-tier exposure). Deleted the 12-line INTERIM/enforcement
  provenance block from the spine; spec-phase prompts now point, they do not
  restate the six elements. Phase 3 gained the covered/excluded tier report.
- Pre-first-run board contact. The decision docket is now WAVE-SCOPED (human-gate beads
  holding a `blocks` edge into the lane set, not the whole board): a live board carries 146
  standing human-gate beads, which made "docket cleared" unsatisfiable by construction and
  the sitting uncrossable. Deferring a blocker now drops its dependent bead, not the wave.
- Pre-ratification review pass. FIXED (probe-verified defects): mutation probe now restores
  the test from the bead commit before running and restores via `git reset --hard` (a bare
  revert deletes the test with the fix; `git checkout -- .` cannot undo a staged revert);
  bisect script gained the exit-125 missing-test-file guard (+ lockfile-commit guard).
  RESOLVED contradictions: children run `br` verbs directly, conductor stays the ledger's
  only git writer (explicit supersede of ceremony-batching-pool deferral); AskUserQuestion
  now names both the sitting and ARIA. HARDENED: mutex 15-min bound + stale-lock steal +
  origin-assert moved inside the lock (single canonical copy now in delegation-prompts —
  spine script deleted); FREEZE_SHA recorded and diff-checked at the sitting; bypass-during-
  Phase-1 re-freeze; risk-queue sequence rule; conductor owns global width via lane budgets;
  ARTIFACTS_DIR derivation restored at the gate site. Net +16 spine lines — growth bought
  with the mutex-script deletion; remainder is barrier-integrity enforcement.
- INITIAL. Authored as a rewrite of the ac-loop copy into the five-phase model. DELETED as
  no-longer-applicable: the width prompt and the whole continuous-width Efficiency
  § Parallelism block (v2's widths are fixed per phase), the queue-with-refill dispatch
  doctrine, the Bug Lane / Rule 0 (replaced by the P0/P1 bypass lane), Phase 1 orphan-batch
  and Phase 2 plan-wave claim mechanics (replaced by Phase 0 lanes), § The Ceremony and the
  ceremony-batching pool (replaced by Phase 3 + Phase 4), the plan-admission `depends-on:`
  Complete(A) apparatus (collapsed to one line in Phase 1), and the concurrency guard-rails
  section. KEPT verbatim-in-substance: the 3-level orchestration contract, the scope
  contract, the beads-closed gate block, Phase ARIA, the exit-land / reflect / deregister
  ritual, and Milestone Notifications. ADDED: references/implementation-contract.md and
  references/converge-phase.md. FRICTIONS.md and MAINTENANCE.md reset to empty scaffolds —
  v1's history is not v2's.
