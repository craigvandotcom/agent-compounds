---
skill: ac-loop-swarm
created: 2026-08-21
last_pass: 2026-08-22
entries: 12
---

# ac-loop-swarm — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

<!-- Neither ac-loop's nor ac-loop-2's friction log is this skill's history: the swarm's
     pull-based, no-conductor model changes which frictions are even possible. Start empty;
     do not import entries from v1 or v2. Cross-cutting frictions that recur here AND in a
     sibling loop skill stay counted at their primary, cross-referenced via `related:` and
     a local pointer entry. -->

## ubs-no-arg-fallback-scans-cwd-instead-of-erroring
- skills: [ac-loop-swarm]
- impact: M
- frequency: occasional
- perceptibility: misleading
- recurrence: 2
- related: [check-exit-status-before-believing-a-zero]
- first_seen: 2026-08-21
- last_seen: 2026-08-22
- stage: ac-loop-swarm
- status: open
- proposed_fix: fail loud when argv was non-empty but nothing parsed; never fall back to cwd in that case.
- narrative: given no parseable args, `ubs` does not error — it falls back to scanning the
  current working directory, and then aborts on directory size. The caller's mistake is
  therefore converted into a different, misleading failure: the output describes a
  too-large-directory problem, with no indication anywhere that the supplied paths never
  arrived. A caller reading that message reasonably concludes the gate is unusable on this
  repo rather than that its own argument list evaporated, so the real defect is invisible at
  the only place it is reported. The arg-MANGLING half — a path list containing `[id]` or
  `(protected)` loses its arguments unless each path is explicitly quoted — is a separate
  root and belongs to the related id, not to this one; this entry is only about the fallback
  that hides the loss.

## vitest-4-removed-reporter-basic-fails-as-module-load-error
- skills: [ac-loop-swarm]
- impact: S
- frequency: occasional
- perceptibility: misleading
- recurrence: 1
- related: [check-exit-status-before-believing-a-zero]
- first_seen: 2026-08-21
- last_seen: 2026-08-21
- stage: ac-loop-swarm
- status: open
- proposed_fix: name a reporter that exists in the pinned vitest major, and treat a runner module-load stack as a harness error, not a test failure.
- narrative: `--reporter=basic` no longer exists in vitest 4. The removal is not reported as
  an unknown-reporter error — it surfaces as an opaque ERR_LOAD_URL / RunnerError stack, which
  reads as the test run itself exploding rather than as a bad flag. This is the false-RED,
  misattributed-failure direction, and it is distinct from the false-GREEN vitest entries
  elsewhere in this sensor: nothing is silently passing here, but the failure names the wrong
  culprit, so the cheap response is to go hunting in the code under test. Two rules close it —
  a reporter name must be checked against the pinned major before it is written into any
  command, and a stack that originates in the runner's module loader is a harness defect that
  must never be counted as a test result.

## vitest-related-fans-out-on-hub-modules
- skills: [ac-loop-swarm]
- impact: M
- frequency: occasional
- perceptibility: loud
- recurrence: 1
- related: [affected-graph-silently-subsets-explicit-test-selection, verification-outlives-the-bash-timeout-cap]
- first_seen: 2026-08-21
- last_seen: 2026-08-21
- stage: ac-loop-swarm
- status: open
- proposed_fix: detect hub-module fanout before running; when the related set exceeds a threshold, run a named tier with a raised timeout instead of pretending the check is scoped.
- narrative: `vitest related` is treated as the cheap scoped check — the thing you run because
  a full tier is too expensive. On a widely-imported module that assumption inverts: one hub
  util fanned out to 209 files and roughly 2700 tests, and the command exceeded the 120s
  timeout without producing a verdict. For a hub module `related` costs as much as a tier run
  while still being presented, in every command that spells it, as the narrow option. The
  fanout is measurable before the run, so the choice between scoped-check and named-tier must
  be made on the size of the related set rather than on the shape of the command.

## dcg-false-positives-on-angle-bracket-inside-quoted-prose
- skills: [ac-loop-swarm]
- impact: M
- frequency: frequent
- perceptibility: loud
- recurrence: 0
- related: []
- first_seen: 2026-08-21
- last_seen: 2026-08-21
- stage: ac-loop-swarm
- status: open
- proposed_fix: see the primary entry.
- narrative: POINTER ENTRY, not a copy — the PRIMARY is this same id in `skills/ac-loop/FRICTIONS.md`,
  where all occurrences are counted. Recorded here because the swarm model inherits the hazard
  unchanged and its own prose-bearing CLI calls emit it. LOCAL MANIFESTATION: a `br comments add`
  call was rejected because the comment TEXT quoted a script's `mv` lines — the destructive-operation
  matcher reads the payload as a command — and, separately, a heredoc containing JSX was rejected
  because its angle brackets tokenise as redirects. The standing remedy is already logged at the
  primary and needs no re-derivation here: route agent-authored prose through the Write tool, never
  through the shell, in either quoting form.

## the-loops-own-gates-have-false-green-mechanisms
- skills: [ac-loop-swarm]
- impact: H
- frequency: every-run
- perceptibility: silent
- recurrence: 0
- related: []
- first_seen: 2026-08-21
- last_seen: 2026-08-21
- stage: ac-loop-swarm
- status: open
- proposed_fix: see the primary entry.
- narrative: POINTER ENTRY, not a copy — the PRIMARY is this same id in `skills/ac-loop-2/FRICTIONS.md`,
  where occurrences are counted. Recorded here because a pull-based swarm has no conductor to
  re-read a gate's output, so every false green lands directly in a worker's own close decision.
  LOCAL MANIFESTATION — TWO faces: (a) vitest 4.1.10 marks files it never reached under bail
  cancellation as `passed` with zero assertionResults, which is indistinguishable from
  `describe.skip`, so a count assertion alone cannot catch a killed run; (b) a down local Supabase
  stack turns every supabase-integration `skipIf` into a green no-op, so a bead whose binding
  acceptance criterion lives in that tier looks satisfiable when it is not. Both share the primary's
  root: a gate that cannot distinguish "ran and found nothing" from "did not run".

## declared-red-not-reconciled-against-territory-or-existing-tests
- skills: [ac-loop-swarm]
- impact: M
- frequency: frequent
- perceptibility: misleading
- recurrence: 0
- related: []
- first_seen: 2026-08-21
- last_seen: 2026-08-21
- stage: ac-loop-swarm
- status: open
- proposed_fix: see the primary entry.
- narrative: POINTER ENTRY, not a copy — the PRIMARY is this same id in
  `skills/ac-bead-refine/FRICTIONS.md`, where occurrences are counted. Recorded here because the
  swarm dispatches from bead text with no conductor pass between refine and build, so an internal
  contradiction in a bead reaches a worker intact. LOCAL MANIFESTATION: a bead's `## Territory`
  listed files in the production write set that the bead's own acceptance criteria forbade by
  directory, leaving the worker to choose which half of its own spec to obey. This widens the entry
  from RED-vs-Territory to **AC-vs-Territory** — the same mechanical reconciliation, run against the
  acceptance criteria as well as the declared RED.

## unrunnable-ac-test-command-must-name-the-repo-runner
- skills: [ac-loop-swarm]
- impact: M
- frequency: occasional
- perceptibility: misleading
- recurrence: 0
- related: []
- first_seen: 2026-08-21
- last_seen: 2026-08-21
- stage: ac-loop-swarm
- status: open
- proposed_fix: see the primary entry.
- narrative: POINTER ENTRY, not a copy — the PRIMARY is this same id in
  `skills/ac-bead-refine/FRICTIONS.md`, where occurrences are counted. Recorded here because the
  swarm runs many workers against ONE shared checkout, which is an execution environment the
  refine-time runnability check does not currently model. LOCAL MANIFESTATION: a bead named a
  full-suite run as its acceptance gate, which is forbidden on a shared swarm checkout — and that
  same gate was independently broken by another bead closed in the same run. This widens the rule
  from "name a runnable command" to "name a command runnable in the run's execution environment":
  a command can be unrunnable by prohibition, not only by runner-wrapper narrowing.

## agent-identity-env-lost-between-tool-calls
- skills: [ac-loop-swarm]
- impact: L
- frequency: every-run
- perceptibility: silent
- recurrence: 1
- related: [br-writes-default-to-human-identity]
- first_seen: 2026-08-22
- last_seen: 2026-08-22
- stage: ac-loop-swarm
- status: open
- proposed_fix: export AGENT_NAME and BR_AGENT_NAME inside every subshell that commits or writes a bead; never pipe a commit through `tail`.
- narrative: shell state does not survive between tool calls, so an identity exported once in a
  seed's setup block is absent by the time any later step commits. Two consequences, and only
  the first is visible. The pre-commit reservation guard does refuse — it writes
  `AGENT_NAME environment variable is required` to stderr and exits 1 — but the commit recipe
  pipes through `tail`, and the refusal falls outside the window, so the caller sees staged
  files, no commit, and no reason. `br` has no such refusal: with the identity unset it writes
  as the human, silently, so every claim comment a run produces is attributed to the fallback
  name. The audit trail the pull-based model depends on to prove who holds a bead is therefore
  wrong on every entry, and nothing anywhere reports it. Truncating a guard's own output is the
  wider hazard: a check that announces into a discarded stream is a check that is off.

## swarm-doctrine-prescribed-a-guard-blocked-command
- skills: [ac-loop-swarm]
- impact: M
- frequency: every-run
- perceptibility: misleading
- recurrence: 1
- related: []
- first_seen: 2026-08-22
- last_seen: 2026-08-22
- stage: ac-loop-swarm
- status: resolved
- proposed_fix: point the step at the runbook that already documents the working recovery; delete the forbidden command.
- narrative: the close-out reconcile step named `git stash push -u` as its escape from a dirty
  tree. `neometa.stashguard` forbids that in a shared checkout, and forbids the scoped
  `git stash push -- <paths>` form the guard's own hint recommends, so both exits the step knew
  about were walls. Doctrine that names an impossible command is worse than doctrine that names
  nothing: it spends the reader's confidence before it spends their time, and the reader assumes
  the environment is broken rather than the instruction. The working sequence already existed in
  a runbook the step never referenced. Fixing this was a subtraction — the wrong lines out, a
  pointer in.

## harness-reports-worker-dead-on-transient-api-error
- skills: [ac-loop-swarm]
- impact: L
- frequency: occasional
- perceptibility: misleading
- recurrence: 1
- related: []
- first_seen: 2026-08-22
- last_seen: 2026-08-22
- stage: ac-loop-swarm
- status: open
- proposed_fix: classify liveness from `br coordination status` before sweeping; a task notification is a hint, not a death certificate.
- narrative: a transient upstream 5xx surfaced to the orchestrator as a terminal worker failure
  while the worker was alive and still holding a claim. Acting on that report, the close-out
  swept: it reopened the held bead, released the worker's reservations and deregistered its
  identity. The worker then continued for hours with no identity and no ability to reserve a
  file — the sweep did not stop it, it disarmed it. `br coordination status` already knew the
  truth throughout, returning `fresh` and `observe` against explicit stale and abandoned
  thresholds. The general rule is cheaper than any patch: prefer live state over reported state,
  and let the system that tracks a fact answer questions about it.

## mcp-tool-arg-names-drift-from-calling-doctrine
- skills: [ac-loop-swarm]
- impact: S
- frequency: every-run
- perceptibility: misleading
- recurrence: 1
- related: []
- first_seen: 2026-08-22
- last_seen: 2026-08-22
- stage: ac-loop-swarm
- status: open
- proposed_fix: name arguments as the tool schema defines them; on a validation error read the schema rather than re-guessing.
- narrative: three calls the workflow spells out do not match the tools they invoke. The guard
  installer is written with `repo_path` and takes `code_repo_path`. The message send is written
  with `registration_token` and takes `sender_token`. The orphan sweep is told to force-release a
  reservation, but that tool refuses any holder with recent activity — which is guaranteed at the
  exact moment a sweep runs — while the plain release tool has no such check and works. Each
  costs only a retry, so each is individually cheap; together they mean the written procedure
  cannot be executed as written, and a reader cannot tell which remaining lines to trust.

## concurrent-beads-dbs-mint-colliding-comment-ids
- skills: [ac-loop-swarm]
- impact: M
- frequency: occasional
- perceptibility: loud
- recurrence: 1
- related: []
- first_seen: 2026-08-22
- last_seen: 2026-08-22
- stage: ac-loop-swarm
- status: open
- proposed_fix: on a ledger union, renumber the incoming side's comment ids above the max; keep the copy already published.
- narrative: comment ids are allocated by per-database autoincrement. When two databases write
  the same shared ledger — a run's own db and a scheduled job's isolated worktree — both mint the
  same next ids, and merging their exports produces one file carrying an id twice. `comments.id`
  is a primary key, so that file cannot be rebuilt into a database at all: a fresh clone fails on
  the constraint and ends with no usable db. A union merge of two ledgers therefore has a
  renumbering step whether or not anyone wrote one down. The husky guard does catch it and names
  every colliding pair, which is why this is a sensor reading rather than a promotion candidate.
