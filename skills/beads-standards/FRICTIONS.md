---
skill: beads-standards
created: 2026-07-22
last_pass: 2026-08-04
entries: 4
---

# beads-standards — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

## br-non-tty-flake-in-compound-one-liners
- skills: [beads-standards]
- impact: S
- frequency: frequent
- recurrence: 4
- related: []
- first_seen: 2026-08-02
- last_seen: 2026-08-04
- stage: ac-loop
- status: open
- proposed_fix: document the workaround once in beads-standards (likely § working cadence or the br cheatsheet): when `br` is chained inside a compound one-liner (`cmd && br ... && cmd`), it can fail with a "not a terminal" error — run the `br` call as its own separate Bash invocation, or pipe with `--json` where supported. Confirm the exact failing shapes before writing the rule (verify-doctrine-claims-against-live-tools).
- narrative: hit 3 independent times in one run (RUN 20260802-084558-9799, ac-loop-lite ablation —
  refine children r1 and r2, then a third occurrence in the implement lane): `br` invoked inside a
  compound shell one-liner errored with a "not a terminal" flake, forcing each child to re-run the
  command standalone. Cost per hit is one retry (~seconds), but three uncoordinated rediscoveries in
  a single run with ZERO doctrine anywhere in the registry (grep confirms no mention) makes it a
  documentation gap, not a tool bug we can fix here. Each child independently found the same
  workaround: separate invocation.
  **RUN 20260803-221658-19787, +1 — the trigger is broader than the `&&` chain this entry was minted
  from.** A review child hit the identical "not a terminal" failure with the call inside a `for` LOOP
  rather than an `&&` chain, and reached the same workaround independently (one invocation per call).
  That is a fourth uncoordinated rediscovery and it reframes the rule that still needs writing: the
  condition is not a particular chaining operator but any construct that costs the call its terminal,
  so doctrine phrased as "don't chain it with `&&`" would have failed to cover this occurrence. Phrase
  it as the positive form instead — a `br` call gets its own Bash invocation — which covers loops,
  chains, substitutions and pipes in one line. A pointer entry now sits in ac-review's log, since a
  panel finishing with a LIST of beads to walk is the shape that most invites the loop. Still
  undocumented anywhere in the registry, and per this entry's own `verify-doctrine-claims-against-live-tools`
  caveat the loop form is one more shape to confirm against the live tool before the rule is written,
  not a confirmation of the rule.

## br-lint-wants-success-criteria-where-doctrine-says-delivers
- skills: [beads-standards, ac-beadify, ac-bead-refine]
- impact: S
- frequency: frequent
- recurrence: 1
- related: []
- first_seen: 2026-08-04
- last_seen: 2026-08-04
- stage: ac-loop
- status: open
- proposed_fix: decide and record which side gives, then make the other side quiet. Either `bead-conventions.md`'s epic template adopts the heading `br lint` expects, or the standard states explicitly that this particular lint warning is EXPECTED on epics authored to our conventions and is not to be actioned. Do not leave both in place: an unexplained warning on every correctly-authored epic is the shape that trains agents to ignore lint output wholesale.
- narrative: `br lint` warns that an epic is missing a `## Success Criteria` section, while `beads-standards/reference/bead-conventions.md` prescribes `## Delivers` for exactly that content. Both are "right" — the tool ships its own expectation, the convention is ours and deliberate — so an epic authored correctly against our doctrine is warned about by our own linter, every time. Warning-only, so nothing blocked and the run cost was zero; logged because the cost is not per-occurrence. A standing warning that correct work always produces is a broken detector: it teaches every agent that reads `br lint` output that some of it is noise, and the judgement of WHICH part is noise is then re-made by each agent under time pressure. That is how a real lint finding gets waved through later. Also a heading-drift hazard in its own right, since two names for one section means beads in the wild will carry both and any grep over epic structure has to know that. This is a doctrine-vs-tool divergence rather than a defect on either side, which is why it wants an explicit recorded decision rather than a fix.

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
