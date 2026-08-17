---
skill: ac-land
created: 2026-07-29
last_pass: 2026-08-17
entries: 7
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

## zsh-nullglob-aborts-the-teardown-selector
- skills: [ac-land, agent-mail]
- impact: M
- frequency: occasional
- recurrence: 2
- related: [format-first-doctrine-conflicts-with-shared-checkout-pathspec]
- first_seen: 2026-08-04
- last_seen: 2026-08-17
- stage: ac-land
- status: open
- proposed_fix: no glob pattern in a teardown selector may be allowed to reach zsh unmatched — the fleet's shell aborts the command on a no-match instead of passing the pattern through, so a selector that finds nothing kills the block it sits in rather than returning an empty set. Write selectors to tolerate the empty case explicitly (match through a command that accepts zero results, or guard the glob before expanding it), and never assume the bash `nullglob`-off behaviour of leaving the pattern literal.
- narrative: a teardown selector in ac-land's own cleanup step used a glob that matched nothing in this repo. Under zsh a no-match is a FATAL error, not an empty expansion, so the failure was not "the selector selected nothing" — it was the whole teardown block aborting at that line, with the steps after it silently never running. That is the expensive part: the visible symptom is one error, while the actual damage is everything downstream of it being skipped, and teardown is exactly the phase whose omissions nobody notices because it produces no artifact anyone reads. Same family as the `find … -name '*.yaml'` zsh-fatal defect recorded against `ac-pipeline/references/board-scan.md` (noted inside ac-loop's dcg entry) and as the memory `loop-retro-zsh-nomatch-glob-wait-predicate` — three independent occurrences of one root, which is that snippets throughout the pipeline are authored with bash glob semantics in mind and run under zsh. Cheap to fix per site and structurally recurring, since the defect is invisible in any repo where the glob happens to match.
  **+1, and the surface widens to the identity layer.** The teardown selectors failed again with
  no-match errors, and the sibling roster-sweep recipe in `agent-mail/references/agent-identity.md`
  fails the same way — so the two recipes an unattended run depends on to leave the machine clean
  are both unrunnable as published. Second mechanism found in the same pass: a while-loop fed by
  `done` with a read redirect from a file is blocked by dcg as a truncation of the file being read
  (counted at `dcg-blocks-the-skills-own-canonical-artifact-redirects` in ac-loop). The two
  together justify a standing rule for teardown snippets specifically: every selector and sweep
  recipe must be executed once, in zsh, under the guard, before it is published — a teardown step
  that aborts produces no artifact and therefore no failure signal, which is the only phase where
  an unrunnable recipe can persist indefinitely without anyone noticing.

## ac-land-assumes-a-pnpm-repo
- skills: [ac-land]
- impact: M
- frequency: occasional
- recurrence: see primary
- related: [doc-only-repo-no-loop-adaptation, format-first-doctrine-conflicts-with-shared-checkout-pathspec]
- first_seen: 2026-08-04
- last_seen: 2026-08-04
- stage: ac-land
- status: open
- proposed_fix: see primary — establish the repo's shape ONCE at Phase 0 (package manager project present? CI? version? QA surface?) and carry that answer into every phase, rather than each phase assuming a Next.js/pnpm app and leaving the translation to whoever is running.
- narrative: POINTER ENTRY, not a copy — the PRIMARY is `doc-only-repo-no-loop-adaptation` in `skills/ac-loop/FRICTIONS.md`, where occurrences are counted. Local manifestation: landing on agent-compounds, ac-land prescribed pnpm-repo commands — the format sweep and the build/lint gates composed on top of it — in a repo with no pnpm project at all. Translated by hand at zero cost, exactly as the loop-end occurrence was on 2026-07-21. Recorded here because the pairing is what matters: the same assumption is now documented at BOTH ends of one pipeline, which turns "ac-loop needs a doc-only adaptation note" into "the pipeline needs a repo-shape precondition", and a fix applied only to ac-loop would leave this land improvising every time. Note the interaction with this file's `format-first-doctrine-conflicts-with-shared-checkout-pathspec`: both entries are about the same mandated format sweep, from different directions — one says the sweep is unsafe when a sibling is live, this one says the sweep may not exist at all.

## disposition-dedupe-self-defect
- skills: [ac-land]
- impact: M
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: 2026-08-04
- last_seen: 2026-08-04
- stage: ac-land
- status: promoted
- proposed_fix: tracked on the bead — do not re-derive here.
- narrative: POINTER ONLY — this run's land hit a dedupe defect in its own disposition step, and it is already filed and carried as **ac-54t8.4**. Logged as a stub so the sensor shows the occurrence and a future promotion pass does not mint a fresh id for something already in flight; the analysis, evidence and fix live on the bead. Deliberately not restated (per friction-capture's routing rule that already-beaded cross-cutting items get pointers, not copies) — a second narrative here would drift from the bead's as the bead is refined.

## mandatory-run-ledger-unreachable-in-fanned-out-child
- skills: [ac-land, ac-bead-refine]
- impact: S
- frequency: every-run
- recurrence: 3
- related: [task-ledger-tools-unreachable-from-a-fanned-out-child]
- first_seen: 2026-07-30
- last_seen: 2026-08-04
- stage: ac-loop
- status: open
- proposed_fix: state the ledger requirement conditionally — "if `TaskCreate`/`TaskUpdate` are available, declare the run ledger; otherwise track the same section list inline and record it in `progress.md`". Applies to every skill whose Phase 0 mandates the ledger AND which also specifies a fan-out path (`ac-land`, `ac-bead-refine`, and any other consumer of `ac-pipeline/references/run-ledger.md`).
- narrative: `ac-pipeline/references/run-ledger.md`'s pattern is declared MANDATORY in Phase 0 of several skills, but no `TaskCreate`/`TaskUpdate` tools exist when a skill runs as a spawned child rather than as the top-level session. The skills state the ledger as mandatory without noting it is impossible in the fan-out path they themselves specify, so a child either reports a false completion or burns time hunting for a tool that was never in its surface. First observed in `ac-bead-refine` (RUN 20260730-215800-loop1); recurrence 2 in `ac-land` itself (RUN 20260731-000500-loop2) — this land had no such tools and tracked its eight sections inline instead. Cost is small each time but it is `every-run` for any fanned-out consumer, and it silently degrades the resume-after-compaction guarantee the ledger exists to provide (a compacted child cannot read a ledger it could never write).
  **RUN 20260803-221658-19787, +1 — a SECOND call site inside ac-land, and the count is now the point.** ac-land hit the TaskCreate gap again at a further mandate site in its own flow, tracking the sections inline as before. The entry's `proposed_fix` (state the ledger conditionally) is still right and still unshipped, but this occurrence sharpens where it must be applied: patching the Phase-0 mandate alone is insufficient because the same skill mandates the ledger at more than one point, so the conditional has to be attached to the ledger PATTERN in `ac-pipeline/references/run-ledger.md` rather than to each consumer's Phase 0. This is also the third distinct member of the family ac-loop's log names as one root — panels a subagent cannot spawn, report channels it does not hold, ledgers it cannot write (`task-ledger-tools-unreachable-from-a-fanned-out-child`) — all detectable by the same one-line spawn-time check of whether the mandated tool is in the child's declared toolset.

## conductor-supplied-candidates-are-leads-not-findings
- skills: [ac-land]
- impact: M
- frequency: rare
- recurrence: 1
- related: []
- first_seen: 2026-08-10
- last_seen: 2026-08-10
- stage: ac-land
- status: open
- proposed_fix: state in the retrospective prompt that conductor-supplied candidates are leads to falsify, not findings to write up, and add "what run-level incident got treated as unavoidable that shouldn't have been?" to the analyst's question set.
- narrative: this land was handed 5 candidate system-upgrade classes; 3 of them (`beads-closed-gate --assignee` syntax, a dcg-blocked echo shape at "the anchor step", a ubs-on-SQL waiver) had ZERO matching evidence — one was already fully documented, one had no matching text anywhere in the `ac-*` skills, and one was already being handled correctly. Meanwhile the highest-value finding of the whole retrospective (/tmp artifact durability, now `ac-28nm`) was NOT on the list at all — it surfaced only by asking "what run-level incident got treated as unavoidable that shouldn't have been?" of source material that already contained a recovered-from-disaster narrative. Cost was minor (~25 min of verification, correctly spent falsifying the 3 dead leads), but the shape is worth naming: a conductor-supplied candidate list carries the conductor's own compression and blind spots, and the retrospective's job is to falsify each one against the live substrate, not transcribe it — the analyst's OWN probing question found the real signal the list missed entirely. evidence: RUN 20260808-221219-47229 ac-land close-out, 2026-08-10.
