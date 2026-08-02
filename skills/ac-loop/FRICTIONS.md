---
skill: ac-loop
created: 2026-07-21
last_pass: 2026-08-01
entries: 13
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
- impact: H
- frequency: every-run
- recurrence: 3
- related: [standing-sanctions-not-threaded-into-delegation-prompt]
- first_seen: 2026-07-22
- last_seen: 2026-08-02
- stage: ac-loop
- status: open
- proposed_fix: delegation briefs must POINT at the bead as the authoritative spec ("read `br show <id>` in full; this brief is a pointer, not a substitute") and must NEVER restate the bead's preconditions as established fact. Pair it with an explicit escape clause so a child that finds a stated precondition false is licensed to widen scope to the bead's own ACs rather than treating the brief as a hard fence. ALSO (2026-08-01): the same prohibition applies to non-bead claims a conductor asserts — bead OPEN/CLOSED status, tool availability, an active blocker, a paraphrased doctrine rule — and it applies to the `ac-pipeline/references/delegation-contract.md` child-spawn preamble itself, which currently asserts "you have NO `mcp__mcp-agent-mail__*` tools" as flat fact when tool availability is per-agent configuration. A false claim in a VERBATIM-copied block reaches every child of every run; that line needs to be conditional ("if you have no ... tools") or dropped.
- narrative: the conductor compressed a refined bead into a delegation brief and stated a PRECONDITION (a PostHog client flag "already set") that was in fact an unimplemented acceptance criterion of that same bead. The brief simultaneously said "one directive, nothing more" and "don't widen CSP on your own judgement" — an over-tight scope the child could not distinguish from a correct one. The child caught the error only because it read `br show` in full instead of trusting the brief; had it obeyed, an incomplete security fix would have shipped (a CSP connect-src fix that could not actually clear the QA errors it targeted). Orchestrator compression is a spec-drift vector exactly as much as filing-time staleness is.
  RUN 2026-07-31/08-01 (BCA, width 2, 4 conductor identities) escalated this from occasional to every-run and from L to H. Measured: 7+ bead premises stated in briefs were false or inverted, one batch at 3-of-6. Four further conductor-claim failures beyond bead preconditions — told a child it had no Agent Mail tools (false; the child checked anyway and the check produced a real finding), told a child a bead was closed (it was open), wrote a self-contradictory seam rule a child had to correct, and retracted a blocker twice. In EVERY instance the child that re-derived from the primary source was right and the child that trusted the brief was wrong; re-derivation costs one call, an inverted premise costs the whole child session and the output looks finished. Root cause is structural, not carelessness: a conductor compresses (drops the qualifier), caches (state moves under it mid-run), and generalizes from its own environment (its tool set is not the child's). Folded into memory `loop-retro-delegation-brief-claims-are-hints` (recurrence bumped to 2).
  RUN 20260802-084558-9799 (agent-compounds, ac-loop-lite ablation), +1: the conductor's review
  payload stated the bead↔commit pairing REVERSED for ac-uvj/ac-bqw relative to the commit
  trailers; the review child caught it by reading the trailers (primary source) instead of
  trusting the payload. Same root — conductor-composed payload facts drift; children citing
  primary sources are right. Conductor's own noted fix: cite trailers when composing, never
  pair from memory.

## child-has-no-upward-report-channel
- skills: [ac-loop, ac-implement]
- impact: M
- frequency: occasional
- recurrence: 1
- related: [phase-skills-mandate-panels-a-subagent-cannot-spawn, delegation-brief-restates-bead-preconditions]
- first_seen: 2026-08-01
- last_seen: 2026-08-01
- stage: ac-loop
- status: open
- proposed_fix: before delegating, the conductor must verify the child has a report path — EITHER the parent blocks on the child's return value (synchronous), OR the child holds `SendMessage`/Agent Mail. Make it an explicit line in the spawn checklist, and never instruct a child to "report to X" / "message the conductor when done" unless the tool that does so is in its declared toolset. Corollary for the `ac-pipeline/references/delegation-contract.md` preamble: the "return a structured `friction:` block" clause is only satisfiable when someone actually reads the return, so a backgrounded child with no messaging tool is a silent-stall by construction, not by failure.
- narrative: three sub-agents in one run completed good work and had NO way to report it upward — no `SendMessage` in their toolset, and the spawn pattern did not have the parent reading their return value. The conductor discovered the completed work incidentally and relayed it by hand. This is the mirror of the existing silent-stall class: clauses 1-5 of the delegation contract all cover a delegate that goes quiet because it STALLED, and none cover a delegate that goes quiet because it FINISHED with no channel. Both look identical from the conductor's side, which is what makes it expensive — the conductor's watchdog fires, the work is presumed lost, and it is either redone or dropped. Tool-restriction is the cause, so it is fully preventable at spawn time.

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
- recurrence: 23
- related: [phase-skills-mandate-panels-a-subagent-cannot-spawn]
- first_seen: 2026-07-22
- last_seen: 2026-08-02
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
  **RUN 20260730-215800-loop1 (2026-07-31), +4:** the same rule blocked `ac-pipeline/references/board-scan.md`'s
  Scan D and Scan E blocks VERBATIM at Phase-0 orient — both write to `$D/…` where
  `D=$(mktemp -d)`. Cost ~4 min / 4 blocked calls before the conductor hand-rewrote them. This
  widens the blast radius beyond artifact-write snippets: board-scan is the shared health-probe
  substrate for FIVE skills (ac-loop, ac-tidy, ac-dashboard, ac-human-session, ac-align), so on a
  guarded machine every one of those probes is improvised or silently absent. This run's Scan D/E
  ALARM readings were only obtained because the conductor rewrote the blocks by hand. Filed
  separately as **bd-nw8r3** (P1), which also carries a SECOND, unrelated defect in the same file:
  `find .github/workflows -name '*.yaml'` is zsh-fatal without nullglob and aborts the whole Scan E
  block in any repo with no `.yaml` files (BCA is one).
  **RUN 20260802-084558-9799 (ac-loop-lite ablation), +4:** conductor blocked twice (a
  `> "/tmp/loop-lite-$RUN_ID/state"` redirect, then a bead description quoting the redirect
  verbatim), batch-close child blocked on ac-batch-close's OWN run-ledger snippet (filed
  ac-d4r), and an implement child blocked on a dynamic-path `wc -l`. All four self-corrected
  (Write tool / literal paths) — the class persists even under the compressed loop-lite
  contract; dream proposal ac-e8m (dcg-resolve-then-paste-writes) covers the general fix.

## dcg-false-positives-on-angle-bracket-inside-quoted-prose
- skills: [ac-loop, ac-land, ac-bead-capture, beads-standards]
- impact: S
- frequency: frequent
- recurrence: 2
- related: [dcg-blocks-the-skills-own-canonical-artifact-redirects]
- first_seen: 2026-07-22
- last_seen: 2026-07-31
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
  **RUN 20260730-215800-loop1 (2026-07-31) — the predicted recurrence landed, same skill, same
  step.** This entry forecast "it will recur every time a memo uses a blockquote"; nine days
  later ac-land's T2 decision bead (`bd-8l4a8`, the qa-blocker proposal) was blocked by the
  identical rule for the identical reason — `>` blockquote lines inside the quoted `-d`
  description. Cost one blocked cycle plus a rewrite (this time resolved by switching the memo to
  4-space-indented code blocks, which also passes and needs no temp file). The friction log
  predicted this precisely and nothing acted on it, which is the point worth noting: the
  `proposed_fix` here is a one-line addition to beads-standards' decision-bead template, still
  unshipped. Escalating `frequency` to `frequent` — every ac-land that files a T2/HUMAN decision
  bead writes exactly this shape of memo.

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

## c2-stop-wording-predates-trunk-direct
- skills: [ac-loop]
- impact: L
- frequency: rare
- recurrence: 1
- related: []
- first_seen: 2026-07-31
- last_seen: 2026-07-31
- stage: ac-loop
- status: open
- proposed_fix: restate stop condition C2 in trunk-direct terms — "do NOT run ac-batch-close, so the review acceptance mark does not advance over an unresolved regression" — and REMOVE the superseded "Do NOT merge" phrasing rather than appending a clarification beside it.
- narrative: C2's published wording is "Hard stop. Do NOT merge." Under trunk-direct there is no
  merge to withhold — the code is already on `main` by the time review runs. The operative meaning
  is entirely different: do not run `ac-batch-close`, so the review acceptance mark does not
  advance over an unresolved regression. This run hit C2 for real (ac-review returned
  NEEDS_DECISION on bd-68bra, a Critical regression the batch itself introduced) and the conductor
  interpreted it correctly — cost was 0. But the correct reading required knowing that the text is
  stale. A conductor reading it literally could reasonably conclude C2 is inapplicable under
  trunk-direct (there being no merge to stop) and run batch-close anyway, advancing the acceptance
  mark over a known Critical regression. Impact is rated L on that failure mode, not on this run's
  actual cost. **This is a SUPERSESSION, not a gap:** "Do NOT merge" is stale text left behind by
  the trunk-direct migration, so the fix is to rewrite it, not to add a note next to it
  (`promotion-ladder.md` ranks removal equally with addition).

## post-merge-stamp-keyed-to-window-not-subject
- skills: [ac-loop]
- impact: S
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: 2026-07-31
- last_seen: 2026-07-31
- stage: ac-loop
- status: open
- proposed_fix: state the trigger as a WINDOW test in the conductor-facing text — "created between batch verify and batch close ⇒ stamp `post-merge`, regardless of what the bead is about" — since the natural misreading is a subject-matter test.
- narrative: the conductor instructed refine children NOT to stamp `post-merge` on follow-up beads,
  reasoning that those beads were outside the batch's scope. That was wrong. The beads were created
  INSIDE the batch's verify→review→close window, which is exactly the stamp-at-creation trigger:
  **the window, not the bead's subject, is what decides.** No harm this run — the beads-closed gate
  is `--beads`-scoped, so the unstamped follow-ups could not trip it — but the rule is easy to
  misread in precisely this direction, because "is this bead part of the batch?" is the more
  natural question to ask and gives the wrong answer.
