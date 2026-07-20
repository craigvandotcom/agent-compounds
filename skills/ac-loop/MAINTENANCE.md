---
skill: ac-loop
archetype: orchestrator
last_pass: 2026-07-20
spine_lines: 949 / target ≤500 orch (legitimately long — enforcement spine; remaining trim is bounded)
---

# ac-loop — maintenance ledger

## Health
Over the line target but an orchestrator (length is largely enforcement). Two diet passes done
(1086 → 949, −137). Inbox clear of actionable shape items; 2 behavior beads open —
`br list -l skill:ac-loop` (ac-uip stale version-bump delegation, ac-plv double-review). Near-dup
scan flags `ac-loop ~ ac-implement` (283 shingles) — that overlap is the delegation prompts, which
were assessed and deliberately KEPT inline (see Cut-log).

## Inbox — shape signal awaiting triage
<!-- Behavior-changing signal does NOT go here — it goes to a skill:ac-loop skill-improvement bead. -->
(empty — both pass-1 items resolved; see Cut-log for the dedup and the delegation-prompt keep decision)

## Holding pen — content pulled from SKILL.md, disposition undecided
(none — both extractions were clean verbatim moves, nothing parked)

## Cut-log — append-only audit trail (feeds the churn detector)
- [2026-07-20] EXTRACTED § Ceremony batching pool mechanics (state store, flock RMW, fire
  opportunities, selected-set/drain policy, report-ack, failure re-merge, risk override, bug-lane,
  guard-rail, §5 fixtures) → `_shared/ceremony-batching-pool.md` (shared with ac-batch-close). Kept
  intro + hookpoints + engagement pointer inline. −109 lines (1086 → 977). Repointed ac-batch-close
  L538 to `_shared/ceremony-batching-pool.md § Drain sequence`. `--diff` clean.
- [2026-07-20] EXTRACTED beads-closed-gate flag rationale (ac-514 / ac-0wi / ac-0i1 / bd-w504y — the
  `--beads` / `--progress` / repeated-`--progress` / union-of-identities reasoning) duplicated across
  Phase 1 & Phase 2 step 6 → `references/beads-closed-gate-invocation.md`. Kept the bash command +
  exit-code decisions + `post-merge`/nudge enforcement **verbatim inline at both sites** (enforcement,
  legit repetition). −28 lines net (977 → 949). NOTE: first attempt reworded the inline nudge text and
  `--diff` correctly FLAGGED it as enforcement-removed-without-relocation; corrected to verbatim-inline,
  `--diff` then clean. The guard earned its keep on the first live dedup.
- [2026-07-20] ASSESSED, DELIBERATELY KEPT INLINE: the ac-implement / ac-review / ac-batch-close
  child-delegation prompts (repeated Phase 1 & Phase 2). Orchestrator-trap case AND they carry the
  `CLAIM_ASSIGNEE` enforcement that makes the beads-closed-gate see delegate claims — inline-at-use is
  strictly stronger than a paste-from-reference pointer (token-economics hierarchy). Not extracted; the
  Phase-1/Phase-2 copies differ by target/context so are not pure sediment. This is a KEEP, not a defer.
