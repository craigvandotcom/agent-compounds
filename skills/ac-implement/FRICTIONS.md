---
skill: ac-implement
created: 2026-07-29
last_pass: 2026-08-10
entries: 10
---

# ac-implement — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

## unverified-causal-story-in-review-finding
- skills: [ac-implement]
- impact: M
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: 2026-07-29
- last_seen: 2026-07-29
- stage: ac-loop
- status: open
- proposed_fix: treat a review panel's causal explanation as a hypothesis, not a finding — verify the mechanism (read the actual emission order/code path) before writing the test that asserts it.
- narrative: a bead's causal story — that the parent wins a map slot — was refuted by a 2-line const (`foodLevels` ordering) once the implementer actually read the emission order before writing the test. Verifying the mechanism first turned a would-be vacuous AC (asserting the reviewers' wrong explanation) into an honest retention assertion plus a real regression guard. Cost ~10 minutes to check; would have cost a wrong test otherwise.

## conductor-direct-close-skips-result-file-artifact
- skills: [ac-implement]
- impact: L
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: 2026-07-29
- last_seen: 2026-07-29
- stage: ac-loop
- status: open
- proposed_fix: require a per-bead engineer result file (or an explicit, stated mechanical-only justification) before a conductor-direct close of a CODE bead.
- narrative: the per-bead engineer result-file artifact contract is not enforced when a code bead is closed conductor-direct. One batch (webui) shipped 4 non-trivial code beads with ZERO engineer result files — including a 133-line new-behaviour bead that does not obviously meet the conductor-direct mechanical-only criteria. This degrades the retrospective's ability to verify RED-proof and skill-routing compliance for a quarter of the run's beads.

## affected-graph-silently-subsets-explicit-test-selection
- skills: [ac-implement]
- impact: H
- frequency: frequent
- recurrence: 5
- related: [unverified-causal-story-in-review-finding]
- first_seen: 2026-07-14
- last_seen: 2026-08-10
- stage: ac-implement
- status: open
- proposed_fix: for any shared-interface / client-call-chain diff, grep the mock-OWNING test files (not just the obvious suites), run that named set with VITEST_AFFECTED_DISABLED=1, and have the conductor pre-authorize those mock-owning suites in the engineer's scope contract. Upstream fix: vitest-affected should honour an explicit selection verbatim or fail loudly when it would drop named files.
- narrative: vitest-affected INTERSECTS an explicitly-named file list with the git-diff set instead of honouring it, so a per-bead gate runs a subset of the suites the engineer named and still exits 0. Observed 3x in RUN 20260714-170945-6308, 7-of-12 named files in RUN 20260728-234407-54469, and 2-of-5 named suites in two independent children in RUN 20260729-170058-3584 (one reported GREEN on 40% of its evidence). The paired half: the per-file affected run under-selects sibling MOCK files, so widening a shared type (optional supabase? on AuthenticatedRequest) or changing which client a route calls breaks hand-rolled requireAuth mocks only after commit — bd-8b61b put main briefly RED plus 3 fix commits, bd-7vta3 cost ~5 rounds. Third shape, 2026-07-28: a scope contract naming only the TOUCHED files stranded the files that MOCK them, so the engineer correctly refused to fix them and the conductor paid a round trip. Same family as org-8f0 (ubs exits 0 having checked nothing) — trusted tools that report success without checking.
  **RUN 20260808-221219-47229, +1 — a fourth shape: a NEW call site breaks OTHER files' mocks, not just the touched ones.** bd-3wfq4.5 (commit b0193509) added a route's first call into an existing repo-module — the route itself had no mock gap, but repo-module mocks living in OTHER test files (never touched by the diff) started returning 500 once the new call landed, because those sibling files' mocks had no stub for the newly-exercised method. The fix pattern from the existing entries (grep mock-owning files, pre-authorize the scope) generalizes to this trigger too, but the trigger itself is new and worth naming explicitly: **a route gaining a new repo-module CALL requires a repo-wide `grep vi.mock` across the whole suite, not just the route's own test file** — the affected-graph gap here is not under-selecting the route's tests, it's failing to notice that unrelated-looking test files now depend on a mock surface the diff silently widened.

## own-suite-only-run-misses-cross-suite-stale-assertions
- skills: [ac-implement]
- impact: M
- frequency: occasional
- recurrence: 1
- related: [affected-graph-silently-subsets-explicit-test-selection]
- first_seen: 2026-07-31
- last_seen: 2026-07-31
- stage: ac-loop
- status: open
- proposed_fix: engineer delegation prompts should NAME the discovered/affected suites explicitly rather than delegating suite discovery to the child; do not rely on the child choosing to run only its own new suites.
- narrative: an implementer ran only the suites for its OWN new tests, not a full `test:all`. Four stale assertions in two OTHER suites still pinned the pre-fix behaviour and were only surfaced when a full run was later executed. Cost ~15 minutes plus a full test:all pass to find and fix. The delegation prompt left suite discovery to the child instead of naming the suites the engineer needed to check.

## prod-only-env-blocks-live-db-ac-undetected-at-claim
- skills: [ac-implement]
- impact: M
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: 2026-07-31
- last_seen: 2026-07-31
- stage: ac-loop
- status: open
- proposed_fix: screen env prerequisites for the WHOLE batch at claim time, not per-bead at execution time — a bead whose binding AC needs a live DB write is unclaimable in a lane whose `.env.local` points at production.
- narrative: bd-l7tvt looked claimable but was structurally unclosable in an autonomous lane: its binding seam-proof acceptance criterion needs a live DB write, and `.env.local` points at PRODUCTION. The child correctly declined rather than make an unsupervised production write; the conductor released the claim and substituted another bead. Cost ~35 minutes on the replacement bead swap.

## lint-piped-to-pager-does-not-gate-the-commit
- skills: [ac-implement, ac-loop]
- impact: M
- frequency: occasional
- recurrence: 2
- related: []
- first_seen: 2026-08-03
- last_seen: 2026-08-05
- stage: ac-loop
- status: open
- proposed_fix: **a quality gate and the irreversible action it guards never share a command block.** Run the gate alone, read its exit status, then commit or push in a separate call. The narrower "no pipe between the gate and the `&&`" form does not cover the recurrence below, where there was no `&&` at all — state the positive rule instead: one block per side, and the second block runs only after the first is read.
- narrative: an implementer chained its quality gate as `bash lint.sh | tail -3 && git commit …`, intending "commit only if lint passes". A pipeline's exit status is the LAST command's, so the `&&` tested `tail` (always 0) and the commit landed on a FAILING lint. Caught after the fact and amended before push, so the cost was one bad commit rather than a broken trunk — but the shape is silent by construction: the gate appears to run, its output appears in the transcript, and the commit proceeds regardless. Any snippet that pipes a gate into a pager/`head`/`tail` for readability has disarmed it.
  **RECURRENCE 2 — the conductor's variant, and it defeats the fix above.** A conductor ran the lint script and `git push` in one command block with NO operator between them. Lint FAILED on a net line growth; the push ran anyway, because nothing was ever gated on the exit status — there was no `&&` to disarm. Same outcome, one step earlier in the causal chain: the first occurrence gates on the wrong exit code, this one gates on none. Both are cured by separating the blocks and neither is cured by fixing the operator, which is why the rule has to be stated as a co-location ban rather than as pipe advice. Note the failure mode is not the gate: the ratchet fired correctly and reported correctly, and the only defect was the shell around it.

## no-net-growth-ratchet-bites-documentation-only-fixes
- skills: [ac-implement, ac-review]
- impact: M
- frequency: frequent
- recurrence: 3
- related: []
- first_seen: 2026-08-03
- last_seen: 2026-08-04
- stage: ac-loop
- status: open
- proposed_fix: budget for compression, not for the stamp — fold an added explanation into an existing bullet rather than appending a new line, and reach for `net-growth-ok` only when the added content is genuinely executable. Note the mechanical constraint when drafting: an HTML-comment stamp cannot live inside a bash fence, so a fenced addition forces the stamp onto an added prose line outside the fence.
- narrative: two children hit the registry's own per-file SKILL.md ratchet while making corrections that are, by nature, additive prose. (1) An implementer fixing doc defects paid two extra edit cycles reworking additions into existing bullets, and where the new content was executable had to ride the `net-growth-ok` stamp on an added prose line because the stamp cannot sit inside the bash fence it was justifying. (2) A review child fixing a Critical in a conductor-core SKILL.md paid three extra edit cycles for the same reason. The ratchet is working as designed — the friction is that neither child had budgeted compression time into a fix that read as "one line of text", and both reached for the stamp before reaching for the shrink.
  **RUN 20260803-221658-19787, +1 — the fix is a BUDGETING step, not a technique, and it belongs before the first edit.** Review auto-fixes landing in conductor-core SKILL.md files hit the ratchet again. The sharpened lesson is about ordering: an auto-fix is scoped from a finding, findings never carry a line budget, so the fix is priced as free and the compression work surfaces only when the ratchet refuses the edit — at which point the text is already written and the author is motivated to preserve it with a `net-growth-ok` stamp rather than choose on the merits. Budget the ratchet cost UP FRONT as part of the fix estimate and decide compress-vs-stamp before writing. A pointer entry now sits in ac-review's log because that phase meets this most often; occurrences stay counted here. Also worth pairing with the memory `loop-retro-origin-main-diffed-checks-zero-headroom`: a check diffed against `origin/main` gives back no headroom for trims that are already pushed, so compression banked in an earlier commit does not fund a later addition.

## bash-isms-in-pasted-snippets-diverge-silently-under-zsh
- skills: [ac-implement]
- impact: H
- frequency: frequent
- recurrence: 4
- related: [tr-shadowed-by-tmux-alias-in-interactive-zsh, test-harness-strictness-manufactures-a-false-red]
- first_seen: 2026-08-03
- last_seen: 2026-08-04
- stage: ac-loop
- status: open
- proposed_fix: the fleet's interactive shell is zsh, so treat every bash-ism in a pasted snippet as a defect: read `$?` directly instead of `${PIPESTATUS[0]}` (drop the pipe rather than translate it), and never rely on word-splitting an unquoted expansion — put multi-item loops in a bash script file or feed them a here-string. **And when the DEFECT is zsh-only, the RED proof must run under zsh** — a bash-run RED for a zsh-only bug is green, so the seam proof silently proves the wrong thing and the fix ships unverified.
- narrative: three occurrences in one run, all silent rather than loud. (1) A verification step read `${PIPESTATUS[0]}` and got an empty string — zsh spells it `$pipestatus[1]` — producing a confusing empty result rather than an error. (2) The same construct after a trailing `echo` had already been reset by the `echo` itself, costing an extra turn. (3) `for f in $FILES` passed the entire whitespace-joined list as ONE filename, because zsh does not word-split unquoted expansions; the loop ran once against a path that did not exist. None of the three failed loudly — each produced a plausible-looking wrong answer, which is what makes the class expensive relative to its trivial per-instance fix. Sibling shapes in the refine snippets (`echo` expanding `\n`, `tr` shadowed by a tmux alias) are logged in ac-bead-refine's file.
  **RUN 20260803-221658-19787, +1 — the class now has a PROOF requirement attached, and impact rises to H.** A live P1 found this run was a zsh-only pathspec collapse: correct under bash, wrong under zsh, in a snippet that runs under the fleet's interactive shell. The trap is in the verification rather than the fix. A RED demonstration written the ordinary way runs under bash, where the defect does not exist, so the RED comes back GREEN — and a green RED reads as "already fixed" or "the bug isn't real", not as "the harness is wrong". So the seam proof for a zsh-only defect must be run under zsh explicitly, and the fix's GREEN must be under zsh too. This is the same root as `test-harness-strictness-manufactures-a-false-red` with the sign flipped: there the harness was STRICTER than production and manufactured a false failure; here it is a DIFFERENT INTERPRETER than production and manufactures a false pass, which is the more dangerous direction because nothing prompts investigation. The unifying rule for this skill: **a seam harness must reproduce the production shell — same interpreter, same strictness — and the interpreter is part of the RED's specification, not an implementation detail.** Escalated M→H: this run's instance was a P1 that reached the live tree, and the failure mode of a false-green RED is a shipped unfixed defect with a proof attached.

## verification-outlives-the-bash-timeout-cap
- skills: [ac-implement, ac-review, ac-qa-browser]
- impact: M
- frequency: occasional
- recurrence: 1
- related: [test-harness-strictness-manufactures-a-false-red, affected-graph-silently-subsets-explicit-test-selection]
- first_seen: 2026-08-04
- last_seen: 2026-08-04
- stage: ac-implement
- status: open
- proposed_fix: any verification step that can plausibly run past the harness's 600s Bash ceiling must be launched as a BACKGROUND runner that writes a done-marker file, with the agent then polling for that marker — never invoked in the foreground and hoped for. State this once alongside the full-suite / long-gate steps, because the failure is discovered at the worst possible moment: after the run has already burned the full ten minutes.
- narrative: a verification command exceeded the harness's hard 600s Bash timeout and was killed mid-run. The cost is not the ten minutes — it is that a timeout is a NON-ANSWER that is easy to misfile. The step produced no verdict, and the next moves available (re-run it and hope, narrow the scope and lose coverage, or declare it unverifiable) are all worse than the one that works, which is to restructure the invocation: start the command detached so it survives the tool call, have it write a completion marker when it finishes, and poll the marker. The child that hit this re-derived that pattern under pressure. Worth logging as its own id rather than as a note on the test entries because it is a HARNESS-CAPACITY constraint, not a test-quality one, and it applies identically to any long gate — full suites, builds, device runs, browser journeys — so the fix belongs wherever a long-running command is prescribed rather than in any single skill's test step. Adjacent failure worth naming: retrying a timed-out gate in the foreground makes it look like a flake, which invites the fix of narrowing the gate's scope — trading real coverage away to fit a clock.

## test-harness-strictness-manufactures-a-false-red
- skills: [ac-implement]
- impact: M
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: 2026-08-03
- last_seen: 2026-08-03
- stage: ac-loop
- status: open
- proposed_fix: a seam/RED harness must reproduce the PRODUCTION shell context, not a stricter one — if the code under test runs without `set -e`, the harness must not impose it. When a RED fires, check the harness's own strictness before believing the failure.
- narrative: a seam harness running under `set -e` aborted its 0-match legacy case at `grep`'s exit 2, BEFORE the FATAL branch that case exists to prove could fire. The production context has no `set -e`, so the failure was manufactured entirely by the harness and the RED said nothing about the code. Cost one turn to diagnose. The general hazard: fixture infrastructure that is stricter than production produces failures that look like real defects and cannot be reproduced by the thing being tested.
