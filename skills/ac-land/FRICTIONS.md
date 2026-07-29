---
skill: ac-land
created: 2026-07-29
last_pass: 2026-07-29
entries: 2
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
