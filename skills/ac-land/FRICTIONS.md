---
skill: ac-land
created: 2026-07-29
last_pass: 2026-07-31
entries: 3
---

# ac-land — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

## format-first-doctrine-conflicts-with-shared-checkout-pathspec
- skills: [ac-land]
- impact: M
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: 2026-07-29
- last_seen: 2026-07-29
- stage: ac-loop
- status: open
- proposed_fix: reconcile the FORMAT-FIRST instruction with pathspec discipline — make the repo-wide `pnpm format` sweep conditional on no live sibling being present; otherwise run a targeted `prettier --write <my paths>` instead.
- narrative: ac-land's own SKILL.md mandates a repo-wide `pnpm format` sweep, but on a shared trunk-direct checkout that sweep rewrites FOREIGN files sitting in a sibling's in-flight working tree. Targeted `prettier --write <my paths>` is the correct form when a sibling is live. This run cost nothing both times it came up — once because an implement child deliberately avoided the repo-wide sweep, and once because this land itself was only safe because no sibling was still live — but the doctrine conflict is real and will bite the next run that runs the sweep literally as written while a sibling is active.

## local-lint-scans-gitignored-scratch-ci-does-not
- skills: [ac-land]
- impact: M
- frequency: every-run
- recurrence: 1
- related: []
- first_seen: 2026-07-29
- last_seen: 2026-07-29
- stage: ac-loop
- status: open
- proposed_fix: keep eslint's ignore list mirrored with `.gitignore` for scratch dirs (fixed for body-compass-app in commit 7f308085); generalise the check to other apps.
- narrative: local `pnpm lint` scans gitignored scratch under `_artifacts/*/local/` that CI never checks out, so CI lint is green while the local land gate fails with 10 phantom errors on 4-day-old non-source files. `build:check` is a composite that runs lint, so it inherited the same false red. Cost ~3 lint/build runs plus diagnosis during this land before the mismatch was understood.

## mandatory-run-ledger-unreachable-in-fanned-out-child
- skills: [ac-land, ac-bead-refine]
- impact: S
- frequency: every-run
- recurrence: 2
- related: []
- first_seen: 2026-07-30
- last_seen: 2026-07-31
- stage: ac-loop
- status: open
- proposed_fix: state the ledger requirement conditionally — "if `TaskCreate`/`TaskUpdate` are available, declare the run ledger; otherwise track the same section list inline and record it in `progress.md`". Applies to every skill whose Phase 0 mandates the ledger AND which also specifies a fan-out path (`ac-land`, `ac-bead-refine`, and any other consumer of `_shared/run-ledger.md`).
- narrative: `_shared/run-ledger.md`'s pattern is declared MANDATORY in Phase 0 of several skills, but no `TaskCreate`/`TaskUpdate` tools exist when a skill runs as a spawned child rather than as the top-level session. The skills state the ledger as mandatory without noting it is impossible in the fan-out path they themselves specify, so a child either reports a false completion or burns time hunting for a tool that was never in its surface. First observed in `ac-bead-refine` (RUN 20260730-215800-loop1); recurrence 2 in `ac-land` itself (RUN 20260731-000500-loop2) — this land had no such tools and tracked its eight sections inline instead. Cost is small each time but it is `every-run` for any fanned-out consumer, and it silently degrades the resume-after-compaction guarantee the ledger exists to provide (a compacted child cannot read a ledger it could never write).
