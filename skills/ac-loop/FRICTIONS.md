---
skill: ac-loop
created: 2026-07-21
last_pass: 2026-07-29
entries: 10
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
- recurrence: 2
- related: [standing-sanctions-not-threaded-into-delegation-prompt, open-tooling-bug-not-checked-against-run-config-at-phase0]
- first_seen: 2026-07-22
- last_seen: 2026-07-29
- stage: ac-loop
- status: open
- proposed_fix: (a) make the explicit per-child FILE-TERRITORY FENCE standard delegation-prompt text — it is the mechanism that made width 3 safe; (b) add a width-safety caveat: parallelism is safe on source FILES but NOT on shared BUILD state (`.next`) or shared SCRATCH state (RUN_ID-derived artifact dirs) — never schedule two prod-build consumers (qa-browser / site-polish / anything triggering the pre-push build) concurrently until a real build slot or a per-consumer `distDir` exists; (c) ramp evidence now covers width=2 as well as width=3 — width 2 is workable on a shared checkout, width 3 would likely need real build isolation.
- narrative: PARALLEL_WIDTH=3 (Craig-chosen) held cleanly — three tree-disjoint implementers committed to `main` concurrently across two batches with ZERO lost work and zero pathspec collisions. The explicit per-child file-territory fence in the delegation prompt is what made that safe, and it is currently improvised per-run rather than standard text. Both genuine collisions this run were on shared NON-SOURCE state, not source: (1) refine siblings share a RUN_ID so their `beads-snapshot.json` collided, a near-miss that nearly stamped another child's beads (filed bd-baudw); (2) two prod-build consumers clobbered each other's `.next`, costing ~35min and a false-positive product investigation (filed bd-y5mza). Ramp conclusion: width 3 is sustainable for refine and implement; it is NOT yet safe for concurrent prod-build consumers.
  RUN 20260728-234407-54469 (width=2, shared trunk-direct checkout) added three more distinct, all non-fatal, cross-child collisions to the ramp evidence: (a) a sibling's uncommitted `lib/**` type error broke the OTHER child's `next build` moments after that child's own `tsc` had passed cleanly; (b) a transient whole-project `tsc` failure caused by in-flight sibling WIP; (c) foreign format churn appearing in the working tree from a sibling's pass. All three were correctly attributed by the children to sibling interference rather than self-blamed as regressions in their own change. This strengthens the width=2-is-workable / width=3-needs-isolation conclusion above.

## phase-skills-mandate-panels-a-subagent-cannot-spawn
- skills: [ac-loop, ac-bead-refine, ac-review, ac-qa-browser]
- impact: L
- frequency: every-run
- recurrence: 30
- related: [standing-sanctions-not-threaded-into-delegation-prompt]
- first_seen: 2026-07-22
- last_seen: 2026-07-22
- stage: ac-loop
- status: open
- proposed_fix: declare an explicit DEGRADED SINGLE-CONDUCTOR MODE in each panel-mandating phase skill (`ac-bead-refine`, `ac-review`, `ac-qa-browser`) — when the skill is invoked from inside a subagent (no spawn capability), the mandated N-way parallel panel collapses to N sequential inline LENSES run by the one agent, and that degradation is declared in the artifact rather than silently substituted. Tracked by bd-nreuv.
- narrative: recurred across ~30 children in one day (2026-07-22, BCA — three ac-loop batches plus
  an infra-four batch). `ac-bead-refine`, `ac-review` and `ac-qa-browser` all MANDATE a parallel
  reviewer/lens panel as their core mechanism, but every one of them is routinely invoked from
  INSIDE a subagent, which cannot spawn further subagents. The mandate is therefore unsatisfiable
  by construction in the most common invocation path. Every child silently degraded to running the
  lenses inline and sequentially — which is a reasonable fallback, but it is undeclared: the
  artifact still reads as though a real panel ran, so the conductor cannot tell a genuine 3-reviewer
  consensus from one agent wearing three hats. The cost is not the degradation itself but the loss
  of signal about which reviews had real independence. bd-nreuv tracks the decision.

## dcg-blocks-the-skills-own-canonical-artifact-redirects
- skills: [ac-loop, ac-bead-refine, ac-review, ac-qa-browser, ac-implement]
- impact: M
- frequency: every-run
- recurrence: 15
- related: [phase-skills-mandate-panels-a-subagent-cannot-spawn]
- first_seen: 2026-07-22
- last_seen: 2026-07-22
- stage: ac-loop
- status: open
- proposed_fix: patch the ac-* skills' own setup snippets so their canonical shell redirects no longer target a dynamic path — dcg blocks `> "$ARTIFACTS_DIR/…"` because the destination is variable-substituted. Either resolve-then-paste the literal path (the pattern teardown already mandates), or route artifact writes through the Write tool instead of a shell redirect. Tracked by bd-5ndzm.
- narrative: ~15 recurrences in one day (2026-07-22). The ac-* phase skills ship copy-paste setup
  snippets that write artifacts via `> "$ARTIFACTS_DIR/<file>"`. dcg blocks variable/substituted
  paths as a matter of policy, so the skills' OWN canonical snippets are guard-blocked on first
  use — every child hit the block, then improvised a workaround. This is the worst shape of
  friction: the doctrine says "a guard block means CHANGE APPROACH, never bypass", and the thing
  being blocked is the doctrine's own example code, so a compliant child is left with no sanctioned
  path and must invent one. Identical in kind to ac-land's own teardown fix (selectors print
  literals, deletion pastes them) — the same resolve-then-paste discipline needs applying to the
  artifact-write snippets across the phase skills. bd-5ndzm tracks it.

## dcg-false-positives-on-angle-bracket-inside-quoted-prose
- skills: [ac-loop, ac-land, ac-bead-capture, beads-standards]
- impact: S
- frequency: occasional
- recurrence: 1
- related: [dcg-blocks-the-skills-own-canonical-artifact-redirects]
- first_seen: 2026-07-22
- last_seen: 2026-07-22
- stage: ac-land
- status: open
- proposed_fix: when a bead description contains markdown that could tokenise as shell metacharacters (a `>` blockquote is the common one), do not inline it in `br create -d "..."` — write the memo to a literal `/tmp/<dir>/memo.md` with the Write tool and pass `-d "$(cat /tmp/<dir>/memo.md)"`. Worth stating once in beads-standards' decision-bead template, since decision memos are exactly the beads long enough to contain blockquotes.
- narrative: filing the ac-land T2 decision bead was BLOCKED by dcg's
  `core.filesystem:redirect-truncate-dynamic-path` rule. Nothing in the command redirected
  anything — the `>` was a markdown blockquote inside the double-quoted `-d` description, and the
  guard's tokeniser read it as a redirect to a dynamic path. Correct guard behaviour is ambiguous
  here (it cannot prove the quoting is safe), so the fix is on the caller side, not a bypass. Cost
  was one blocked cycle plus a rewrite; trivial individually, but decision beads are precisely the
  ones with long prose memos, so it will recur every time a memo uses a blockquote. Resolved by
  writing the memo to a literal /tmp path and passing it via command substitution.

## hand-typed-sha-not-git-rev-parsed
- skills: [ac-loop]
- impact: M
- frequency: rare
- recurrence: 1
- related: []
- first_seen: 2026-07-29
- last_seen: 2026-07-29
- stage: ac-loop
- status: open
- proposed_fix: ALWAYS `git rev-parse` a SHA argument before using it — never abbreviate it, never type it from memory.
- narrative: the conductor hand-typed a `batch_anchor` full SHA instead of resolving it with `git rev-parse`, producing a fabricated SHA that did not correspond to any real commit. The CI workflow peels it via `^{commit}`, which failed, and the run was cancelled. Cost one cancelled CI run.

## bug-lane-generation-outpaces-drain-rate
- skills: [ac-loop]
- impact: M
- frequency: frequent
- recurrence: 1
- related: []
- first_seen: 2026-07-29
- last_seen: 2026-07-29
- stage: ac-loop
- status: open
- proposed_fix: Rule 0's "drain the bug lane COMPLETELY before steps 1-2" can never be satisfied at the current review depth — either cap the drain at a budget instead of exhaustion, or re-scope Rule 0 explicitly. This needs a human decision, not a skill patch.
- narrative: the ready-bug count went from 31 to 34 across a run that shipped 10 beads — the review and QA panels file findings faster than the bug lane drains them at current review depth. This is a structural economics observation, not a single incident: at this depth of review scrutiny, bug-lane exhaustion is not a reachable state, so Rule 0 as currently written sets an unmeetable bar every run.

## open-tooling-bug-not-checked-against-run-config-at-phase0
- skills: [ac-loop]
- impact: M
- frequency: occasional
- recurrence: 1
- related: [width-safe-on-files-not-on-shared-build-and-scratch-state]
- first_seen: 2026-07-29
- last_seen: 2026-07-29
- stage: ac-loop
- status: open
- proposed_fix: make "read the board for OPEN tooling bugs whose trigger condition this run's own configuration satisfies" a standard Phase-0 step.
- narrative: bd-baudw (siblings sharing `ARTIFACTS_DIR` on one `RUN_ID`, cross-stamping beads) was an OPEN bug at this run's start, and width=2 is exactly its trigger condition. Giving each child a distinct RUN_ID suffix pre-empted it this time — but only because the conductor happened to remember the bug, not because Phase-0 has a step that checks for it. Despite that top-level pre-emption, a child later reproduced the identical collision live in a nested run, showing the fix doesn't cascade down automatically — it has to be re-applied consciously at every level where the trigger condition recurs. Cost this run was 0, purely because the check happened informally; the process gap remains.
