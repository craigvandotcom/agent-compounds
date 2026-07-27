---
skill: beads-standards
created: 2026-07-22
last_pass: 2026-07-27
entries: 2
---

# beads-standards — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

## epic-endpoint-blocks-edges-make-children-unclaimable
- skills: [beads-standards, ac-beadify, ac-loop]
- impact: M
- frequency: occasional
- recurrence: 2
- related: []
- first_seen: 2026-07-22
- last_seen: 2026-07-22
- stage: ac-loop
- status: open
- proposed_fix: state explicitly in beads-standards § dependencies that an epic must NEVER be an endpoint of a `blocks` edge to its own children — parent/child containment is expressed with the `parent-child` dep type, and `blocks` is reserved for true ordering between peers. Add the repair recipe inline (`br dep remove <child> <epic>` then re-add as `parent-child`) so a conductor that hits it can fix it without re-deriving the diagnosis.
- narrative: hit TWICE in one day (2026-07-22, BCA final-push + infra-four batches). When an
  epic bead is wired as an endpoint of a `blocks` edge to its own children, the children become
  both unclaimable and unclosable — `br ready` never surfaces them (the epic "blocks" them and
  the epic cannot close until the children do), and a direct `br close` on a child is refused.
  The graph is a self-deadlock: containment was encoded as ordering. Each occurrence cost a
  diagnosis cycle before the conductor recognised the shape; the repair itself is trivial
  (`br dep remove` + re-add as `parent-child`). The standard currently documents the dep types
  but does not warn that mixing containment into `blocks` deadlocks the epic's whole subtree,
  so the mistake keeps getting re-made at beadify time and only surfaces at claim time.

## ledger-has-no-single-writer-duplicate-commit-stalls-automated-rebase
- skills: [beads-standards, ac-loop, ac-tidy]
- impact: H
- frequency: occasional
- recurrence: 1
- related: [beads-ledger-shared-file-conductor-should-own-final-commit]
- first_seen: 2026-07-27
- last_seen: 2026-07-27
- stage: session-protocol
- status: open
- proposed_fix: state in beads-standards § Session protocol that `.beads/issues.jsonl` is a DERIVED
  artifact of the DB with exactly ONE committer per scope, and that scopes must nest — within a run the
  conductor owns the final ledger commit; across scheduled jobs exactly one designated job commits it (or
  none, regenerating on demand). The standard currently PRESCRIBES flush-then-commit with no multi-writer
  warning at all, which is what licenses every job to commit it independently.
- narrative: an automated `git pull --rebase` started 07:33 and never finished, leaving the shared BCA
  checkout DETACHED mid-rebase for 8+ hours; ~26 agent sessions (including the one that found it) then
  committed onto that detached HEAD. Root cause was NOT a rebase problem: the dream job committed
  `.beads/issues.jsonl` plus tidy proposal files locally at 02:01, and the nightly tidy independently
  generated and PUSHED the SAME derived content. Replaying the dream commit onto the pushed one therefore
  produced an EMPTY commit; git stopped to ask --skip or --continue, and no operator existed to answer, so
  the process exited mid-rebase. Nothing was lost (the DB is the source of truth and every bead survived),
  but the checkout was wedged and every commit in the window landed orphaned. NOTE this is the trigger
  condition the 2026-07-14 memory `beads-ledger-shared-file-conductor-should-own-final-commit` was waiting
  for — it predicted a LOST update between children of one run and said that would be the moment to act.
  What actually fired was the mirror image: a DUPLICATE update between two independent SCHEDULED JOBS, which
  the conductor-owns-the-commit fix does not cover at all, because no conductor sits above both jobs.
  Hence the fix must be scoped per-writer-scope, not per-run.
