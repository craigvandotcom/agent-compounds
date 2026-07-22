---
skill: beads-standards
created: 2026-07-22
last_pass: 2026-07-22
entries: 1
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
