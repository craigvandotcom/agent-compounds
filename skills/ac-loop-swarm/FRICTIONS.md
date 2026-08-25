---
skill: ac-loop-swarm
created: 2026-08-21
last_pass: 2026-08-26
entries: 34
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
- recurrence: 2
- related: [affected-graph-silently-subsets-explicit-test-selection, verification-outlives-the-bash-timeout-cap]
- first_seen: 2026-08-21
- last_seen: 2026-08-24
- stage: ac-loop-swarm
- status: open
- proposed_fix: detect hub-module fanout before running; when the related set exceeds a threshold, run a named tier with a raised timeout instead of pretending the check is scoped.
- narrative: SECOND INSTANCE 20260824-231514-17151 — MaroonFalcon: `vitest related` on a two-line `pnpm-workspace.yaml` packaging change expanded to 127 files / 1461 tests. Same root: a hub (workspace config) inverts the cheap-check assumption. FIRST INSTANCE — `vitest related` is treated as the cheap scoped check — the thing you run because
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
- recurrence: 1
- related: []
- first_seen: 2026-08-21
- last_seen: 2026-08-23
- stage: ac-loop-swarm
- status: open
- proposed_fix: see the primary entry.
- narrative: WIDENED 2026-08-23 — all five workers and the orchestrator hit this, and a SECOND dcg
  rule joins the same family: `core.filesystem:redirect-truncate-dynamic-path` blocks any `>`
  redirect whose target is shell-expanded (`> "$VAR/file"`), which is how an agent naturally writes
  a scratch file. Blocked this run: a TS block using `toBeGreaterThanOrEqual`, a comment containing
  `Record<string, …>`, a git rev using `^{commit}`, a python heredoc whose DATA contained
  redirects, and `git show HEAD:$f > "$f"` baseline loops. The remedy generalises to both rules and
  is the same one: author the text with the Write tool and give bash only literal paths — never
  route agent-authored prose or a computed path through the shell. POINTER ENTRY, not a copy — the
  PRIMARY is this same id in `_archive/skills/ac-loop/FRICTIONS.md`,
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
- narrative: POINTER ENTRY, not a copy — the PRIMARY is this same id in `_archive/skills/ac-loop-2/FRICTIONS.md`,
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
- recurrence: 4
- related: [br-writes-default-to-human-identity]
- first_seen: 2026-08-22
- last_seen: 2026-08-24
- stage: ac-loop-swarm
- status: open
- proposed_fix: exporting in the same command is NOT sufficient — `br` must be given the identity by flag or config, not by inherited environment; never pipe a commit through `tail`.
- narrative: FOURTH INSTANCE 2026-08-24 RUN 20260824-212117-23585 — orchestrator PurpleDune exported AGENT_NAME and BR_AGENT_NAME in the SAME command as `br comments add bd-21ej -f <file>`; comment still landed as FoggyCreek. Same close-out path as instance 3.
- narrative: THIRD INSTANCE 2026-08-24 — orchestrator exported AGENT_NAME=WildCat BR_AGENT_NAME=WildCat in the SAME command as `br comments add bd-21ej -f <file>` and the comment still landed as FoggyCreek. Same root, close-out path this time rather than a worker claim comment.
- narrative: SECOND INSTANCE 2026-08-23 — the proposed fix below was applied and did not hold. A
  worker exported `AGENT_NAME` and `BR_AGENT_NAME` in the SAME command as the `br` call and `br`
  still wrote the comment as `FoggyCreek`. Every claim comment this run carries the fallback
  identity, with the real worker name surviving only inside the comment TEXT because the seed
  happens to spell it there. That is luck, not design. The entry is therefore widened: the root is
  not merely that shell state is lost between tool calls, it is that `br`'s identity resolution
  does not reliably read the exported environment even when it is present, so no export discipline
  can close it. The audit trail the pull-based model depends on to prove who holds a bead is wrong
  on every entry, and nothing anywhere reports it.
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
- recurrence: 2
- related: []
- first_seen: 2026-08-22
- last_seen: 2026-08-23
- stage: ac-loop-swarm
- status: open
- proposed_fix: point the step at the runbook that already documents the working recovery; delete the forbidden command. Same rule for the stagger: the seed must not prescribe a call the harness refuses.
- narrative: SECOND INSTANCE 2026-08-23 — the worker seed's ONCE block opens with a foreground
  `sleep` to stagger first picks, and this harness blocks foreground sleep outright. Every worker
  spawned hit it on its first action and had to invent its own wait (a date-deadline until-loop,
  or a background shell). The root is unchanged from the first instance below: doctrine naming a
  command the environment refuses. It is worth re-counting because the first instance was closed
  by fixing ONE named command, which did not generalise — the skill still contains other
  prescribed calls never checked against the harness that runs them, and the first thing a worker
  does is the worst place to put one. FIRST INSTANCE — the close-out reconcile step named
  `git stash push -u` as its escape from a dirty
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

## guards-name-each-others-forbidden-commands-as-the-remedy
- skills: [ac-loop-swarm]
- impact: M
- frequency: occasional
- perceptibility: loud
- recurrence: 1
- related: [swarm-doctrine-prescribed-a-guard-blocked-command]
- first_seen: 2026-08-24
- last_seen: 2026-08-24
- stage: ac-loop-swarm
- status: open
- proposed_fix: a guard's remedy text must be checked against the other guards installed in the same repo; where two guards mutually exclude, the runbook route is the only exit and the guard should name it.
- narrative: close-out needed to restore one file to HEAD before a fast-forward. `dcg`'s
  `core.git:checkout-discard` refuses `git checkout -- <path>` and its refusal text prescribes
  `git stash` — which `neometa.stashguard` forbids outright in this checkout, in both the plain
  and the scoped form. Two guards, each naming the other's forbidden command as the safe
  alternative, so following either message walks into the other wall. This is distinct from the
  related entry, where DOCTRINE named a blocked command: here the blocked command is prescribed
  by a GUARD, at the moment of refusal, which is exactly when a caller is most likely to trust it.
  The working exit existed and neither guard mentioned it — the ledger-recovery runbook's
  `git show HEAD:<literal path> > <literal path>`, which is not a checkout and not a stash. A
  guard that cannot name a legal remedy in its own repo should point at the runbook rather than
  invent one.

## commit-message-apostrophe-truncates-the-commit-inside-the-sh-c-wrapper
- skills: [ac-loop-swarm]
- impact: H
- frequency: frequent
- perceptibility: silent
- recurrence: 1
- related: [agent-identity-env-lost-between-tool-calls]
- first_seen: 2026-08-23
- last_seen: 2026-08-23
- stage: ac-loop-swarm
- status: open
- proposed_fix: write the message to a file and use `git commit -F <file>`; never an inline `-m` inside a single-quoted `sh -c` wrapper.
- narrative: the commit step is a `sh -c '…'` wrapper so that the whole add/commit/push sequence
  runs under one flock. The message is passed inline with `-m`. Any apostrophe in the body — and
  this board's prose is full of them, `Craig's`, a bead id's possessive — closes the outer single
  quote. What lands is a commit TRUNCATED at that apostrophe, and the `git push` that followed it
  on the same line never runs at all, while the wrapper still exits 0. Three failures compose into
  one silent one: the message is corrupted, the push is skipped, and the status code says success,
  so the worker proceeds to close its bead believing the work shipped. The quoting hazard is
  ordinary; what makes this high-impact is that the flock wrapper puts the push INSIDE the same
  fragile quoting context as the prose, so a text defect silently becomes a delivery defect.

## ubs-summary-counter-and-language-coverage-both-misreport
- skills: [ac-loop-swarm]
- impact: M
- frequency: every-run
- perceptibility: misleading
- recurrence: 2
- related: [ubs-no-arg-fallback-scans-cwd-instead-of-erroring, the-loops-own-gates-have-false-green-mechanisms]
- first_seen: 2026-08-23
- last_seen: 2026-08-26
- stage: ac-loop-swarm
- status: open
- proposed_fix: report findings not categories in the summary line, and exit non-zero — or print an explicit NOT-CHECKED verdict — when no scanner matched the supplied files.
- narrative: the step-6 gate calls `ubs` and reads its summary. That summary lies in both
  directions. Upward: it printed `Critical: 17` on a file whose own detail lines all read OK,
  because the counter tallies security CATEGORIES CHECKED rather than findings — taken at face
  value it blocks a clean commit, and the only way to recover the real signal is to read every
  detail line or diff criticals against the `git show HEAD:` copy. Downward: it has no shell, CSS
  or markdown scanner, so on a `.sh` or `.css` file it reports a files-scanned count while
  checking nothing; on mixed path lists it silently scanned 3 of 4 and 4 of 5 files. A gate whose
  headline number means neither "findings" nor "files actually checked" cannot be read quickly by
  anyone, which is the only way a per-bead gate ever gets read.
  RUN 20260826-002220-22130 CyanLantern reproduced both directions in one run: `3 critical` and
  `18 critical` on the same scope both resolved to pre-existing `!= null` idioms plus one false
  positive on a local variable named `token`, and `.mdx` turned out to have no scanner at all —
  it reports `nothing was checked - this is NOT a pass`. Add `.mdx` to the uncovered-language
  list alongside shell, CSS and markdown.

## prepush-build-checks-the-working-tree-not-the-pushed-commit
- skills: [ac-loop-swarm]
- impact: M
- frequency: frequent
- perceptibility: misleading
- recurrence: 1
- related: []
- first_seen: 2026-08-23
- last_seen: 2026-08-23
- stage: ac-loop-swarm
- status: open
- proposed_fix: build the pushed commit from a detached or stashless archive of it, not the live working tree; failing that, retry once before reporting a rejection. The build is also globally exclusive, so serialise pushes rather than racing them.
- narrative_addendum: the hook is additionally MUTUALLY EXCLUSIVE across agents — `next build`
  refuses to start while another build holds the lock, and reports it as a plain hook failure
  (`husky - pre-push script failed`). At width 4 every push therefore contends on one global
  build lock, and a worker whose push is refused because a SIBLING is mid-build reads an error
  naming neither the sibling nor the lock. Combined with the working-tree defect above, the
  pre-push gate fails for two unrelated concurrency reasons that present identically.
- narrative: the husky pre-push hook runs a Next.js build against the WORKING TREE. On a shared
  swarm checkout the working tree is never any one worker's: it carries every sibling's in-flight,
  uncommitted edits. So a worker pushing a correct, self-contained commit is rejected by a build
  failure located entirely in code it does not own and did not touch. Three workers hit this and
  all three cleared on a plain retry, because the offending sibling had committed in the interval —
  which is the tell that the check is timing-dependent rather than truth-dependent. The cost is not
  the retry, it is the diagnosis: each rejection reads as "your commit broke the build" and buys a
  full `pnpm build` to disprove. A gate that attributes siblings' half-edits to whoever pushes next
  cannot be used to decide whether a push is safe.

## br-dep-add-argument-order-inverts-the-natural-reading
- skills: [ac-loop-swarm]
- impact: M
- frequency: occasional
- perceptibility: silent
- recurrence: 1
- related: []
- first_seen: 2026-08-23
- last_seen: 2026-08-23
- stage: ac-loop-swarm
- status: open
- proposed_fix: assert the edge direction with `br dep cycles` plus a read-back after every `br dep add`; state the argument order at the call site in any skill that spells the command.
- narrative: `br dep add` reads `<issue> depends on <depends-on>`, so the BLOCKED bead is the
  first argument. Every natural-language framing a worker starts from — "the gate blocks this
  bead", "this bead is blocked by the gate" — puts them the other way round. The edge is created
  successfully either way, so nothing reports the error: a backwards dependency is a well-formed
  edge that silently inverts the board's execution order, making blocked work look ready and ready
  work look blocked. One worker created three backwards edges and a dependency CYCLE before
  `br dep cycles` surfaced it. The command is used exactly when a worker is filing a gate it
  cannot resolve, which is the moment it has least context to notice the inversion.

## br-ready-serves-stale-assigned-open-beads
- skills: [ac-loop-swarm]
- impact: H
- frequency: every-run
- perceptibility: misleading
- recurrence: 2
- related: [harness-reports-worker-dead-on-transient-api-error]
- first_seen: 2026-08-24
- last_seen: 2026-08-24
- stage: ac-loop-swarm
- status: open
- proposed_fix: exclude assignee-set issues from the Phase-0 pickable count and from worker pick; widen the orphan sweep to assigned-open beads whose assignee is not a live actor in `br coordination status`, not only in_progress swarm-RUN_ID claims.
- narrative: SECOND INSTANCE 20260824-212117-23585 — ~19h later, same bead, same assignee, same three-worker no-op. Phase 0 again counted 1 pickable (bd-21ej). RoseBeaver / JadeMoose / WildBear all `--claim` VALIDATION_FAILED against LavenderCastle. Orphan sweep again saw 0 in_progress claims and did not unstick. WildBear's extra face: after VALIDATION_FAILED the seed says goto 1, and `br ready` still returns the assigned row first, so the worker re-picks the same unclaimable bead until it invents an "assigned means taken" filter the seed forbids as narrowing. The morning run's comment on bd-21ej did not change ready-vs-claimable. Until Phase 0 / pick / orphan-sweep exclude stale assignees, every swarm on this pool will close zero beads.
- narrative: Phase 0 counted 1 pickable refined bead (bd-21ej) and spawned width 3. Every worker
  then lost `--claim` with VALIDATION_FAILED because the bead was OPEN (not in_progress) and
  still assigned to LavenderCastle — an ac-loop-2 implement lane from RUN 20260820-001030-26139,
  four days dead, never flipped to in_progress. The orphan sweep looks only at in_progress
  claims held by `swarm-<RUN_ID>-*` actors, so it did not unstick this. Workers treated the
  queue as dry. The ready set and the claimable set diverged by one row, and that one row was
  the entire pool: three workers, zero beads closed. `br ready` asserting pickable work that
  `--claim` will refuse is the misleading face; the silent half is that a leftover implement-lane
  assignee starves a pull swarm with no live holder to negotiate with.

## ubs-heuristic-false-positives-on-non-security-code
- skills: [ac-loop-swarm]
- impact: M
- frequency: frequent
- perceptibility: misleading
- recurrence: 1
- related: [ubs-summary-counter-and-language-coverage-both-misreport]
- first_seen: 2026-08-24
- last_seen: 2026-08-24
- stage: ac-loop-swarm
- status: open
- proposed_fix: suppress or recategorise CACurrentMediaTime, `== null`, and identifier-self-equality as non-findings outside token/secret paths; a step-6 RED must be a DETAIL-line finding on the reserved file, not a heuristic on a clock or an email lookup.
- narrative: RUN 20260824-231514-17151 — three workers spent step 6 on ubs false-REDs that were not the bead. TealWaterfall: `CACurrentMediaTime()` flagged as non-cryptographic randomness for security tokens (it is the session tMs clock in ARSessionManager), plus a pre-existing `== null` in cross-runtime-parity.test.ts. MaroonFalcon: `email === email` flagged CRITICAL timing-safe-compare, forcing a rewrite of an email lookup. Distinct from the summary-counter lie: here the DETAIL lines themselves assert a security finding on non-security code, so reading past the summary still blocks the commit.

## capacitor-stillness-types-live-in-gitignored-dist
- skills: [ac-loop-swarm]
- impact: M
- frequency: occasional
- perceptibility: misleading
- recurrence: 1
- related: []
- first_seen: 2026-08-24
- last_seen: 2026-08-24
- stage: ac-loop-swarm
- status: open
- proposed_fix: either commit a types stub, or make the worker seed name `pnpm --filter @neometa/capacitor-stillness build` as a prerequisite before type-check on plugin API changes.
- narrative: RUN 20260824-231514-17151 PurpleFinch — `@neometa/capacitor-stillness` types come from gitignored `dist/`. Adding `addListener('storage-full')` does not type-check until `pnpm --filter @neometa/capacitor-stillness build`. A scoped type-check RED on a reserved definitions.ts change is therefore a missing-artifact problem, not a type error in the source the worker just wrote.

## playwright-reuseexistingserver-binds-foreign-localhost-3000
- skills: [ac-loop-swarm]
- impact: M
- frequency: occasional
- perceptibility: misleading
- recurrence: 1
- related: []
- first_seen: 2026-08-24
- last_seen: 2026-08-24
- stage: ac-loop-swarm
- status: open
- proposed_fix: fail the e2e harness when the process on :3000 is not this app (probe /sign-up or a known route); never reuse a foreign server on a shared machine.
- narrative: RUN 20260824-231514-17151 MaroonFalcon — localhost:3000 during the run was a foreign 404 server, not this app's /sign-up. Playwright `reuseExistingServer` is therefore unsafe on the shared machine: the suite binds a stranger and the failures name the app under test.

## seed-device-title-filter-starves-native-parity-beads
- skills: [ac-loop-swarm]
- impact: H
- frequency: occasional
- perceptibility: silent
- recurrence: 1
- related: []
- first_seen: 2026-08-25
- last_seen: 2026-08-25
- stage: ac-loop-swarm
- status: open
- proposed_fix: drop titles matching /simulator|real-device/ only, or require the `device` label; do not grep the word `device` in titles of native XCTest / plugin beads.
- narrative: RUN 20260825-221507-7733 BrownHollow — the seed drops any ready title matching `/device|simulator|real-device/`. The only pickable bead was ipy.3, titled "web parity on device". That is XCTest work, not a physical-device sitting. Following the seed would have starved the entire pool. The worker overrode the filter and closed it. Unlabelled device sittings still need a filter; this one is too broad.

## vitest-related-no-op-on-plugin-swift
- skills: [ac-loop-swarm]
- impact: M
- frequency: occasional
- perceptibility: silent
- recurrence: 1
- related: [unrunnable-ac-test-command-must-name-the-repo-runner]
- first_seen: 2026-08-25
- last_seen: 2026-08-25
- stage: ac-loop-swarm
- status: open
- proposed_fix: when Territory is Swift under plugins/stillness, skip vitest related and require the Package XCTest command from CORE/native-testing.md; a passWithNoTests green on zero files is a false green.
- narrative: RUN 20260825-221507-7733 BrownHollow — step 6 `vitest related` on Swift plugin paths is a no-op because `plugins/**` is excluded. The run can print passed-with-no-tests while the real tier is XCTest. The worker noticed and ran XCTest; a worker that trusted vitest related would have closed a native bead on an empty JS suite.

## playwright-install-chromium-prunes-shared-webkit-cache
- skills: [ac-loop-swarm]
- impact: S
- frequency: occasional
- perceptibility: loud
- recurrence: 1
- related: []
- first_seen: 2026-08-24
- last_seen: 2026-08-24
- stage: ac-loop-swarm
- status: open
- proposed_fix: install browsers without deleting unused runtimes from a shared cache, or pin the install to a per-repo cache path.
- narrative: RUN 20260824-231514-17151 MaroonFalcon — `pnpm exec playwright install chromium` also deleted unused webkit from the shared cache. A swarm worker installing one browser mutates siblings' and later sessions' browser availability.

## vitest-related-blind-to-source-scanning-tests
- skills: [ac-loop-swarm]
- impact: L
- frequency: occasional
- perceptibility: silent
- recurrence: 1
- related: [the-loops-own-gates-have-false-green-mechanisms, vitest-related-no-op-on-plugin-swift, vitest-related-fans-out-on-hub-modules]
- first_seen: 2026-08-26
- last_seen: 2026-08-26
- stage: ac-loop-swarm
- status: open
- proposed_fix: step 6 must additionally run the alwaysRunTests set (the raw-line-scan guards) whenever the Territory touches source at all; `vitest related` cannot reach them by construction.
- narrative: RUN 20260826-002220-22130 OrangeGlacier — `vitest related` builds its set from the IMPORT GRAPH, so a guard test that reads files as raw text (`__tests__/unit/no-transition-all.test.ts`) never appears: it imports nothing. The worker's commit added a CODE COMMENT containing a literal that guard forbids. Step 6 was green; the real suite would have gone red. A sibling (CyanLantern) found main already red from the same class and fixed it in d034f024. This is the sharpest form of the false-green family: the gate is not merely shallow, it is structurally incapable of seeing a whole tier of test.

## claim-and-comment-batched-in-one-call-comments-on-a-lost-race
- skills: [ac-loop-swarm]
- impact: S
- frequency: frequent
- perceptibility: loud
- recurrence: 2
- related: [br-ready-serves-stale-assigned-open-beads]
- first_seen: 2026-08-26
- last_seen: 2026-08-26
- stage: ac-loop-swarm
- status: open
- proposed_fix: the seed already says "gate the comment on the claim's exit status" — make it mechanical, e.g. `br update <id> --claim ... && br comments add ...`, and say so in the seed rather than as prose the worker must remember.
- narrative: RUN 20260826-002220-22130 — TWO of three workers (CyanLantern, worker 3) posted a `CLAIM:` comment on a bead whose claim had just lost the race, because they ran claim and comment in one unconditional shell call. Both had to post a retraction. Compounding it: `br update --claim` prints a TRUNCATED JSON body on a lost race, so the `VALIDATION_FAILED` marker is easy to miss when tailing output. Two independent workers hitting it in one run makes this a seed defect, not worker sloppiness.

## bead-body-goes-stale-against-its-own-newer-comments
- skills: [ac-loop-swarm]
- impact: M
- frequency: frequent
- perceptibility: silent
- recurrence: 1
- related: [br-ready-serves-stale-assigned-open-beads]
- first_seen: 2026-08-26
- last_seen: 2026-08-26
- stage: ac-loop-swarm
- status: open
- proposed_fix: move `br comments <id>` BEFORE the premise/scope work in step 3 and make the comment TAIL binding — a bead's newest truth lives in its comments, not its STATUS block.
- narrative: RUN 20260826-002220-22130 CyanLantern — duplicated a sibling's in-flight work twice: bd-4dosp's AC2 (a sibling had answered it three minutes earlier) and bd-fc1du/bd-motion AC2 (already shipped, bead never closed). Root cause is two-part: `br ready` re-lists a bead the instant it is released, and the bead's own STATUS block goes stale relative to its newer comments. The seed already tells workers to read comments, but AFTER scoping, which is too late to prevent the duplicate.

## shared-tree-half-edits-redden-checks-beyond-the-60s-retry
- skills: [ac-loop-swarm]
- impact: M
- frequency: frequent
- perceptibility: loud
- recurrence: 1
- related: [prepush-build-checks-the-working-tree-not-the-pushed-commit]
- first_seen: 2026-08-26
- last_seen: 2026-08-26
- stage: ac-loop-swarm
- status: open
- proposed_fix: the wait-60s-retry-once rule is not enough; the only reliable resolution is the sibling's COMMIT landing. Either wait on the commit (poll `git log`) or treat a failure confined to unreserved files as not-yours and proceed.
- narrative: RUN 20260826-002220-22130 CyanLantern — a sibling's mid-edit tree turned the worker's `vitest related` red on `blog-page-metadata`, files the worker never touched (1 failure, then 3 sixty seconds later), then green once the sibling committed. The seed's "wait 60s, retry once, then own it" would have had this worker OWN a failure that was never theirs. Also hit OrangeGlacier from the other side: the pre-push build compiles the working tree, so a sibling's half-edit reddens your push.

## ledger-recovery-runbook-prescribes-a-br-subcommand-that-does-not-exist
- skills: [ac-loop-swarm]
- impact: L
- frequency: occasional
- perceptibility: loud
- recurrence: 1
- related: [swarm-doctrine-prescribed-a-guard-blocked-command, guards-name-each-others-forbidden-commands-as-the-remedy]
- first_seen: 2026-08-26
- last_seen: 2026-08-26
- stage: ac-loop-swarm
- status: open
- proposed_fix: update `_docs/runbooks/beads-ledger-recovery.md` to use `br sync --import-only` (and note `br sync --merge --force` = newer-timestamp-wins); `br import` is not a subcommand in the installed br.
- narrative: RUN 20260826-002220-22130 StormyRidge (orchestrator) — close-out needed Recovery A because origin/main had a nightly ac-tidy ledger commit the swarm DB never imported. Every command the runbook prescribes for the union is `br import <file>`, which exits `unrecognized subcommand 'import'`. The documented recovery for the highest-stakes data operation in the pipeline cannot be executed as written. The orchestrator had to hand-build the union in Python and load it with `br sync --import-only`. The runbook is otherwise correct — the arithmetic check it prescribes (Created/Updated/Skipped) validated the union exactly (Created 0, Updated 40, Skipped 3178, matching the incoming commit's 40-row diff).

## full-ledger-re-export-invalidates-every-gitleaks-line-fingerprint
- skills: [ac-loop-swarm]
- impact: M
- frequency: occasional
- perceptibility: loud
- recurrence: 1
- related: []
- first_seen: 2026-08-26
- last_seen: 2026-08-26
- stage: ac-loop-swarm
- status: open
- proposed_fix: prefer fingerprints that are not line-keyed for `.beads/issues.jsonl`, or accept that any forced full re-export requires re-deriving the whole `.beads/issues.jsonl:generic-api-key:<line>` block in one pass (`gitleaks protect --staged --report-format json`).
- narrative: RUN 20260826-002220-22130 StormyRidge — `br sync --flush-only --force` rewrote all 3218 rows, shifting every line number. All four staged findings were already-known false positives (bead labels, RED-gate identifier constants, and one two-word DB-filter phrase in a worker close-comment) but every existing line-keyed allowlist entry now pointed at the wrong line. The `.gitleaksignore` header already warns "line numbers shift as .beads/issues.jsonl grows"; a forced re-export makes that shift total rather than incremental.

## prepush-gate-exceeds-tool-timeout-success-reads-as-failure
- skills: [ac-loop-swarm]
- impact: S
- frequency: frequent
- perceptibility: loud
- recurrence: 1
- related: [prepush-build-checks-the-working-tree-not-the-pushed-commit]
- first_seen: 2026-08-26
- last_seen: 2026-08-26
- stage: ac-loop-swarm
- status: open
- proposed_fix: seed step 7 should name an explicit long timeout for the push, and tell the worker to confirm via `git log origin/main` rather than the tool's exit report.
- narrative: RUN 20260826-002220-22130 OrangeGlacier — the pre-push hook runs a full Next build plus the journey e2e (~2 min, measured 42s for e2e alone at close-out), which exceeds the default Bash timeout. The push SUCCEEDS but the tool reports a timeout, so it reads as a failure. A worker that believes the report will retry a push that already landed, or wrongly record PUSH_REJECTED.

## agent-mail-outage-leaks-reservations-until-ttl
- skills: [ac-loop-swarm]
- impact: S
- frequency: rare
- perceptibility: loud
- recurrence: 1
- related: [agent-identity-env-lost-between-tool-calls]
- first_seen: 2026-08-26
- last_seen: 2026-08-26
- stage: ac-loop-swarm
- status: open
- proposed_fix: on an Agent Mail connection error at step 9, retry on the next loop iteration rather than proceeding; the orchestrator's close-out force-release already covers the terminal case.
- narrative: RUN 20260826-002220-22130 OrangeGlacier — Agent Mail was unreachable for roughly five minutes mid-run ("Unable to connect"). Reservations could only be released on a later retry and would otherwise have leaked until TTL, blocking siblings from paths nobody was editing.

## br-create-rejects-file-body-together-with-a-title
- skills: [ac-loop-swarm]
- impact: S
- frequency: occasional
- perceptibility: loud
- recurrence: 1
- related: [br-dep-add-argument-order-inverts-the-natural-reading]
- first_seen: 2026-08-26
- last_seen: 2026-08-26
- stage: ac-loop-swarm
- status: open
- proposed_fix: document the form in the seed — `br create "<title>" -d "$(cat <file>)"`; `-f` is comments-only.
- narrative: RUN 20260826-002220-22130 CyanLantern — the seed tells workers to pass prose through a file to dodge the destructive-op matcher, but `br create` rejects `-f` and a title in the same invocation, so a file-based body must go through `-d "$(cat file)"`. The rule and the tool disagree, discovered only at the point of filing a bead.

## dcg-blocks-redirect-to-a-variable-expanded-scratch-path
- skills: [ac-loop-swarm]
- impact: S
- frequency: frequent
- perceptibility: loud
- recurrence: 1
- related: [dcg-false-positives-on-angle-bracket-inside-quoted-prose, swarm-doctrine-prescribed-a-guard-blocked-command]
- first_seen: 2026-08-26
- last_seen: 2026-08-26
- stage: ac-loop-swarm
- status: open
- proposed_fix: write scratch files to the fully-literal job-dir path; do not use `$CLAUDE_JOB_DIR` or any variable on the left of `>`.
- narrative: RUN 20260826-002220-22130 StormyRidge — the harness supplies the scratch directory AS a variable (`$CLAUDE_JOB_DIR/tmp`) and instructs agents to use it, but `core.filesystem:redirect-truncate-dynamic-path` blocks any redirect whose target is variable-expanded, because dcg cannot resolve it before O_TRUNC. Two calls were rejected before switching to literal paths. The harness instruction and the guard are in direct tension.
