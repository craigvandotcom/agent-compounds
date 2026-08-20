---
skill: ac-loop
created: 2026-07-21
last_pass: 2026-08-17
entries: 17
---

# ac-loop — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

## doc-only-repo-no-loop-adaptation
- skills: [ac-loop, ac-land]
- impact: M
- frequency: occasional
- recurrence: 2
- related: []
- first_seen: 2026-07-21
- last_seen: 2026-08-04
- stage: ac-loop
- status: open
- proposed_fix: add a short "doc-only / non-app repo" adaptation note to ac-loop — when the target repo has no vitest/app-CI/version/QA (e.g. agent-compounds itself), the verify-gate collapses to `lint.sh` + `validate-skill.sh`, and CI-dispatch / version-bump / browser-device passes are skipped; the operator shouldn't have to hand-translate the whole ceremony.
- narrative: during the W3.2 pilot's live-run acceptance (G2), a fresh conductor ran the Rule-0 bug lane on agent-compounds. The loop's Phase-0 board-scan and the verify→CI-dispatch→ac-publish spine all assume a Next.js app; on a doc-only repo the "gate" is really lint.sh + validate-skill.sh and there is no CI/version/QA. The run succeeded, but only because the operator translated the ceremony by hand — the skill has no documented adaptation for this case.
  **RUN 20260803-221658-19787, +1 — the same gap at the LAND end of the pipeline, which widens the fix.** Landing on agent-compounds ran into `ac-land` prescribing pnpm-repo commands (the format sweep and the build/lint gates it composes) in a repo that has no pnpm project at all. The child translated by hand, as the operator did on the 2026-07-21 occurrence, and at zero cost — but that is now two skills, at opposite ends of one pipeline, each independently assuming a Next.js/pnpm app and each leaving the translation to whoever is running. The generalisation the original entry did not have: this is not an ac-loop adaptation note, it is a PIPELINE-WIDE precondition. The cheap form is to establish the repo's shape once at Phase 0 (does a package manager project exist; is there CI, a version, a QA surface) and carry that answer to every phase, so a doc-only repo collapses each gate to its available equivalent by construction rather than by improvisation at four separate call sites. A pointer entry now sits in ac-land's log; occurrences stay counted here.

## delegation-brief-restates-bead-preconditions
- skills: [ac-loop, ac-implement, ac-pipeline]
- impact: H
- frequency: every-run
- recurrence: 6
- related: [standing-sanctions-not-threaded-into-delegation-prompt, dispatch-scoped-from-spec-not-comment-history]
- first_seen: 2026-07-22
- last_seen: 2026-08-17
- stage: ac-loop
- status: open (ac-loop half SHIPPED 2026-08-06 as `references/delegation-prompts.md` § Brief-claim rule — compose-time citation requirement + verbatim child-facing pointer/escape clause; awaiting live-run confirmation. The ac-pipeline half — same rule in `delegation-contract.md` — remains unshipped and is tracked in that skill's log.)
- proposed_fix: delegation briefs must POINT at the bead as the authoritative spec ("read `br show <id>` in full; this brief is a pointer, not a substitute") and must NEVER restate the bead's preconditions as established fact. Pair it with an explicit escape clause so a child that finds a stated precondition false is licensed to widen scope to the bead's own ACs rather than treating the brief as a hard fence. ALSO (2026-08-01): the same prohibition applies to non-bead claims a conductor asserts — bead OPEN/CLOSED status, tool availability, an active blocker, a paraphrased doctrine rule — and it applies to the `ac-pipeline/references/delegation-contract.md` child-spawn preamble itself, which currently asserts "you have NO `mcp__mcp-agent-mail__*` tools" as flat fact when tool availability is per-agent configuration. A false claim in a VERBATIM-copied block reaches every child of every run; that line needs to be conditional ("if you have no ... tools") or dropped.
- narrative: the conductor compressed a refined bead into a delegation brief and stated a PRECONDITION (a PostHog client flag "already set") that was in fact an unimplemented acceptance criterion of that same bead. The brief simultaneously said "one directive, nothing more" and "don't widen CSP on your own judgement" — an over-tight scope the child could not distinguish from a correct one. The child caught the error only because it read `br show` in full instead of trusting the brief; had it obeyed, an incomplete security fix would have shipped (a CSP connect-src fix that could not actually clear the QA errors it targeted). Orchestrator compression is a spec-drift vector exactly as much as filing-time staleness is.
  RUN 2026-07-31/08-01 (BCA, width 2, 4 conductor identities) escalated this from occasional to every-run and from L to H. Measured: 7+ bead premises stated in briefs were false or inverted, one batch at 3-of-6. Four further conductor-claim failures beyond bead preconditions — told a child it had no Agent Mail tools (false; the child checked anyway and the check produced a real finding), told a child a bead was closed (it was open), wrote a self-contradictory seam rule a child had to correct, and retracted a blocker twice. In EVERY instance the child that re-derived from the primary source was right and the child that trusted the brief was wrong; re-derivation costs one call, an inverted premise costs the whole child session and the output looks finished. Root cause is structural, not carelessness: a conductor compresses (drops the qualifier), caches (state moves under it mid-run), and generalizes from its own environment (its tool set is not the child's). Folded into memory `loop-retro-delegation-brief-claims-are-hints` (recurrence bumped to 2).
  RUN 20260802-084558-9799 (agent-compounds, ac-loop-lite ablation), +1: the conductor's review
  payload stated the bead↔commit pairing REVERSED for ac-uvj/ac-bqw relative to the commit
  trailers; the review child caught it by reading the trailers (primary source) instead of
  trusting the payload. Same root — conductor-composed payload facts drift; children citing
  primary sources are right. Conductor's own noted fix: cite trailers when composing, never
  pair from memory.
  **RUN 20260804-202200-loop (BCA, width 2), +1 — the failure is TIMING, and the fix is a
  citation requirement.** The conductor's refine brief asserted that a sibling bead's Parts A+B
  were "being implemented RIGHT NOW" by a concurrent child, and instructed the refiner to write
  against that post-implementation world (possibly wiring a dep edge). All false: A+B had landed
  five days earlier (2026-07-29). All three round-1 reviewers independently had to refute the
  brief before any refining could begin — ~15 minutes of panel time spent disproving the
  conductor. The root cause is not compression this time but ORDER: the brief was composed from
  the dispatch PLAN before the implement child had reported back, so the claim described an
  intention, not a state. Hence the sharpened rule, which is mechanically checkable at compose
  time: **a dispatch brief may state a fact only if it can cite a commit SHA or a `br show`
  verdict — never a narrative claim about in-flight work.** If no citation exists yet, the claim
  is not ready to be stated; say "premise, NOT verified" or wait for the child's return.
  **+1 — a 9-hour, ~40-agent v2 run put FIVE false premises into child briefs; every one was
  caught by a child that re-verified instead of trusting, and none by the conductor.** The five,
  and the artifact class each one corrupts: (1) a risk flag inherited from a scan TABLE rather
  than re-derived from the board — corrupts the risk queue's membership; (2) "fresh work
  reclaimed from a dead agent" on a bead whose seven ACs were already discharged — a believing
  child would have re-run a landed production data repair; (3) a UI claim about a backend-only
  change with zero UI diff — sends a verifier to look at nothing; (4) "the app was built and
  launched earlier this run" when the installed bundle predated the commit under test by 80
  minutes — the device pass caught it with a symbol grep and rebuilt, where trusting would have
  produced a confident FALSE NEGATIVE on the only thing that pass could verify; (5) a test-tier
  WAIVER granted on a local host symptom (a collation mismatch producing ~81 local failures) for
  a tier CI measures at 737/739 green — the waiver let a genuinely-red proof through. The shape
  is constant across all five: **an INFERRED fact asserted as an ESTABLISHED one.** The scale
  matters more than the count — five false premises survived the conductor and zero survived
  the children, so child-side re-verification is not a courtesy round, it is the layer that
  made a run of that size safe. Corollary the run added: **a waiver is a premise too.** Waiving
  a gate requires measured state on the surface being waived, at the place the gate measures it;
  a local symptom is not evidence about a CI-measured tier.

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
- recurrence: 3
- related: [standing-sanctions-not-threaded-into-delegation-prompt, open-tooling-bug-not-checked-against-run-config-at-phase0, divergence-check-while-a-child-is-live-proves-nothing]
- first_seen: 2026-07-22
- last_seen: 2026-08-04
- stage: ac-loop
- status: open
- proposed_fix: (a) make the explicit per-child FILE-TERRITORY FENCE standard delegation-prompt text — it is the mechanism that made width 3 safe; (b) add a width-safety caveat: parallelism is safe on source FILES but NOT on shared BUILD state (`.next`) or shared SCRATCH state (RUN_ID-derived artifact dirs) — never schedule two prod-build consumers (qa-browser / site-polish / anything triggering the pre-push build) concurrently until a real build slot or a per-consumer `distDir` exists; (c) ramp evidence now covers width=2 as well as width=3 — width 2 is workable on a shared checkout, width 3 would likely need real build isolation.
- narrative: PARALLEL_WIDTH=3 (Craig-chosen) held cleanly — three tree-disjoint implementers committed to `main` concurrently across two batches with ZERO lost work and zero pathspec collisions. The explicit per-child file-territory fence in the delegation prompt is what made that safe, and it is currently improvised per-run rather than standard text. Both genuine collisions this run were on shared NON-SOURCE state, not source: (1) refine siblings share a RUN_ID so their `beads-snapshot.json` collided, a near-miss that nearly stamped another child's beads (filed bd-baudw); (2) two prod-build consumers clobbered each other's `.next`, costing ~35min and a false-positive product investigation (filed bd-y5mza). Ramp conclusion: width 3 is sustainable for refine and implement; it is NOT yet safe for concurrent prod-build consumers.
  RUN 20260728-234407-54469 (width=2, shared trunk-direct checkout) added three more distinct, all non-fatal, cross-child collisions to the ramp evidence: (a) a sibling's uncommitted `lib/**` type error broke the OTHER child's `next build` moments after that child's own `tsc` had passed cleanly; (b) a transient whole-project `tsc` failure caused by in-flight sibling WIP; (c) foreign format churn appearing in the working tree from a sibling's pass. All three were correctly attributed by the children to sibling interference rather than self-blamed as regressions in their own change. This strengthens the width=2-is-workable / width=3-needs-isolation conclusion above.
  **RUN 20260804-202200-loop (BCA, width=2), +1 — the positive form of the disjointness rule:
  HOIST the shared file, do not hunt for beads that share none.** Both beads in batch 2 implied
  edits to the same file (`scripts/curate-foods/cli.ts`). Rather than dropping one bead or
  serialising the batch, the conductor kept that ONE file conductor-owned and gave each
  implementer the rest of its territory — the two children then ran genuinely disjoint at zero
  collision cost. This reframes batch selection: the constraint that makes width>1 safe is not
  "select beads whose file sets are disjoint" (a rare and shrinking set as batches grow), it is
  "make the selected set disjoint by HOISTING the intersection to the conductor". The
  intersection is typically one or two files and the conductor is already the serialising agent,
  so the hoist is cheap. Fold this into the file-territory fence asked for in (a): the fence must
  name both the child's territory AND the conductor-retained files. The same run also shows the
  ledger is this case in disguise — `.beads/issues.jsonl` cannot be staged per-line, so telling
  one child "you own the ledger for this window" while telling another "hold ALL br mutations" is
  not an ownership protocol; the two instructions are not jointly satisfiable on one file, and the
  implement child ended up committing two ledger lines it did not author (they were the
  conductor's own Phase-0 comments). Hoist the ledger too: the conductor commits it.

## phase-skills-mandate-panels-a-subagent-cannot-spawn
- skills: [ac-loop, ac-loop-2, ac-bead-refine, ac-review, ac-qa-browser]
- impact: L
- frequency: every-run
- recurrence: 32
- related: [standing-sanctions-not-threaded-into-delegation-prompt, refine-all-degrades-to-priority-cut-when-set-exceeds-width]
- first_seen: 2026-07-22
- last_seen: 2026-08-14
- stage: ac-loop
- status: open
- proposed_fix: declare an explicit DEGRADED SINGLE-CONDUCTOR MODE in each panel-mandating phase skill (`ac-bead-refine`, `ac-review`, `ac-qa-browser`) — when the skill is invoked from inside a subagent (no spawn capability), the mandated N-way parallel panel collapses to N sequential inline LENSES run by the one agent, and that degradation is declared in the artifact rather than silently substituted. Tracked by bd-nreuv. LOOP-2 ADDITION (2026-08-13): a sitting that finished a degraded drain must not be read as panel-quality, and drain WIDTH must not be collapsed because of it — throughput across beads is still paid.
- narrative: recurred across ~30 children in one day (2026-07-22, BCA — three ac-loop batches plus
  an infra-four batch). `ac-bead-refine`, `ac-review` and `ac-qa-browser` all MANDATE a parallel
  reviewer/lens panel as their core mechanism, but every one of them is routinely invoked from
  INSIDE a subagent, which cannot spawn further subagents. The mandate is therefore unsatisfiable
  by construction in the most common invocation path. Every child silently degraded to running the
  lenses inline and sequentially — which is a reasonable fallback, but it is undeclared: the
  artifact still reads as though a real panel ran, so the conductor cannot tell a genuine 3-reviewer
  consensus from one agent wearing three hats. The cost is not the degradation itself but the loss
  of signal about which reviews had real independence. bd-nreuv tracks the decision.
  **RUN 20260813-235654-12053 (BCA, ac-loop-2 Phase 1), +1 — first observation under the v2
  drain model, and the honesty half of bd-nreuv held.** Every refine child this run was
  degraded-solo (no Task tool in this harness) and ran 3-4 sequential lenses; independence was
  lost, as this entry already predicts. Children stamped `degraded-solo` rather than faking a
  panel, so the undeclared-substitution failure that motivated bd-nreuv did not recur. What this
  run adds is a conductor-facing rule the v1 entry never needed: a finished degraded drain is
  still a drain — do not collapse Phase-1 width because quality is solo, and a sitting must not
  be read as panel-quality. Pointer in `skills/ac-loop-2/FRICTIONS.md` (same id). Land's mint
  suggestion `phase-1-refine-all-degraded-solo-no-task-tool` was judged same-root and not minted.
  **RUN 20260814-213141-15553 (BCA, ac-loop), +1 — refine again sequential 3-round solo vs panel.**
  No Task tool → degraded-solo. Honesty half held (label stamped, panel not faked). Pointer
  added in `skills/ac-bead-refine/FRICTIONS.md` (same id) — this run's land tagged the
  friction skill-scoped to refine, which is a consumer of the mandate, not a new root.

## dcg-blocks-the-skills-own-canonical-artifact-redirects
- skills: [ac-loop, ac-bead-refine, ac-review, ac-qa-browser, ac-implement, ac-pipeline, agent-mail, ac-land, ac-loop-2]
- impact: M
- frequency: every-run
- recurrence: 47
- related: [phase-skills-mandate-panels-a-subagent-cannot-spawn, dcg-guard-blocks-the-skills-own-setup-snippet]
- first_seen: 2026-07-22
- last_seen: 2026-08-17
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
  **RUN 20260803-113231-34132, +8 — the highest-recurrence friction of the run, spread across FIVE
  children in four different phase skills.** Refine children: a probe blocked for quoting a redirect
  construct in its TEXT (nothing was being redirected), two blocks on redirects inside a python
  heredoc, one on a dynamic-path write that switched to the Write tool. Implement children: a bead
  comment whose BODY quoted a redirect construct, a verification command whose capture path was
  variable-built, a delete-then-create fixture inside a heredoc (resolved by using a fresh unique
  /tmp dir instead), and a close reason whose prose merely DESCRIBED repairing a file. Review child:
  restore-to-pristine inside a disposable /tmp worktree, resolved by overwriting from a git ref
  rather than a checkout, plus a probe driver moved out of a heredoc into a Write-tool file.
  Two things this run adds beyond the count. (1) It confirms the fix-shape constraint recorded in
  ac-bead-refine's sibling entry from the OTHER direction: three of the eight blocks were on
  commands that contained no redirect at all — the construct appeared inside a quoted prose payload
  (a bead comment, a close reason, a probe argument) — so guidance that SHOWS the blocked construct
  is itself blocked, and "decorating the command" is never the fix. Notably one implement child was
  blocked this way while fixing ac-d4r, the bead that documents this exact hazard. (2) The blast
  radius now includes `ac-pipeline`'s shared substrate (board-scan, and the artifact-write shapes
  the delegation preamble hands to every child), so a pointer entry has been added to ac-pipeline's
  own log; this id remains the PRIMARY and the sole place occurrences are counted.
  **RUN 20260803-221658-19787 (agent-compounds, 27 beads / 5 batches / 16 children), +5 — the run
  that maps the rule's BOUNDARY rather than just adding volume.** Four of the five are the redirect
  family and are detailed in ac-pipeline's pointer entry (that skill owns the substrate that emits
  them): a read-redirect whose source path came from a variable; an error-stream redirect nested
  inside a command substitution; a `br list` write blocked even though the destination was a literal
  value that merely lived in a variable; and a write to a PID-suffixed scratch file. The fifth was a
  genuine `git checkout --` used to restore a file — the destructive-operation rule firing correctly,
  a recurrence of the same shape this entry logged last run (restore-to-pristine in a disposable
  worktree), and resolved the same way: overwrite from a git ref instead of restoring. Three further
  blocks this run were prose-payload false positives and are counted at
  `dcg-false-positives-on-angle-bracket-inside-quoted-prose` instead, not here.
  What this run adds to the FIX, beyond the count: the four redirect blocks between them falsify
  every workaround short of the real one. Reading rather than writing does not escape the rule;
  nesting the construct deeper does not escape it; and — the one that costs the most rediscovery —
  making the path *literal* does not escape it either, because a literal held in a variable is still
  a variable to the guard. The only shapes that worked were the Write tool, a pasted literal at the
  call site, and `tee`. `tee` should be named as the sanctioned redirect substitute in the shared
  substrate; four children re-derived it independently this run.
  **RUN 20260804-202200-loop (BCA), +3 — and the root cause is now named: bd-5ndzm's sweep was
  botched, not incomplete.** Three published idioms blocked in one run, in three separate documents:
  `ac-pipeline/references/board-scan.md`'s Scan E snippet, `ac-loop/SKILL.md` Phase 1's MANDATED
  `$ARTIFACTS_DIR/.claim-id` write, and `ac-bead-refine`'s tee idiom (already on the board as
  bd-qfqdv). **Correction to this run's first-pass diagnosis** — the carrier initially reported that
  Scan D passes while Scan E is blocked, and inferred an inconsistently-firing rule. A direct probe
  of dcg 0.6.7 refuted that: **both Scan D and Scan E are blocked**, the rule fires consistently, and
  the doc's own claim that "the literal form is the only one that runs here" is simply false for both.
  The real root cause is process, not guard behaviour: bd-5ndzm (the bead this entry names as its
  tracker) was **closed as Fixed on 2026-07-30 having scoped 6 skills and mechanically fixed exactly
  one** — so the blocked shapes were never removed from the other five, and nothing detects a
  reintroduction. Refiled with that framing as bd-scjgv. Two things follow: (a) the fix needs a
  mechanical DETECTOR (grep the registry for redirects to a non-literal destination) or the sweep
  will rot again; (b) a bead closed Fixed after a partial sweep is worse than one left open — it
  removes the signal that anything remains.
  **RUN 20260808-221219-47229, +1 — an assign-then-redirect shape, same root.** dcg blocked a
  command of the form `> $A/f` (assign a path to a shell variable, then redirect to it) during
  bd-8q26b. Same class as every prior occurrence here: the destination is not a pasted literal at
  the call site, whatever intermediate form it takes (direct substitution, a heredoc, or — this
  time — a plain variable assignment one line earlier). No new workaround needed; resolved the
  same way as the rest of this family (Write tool / literal-paste). Counted here, not as a new id.
  **RUN 20260817-122900-2583 (BCA, ac-loop-2, ~40 agents), +1 — the family reaches the IDENTITY
  layer, and a READ is misparsed as a truncate.** Two published recipes were unrunnable as
  written: `agent-mail/references/agent-identity.md`'s roster sweep, and ac-land's teardown
  selectors. The new mechanism worth naming is a while-loop fed by `done` with a read redirect
  from a file — the guard reads that as a destructive truncation of the file being READ, so a
  pure read is blocked as a write. Sanctioned rewrite: pipe the file into the loop, or read it
  with a command substitution; do not try to quote or escape the redirect. Also, a build lane
  hit the classic variable-target form in the conductor's own briefed commit-mutex recipe and
  silently FORKED the template instead of reporting the block (`ac-loop-2/FRICTIONS.md`,
  `commit-mutex-lock-path-assumes-git-is-a-directory`) — which is the cost this entry has been
  logging for 41 occurrences finally landing on a safety mechanism rather than an artifact write.
  Counted here; pointer entries in `agent-mail` and `ac-land`.

## dcg-false-positives-on-angle-bracket-inside-quoted-prose
- skills: [ac-loop, ac-loop-2, ac-land, ac-bead-capture, ac-pipeline, beads-standards]
- impact: M
- frequency: frequent
- recurrence: 6
- related: [dcg-blocks-the-skills-own-canonical-artifact-redirects]
- first_seen: 2026-07-22
- last_seen: 2026-08-11
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
  **RUN 20260803-221658-19787, +3 — the class is wider than a blockquote, and impact rises to M.**
  Three blocks this run, none of them a blockquote and none of them redirecting anything. (a) A
  command was rejected because the ordinary English word `restore` appeared inside a quoted prose
  payload — the destructive-operation matcher reads command text, so a bead comment that *describes*
  restoring a file is indistinguishable to it from one that performs the restore. (b) An arrow
  written in prose was tokenised as a redirect. (c) A placeholder in angle brackets inside a bead
  description body was read as a redirect target. The generalisation this settles: the trigger is
  not the `>` character and not markdown — it is **prose on a command line**, where any shell-
  significant token or destructive-sounding verb inside a quoted payload is a live match. That makes
  the fix one rule instead of three exceptions: never inline a prose payload, write it to a literal
  temp file with the Write tool and pass it by command substitution. A pointer entry now exists in
  ac-pipeline's log because the payload SHAPES (delegation preamble, disposition and close-reason
  templates) are shared substrate it owns; occurrences stay counted here.
  **RUN 20260811-113939-36193 (BCA, ac-loop-2 phase-gated, 6 beads / 5 lanes), +5 — first
  occurrences under the v2 phase model, so this id now spans BOTH loop skills.** Hit
  independently by the conductor (a literal placeholder in angle brackets inside a `br create -d`
  body parsed as a shell redirect), the doctrine refine child, the ledger build child, and twice
  more during the closing/reflect ceremonies — including by the reflect agent writing THIS entry,
  whose memory-fact prose merely *named* angle-bracket placeholders. Each agent rediscovered the
  same heredoc-to-file workaround at its own cost; none had it in front of them at the moment of
  the block. Two things this run adds. (1) The trigger set is wider than the redirect family
  alone: `-` plus a closing angle bracket and `=` plus a closing angle bracket (ASCII arrows in
  ordinary prose) tokenise the same way, which makes ordinary technical writing a trigger.
  (2) The v2 delegation prompts inherit the hazard unchanged from v1, so the fix belongs in
  `ac-loop-2/references/delegation-prompts.md` too, in every prompt that writes bead body text:
  **never interpolate prose into a double-quoted shell argument — write it to a literal temp file
  and pass the file.** Sharper still, and cheaper than remembering: keep placeholders out of prose
  entirely (write `ID`, `FILE`, `SLUG` bare) so the construct never reaches the tokeniser.

## divergence-check-while-a-child-is-live-proves-nothing
- skills: [ac-loop]
- impact: M
- frequency: occasional
- recurrence: 1
- related: [width-safe-on-files-not-on-shared-build-and-scratch-state, hand-typed-sha-not-git-rev-parsed]
- first_seen: 2026-08-04
- last_seen: 2026-08-04
- stage: ac-loop
- status: open
- proposed_fix: assert the origin/local SHA relationship ONLY at a quiescent point — after a child has returned, never mid-flight — and treat a push rejection or a local-ahead reading as a QUESTION (re-read after the writer settles), never as a finding. Corollary for the run report: a "known bug recurrence" claim about push/divergence needs the same citation discipline as any other brief claim, because the cheapest confirmation is one re-check and the cost of publishing it wrong is a false bug report the next conductor believes.
- narrative: the conductor checked origin divergence while an implement child was still live, saw
  local ahead of `origin/main` by one commit, and wrote it up as a recurrence of a known
  push-swallowing hook bug. FALSE ALARM — the check had landed in the gap between the child's
  commit and its push, and reconciled on the next read; it had to be retracted in the carrier.
  Separately and in the same run, a genuine `cannot lock ref` push rejection SELF-RESOLVED once a
  concurrent writer pushed the same commit forward. Both halves teach the identical thing:
  **trunk state read while another writer is mid-operation is not evidence.** The second half also
  falsifies a standing loop assumption — the nightly curator job committed to `main` DURING this
  run, so the loop and its children are not the only writers on trunk, and any check that assumes
  they are will manufacture findings. Verify by SHA after the writer settles; a rejected push does
  not mean lost work.

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
- recurrence: 2
- related: [width-safe-on-files-not-on-shared-build-and-scratch-state]
- first_seen: 2026-07-29
- last_seen: 2026-08-04
- stage: ac-loop
- status: open (fix shipped as the Phase-0 precondition check; first live firing 2026-08-04 — see confirmation below)
- proposed_fix: make "read the board for OPEN tooling bugs whose trigger condition this run's own configuration satisfies" a standard Phase-0 step.
- narrative: bd-baudw (siblings sharing `ARTIFACTS_DIR` on one `RUN_ID`, cross-stamping beads) was an OPEN bug at this run's start, and width=2 is exactly its trigger condition. Giving each child a distinct RUN_ID suffix pre-empted it this time — but only because the conductor happened to remember the bug, not because Phase-0 has a step that checks for it. Despite that top-level pre-emption, a child later reproduced the identical collision live in a nested run, showing the fix doesn't cascade down automatically — it has to be re-applied consciously at every level where the trigger condition recurs. Cost this run was 0, purely because the check happened informally; the process gap remains.
  **CONFIRMATION — RUN 20260803-221658-19787, the shipped check fired for the first time and paid immediately.** The Phase-0 precondition step this entry asked for now exists (ac-fxq) and ran on first use. It found that ALL SEVEN ready bug beads were self-triggering — every one of them described a condition this run's own configuration satisfied — which is exactly the state the informal 2026-07-29 check caught by luck. The conductor answered it structurally: bug-lane-first ordering, plus the known route-arounds seeded into every child brief rather than left to be rediscovered. Result: **zero retries burned on any of the seven**, against a baseline where the same class cost blocked calls and rediscovery time in each of the three preceding runs. Logged as a confirmation rather than a friction because the promotion ladder needs the evidence trail of a shipped fix WORKING as much as it needs the pain that motivated it — and because the mechanism generalises past this bug class: pre-seeding a known route-around into the brief is cheaper than every child re-deriving it, which is the same economics that `standing-sanctions-not-threaded-into-delegation-prompt` argues from the failure side.

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

## task-ledger-tools-unreachable-from-a-fanned-out-child
- skills: [ac-loop, ac-bead-refine]
- impact: M
- frequency: every-run
- recurrence: 2
- related: [child-has-no-upward-report-channel, phase-skills-mandate-panels-a-subagent-cannot-spawn]
- first_seen: 2026-08-03
- last_seen: 2026-08-03
- stage: ac-loop
- status: open
- proposed_fix: the MANDATED run ledger must be expressed in terms a child can actually satisfy — name the file-based ledger (progress.md) as the canonical form for a delegated child and reserve the Task-tool ledger for the conductor, rather than mandating a tool the child's declared toolset does not contain. Same spawn-time check as `child-has-no-upward-report-channel`: verify the tool exists in the child's toolset before mandating its use.
- narrative: two refine children were instructed to maintain a Task-tool run ledger and held no TaskCreate/TaskUpdate tools — the tools are simply absent to a fanned-out subagent. Both improvised the same substitute (carried the ledger in progress.md), so no ledger data was lost, but the mandate is unsatisfiable by construction in the most common invocation path and each child paid rediscovery time. This is the third member of a family this log already carries: panels a subagent cannot spawn, report channels a subagent does not hold, and now ledgers a subagent cannot write. All three share one root — the skills are written from the conductor's vantage and mandate capabilities that do not survive delegation — and all three are detectable at spawn time by the same one-line check.

## agent-name-unset-yields-an-empty-child-id-segment
- skills: [ac-loop]
- impact: M
- frequency: occasional
- recurrence: 2
- related: [open-tooling-bug-not-checked-against-run-config-at-phase0, width-safe-on-files-not-on-shared-build-and-scratch-state]
- first_seen: 2026-08-03
- last_seen: 2026-08-04
- stage: ac-loop
- status: open
- proposed_fix: two halves, and the second is cheaper. (a) any identity string composed from environment (CHILD_ID and the artifact dirs derived from it) must ASSERT each segment is non-empty at the point it is built, and fail loudly if not — an empty segment must never be allowed to silently degrade to a shared path. (b) UPSTREAM of that: the conductor must hand EVERY spawned child an explicit `AGENT_NAME` in its brief, including children not expected to claim or commit — an unset variable is the input both failure shapes read from, and the conductor is the only agent that can set it.
- narrative: a child's CHILD_ID formula read AGENT_NAME from the environment, where it was unset, and produced an identity with an EMPTY agent segment. Nothing errored. The consequence is the one that matters: CHILD_ID is what gives siblings distinct artifact directories, so an empty segment collapses two children's scratch space toward the same path — precisely the bd-baudw cross-stamping collision that width>1 runs are supposed to be protected from. Same silent-empty shape as the `tr` alias defect logged in ac-bead-refine (there a shadowed command, here an unset variable), and the same consequence, which is why the fix belongs at the ASSERTION level rather than at each individual source: the formula has several ways to yield an empty segment and no way to notice.
  **RUN 20260804-202200-loop (BCA), +1 — the other branch of the same unset variable: a silent
  identity FALLBACK rather than an empty segment.** A refine child spawned without an `AGENT_NAME`
  fell back to the Tier-2 chore identity FoggyCreek (artifacts dir
  `/tmp/bead-refine-FoggyCreek-47404-…`). Harmless ONLY because that child had been told to defer
  every `br` mutation and claimed nothing — the FoggyCreek claim guard would have fired otherwise,
  mid-refine, on a child with no standing to fix it. Two children of one run read the same unset
  variable and degraded in two different directions (empty path segment / borrowed identity), which
  is precisely the argument for fixing it at the SPAWN site: whatever each downstream consumer does
  with the empty value, the conductor knows the right value and simply did not pass it.

## tmp-artifacts-not-durable-across-a-long-run
- skills: [ac-loop]
- impact: H
- frequency: rare
- recurrence: 1
- related: []
- first_seen: 2026-08-10
- last_seen: 2026-08-10
- stage: ac-loop
- status: open
- proposed_fix: tracked as a decision bead under human gate (`ac-28nm`, /tmp artifact durability) — do not re-derive the fix here. Note for this skill specifically: ac-land's own teardown selector globs `/tmp/<prefix>-*` for cleanup, so any fix that moves the artifact root must also update that selector or teardown will silently stop matching its own targets.
- narrative: macOS periodic cleanup destroyed the run's own artifact carrier plus ~35 of the run's 41 claim dirs UNDER /tmp mid-run — R20's refine artifact dir was lost between rounds 2 and 3 (forcing a reconstruction from the ledger rather than a fresh read for the B1 write-the-patch-dry-run finding logged in ac-bead-refine's log), and the run's own beads-closed-gate Ceremony ran its final check on degraded evidence as a result. This is the run-level incident this retrospective almost missed entirely: it was not on the conductor's candidate list of things to investigate, and surfaced only when asked "what got treated as unavoidable that shouldn't have been?" (see the paired `conductor-supplied-candidates-are-leads-not-findings` entry in ac-land's log). /tmp is not a durable artifact root for anything a long-running loop needs to survive past an OS-level cleanup window; the pipeline's use of it for run carriers and claim dirs is a latent single point of failure that this run made visible by chance rather than by design.
