---
skill: ac-implement
created: 2026-07-29
last_pass: 2026-08-03
entries: 9
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
- recurrence: 4
- related: [unverified-causal-story-in-review-finding]
- first_seen: 2026-07-14
- last_seen: 2026-07-29
- stage: ac-implement
- status: open
- proposed_fix: for any shared-interface / client-call-chain diff, grep the mock-OWNING test files (not just the obvious suites), run that named set with VITEST_AFFECTED_DISABLED=1, and have the conductor pre-authorize those mock-owning suites in the engineer's scope contract. Upstream fix: vitest-affected should honour an explicit selection verbatim or fail loudly when it would drop named files.
- narrative: vitest-affected INTERSECTS an explicitly-named file list with the git-diff set instead of honouring it, so a per-bead gate runs a subset of the suites the engineer named and still exits 0. Observed 3x in RUN 20260714-170945-6308, 7-of-12 named files in RUN 20260728-234407-54469, and 2-of-5 named suites in two independent children in RUN 20260729-170058-3584 (one reported GREEN on 40% of its evidence). The paired half: the per-file affected run under-selects sibling MOCK files, so widening a shared type (optional supabase? on AuthenticatedRequest) or changing which client a route calls breaks hand-rolled requireAuth mocks only after commit — bd-8b61b put main briefly RED plus 3 fix commits, bd-7vta3 cost ~5 rounds. Third shape, 2026-07-28: a scope contract naming only the TOUCHED files stranded the files that MOCK them, so the engineer correctly refused to fix them and the conductor paid a round trip. Same family as org-8f0 (ubs exits 0 having checked nothing) — trusted tools that report success without checking.

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
- skills: [ac-implement]
- impact: L
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: 2026-08-03
- last_seen: 2026-08-03
- stage: ac-loop
- status: open
- proposed_fix: never put a pipe between the gate and the `&&` — chain as `bash lint.sh >/dev/null 2>&1 && git commit …`. If the gate's output is wanted, redirect it to a literal file and read `$?`, then commit in a separate call.
- narrative: an implementer chained its quality gate as `bash lint.sh | tail -3 && git commit …`, intending "commit only if lint passes". A pipeline's exit status is the LAST command's, so the `&&` tested `tail` (always 0) and the commit landed on a FAILING lint. Caught after the fact and amended before push, so the cost was one bad commit rather than a broken trunk — but the shape is silent by construction: the gate appears to run, its output appears in the transcript, and the commit proceeds regardless. Any snippet that pipes a gate into a pager/`head`/`tail` for readability has disarmed it.

## no-net-growth-ratchet-bites-documentation-only-fixes
- skills: [ac-implement, ac-review]
- impact: M
- frequency: frequent
- recurrence: 2
- related: []
- first_seen: 2026-08-03
- last_seen: 2026-08-03
- stage: ac-loop
- status: open
- proposed_fix: budget for compression, not for the stamp — fold an added explanation into an existing bullet rather than appending a new line, and reach for `net-growth-ok` only when the added content is genuinely executable. Note the mechanical constraint when drafting: an HTML-comment stamp cannot live inside a bash fence, so a fenced addition forces the stamp onto an added prose line outside the fence.
- narrative: two children hit the registry's own per-file SKILL.md ratchet while making corrections that are, by nature, additive prose. (1) An implementer fixing doc defects paid two extra edit cycles reworking additions into existing bullets, and where the new content was executable had to ride the `net-growth-ok` stamp on an added prose line because the stamp cannot sit inside the bash fence it was justifying. (2) A review child fixing a Critical in a conductor-core SKILL.md paid three extra edit cycles for the same reason. The ratchet is working as designed — the friction is that neither child had budgeted compression time into a fix that read as "one line of text", and both reached for the stamp before reaching for the shrink.

## bash-isms-in-pasted-snippets-diverge-silently-under-zsh
- skills: [ac-implement]
- impact: M
- frequency: frequent
- recurrence: 3
- related: [tr-shadowed-by-tmux-alias-in-interactive-zsh]
- first_seen: 2026-08-03
- last_seen: 2026-08-03
- stage: ac-loop
- status: open
- proposed_fix: the fleet's interactive shell is zsh, so treat every bash-ism in a pasted snippet as a defect: read `$?` directly instead of `${PIPESTATUS[0]}` (drop the pipe rather than translate it), and never rely on word-splitting an unquoted expansion — put multi-item loops in a bash script file or feed them a here-string.
- narrative: three occurrences in one run, all silent rather than loud. (1) A verification step read `${PIPESTATUS[0]}` and got an empty string — zsh spells it `$pipestatus[1]` — producing a confusing empty result rather than an error. (2) The same construct after a trailing `echo` had already been reset by the `echo` itself, costing an extra turn. (3) `for f in $FILES` passed the entire whitespace-joined list as ONE filename, because zsh does not word-split unquoted expansions; the loop ran once against a path that did not exist. None of the three failed loudly — each produced a plausible-looking wrong answer, which is what makes the class expensive relative to its trivial per-instance fix. Sibling shapes in the refine snippets (`echo` expanding `\n`, `tr` shadowed by a tmux alias) are logged in ac-bead-refine's file.

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
