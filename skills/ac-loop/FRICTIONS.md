---
skill: ac-loop
created: 2026-07-21
last_pass: 2026-07-22
entries: 4
---

# ac-loop — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

## doc-only-repo-no-loop-adaptation
- skills: [ac-loop]
- impact: M
- frequency: rare
- recurrence: 1
- related: []
- first_seen: 2026-07-21
- last_seen: 2026-07-21
- stage: ac-loop
- status: open
- proposed_fix: add a short "doc-only / non-app repo" adaptation note to ac-loop — when the target repo has no vitest/app-CI/version/QA (e.g. agent-compounds itself), the verify-gate collapses to `lint.sh` + `validate-skill.sh`, and CI-dispatch / version-bump / browser-device passes are skipped; the operator shouldn't have to hand-translate the whole ceremony.
- narrative: during the W3.2 pilot's live-run acceptance (G2), a fresh conductor ran the Rule-0 bug lane on agent-compounds. The loop's Phase-0 board-scan and the verify→CI-dispatch→ac-publish spine all assume a Next.js app; on a doc-only repo the "gate" is really lint.sh + validate-skill.sh and there is no CI/version/QA. The run succeeded, but only because the operator translated the ceremony by hand — the skill has no documented adaptation for this case.

## delegation-brief-restates-bead-preconditions
- skills: [ac-loop, ac-implement]
- impact: L
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: 2026-07-22
- last_seen: 2026-07-22
- stage: ac-loop
- status: open
- proposed_fix: delegation briefs must POINT at the bead as the authoritative spec ("read `br show <id>` in full; this brief is a pointer, not a substitute") and must NEVER restate the bead's preconditions as established fact. Pair it with an explicit escape clause so a child that finds a stated precondition false is licensed to widen scope to the bead's own ACs rather than treating the brief as a hard fence.
- narrative: the conductor compressed a refined bead into a delegation brief and stated a PRECONDITION (a PostHog client flag "already set") that was in fact an unimplemented acceptance criterion of that same bead. The brief simultaneously said "one directive, nothing more" and "don't widen CSP on your own judgement" — an over-tight scope the child could not distinguish from a correct one. The child caught the error only because it read `br show` in full instead of trusting the brief; had it obeyed, an incomplete security fix would have shipped (a CSP connect-src fix that could not actually clear the QA errors it targeted). Orchestrator compression is a spec-drift vector exactly as much as filing-time staleness is.

## standing-sanctions-not-threaded-into-delegation-prompt
- skills: [ac-loop]
- impact: M
- frequency: frequent
- recurrence: 1
- related: [delegation-brief-restates-bead-preconditions]
- first_seen: 2026-07-22
- last_seen: 2026-07-22
- stage: ac-loop
- status: open
- proposed_fix: any standing sanction that resolves a guard-vs-contract conflict (notably ac-loop § Efficiency's allowance of `git push --no-verify` for loop commits) must be stated VERBATIM IN the delegation prompt. A child cannot be expected to have loaded the conductor's doctrine; absent the text it re-derives the conflict from scratch, and a correct child will refuse the bypass.
- narrative: the husky pre-push hook runs `next build`. The delegation contract says "commit the instant your ACs verify", while a concurrent QA hold says "don't rebuild while QA owns the server". Those are in direct conflict, and there was NO compliant path available to the child. One review child correctly refused `--no-verify` as a guard bypass (right instinct per the guard doctrine) and consequently clobbered the running QA server. ac-loop § Efficiency ALREADY sanctions `--no-verify` for loop commits — the doctrine existed, it just never reached the child. Once threaded explicitly into the prompt, zero recurrences for the rest of the run. Related decision bead: bd-652ap.

## width-safe-on-files-not-on-shared-build-and-scratch-state
- skills: [ac-loop]
- impact: L
- frequency: every-run
- recurrence: 1
- related: [standing-sanctions-not-threaded-into-delegation-prompt]
- first_seen: 2026-07-22
- last_seen: 2026-07-22
- stage: ac-loop
- status: open
- proposed_fix: (a) make the explicit per-child FILE-TERRITORY FENCE standard delegation-prompt text — it is the mechanism that made width 3 safe; (b) add a width-safety caveat: parallelism is safe on source FILES but NOT on shared BUILD state (`.next`) or shared SCRATCH state (RUN_ID-derived artifact dirs) — never schedule two prod-build consumers (qa-browser / site-polish / anything triggering the pre-push build) concurrently until a real build slot or a per-consumer `distDir` exists.
- narrative: PARALLEL_WIDTH=3 (Craig-chosen) held cleanly — three tree-disjoint implementers committed to `main` concurrently across two batches with ZERO lost work and zero pathspec collisions. The explicit per-child file-territory fence in the delegation prompt is what made that safe, and it is currently improvised per-run rather than standard text. Both genuine collisions this run were on shared NON-SOURCE state, not source: (1) refine siblings share a RUN_ID so their `beads-snapshot.json` collided, a near-miss that nearly stamped another child's beads (filed bd-baudw); (2) two prod-build consumers clobbered each other's `.next`, costing ~35min and a false-positive product investigation (filed bd-y5mza). Ramp conclusion: width 3 is sustainable for refine and implement; it is NOT yet safe for concurrent prod-build consumers.
