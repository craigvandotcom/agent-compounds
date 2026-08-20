---
skill: ac-loop-2
created: 2026-08-09
last_pass: 2026-08-20
entries: 16
---

# ac-loop-2 — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

<!-- ac-loop's friction log is NOT this skill's history: the phase model changes which
     frictions are even possible. Start empty; do not import entries from v1. Cross-cutting
     frictions that recur here AND in ac-loop stay counted in each log, cross-referenced
     via `related:`. -->

## commit-mutex-lock-path-assumes-git-is-a-directory
- skills: [ac-loop-2]
- impact: L
- frequency: every-run
- recurrence: 2
- related: [harness-tool-defects-are-the-machinery-bead-volume-driver]
- first_seen: 2026-08-11
- last_seen: 2026-08-17
- stage: build
- status: open
- proposed_fix: derive the lock path with `git rev-parse --git-common-dir` (NOT `--git-dir`, which is per-worktree and re-opens the collision under linked worktrees), add a liveness assertion logging seconds-to-acquire, fail LOUD on "cannot create" (ENOTDIR/EACCES) instead of folding it into the "held by someone else" retry path, and cut the retry bound to safely under the Bash tool's 600s cap.
- narrative: THE RUN'S HEADLINE DEFECT. Phase 2's only mandated safety mechanism was INERT for the
  entire run and nobody could tell. The briefed lock path is `$PROJECT_ROOT/.git/ac-loop2-commit.lock`,
  but `.git` in body-compass-app is a 64-byte git-submodule POINTER FILE, so `mkdir` returns
  ENOTDIR on every one of 450 retries — indistinguishable from "lock held" to the retry loop. Found
  independently by two lanes (the curator lane observed ZERO lock directory while siblings were
  landing commits), then reproduced by the conductor. SYSTEMIC: every neoMeta app under `software/`
  is a submodule, so this is not BCA-specific. Five clean Phase-2 commits landed anyway — through
  lane spacing and territory disjointness, NOT through the mechanism briefed to provide that
  guarantee, which makes the clean outcome zero evidence the mutex works. Compounding: the 450x2s
  bound is 900s, which exceeds the Bash 600s cap, so a stuck worker is SIGTERMed before its own
  FATAL line can print — silent by construction; the guards lane burned a full 10-minute tool
  timeout and landed nothing. The corrected form was proven live in this same run: the serial risk
  queue acquired first try at the `--git-common-dir` path. Beads bd-ye0rp (P0, its body still
  specifies the narrower `--git-dir` and needs amending), ac-ac-loop2-commit-mutex-submodule-fsmh
  (agent-compounds board), bd-giy7u (P1, the 900s-vs-600s collision). Fleet fact:
  `neometa/memory/auto/loop-retro-neometa-app-dotgit-is-a-pointer-file.md`.
  **+1 — the briefed template is itself unrunnable, and lanes fork it silently.** A build lane
  handed the mutex recipe could not run the RELEASE line: dcg blocks any redirect whose target
  is a runtime-expanded variable, which is exactly the shape the briefed recipe is written in.
  The lane wrote its own variant rather than reporting the block, so the run held two different
  mutex implementations with no way to tell which lanes shared a lock. Two properties compound
  here — the recipe cannot be executed as briefed, and a lane's cheapest response to that is a
  private fork — so the fix must be a LITERAL-path, copy-paste-runnable snippet in
  `references/`, verified against dcg before it is briefed, never a shape a child must adapt.

## phase-3-global-pass-does-not-state-which-test-tiers-it-covers
- skills: [ac-loop-2]
- impact: L
- frequency: occasional
- recurrence: 1
- related: [commit-mutex-lock-path-assumes-git-is-a-directory]
- first_seen: 2026-08-11
- last_seen: 2026-08-11
- stage: converge
- status: fixed
- proposed_fix: LANDED — element 3 requires `### Test-tier exposure` in bead-conventions § Implementation contract; Phase 3 must enumerate covered/excluded tiers and run any declared tier the standing pass skipped (`converge-phase.md` § 1).
- narrative: Phase 3 reported `pnpm test:all` 12366 passed / 0 failures on 0c1ca0a7. The identical
  commit then failed CI's DB Deploy validate leg TWICE with 23514 constraint violations, because
  `__tests__/supabase-integration/**` (74 files / 705 tests) is excluded from the standing vitest
  gate by config and runs only under `pnpm test:integration:local`. So a migration-shaped bead can
  satisfy every Phase-3 signal the loop checks and still be wrong. The converge agent NOTED the
  exclusion in its report and the conductor did not treat it as a hole — the conductor's error, not
  the agent's, which is why the fix is a required report field rather than an exhortation. Direct
  cause of the run's repair% breach: 1 repair item / 6 beads = 16.7%, above the 10% guidance line,
  and specifically a TEST-TIER scope miss rather than a spec miss (the bead's spec was complete; it
  was never asked the question). Cost: a full repair round of a 2-round cap, a fixture rewrite,
  a second CI dispatch. Beads bd-qouko (project-local hole), bd-04bfp (the contract fix, human-gate).

## frozen-head-is-not-enforceable-on-a-shared-checkout
- skills: [ac-loop-2]
- impact: M
- frequency: every-run
- recurrence: 2
- related: [filed-beads-carry-drifted-anchors-and-false-premises]
- first_seen: 2026-08-11
- last_seen: 2026-08-13
- stage: spec
- status: open
- proposed_fix: stop treating FREEZE_SHA as a guarantee and state its real status in the skill: it is a LABEL for a moment, not a lock. Every barrier crossing and every anchor re-check must MEASURE drift (`git diff --name-only FREEZE..HEAD`) and intersect the changed paths against each lane's territory, rather than trusting that the freeze held. Say explicitly which artifact classes survive drift (file-derived anchors) and which do not (board-derived counts). JSONL ADDITION: last-line-wins on `.beads/issues.jsonl` can destamp a `refined` record when nightly tidy (or any out-of-loop writer) rebases the same rows — on that conflict, prefer the refined side.
- narrative: reported independently THREE times in one run by three different agents. A concurrent
  non-loop curator session moved HEAD twice during Phase 1 alone (853fcd8c to cdc22bc3 to 96c01acb).
  Nothing in ac-loop-2 can stop this — the checkout is shared with sessions that never read the
  skill — so a contract written as though the freeze holds is unenforceable by construction. The
  observed split is the useful part and belongs in the skill text: file-derived anchors held across
  the drift, board-derived counts drifted WITHIN the run (the cross-repo bead fraction was measured
  at 10/22, then 12/30 later the same run, partly self-inflicted by the refining agent's own
  stamps). The run's own Phase 1-to-2 barrier did the right thing — it diffed the freeze against
  live HEAD and confirmed the changed paths were disjoint from every refined bead's territory — so
  the correct behaviour already exists in practice and just needs to be the written contract.
  **RUN 20260813-235654-12053 (BCA, ac-loop-2 Phase 1), +1 — a new writer class, and a new
  artifact class that does not survive.** Nightly tidy moved origin during Phase 1 (rebase
  conflict). Last-line-wins on `.beads/issues.jsonl` can destamp a `refined` record when the
  tidy rewrite of the same rows lands after the refine stamp. Prefer the refined side on that
  conflict. This extends the original split: file-derived anchors still hold, board-derived
  counts still drift, and now the jsonl row itself can lose its stamp. Same root — the freeze
  is a label, not a lock — with a merge-resolution rule the first run did not have.

## skill-edit-guard-fires-on-reads-under-skills
- skills: [ac-loop-2]
- impact: S
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: 2026-08-11
- last_seen: 2026-08-11
- stage: build
- status: open
- proposed_fix: document the actual trigger surface where children are told to consult registry doctrine — the agent-compounds skill-edit guard fires on READ operations under `skills/`, not only on writes — and give the accepted read form so a child does not read the block as "this file is off-limits" and silently skip the doctrine it was told to check.
- narrative: a child instructed to consult registry doctrine was blocked while merely READING a file
  under `skills/`. The guard's name and every mental model of it say "edit", so the block reads as a
  permissions error rather than an expected shape, and the cheap wrong response is to skip the read
  and proceed on memory. Small cost this run, but the failure mode is invisible: a child that skips a
  doctrine read reports nothing unusual. Note the contrast with ac-human-session's
  `am-edit-guard.py` entry, where the Agent Mail guard was in advisory mode and did NOT fire on four
  real shared-registry edits — two different guards, opposite calibration errors, same net effect of
  agents not knowing what is actually enforced.

## dcg-false-positives-on-angle-bracket-inside-quoted-prose
- skills: [ac-loop-2]
- impact: M
- frequency: frequent
- recurrence: 0
- related: []
- first_seen: 2026-08-11
- last_seen: 2026-08-11
- stage: build
- status: open
- proposed_fix: see the primary entry.
- narrative: POINTER ENTRY, not a copy — the PRIMARY is this same id in `skills/ac-loop/FRICTIONS.md`,
  where all occurrences are counted (recurrence 6 as of RUN 20260811-113939-36193). Recorded here
  because the v2 phase model inherits the hazard unchanged and its own delegation prompts emit it.
  LOCAL MANIFESTATION: five independent blocks in one ac-loop-2 run — conductor, doctrine refine
  child, ledger build child, and the closing/reflect ceremonies — each rediscovering the same
  heredoc-to-file workaround at its own cost. Trigger set is wider than shell redirects: ASCII
  arrows in ordinary prose tokenise identically, so writing ABOUT the hazard triggers it. Local fix:
  `ac-loop-2/references/delegation-prompts.md` must tell every prompt that writes bead body text to
  write the prose to a literal temp file and pass the file, and to keep bracket-style placeholders
  out of prose entirely.

## filed-beads-carry-drifted-anchors-and-false-premises
- skills: [ac-loop-2]
- impact: M
- frequency: every-run
- recurrence: 0
- related: []
- first_seen: 2026-08-11
- last_seen: 2026-08-11
- stage: spec
- status: open
- proposed_fix: see the primary entry.
- narrative: POINTER ENTRY, not a copy — the PRIMARY is this same id in
  `skills/ac-bead-refine/FRICTIONS.md`, where occurrences are counted. Recorded here because it is
  the strongest validation ac-loop-2's own implementation contract received this run. LOCAL
  MANIFESTATION: cited `file:line` anchors had drifted in 100% of the beads audited, 13 separate
  drifts in a single bead — which makes contract element 1 (re-open every anchor at the frozen HEAD)
  load-bearing rather than ceremony, and makes an inherited "verified" claim from a prior refine
  round worthless as evidence. Element 6 (the adversarial break-attempt round) separately caught a
  territory omission that would have shipped a self-contradictory, byte-parity-CI-enforced prompt
  pair asserting the OPPOSITE of Craig's ruling; a refine without that round would have stamped it
  refined. Both elements earned their cost in measured terms this run — record that before anyone
  proposes trimming them.
  **+1, and the payoff moved from CORRECTING beads to KILLING them.** A later run's spec phase
  destroyed two beads before a line of code was written: one had already been fixed two months
  earlier and had sat with a frozen body while five comments carried the real state, and one's
  agent-deliverable half was already delivered. It also corrected a third bead's scale by
  roughly 12x — 226 consecutive failed deploys over ~88 days, not the 19 over 39 the body
  claimed, because the author had read a paginated `vercel ls` rather than the full list. Three
  beads, and in every case the bead's own body was the least reliable artifact about itself.
  This is the sharpest available argument about WHERE verification effort belongs: killing a
  bead in spec costs one child, while discovering the same fact in build costs a dispatch, a
  diff, a review and a close — and not discovering it means shipping a fix for a bug that no
  longer exists. Record the direction: the value of the spec phase is not that it writes better
  specs, it is that it declines to spend the rest of the pipeline.

## refine-all-degrades-to-priority-cut-when-set-exceeds-width
- skills: [ac-loop-2]
- impact: H
- frequency: every-run
- recurrence: 0
- related: []
- first_seen: 2026-08-11
- last_seen: 2026-08-11
- stage: spec
- status: fixed
- proposed_fix: LANDED — Phase 1 item 2 restated as a DRAIN (width bounds concurrency, never
  coverage; conductor decides ORDER, never MEMBERSHIP), grouping/order/assertion moved to
  `references/refine-drain.md`, and a `refine-drain:` assertion added to the sitting barrier.
- narrative: Phase 1 said refine "every unrefined non-`human-gate` bead" but fixed width at 5-6 and
  defined NO overflow behaviour. RUN 20260811-113939-36193 opened with 83 unrefined beads against a
  width of 5, so "every" silently degraded to "as many as fit" and the conductor improvised a cut.
  The nearest signal to hand was `priority` — which on this board encodes WHO FILED THE BEAD, not
  its value. Measured: 9 of 9 Craig-reported beads sat at P2; 14 of 26 agent-filed beads sat at
  P0/P1. A `priority <= 1` cut therefore admitted 14 agent-filed beads and STRUCTURALLY ZERO
  human-reported ones — it was arithmetically impossible for a Craig bug report to enter the wave.
  Eleven of his product bugs (input hidden behind the keyboard, credit-failed rows never
  self-healing, widget staleness) were ready, unblocked, non-human-gate, and invisible; one was
  re-discovered hours later by an expensive device-QA pass in the same run. The loop shipped
  beads-ledger guards and husky hooks instead. NOTE the regression direction: `ac-loop` v1 already
  states the correct doctrine ("ONE eligible-work queue, dispatched CONTINUOUSLY up to
  PARALLEL_WIDTH... the list is PRIORITY, NOT a barrier") and carries a Rule-0 Bug Lane that would
  have caught these. v2's phase-gated redesign dropped both and replaced them with nothing, so this
  is a restoration, not an invention. v1 needs no edit.

## phase-skills-mandate-panels-a-subagent-cannot-spawn
- skills: [ac-loop-2]
- impact: L
- frequency: every-run
- recurrence: 0
- related: [refine-all-degrades-to-priority-cut-when-set-exceeds-width]
- first_seen: 2026-08-13
- last_seen: 2026-08-14
- stage: spec
- status: open
- proposed_fix: see the primary entry.
- narrative: POINTER ENTRY, not a copy — the PRIMARY is this same id in `skills/ac-loop/FRICTIONS.md`,
  where occurrences are counted (recurrence 32 as of RUN 20260814-213141-15553). Land suggested
  minting `phase-1-refine-all-degraded-solo-no-task-tool`; judged same-root (no Task tool, sequential
  lenses, independence lost) and not minted. LOCAL MANIFESTATION: every Phase-1 refine child this
  run was degraded-solo (no Task tool in this harness) and ran 3-4 sequential lenses. The honesty
  half of bd-nreuv held — children stamped `degraded-solo` rather than faking a panel. What this
  run adds is a conductor-facing rule: do not collapse drain width because quality is solo
  (throughput across beads is still paid), and a sitting must not be read as panel-quality.
  **RUN 20260814-213141-15553 — same root under ac-loop (not v2):** sequential 3-round refine,
  no Task tool, `degraded-solo` stamped. Counted at the primary.

## later-overlap-revert-is-unprobeable-not-hollow
- skills: [ac-loop-2]
- impact: M
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: 2026-08-14
- last_seen: 2026-08-14
- stage: converge
- status: open
- proposed_fix: when a later commit rewrites a shared file, a full-commit revert that auto-merges and stays green is UNPROBEABLE, not hollow. Probe by isolated-file revert of the bead's exclusive paths; exclude unprobeable from the hollow% denominator; do not reopen.
- narrative: RUN 20260814-062417-51731 (BCA, ac-loop-2 Phase 3). The mutation probe on the
  onboarding bead reverted its commit into 7oss7's later `page.tsx` rewrite; git auto-merged
  and the named test stayed green. That is not a hollow test — the later overlap made the
  commit-revert a no-op on the shared file, so the probe never removed the onboarding change.
  Isolated-file revert of 6iikv's exclusive `entries-view` path was the honest probe on the
  same sample (page.tsx is shared; that file is not). converge-phase.md § 5 currently has
  only PASS / HOLLOW / MISMATCH — a later-overlap stay-green scores as HOLLOW and would
  reopen a working bead and inflate hollow%. Cost this run was minor (classified correctly
  in the carrier; hollow% stayed 0/6) but the skill text will mis-score it next time.
  Evidence: carrier `/tmp/loop-retro-20260814-062417-51731.md`; commits `7771f324` (7oss7
  page.tsx) vs the onboarding commit it overlapped.

## machinery-findings-route-to-the-board-as-beads
- skills: [ac-loop-2]
- impact: L
- frequency: every-run
- recurrence: 1
- related: [harness-tool-defects-are-the-machinery-bead-volume-driver, discoveries-filed-never-fixed-has-no-trivial-harness-exception]
- first_seen: 2026-08-17
- last_seen: 2026-08-17
- stage: build
- status: open (policy half SHIPPED — `references/filing-bar.md` gives the loop a kind-then-bar router and `beads-standards` gives priority an admission test; the two causes below survive that fix and are logged as their own ids)
- proposed_fix: keep the kind-then-bar router as the single filing gate and measure it next run — machinery percentage of filed beads is the metric; if it does not collapse, the residual is the harness defect rate, not the policy.
- narrative: 51 beads filed in one run, 16 of them about the pipeline rather than the app — a
  third of the board's intake was the factory describing itself. Four causes, in volume order,
  two of which are now fixed. FIXED: the known-action rule had no PRODUCT AXIS, so a broken tool
  flag and a user-facing bug routed identically; the same sentence told children that a prose
  findings channel ORPHANS, so a child that cared about its finding rationally preferred a bead
  to a friction entry (we told them frictions do not survive, then were surprised they avoided
  them); and nothing CLASSIFIED at the filing site, since labels describe after the fact and
  gate nothing. Those three are answered by the filing bar. SURVIVING: the harness's own defect
  rate (the volume driver) and the no-trivial-fix absolute, both logged separately below. The
  structural lesson is the ordering — the policy was the easy half, and the run's own root-cause
  pass found that fixing the tools would have collapsed the rate with no discipline change at
  all. Evidence: carrier `/tmp/loop-retro-20260817-122900-2583.md` § NON-PRODUCT BEAD ROOT-CAUSE
  ANALYSIS; 13 of the 16 were closed and their substance migrated into that carrier.

## harness-tool-defects-are-the-machinery-bead-volume-driver
- skills: [ac-loop-2]
- impact: L
- frequency: every-run
- recurrence: 1
- related: [machinery-findings-route-to-the-board-as-beads, commit-mutex-lock-path-assumes-git-is-a-directory]
- first_seen: 2026-08-17
- last_seen: 2026-08-17
- stage: build
- status: open
- proposed_fix: treat the seven footguns below as a fix LIST, not a lore list — each is a one-line tool or wrapper fix, and each is currently paid for by every child that meets it. Until they are fixed, carry them as a verbatim ENVIRONMENT CONTRACT block in every child brief (the run that did this saw children pre-empt three of them); a footgun a child must rediscover is a footgun charged once per child per run.
- narrative: the run's root-cause pass named this THE volume driver behind machinery beads, above
  any policy cause. Seven harness defects, each hit by MULTIPLE independent children in a single
  run: dcg blocks any redirect whose target is a runtime-expanded variable (6-plus lanes, and the
  conductor's own briefed mutex recipe is written in exactly that shape); `br comments ID add`
  silently no-ops at exit 0 while echoing the text back, so a child believes it filed a comment
  that does not exist (2-plus lanes); `rg -rn` parses as `rg -r n` and SILENTLY REWRITES the
  matched files (2 lanes, one of which nearly filed a bogus P1 off the corrupted output);
  vitest-affected silently excludes a directly-NAMED file when that file is absent from its
  graph; `pnpm test:integration:local` with a file pattern after the double-dash ignores the
  pattern and runs all 82 integration files (157s instead of ~1s, with the wanted file buried in
  93 unrelated failures — trivially misread as "my change broke everything"); `git commit --
  PATH -m MSG` fails because a dash-m after the double-dash reads as a pathspec; and zsh does
  not word-split unquoted variables, so a `git add --` with a variable holding several paths
  collapses to one pathspec. What makes these expensive is not the individual cost but the shape:
  every one is SILENT (exit 0, or a coherent-looking wrong result), so the child's next action is
  built on a false observation, and every encounter qualifies as a "known action" that the filing
  rule then routes to the board. The defect rate is a tooling-quality problem wearing a
  discipline problem's clothes.

## discoveries-filed-never-fixed-has-no-trivial-harness-exception
- skills: [ac-loop-2]
- impact: M
- frequency: every-run
- recurrence: 1
- related: [machinery-findings-route-to-the-board-as-beads]
- first_seen: 2026-08-17
- last_seen: 2026-08-17
- stage: build
- status: open
- proposed_fix: admit one bounded exception to "discoveries are filed, never fixed" — a MACHINERY fix that touches no product file, is a single line or a single flag, and is committed as its OWN commit with no bead trailer, may be fixed in place and reported in the `friction:` block. One-bead-one-commit is preserved because the fix carries no bead; bisect attribution is preserved because the commit is separate and product-empty. Everything touching a product file stays filed, unchanged.
- narrative: the absolute exists for a real reason — one-bead-one-commit is the basis of Phase 3's
  bisect attribution, and a worker that opportunistically fixes things destroys the mapping from
  commit to bead. But it admits NO exception for a one-line harness fix a worker could make
  safely in seconds, so a broken flag in a wrapper script becomes a bead, a refine cycle, a
  dispatch, and a commit — process weight two orders of magnitude above the fix. Combined with
  the harness defect rate this is a multiplier, not an additive cost: the tools the rule forbids
  fixing are precisely the tools generating the findings, so each run re-files what the last run
  was forbidden from repairing. Note the interaction with the new filing bar: machinery may no
  longer be filed as a bead at all, which means without a fix exception a trivial harness defect
  now has NO route to repair — it lands in a friction log and waits for a promotion pass. That
  makes the exception more load-bearing after the bar than before it.

## device-only-native-beads-are-dead-dispatches-in-the-risk-queue
- skills: [ac-loop-2]
- impact: M
- frequency: every-run
- recurrence: 1
- related: []
- first_seen: 2026-08-17
- last_seen: 2026-08-17
- stage: risk-queue
- status: open
- proposed_fix: pre-filter the Phase-2 risk queue before dispatching it — a bead whose acceptance criteria already state that a physical device is required is UNRUNNABLE in this harness, and re-deriving that fact costs a full serial dispatch each time. Filter on the ACs' own words at queue-build time, mark the beads `device-blocked`, and report them as a queue exclusion rather than sending an agent to read them.
- narrative: the risk queue held 13 beads; 9 of them returned `unrunnable` for the same reason —
  a real iPhone is required — and in every case the bead's own acceptance criteria SAID SO in
  text the queue builder had already read. Nine serial dispatches (the risk queue runs at width
  1, so this is the most expensive place in the pipeline to waste a slot) produced nine
  re-derivations of a fact that was sitting in the input. The generalisation worth keeping: a
  queue that dispatches an agent to discover something stated in the queue's own source data is
  paying agent-minutes for a grep. Any phase that builds a work list from bead text should extract
  the runnability preconditions at BUILD time, not at dispatch time.

## concurrent-qa-browser-and-qa-device-contend-for-one-test-account
- skills: [ac-loop-2]
- impact: M
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: 2026-08-17
- last_seen: 2026-08-17
- stage: verify
- status: open
- proposed_fix: run qa-browser and qa-device SEQUENTIALLY. They are territory-disjoint in files and NOT disjoint in state — one shared test account, one shared journey-stamp store — so the loop's file-based disjointness test does not model them. State the rule in the verify phase rather than leaving it to the conductor's wall-clock judgement.
- narrative: the conductor ran both QA passes in parallel to save wall-clock and they contended
  over a single test account, overwriting three sim-drive journey stamps — evidence destroyed,
  not merely delayed, since a stamp is the artifact the pass exists to produce. The interesting
  part is WHY the conductor believed it was safe: territory disjointness in ac-loop-2 is defined
  over FILES, and these two passes touch no common file. The disjointness model has no term for
  shared external state (a test account, a simulator, a stamp store, a build slot), so anything
  whose collision surface is outside the repo reads as safe to parallelise. Recorded here rather
  than as a QA-skill friction because the defect is in the loop's concurrency model, not in
  either QA skill.

## coordinator-layer-drops-work-on-a-short-lane
- skills: [ac-loop-2]
- impact: M
- frequency: occasional
- recurrence: 1
- related: [conductor-briefs-assert-inferred-facts-as-established]
- first_seen: 2026-08-20
- last_seen: 2026-08-20
- stage: build
- status: open
- proposed_fix: size the delegation layer to the lane — dispatch build workers DIRECTLY when a lane holds two or fewer beads, and spend a coordinator only where there are enough beads that sequencing is real work. A coordinator whose entire job is to order two beads adds a turn boundary without adding judgement, and a turn boundary is where in-flight children die. Corollary for recovery: re-derive lane state from `git log` rather than from the detached coordinator's report, since the report is exactly the artifact that did not survive.
- narrative: a lane coordinator ended its turn while its build worker was still in flight, violating the delegation contract's clause 5. The first bead of the lane had already landed; the second worker died with the coordinator's turn and produced nothing. The cost was recoverable — lane state was rebuilt by reading git rather than the report, and the coordinator was resumed with verified facts and told to do the remaining small bead in-session rather than hand it off a third time — but the shape is worth naming because it is a pure structural loss. The lane had two beads and one ordering constraint, so the coordinator contributed no decision the conductor had not already made when it built the lane; every hop it added was a place work could be dropped and none was a place judgement was added. Note the interaction with the delegation contract generally: clause 5 forbids self-detaching while a child is live, but nothing sizes the layer in the first place, so the contract is defending a structure that should not have existed on a lane this short.

## conductor-briefs-assert-inferred-facts-as-established
- skills: [ac-loop-2]
- impact: H
- frequency: every-run
- recurrence: 0
- related: [filed-beads-carry-drifted-anchors-and-false-premises]
- first_seen: 2026-08-17
- last_seen: 2026-08-17
- stage: spec
- status: open
- proposed_fix: see the primary entry.
- narrative: POINTER ENTRY, not a copy — the PRIMARY is `delegation-brief-restates-bead-preconditions`
  in `skills/ac-loop/FRICTIONS.md`, where occurrences are counted (recurrence 5), with the
  canonical statement in memory `loop-retro-delegation-brief-claims-are-hints`. LOCAL
  MANIFESTATION, and the strongest evidence the v2 phase model has produced for the rule: across
  a 9-hour, ~40-agent run the conductor put FIVE false premises into child briefs — an inherited
  risk flag, a discharged bead described as fresh work, a UI claim about a backend-only change,
  an "already built" app whose installed bundle predated the commit under test by 80 minutes, and
  a test-tier waiver argued from a local symptom against a tier CI measured green. Five caught by
  children, zero caught by the conductor. At v2's width and duration the conductor writes more
  briefs from more compacted context than any earlier loop version, so the defect rate scales with
  the very thing v2 exists to increase — which makes child-side re-verification a STRUCTURAL
  requirement of the phase model, not a quality nicety, and it should be stated that way wherever
  v2 composes a brief.
  **NOT COUNTED — a positive confirmation, recorded so the weighting pass does not miss it.** A
  later v2 run put a wrong absolute brand path into a worker's brief and it cost ZERO: the worker
  sourced its territory from `br show` and never depended on the prose, so the conductor's error
  decayed into nothing. Deliberately NOT a recurrence bump at the primary — counting a no-cost
  occurrence would inflate the pain signal for the case where the mitigation WORKED, and invert
  what the count means. Captured instead in memory
  `loop-retro-delegation-brief-claims-are-hints` (recurrence 7). Read the two together before
  anyone proposes trimming child-side re-verification as overhead: this log records what the
  defect costs, and only that memory records what the defence saves.
