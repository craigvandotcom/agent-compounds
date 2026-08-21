---
skill: ac-loop-2
created: 2026-08-09
last_pass: 2026-08-21
entries: 25
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
- recurrence: 3
- related: [harness-tool-defects-are-the-machinery-bead-volume-driver, commit-mutex-does-not-resync-or-assert-the-branch]
- first_seen: 2026-08-11
- last_seen: 2026-08-20
- stage: build
- status: open
- proposed_fix: derive the lock path with `git rev-parse --absolute-git-dir` — NOT `--git-dir` (per-worktree, re-opens the collision under linked worktrees) and NOT `--git-common-dir` (returns a RELATIVE path, so the lock resolves against each worker's own cwd). Add a liveness assertion logging seconds-to-acquire, fail LOUD on "cannot create" (ENOTDIR/EACCES) instead of folding it into the "held by someone else" retry path, and cut the retry bound to safely under the Bash tool's 600s cap.
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
  **+1 (RUN 20260820-005558-8974) — the CORRECTED form was also wrong, and this is the third
  spelling of one flag.** The previous occurrence's fix (`--git-common-dir`) was propagated to
  ~20 workers by the conductor and is ALSO defective: `--git-common-dir` returns a **relative**
  path, so every worker resolved the lock against its own cwd and a cross-repo worker silently
  contended for the wrong repo's lock — a mutex that appears to be held and shared while
  actually partitioning workers into private locks. Only `--absolute-git-dir` is correct. Two
  properties make this worth its own note rather than a footnote on the fix: (a) the bad form
  appears in NO skill file — it was conductor improvisation pasted into a delegation brief, so
  a doctrine grep would not have found it and a doctrine edit will not prevent the next one;
  (b) all three spellings of the flag succeed and print a path, so the difference between them
  is invisible at every call site. The counter-measure is the same as the parent entry's: the
  mutex must be a copy-paste-runnable literal snippet in `references/` that no conductor ever
  re-derives, and any brief that inlines a git-plumbing invocation is a defect in itself.

## phase-3-global-pass-does-not-state-which-test-tiers-it-covers
- skills: [ac-loop-2]
- impact: L
- frequency: occasional
- recurrence: 2
- related: [commit-mutex-lock-path-assumes-git-is-a-directory]
- first_seen: 2026-08-11
- last_seen: 2026-08-20
- stage: converge
- status: open (regressed at the BEAD level — the tier is declared and still not run)
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
  **RUN 20260820-005558-8974, +1 — the fix landed and the hole reopened one layer down.** Element 3
  now carries `### Test-tier exposure`, and bd-uf4m5's spec USED it: it declared, in its own words,
  "NOT RUN: the 4 supabase-integration suites". Phase 3 then did not run them either. So the
  declaration was made, recorded, read, and treated as information rather than as an obligation —
  which is the same conductor-side error as the original occurrence, now with better paperwork.
  The consequence was the run's most dangerous near-miss: the unrun tier was the only thing that
  could have contradicted bd-uf4m5's central premise, and that premise (a canonical gate-key
  spelling settled on a census of the TEST TREE) would have retuned a validator to reject 100% of
  live production rows. **A declared-and-skipped tier is not a smaller version of an undeclared
  one — it is worse, because the declaration reads as diligence to the reviewer.** The fix must be
  mechanical: Phase 3 RUNS every tier any shipped bead declared, or the phase does not close.
  Full account: memory `loop-retro-census-must-count-the-governed-population` and BCA memory
  `bca-red-gate-key-spelling-long-in-production`.

## frozen-head-is-not-enforceable-on-a-shared-checkout
- skills: [ac-loop-2]
- impact: M
- frequency: every-run
- recurrence: 3
- related: [filed-beads-carry-drifted-anchors-and-false-premises, commit-mutex-does-not-resync-or-assert-the-branch]
- first_seen: 2026-08-11
- last_seen: 2026-08-20
- stage: spec
- status: open
- proposed_fix: stop treating FREEZE_SHA as a guarantee and state its real status in the skill: it is a LABEL for a moment, not a lock. Every barrier crossing and every anchor re-check must MEASURE drift (`git diff --name-only FREEZE..HEAD`) and intersect the changed paths against each lane's territory, rather than trusting that the freeze held. Say explicitly which artifact classes survive drift (file-derived anchors) and which do not (board-derived counts). JSONL ADDITION: last-line-wins on `.beads/issues.jsonl` can destamp a `refined` record when nightly tidy (or any out-of-loop writer) rebases the same rows — on that conflict, prefer the refined side.
- narrative: reported independently THREE times in one run by three different agents. A concurrent
  non-loop curator session moved HEAD twice during Phase 1 alone (853fcd8c to cdc22bc3 to 96c01acb).
  Nothing in ac-loop-2 can stop this — the checkout is shared with sessions that never read the
  **RUN 20260820-005558-8974, +1 — and the worst case is not drift, it is the WRONG BRANCH.** The
  freeze was declared and not enforced; HEAD moved twice during Phase 1 alone. Harmless only because
  the affected child diffed and proved no cited file had changed — a refine that TRUSTED the freeze
  and skipped the diff would have stamped stale anchors. Then the sharper version: at the Phase-1
  barrier the checkout was on branch `m0uw-push`, not `main`, because a concurrent NON-LOOP agent was
  pushing a cross-app migration through this checkout (BCA is the canonical migration host). Two
  things the spine currently assumes and must not: (a) **the mutex's origin==HEAD assert compares
  against the CURRENT branch**, so it passes while pointing at the wrong target — this guard class
  cannot catch a branch swap and must be paired with an explicit `branch == main` assert; (b) Agent
  Mail's roster was EMPTY (`fetch_summary` returned nothing), so the foreign agent was invisible to
  coordination and could not be negotiated with or force-released. A conductor's picture of who else
  is in the checkout is only as good as voluntary registration, and the reflog — not the roster — is
  what reconstructed the truth. The conductor's correct response is recorded for reuse: do NOT touch
  the branch, hold Phase 2 at the barrier (Phase 1 is beads-DB-only and branch-agnostic so it runs
  on), commit the ledger PATHSPEC-SCOPED before any history rewrite, then reconcile, then re-verify
  branch AND origin==HEAD before opening Phase 2.
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
- last_seen: 2026-08-20
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
  LOCAL MANIFESTATION +1 (RUN 20260820-005558-8974, primary now recurrence 7): the published
  heredoc workaround is itself blocked on the same prose, so the v2 prompts must route
  agent-authored prose through the Write tool rather than any shell form.

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
- recurrence: 3
- related: [harness-tool-defects-are-the-machinery-bead-volume-driver, discoveries-filed-never-fixed-has-no-trivial-harness-exception]
- first_seen: 2026-08-17
- last_seen: 2026-08-20
- stage: build
- status: open (policy half SHIPPED and MEASURED — it did NOT bind; the gate exists as a reference but nothing applies it at the `br create` site, and the delegation prompts actively contradict it)
- proposed_fix: bind the bar AT the filing site, not as a citation. Two concrete edits: (1) `references/delegation-prompts.md` tells every build worker "Adjacent defects: FILE an `unrefined` bead" with no kind-then-bar routing — rewrite it to route machinery to the returned `friction:` block and sub-bar product to the return summary, so a child cannot file machinery even if it wants to; (2) the spine's Phase-4 step must print the filing split (machinery / sub-bar / on-bar) before close, because an unmeasured bar is an unenforced one.
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
- MEASUREMENT (the metric the prior entry asked for): the first run under the filing bar filed
  29 items — 18 machinery (62%), 8 product below the priority bar (28%), 3 that actually pass
  (10%). The prior, pre-bar run was 31% machinery. The rate did not collapse; it roughly
  DOUBLED. So the residual is NOT the harness defect rate as predicted — the policy simply did
  not bind on the one agent that files. Root cause is now visible and is not discipline: the
  conductor cited `filing-bar.md` in its own § Remember and still routed machinery to the board,
  and every child was DISPATCHED with "Adjacent defects: FILE an `unrefined` bead (stamped
  `post-merge`), never fix" — the delegation prompt orders the exact behaviour the bar forbids.
  A rule stated in a reference and contradicted in the prompt that is actually executed loses to
  the prompt every time. Machinery beads from this run were closed `obsolete: wrong channel` with
  their substance already preserved in the run carrier.
- MEASUREMENT 2 (RUN 20260820-005558-8974, +1): **26 items filed against a threshold of 10**, and a
  dedupe audit run afterwards found roughly **40% redundancy** in that intake. So the bar is now
  breached on two independent axes at once — volume, and the same finding filed more than once —
  and the second is the one no per-item gate can catch, because every duplicate is individually
  defensible. Two additions this suggests for the Phase-4 filing split the proposed fix already
  asks for: print the DEDUPE rate beside the machinery/sub-bar/on-bar split, and run the dedupe
  audit BEFORE filing rather than after, since a redundancy found post-filing costs a close cycle
  per duplicate. One positive from the same run worth copying: the test-suite topology finding (two
  suites covering one hook in two directories) was deliberately recorded as friction rather than as
  a 26th bead, with the reason stated inline — "machinery goes in friction, never on the board".
  That is the bar working, in one agent, once, by explicit self-instruction.

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

## the-loops-own-gates-have-false-green-mechanisms
- skills: [ac-loop-2]
- impact: H
- frequency: every-run
- recurrence: 2
- related: [machinery-findings-route-to-the-board-as-beads, phase-3-global-pass-does-not-state-which-test-tiers-it-covers, bisect-attribution-has-no-error-state]
- first_seen: 2026-08-20
- last_seen: 2026-08-20
- stage: converge
- status: open
- proposed_fix: three separate edits, one shared assertion. (a) `references/converge-phase.md` § 5 — revert only the SOURCE files from `<commit>~1` via `git show | tee` and leave tests at HEAD, restoring with a scoped `git stash push -- <paths>`; drop the `git revert --no-commit` + restore-test dance and the `git reset --hard` recovery. (b) `references/beads-closed-gate-invocation.md` — never read the gate's exit through a pipe; capture `rc=$?` on the bare call. (c) the RED-PROOF gate must assert the declared REDs are AMONG the failures, never that they are the ONLY ones. Shared: every gate in this skill must be able to distinguish "ran and found nothing" from "did not run".
- narrative: Three independent gates in one run each had a state where NOT RUNNING is reported as
  PASSING. (1) The § 5 mutation-probe protocol reverts the whole bead commit then restores its
  test files — but for a bead whose test file is NEW the revert deletes the containing DIRECTORY,
  the restore write ENOENTs, and vitest then exits 0 against no tests. A false green inside the
  mechanism built to detect false greens; it fired on the first probe attempted. Its documented
  recovery, `git reset --hard` (called "the ONLY restore that works"), is additionally blocked by
  dcg. (2) The beads-closed gate's exit read through `| tail` captures tail's status: the gate
  exited 2 FAIL-CLOSED and was reported 0. (3) An exactly-N RED-PROOF gate forbids any EXTRA test
  that bites pre-fix, so a worker DELETED a good repair-branch test to hold the count at 3 and
  filed the coverage gap instead — the gate pressured coverage DOWN. Same root as the
  `skipIf`-suite-exits-0 case the migration bead had to defend against with a dedicated criterion.
  **RUN 20260820-005558-8974, +1 — a FOURTH gate, reported independently by FIVE lanes, and it is
  the one Phase 3 leans on hardest.** `npx vitest run <5 files>` SILENTLY COLLAPSED to 1 file
  (vitest-affected cache interaction) while reporting `1 passed`. Lanes L5, L7, L6, L9 and L3 each
  hit the class without knowing the others had. Three faces of one defect: an explicitly-named file
  list is intersected with the affected set rather than honoured; a named suite outside that set
  resolves to `No test files found`, which is INDISTINGUISHABLE FROM A BROKEN PATH; and a NEW test
  file is not in the dependency graph at all, so it needs `VITEST_AFFECTED_DISABLED=1` (its
  companion, `VITEST_AFFECTED_REF=<older sha>`, forces an unaffected suite to run WITHIN affected
  mode). **The assertion that closes all three: any consumer of a multi-file vitest summary must
  compare the reported FILE COUNT against the files requested and fail loud on a mismatch — never
  trust a bare pass line.** Phase 3's global pass is the highest-stakes consumer in the skill.
  Two more false-green shapes from the same run's gate layer, both cheap to defend: `pnpm lint`
  PASSES while `prettier --check` fails independently (formatting is outside the lint script, which
  is how drift accumulated across ten lanes unnoticed), and `pnpm format:check` emits ANSI colour
  codes so a naive `grep '^\[warn\]'` matches ZERO lines and reports a FALSE ALL-CLEAR — strip with
  `sed -E 's/\x1b\[[0-9;]*m//g'` before parsing any gate output. General class:
  `wrapper-exit-0-masks-real-outcome` in the global memory substrate.

## delegation-prompts-contradict-the-filing-bar-and-omit-the-claim-verb
- skills: [ac-loop-2]
- impact: M
- frequency: every-run
- recurrence: 1
- related: [machinery-findings-route-to-the-board-as-beads]
- first_seen: 2026-08-20
- last_seen: 2026-08-20
- stage: build
- status: open
- proposed_fix: in `references/delegation-prompts.md`, replace the build-worker's "Adjacent defects: FILE an `unrefined` bead" with kind-then-bar routing (machinery to the returned `friction:` block, sub-bar product to the return summary, board only for product 0/1 with a verified repro); add an explicit CLAIM verb beside `CLAIM_ASSIGNEE`; and state the `### Bead <id>` + `COMPLETED: n/N` progress schema the close gate's completeness check requires.
- narrative: The prompt that is actually executed beat the reference that is merely cited, three
  ways in one run. The build-worker prompt orders "FILE an `unrefined` bead" for every adjacent
  defect, with no kind axis — which is the precise behaviour `filing-bar.md` forbids, so children
  filed machinery obediently. Separately the prompt threads `CLAIM_ASSIGNEE=<name>` but never says
  CLAIM, so no bead was ever assigned and the close gate's union claimed-set came back EMPTY
  (FAIL-CLOSED). And it specifies a progress.md HEADER but not the per-bead entry schema the
  completeness check reads, so every child file came back thin and the gate returned
  PROGRESS-INCOMPLETE. All three are one class: a contract stated only in a reference does not
  bind the agent that never reads it.

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
  `loop-retro-delegation-brief-claims-are-hints` (recurrence 8). Read the two together before
  anyone proposes trimming child-side re-verification as overhead: this log records what the
  defect costs, and only that memory records what the defence saves.
  **RUN 20260820-005558-8974 — local manifestation, and it names the SOURCE the conductor composed
  from.** A Phase-1 group brief asserted a bead was ruleset-determined; ONE production `SELECT`
  refuted it. The brief had been written from the beads' TITLES rather than their bodies. A title is
  the most compressed representation of a bead the system holds, so composing group context from
  titles MANUFACTURES premises rather than summarising them — compose from `## Delivers` /
  `## Territory`, or state no context at all. The load-bearing scope correction: the brief-claim
  rule binds the conductor's own group-context paragraphs, not only its claims about in-flight work.
  Same run, second carrier, recorded at the primary: a TRIAGE bead written by a verifier is a
  HYPOTHESIS, not a finding — bd-...-ba4ga was inverted on both its claims and trusting it would
  have relaxed a test and destroyed a real seam guard.

## commit-mutex-does-not-resync-or-assert-the-branch
- skills: [ac-loop-2]
- impact: H
- frequency: every-run
- recurrence: 1
- related: [commit-mutex-lock-path-assumes-git-is-a-directory, frozen-head-is-not-enforceable-on-a-shared-checkout]
- first_seen: 2026-08-20
- last_seen: 2026-08-20
- stage: build
- status: open
- proposed_fix: three lines inside the lock, before staging — `git rev-parse --abbrev-ref HEAD` must equal `main`; `git fetch && git merge --ff-only origin/main` (or `git reset --mixed origin/main`); then stage. And replace `git add -- $PATHS` with literal paths on BOTH the add and the commit, because zsh does not word-split an unquoted variable.
- narrative: TWO lanes reached this independently in one run, which makes it a canon defect rather
  than a one-off. The mutex serialises add/commit/push, so no two lanes interleave — but it never
  RESYNCS a stale local `main`, so a lane holding the lock stages against a HEAD that origin has
  already moved past and the commit aborts with "HEAD did not advance". The second lane hit the
  same wall through the zsh half: the canonical block's `git add -- $PATHS` is NOT word-split by
  zsh, so the whole path list becomes ONE pathspec matching nothing and the commit aborts with the
  same message — two different causes producing one indistinguishable symptom, which is why both
  lanes spent diagnosis time before finding it. The third face is the dangerous one: **the mutex's
  `origin == HEAD` assert compares against the CURRENT branch**, so on a checkout that a foreign
  agent has left on a feature branch the assert PASSES while pointing at the wrong target. Phase 2's
  entire design is ~30 pathspec-scoped commits landing trunk-direct on main; landing them on someone
  else's branch attaches the whole wave to a ref a squash-merge or force-push destroys. A guard that
  cannot distinguish "up to date with main" from "up to date with whatever branch I am on" is not
  guarding the invariant the phase depends on.

## board-truth-scan-misses-commits-that-do-not-cite-the-bead
- skills: [ac-loop-2]
- impact: M
- frequency: every-run
- recurrence: 1
- related: [machinery-findings-route-to-the-board-as-beads]
- first_seen: 2026-08-20
- last_seen: 2026-08-20
- stage: phase-0
- status: open
- proposed_fix: make `git log -- <territory>` a MANDATORY step of lane construction, run once per lane before dispatch, with any commit touching the territory since the bead was filed surfaced to the conductor for a shipped/not-shipped ruling. Board-truth by bead-id citation is a best-effort scan and must be documented as one; territory-scoped log is the complete one.
- narrative: THREE beads in one run (bd-nf4ie, bd-66zbk, bd-ufdyt) had been fully implemented days
  earlier and left open, and all three share ONE cause: **the fixing commit did not cite the bead
  id**, so the board-truth scan cannot see them. Cost ~3 beads of lane time — dispatched children
  that arrived to find the work already done. A fourth instance in the same run makes the shape a
  pattern rather than an anecdote: bd-dznw1's AC block asserted three files did not exist and all
  three had shipped 3 days earlier; the lane brief DID say to run `git log -- <territory>` first,
  and the worker did it for beads 1-5 and skipped it for bead 6. That is the argument for making it
  a step of lane CONSTRUCTION (conductor-side, once, mechanically) rather than an instruction in a
  worker brief (per-worker, per-bead, skippable). The scan's blind spot is structural: citation is a
  courtesy the committing agent may or may not extend, and every uncited fix is invisible forever.

## risk-class-native-self-declared-contradicts-the-spine
- skills: [ac-loop-2]
- impact: M
- frequency: occasional
- recurrence: 1
- related: [device-only-native-beads-are-dead-dispatches-in-the-risk-queue]
- first_seen: 2026-08-20
- last_seen: 2026-08-20
- stage: phase-2
- status: open
- proposed_fix: delete the instruction to self-label `native` in element 5 from the group-brief template, and state the spine's own rule in its place — risk class is derived from FILES TOUCHED, never from a self-label (`ac-pipeline/references/risk-classification.md`). A bead whose proof modality is native but whose diff is CSS/TSX is class A; only a diff that compiles native code or replays a migration is class B.
- narrative: the conductor's group briefs told children to "flag `native` in element 5 — it routes
  to the serial risk queue". A child refuted it by reading the canon: `risk-classification.md` is
  titled "files-touched, NEVER self-label" and cites earlier loop-retro evidence for exactly this.
  The conductor had, in effect, re-invented a rule the spine already forbids, and the consequence
  was concrete: element 5 declared `native` "for the PROOF only" on beads whose code is pure
  CSS/TSX, and the lane planner's resulting B set was 27 beads. Taking it literally would have
  SERIALISED THE ENTIRE PHASE. Overruling it to 10 restored parallelism on the correct principle —
  a migration poisons the shared local stack and a native build must compile, but a device-proved
  CSS change endangers neither. The generalisable half: a proof MODALITY is not a risk class, and
  conflating them lets any bead that merely wants a device screenshot serialise the whole run.

## bisect-attribution-has-no-error-state
- skills: [ac-loop-2]
- impact: M
- frequency: occasional
- recurrence: 1
- related: [the-loops-own-gates-have-false-green-mechanisms]
- first_seen: 2026-08-20
- last_seen: 2026-08-20
- stage: converge
- status: open
- proposed_fix: two assertions in `references/converge-phase.md` § attribution. (1) After a bisect verdict, run `git log --diff-filter=A -- <test-file>`; if the culprit commit is the file's ADD commit, the verdict is an artifact, not a regression — and the cluster brief must state which of the two it is asserting. (2) Any known-artifact EXCLUSION in a verification brief carries the full repo-relative path and asserts it resolves to exactly one file; basename-only exclusions are banned.
- narrative: `git bisect run` cannot distinguish "this file went red" from "this file first
  existed" — a test file is failing at its own ADD commit and passing before it, which is precisely
  the predicate bisect searches for. `use-form-submission.test.ts` was flagged as a regression at
  d228f65e, its own introducing commit; it is 9/9 green standalone, paired, and in the full suite.
  The run's real regression count was 6, not 7, so one repair worker was nearly dispatched against
  nothing. The mirror defect, from the conductor's own final-verification brief in the same run:
  a failure was excluded BY BASENAME, **two files in the tree share that basename**, and a real
  regression was nearly waved through as the known artifact. Both failures share the signature that
  makes this phase's mechanism dangerous — the answer arrives with full confidence and there is no
  error state to read. Sibling memory: `re-run-in-isolation-before-spending-a-bisect` (flakes) and
  `verify-red-tests-against-history-before-preexisting-claim` (baselines).

## conductor-hand-builds-what-the-spine-should-compute
- skills: [ac-loop-2]
- impact: H
- frequency: every-run
- recurrence: 1
- related: [conductor-briefs-assert-inferred-facts-as-established, coordinator-layer-drops-work-on-a-short-lane]
- first_seen: 2026-08-20
- last_seen: 2026-08-20
- stage: phase-2
- status: open
- proposed_fix: compute, do not summarise. (1) A lane manifest is the UNION of its member beads' `## Territory` blocks INCLUDING their test paths, taken verbatim — and for repair%, the union of `git grep`-derived CONSUMERS of every symbol a bead changes. (2) The per-lane artifact path is a FORMULA in the prompt (`.claude/reports/ac-loop2-<RUN_ID>-<LANE>/progress.md`), not a rule elsewhere in the spine. (3) Before dispatch, check every dispatched bead's ACs against the brief's own bans and resolve the conflict conductor-side.
- narrative: four conductor defects in one run, all caught by children, all the same shape — an
  artifact the conductor wrote by hand where the spine could have computed it. (1) The L3 lane
  manifest OMITTED every test path bd-ctb4c's own Territory named; the lane followed the BEAD and
  flagged rather than silently widening, which is the correct response but only because the child
  chose it. (2) The lane briefs said "your ledger is your progress.md" without a per-lane PATH, and
  root `progress.md` was ALREADY CLAIMED by another lane in the shared checkout — the invariant
  "children never share a progress file" existed in the spine and not in the prompt, so L11 had to
  invent its own path. (3) The L12 brief banned starting the local Supabase stack while bd-am450's
  AC6 makes a real-DB probe MANDATORY; the lane reconciled it sensibly at apply time, but that
  reconciliation is the conductor's job before dispatch. (4) The final-verification brief's
  basename exclusion (logged at `bisect-attribution-has-no-error-state`). The repair% of this run
  points at the same root from the metrics side: 6/37 = 16.2%, above the ≤10% guidance, and every
  one of the six was a CONTRACT-BOUNDARY failure rather than a coding failure — **4 of 6 were "a
  second file asserted the thing I changed and nobody looked."** A hand-summarised territory is
  exactly how a second file goes unlooked-at.

## phase-0-lane-construction-assumes-an-already-refined-board
- skills: [ac-loop-2]
- impact: M
- frequency: occasional
- recurrence: 1
- related: [refine-all-degrades-to-priority-cut-when-set-exceeds-width]
- first_seen: 2026-08-20
- last_seen: 2026-08-20
- stage: phase-0
- status: open
- proposed_fix: state the two-stage construction explicitly in the spine — Phase 0 emits refine GROUPS (locality only, per `references/refine-drain.md` § Grouping); territory-disjoint LANES are built at the PHASE-1 BARRIER from the manifests Phase 1 produced. Then scope the "no computable manifest, no lane" rule to already-refined beads, so it cannot swallow the unrefined majority.
- narrative: Phase 0 § "Build the lanes" computes each epic's territory manifest from its member
  beads' `## Delivers`. On a board that is 69 of 94 UNREFINED those manifests DO NOT EXIST — element
  3 is an OUTPUT of Phase 1, not an input to Phase 0. Read literally, the rule "an epic with no
  computable manifest does not get a lane" sends the entire unrefined majority to the human docket,
  which contradicts the refine-drain invariant stated one section later ("width bounds concurrency,
  never coverage"). The conductor deviated from the literal text and was right to; the cost was a
  reasoning detour rather than a wasted child, but the deviation is undocumented and the next
  conductor pays it again. Two rules in one skill that cannot both be followed is a spine defect,
  not a judgement call.

## baseline-precedes-range
- skills: [ac-loop-2]
- impact: H
- frequency: occasional
- recurrence: 1
- related: [bisect-attribution-has-no-error-state, the-loops-own-gates-have-false-green-mechanisms, conductor-briefs-assert-inferred-facts-as-established]
- first_seen: 2026-08-20
- last_seen: 2026-08-20
- stage: converge
- status: open
- proposed_fix: Phase 3 must COMPUTE the baseline SHA once, at phase open, as the commit immediately preceding the wave's first commit, and publish it in every converge brief as a literal. Every "pre-existing" claim must then cite that SHA, and the phase asserts `git merge-base --is-ancestor BASELINE FIRST_COMMIT_OF_RANGE` before accepting the claim. A claim that names no SHA, or names a SHA inside the range, is rejected unread — no re-litigation, no benefit of the doubt.
- narrative: THE RUN'S MOST EXPENSIVE FALSE CLAIM, and the shape is that evidence made it worse.
  bd-8v1l2 reported 7 red tests as "pre-existing, PROVEN by a side-by-side run" against two
  commits it described as pristine HEAD. Both were INSIDE the wave. A throwaway worktree at the
  wave's true predecessor was 845 passed / 0 failed, so all 7 reds were the run's own. The
  conductor had already repeated the claim upward to Craig before the worktree corrected it, so
  the false classification left the machine. What makes this a spine defect rather than one
  bead's mistake: Phase 3 asks children to classify failures as ours-or-theirs but never supplies
  the only datum that can answer the question, so every child improvises a baseline from whatever
  commit is nearest to hand — and on a shared trunk-direct checkout with ~30 commits landing per
  phase, "nearest to hand" is almost always inside the range. An asserted pre-existing invites
  challenge; a PROVEN one closes the question, which is why the evidenced version cost more than
  the unevidenced 2026-07-04 instance did. Cheap and absolute: a throwaway worktree at the
  pre-range commit with node_modules symlinked answers it in minutes. Fleet memory:
  `verify-red-tests-against-history-before-preexisting-claim` (BCA, recurrence 2).
