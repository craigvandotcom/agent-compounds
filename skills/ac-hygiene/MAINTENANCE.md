---
skill: ac-hygiene
archetype: orchestrator
last_pass: 2026-08-06
spine_lines: 657 / target ≤500 orch
---

# ac-hygiene — maintenance ledger

## Health

The single code-quality lane. Panel narrowed 7 → 5 and scoped to the product surface; the
test-warden lens gained a trimming mandate (net test-count delta). Spine is net-negative
across the change (−1 SKILL.md, −39 references/reviewers.md).

Spine still over the orchestrator target. Next trim candidates, in payoff order: the
`ac-review` cross-references throughout (they go dead when review retires), the Close Ceremony
section (delegates to `ac-batch-close`, which is itself slated to collapse into `ac-merge`),
and the three weekly-cadence lens sections (knip / stamp-audit / friction cluster-walk), which
are conductor-run mechanics that read like references.

## Holding pen

Content removed from the skill, aged here before git-delete. Resolve or delete by the
review-by date; the default resolution applies if nobody acts.

### Explorer lens (Agent 2) + Structural Reviewer lens (Agent 3)

- **Removed:** 2026-08-06, from `references/reviewers.md` (70 lines).
- **Why:** panel narrowed to product-critical findings. `knip` covers unused code
  deterministically and already runs as its own weekly lens, so Explorer duplicated a
  mechanical check with a sampled one. Structural Reviewer hunted SRP/modularity taste, which
  produced findings that were real but never scheduled — the class that filled the board.
- **Recoverable from:** git history of `skills/ac-hygiene/references/reviewers.md` at the
  commit that removed them.
- **Review by:** 2026-11-06.
- **Default resolution:** git-delete stands. Reinstate only on evidence that a defect class
  reaching users went unfound because neither lens ran — not on the general argument that more
  lenses find more things.

## Cut-log

- [2026-08-06] Panel 7 → 5 lenses; `THE BAR` product-surface scope added to
  `references/reviewers.md`; test-warden gained `Trim as hard as you fix` (net test-count
  delta, deletion as a first-class finding, never delete the last cover over a behaviour).
  Net −40 lines across the skill.
