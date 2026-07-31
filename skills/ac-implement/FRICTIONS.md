---
skill: ac-implement
created: 2026-07-29
last_pass: 2026-07-31
entries: 5
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
