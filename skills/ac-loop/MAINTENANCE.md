---
skill: ac-loop
archetype: orchestrator
last_pass: 2026-08-06 (correctness pass)
spine_lines: 897 / target ≤500 orch (legitimately long — enforcement spine; remaining trim is bounded)
---

# ac-loop — maintenance ledger

## Health
Over the line target but an orchestrator (length is largely enforcement). Diet passes
done (1086 → 949 → 956 (interim additions) → 948 → 916 → 897, net −189 from baseline). Inbox clear of
actionable shape items; 2 behavior beads open — `br list -l skill:ac-loop` (ac-uip stale
version-bump delegation, ac-plv double-review). Near-dup scan flags `ac-loop ~ ac-implement`
(283 shingles) — that overlap is the delegation prompts, which were assessed and deliberately
KEPT inline (see Cut-log). Contested pipelining block RESOLVED via ac-znk.3 Stage-1: hookpoints
wired live, guard-rails extracted (see Cut-log 2026-08-03).

## Inbox — shape signal awaiting triage
<!-- Behavior-changing signal does NOT go here — it goes to a skill:ac-loop skill-improvement bead. -->
(empty — both pass-1 items resolved; see Cut-log for the dedup and the delegation-prompt keep decision)

## Holding pen — content pulled from SKILL.md, disposition undecided
(none — both extractions were clean verbatim moves, nothing parked)

## Cut-log — append-only audit trail (feeds the churn detector)
- [2026-08-06] CORRECTNESS PASS (no diet). Completed the same-day review cut, which had left
  live text: 5 ceremony chains still read `verify → review → close` (Rule 0 drain, Phase 1
  step 2, the `post-merge` window definition, Phase 2 step 2, Efficiency § Parallelism) and
  `references/delegation-prompts.md`'s Implement prompt still told every child the loop
  advances to review. All 5 + the prompt now read `verify → close`. `review-mark` sites were
  CHECKED and KEPT — `.claude/reviews/batch/` is the verification-gate diff anchor and
  outlives ac-review's retirement. Fixed the cross-ref the same cut broke: Phase 2 step 4
  pointed at "Phase 1 step 6" (the Slack notify) instead of step 4 (the beads-closed gate).
  ADDED to `references/delegation-prompts.md` § Brief-claim rule: compose-time citation
  requirement (a fact needs a commit SHA or `br show` verdict; an in-flight claim is not
  citable) + the verbatim child-facing pointer/escape clause — ships the ac-loop half of
  friction `delegation-brief-restates-bead-preconditions` (impact H, every-run). The
  ac-pipeline half (same rule in `delegation-contract.md`) stays open in that skill's log.
  SKILL.md 898 → 897; growth is references-only.
- [2026-08-06] CUT the review step from both phases (steps 4+5 → gone, tail renumbered), the
  Review prompt from `references/delegation-prompts.md`, and every `ac-review` reference. C2
  rebound from a panel verdict to the verification gate / red CI leg. No holding pen: the
  content is dead by construction, not deferred — `ac-review` is being retired and `ac-hygiene`
  is the single quality lane. −8 SKILL.md, −13 delegation-prompts.
- [2026-07-20] EXTRACTED § Ceremony batching pool mechanics (state store, flock RMW, fire
  opportunities, selected-set/drain policy, report-ack, failure re-merge, risk override, bug-lane,
  guard-rail, §5 fixtures) → `ac-pipeline/references/ceremony-batching-pool.md` (shared with ac-batch-close). Kept
  intro + hookpoints + engagement pointer inline. −109 lines (1086 → 977). Repointed ac-batch-close
  L538 to `ac-pipeline/references/ceremony-batching-pool.md § Drain sequence`. `--diff` clean.
- [2026-07-20] EXTRACTED beads-closed-gate flag rationale (ac-514 / ac-0wi / ac-0i1 / bd-w504y — the
  `--beads` / `--progress` / repeated-`--progress` / union-of-identities reasoning) duplicated across
  Phase 1 & Phase 2 step 6 → `references/beads-closed-gate-invocation.md`. Kept the bash command +
  exit-code decisions + `post-merge`/nudge enforcement **verbatim inline at both sites** (enforcement,
  legit repetition). −28 lines net (977 → 949). NOTE: first attempt reworded the inline nudge text and
  `--diff` correctly FLAGGED it as enforcement-removed-without-relocation; corrected to verbatim-inline,
  `--diff` then clean. The guard earned its keep on the first live dedup.
- [2026-07-20] ASSESSED, DELIBERATELY KEPT INLINE: the ac-implement / ac-review / ac-batch-close
  child-delegation prompts (repeated Phase 1 & Phase 2). Orchestrator-trap case AND they carry the
  `CLAIM_ASSIGNEE` enforcement that makes the beads-closed-gate see delegate claims — inline-at-use is
  strictly stronger than a paste-from-reference pointer (token-economics hierarchy). Not extracted; the
  Phase-1/Phase-2 copies differ by target/context so are not pure sediment. This is a KEEP, not a defer.
- [2026-07-20, W3.2 pilot] DELETED HISTORY: the Rule 0 "(Historical — superseded 2026-07-12,
  trunk-direct migration bd-u2lo1: the bug lane formerly minted a `bugs/batch-<YYYYMMDD>-<n>`
  branch...)" blockquote. Superseding change: commit `3016b40` ("docs(ac-loop): migrate Bug Lane +
  stale refs to trunk-direct [bd-smrcb, bd-gojie]", 2026-07-12) — itself the commit that added this
  note as "retained, reversible per Craig" pending a post-migration reassessment (bd-smrcb). Both
  bd-smrcb and bd-u2lo1 no longer resolve in `br show` (closed/purged) and 8 days have passed with
  no reversal signal — git (3016b40) is the archive; the note added no operative behavior beyond
  what the paragraph above it already states (claim-at-selection, direct-to-main, one ceremony).
  −3 lines.
- [2026-07-20, W3.2 pilot] COMPRESSED PERSUASION (rule kept, incident specifics dropped — the causal
  "why" already stood alone in each surrounding sentence): (1) `br ready --limit 20` truncation
  example — dropped "23 refined maintenance beads … 2026-07-08" (rule: "silently stranded ready work
  and derailed a run before"); (2) Rule 0 batch-ceremony bullet — dropped "(the 2026-07-10 all-nighter
  post-mortem: … ~3h in CI for ~1h of fixes)" (rule: "a 9-bug drain costs one close ceremony, not
  nine" already carries the point) and the doc-history aside "(this replaces the old 'never bundle
  unrelated bugs' rationale)"; (3) CI-runner-is-this-Mac rule — dropped "(a ~21-min suite became
  ~50 min at load-68)", pointed the numbers at the already-cited memory fact
  `bca-ci-and-ios-build-ops` instead of duplicating them inline. −7 lines net.
- [2026-07-20, W3.2 pilot] DEDUPED (duplicate content, twin survives): the `ac-land` "not per-wave"
  historical aside appeared twice with the same fact ("(it was wrongly in the per-wave path
  before)" at ON EXIT; "per-wave landing was the leftover the 'land runs LAST' reconciliation
  retired" at Phase 1 step 9) — both are doc-history commentary on the same superseded design, no
  operative content beyond the rule itself. Cut both asides, kept the rule ("`ac-land` does NOT run
  per-wave — it runs ONCE at loop exit") at both sites unchanged. −3 lines.
- [2026-07-20, W3.2 pilot] DEDUPED (duplicate content, twin survives): Phase 0's `depends-on:`
  preview restated the epic-id-deprecated/ERRORS/skip-admission/advisory-nudge/never-hard-stop
  mechanics that Phase 2 § Plan-admission gate (the actual enforcement point) already states in
  full. Trimmed Phase 0's copy to the plain-language convention + a forward pointer to Phase 2;
  Phase 2's full Complete(A) + ERROR-handling definition is untouched and remains the sole
  authoritative copy. −6 lines.
- [2026-07-20, W3.2 pilot] NOT TOUCHED per explicit scope: § Phase pipelining permissions
  (bd-chd5p.3 / Item 2). Analyzed only — grep evidence + recommendation in the W3.2 pilot report
  (`ac-2wg.2`); no edit made. Left in the holding-pen-adjacent "flagged for Craig's gate" state
  noted in Health above, not the Cut-log proper (nothing was cut).
- Net this pass: 956 → 948 (−8 lines; the depends-on dedup landed a slightly larger prose block
  than the original despite the line-count drop, because the compressed forward-pointer replaced
  several one-clause-per-line bullets with denser prose — verified by `--diff`/conservation, no
  heading removed, no enforcement lost).
- [2026-08-03, ac-znk.3 Stage-1] EXTRACTED (rule stays core, procedure → references): file-cluster
  density command + grep-truncation gotcha → `ac-pipeline/references/board-scan.md` § File-cluster
  density; the batching rule (densest first, disjoint clusters per child) kept in core. Evidence
  tails cut (bd-ctlqg narrative — grepped nowhere else; "20 of 94" measurement). −26 lines.
- [2026-08-03, ac-znk.3 Stage-1] EXTRACTED: pipelining GUARD-RAILs (ledger commit mixed-state +
  beads-DB mutation deferral) → `ac-pipeline/references/ceremony-batching-pool.md`
  § Refine-during-ceremony guard-rails (shared ceremony-concurrency canon). Permissions +
  hookpoint tables + SCOPE prohibition stay core (the conductor's binding *when*).
- [2026-08-03, ac-znk.3 Stage-1] CUT (dedup): "MIN_ROUNDS untouched" subsection (restated the
  block intro); bd-baudw enforcement blockquote compressed to 4 lines + run-id.md pointer (full
  canon lives there); "~4h reclaim" justification tail; WIDTH-cap not-restated-here line.
  Net Stage-1: 948 → 916 (−32 lines).
