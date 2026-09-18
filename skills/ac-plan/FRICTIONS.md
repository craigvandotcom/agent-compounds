---
skill: ac-plan
created: 2026-09-18
last_pass: never
entries: 8
---

# ac-plan — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see friction-capture.md
     § Deduplication) — do not append a duplicate root friction under a new id. -->

## diet-fixpoint-unbounded-with-stateless-readers
- skills: [ac-plan]
- impact: L
- frequency: occasional
- perceptibility: silent
- recurrence: 1
- related: [diet-repeated-question-is-a-cut, seams-fixpoint-never-stamps-on-accumulator]
- first_seen: 2026-09-18
- last_seen: 2026-09-18
- stage: ac-plan
- status: open
- proposed_fix: bound the diet (about eight rounds) and stop on two consecutive rounds with no
  mechanism change OR the bound; hand each fresh reader a one-paragraph list of cuts already
  refused, so a stateless reader cannot re-open them.
- narrative: step 7 runs "to fixpoint: until a round proposes no change to a mechanism". On
  the bead-record seams plan that took 17 rounds (~100k subagent tokens and ~5 min each).
  Mechanism cuts continued through round 16 and four decisions flipped between rounds (the
  gate's ownership check, the empty-roster verdict, the ruling tap in the commit lane, a
  token rename) because each reader is stateless and can always find one more thing. The
  prior run (2026-09-15) settled in 6, so the rule reads as bounded when it is not.

## diet-repeated-question-is-a-cut
- skills: [ac-plan]
- impact: M
- frequency: occasional
- perceptibility: misleading
- recurrence: 1
- related: [diet-fixpoint-unbounded-with-stateless-readers]
- first_seen: 2026-09-18
- last_seen: 2026-09-18
- stage: ac-plan
- status: open
- proposed_fix: state in step 7 that the floor protects the FINDING, never the conductor's
  remedy for it; a question returned by two consecutive fresh readers is adjudicated as a cut.
- narrative: the floor says a reader never cuts a refusal, a fail-closed check or a confirmed
  finding, so doubts about them arrive as QUESTIONS. The conductor read that as protection for
  its own mechanism: the check-36 token edit came back seven rounds running, the fence lint
  four, the read helper three, before each was dropped or moved. Every one of those rounds was
  paid for a cut the plan eventually took.

## diet-doubles-as-correctness-review
- skills: [ac-plan, ac-polish]
- impact: M
- frequency: occasional
- perceptibility: silent
- recurrence: 1
- related: [diet-fixpoint-unbounded-with-stateless-readers]
- first_seen: 2026-09-18
- last_seen: 2026-09-18
- stage: ac-plan
- status: open
- proposed_fix: decide which stage owns claim-checking. Either the diet reader's prompt stays
  fat-only and `ac-polish plan` owns correctness, or step 7 says the diet verifies the claims
  it reads and polish is told which sections were already code-checked.
- narrative: the one-question diet readers also found defects the plan would have shipped
  into beads: a jq guard that could never fire, a false premise that the disposition flag
  skips the gate's probe legs, an ownership leg that would refuse every ruling tap, a verb
  that bypassed the causal gate, a cutover date that failed the criterion's own HEAD run.
  Valuable, but it is `ac-polish plan`'s job, so the two stages now overlap and neither knows
  what the other already checked.

## seams-reader-template-names-its-own-blanks
- skills: [ac-plan]
- impact: S
- frequency: every-run
- perceptibility: misleading
- recurrence: 1
- related: []
- first_seen: 2026-09-18
- last_seen: 2026-09-18
- stage: ac-plan
- status: open
- proposed_fix: mark the four substitution slots in `references/plan-seams-reader.md` with a
  token the prose never uses (or fence them in one block), so a conductor's replace-all
  fills the slots and leaves the explanatory mentions alone.
- narrative: the reader prompt names `<OBJECT>`, `<DELIVERABLES>`, `<FILES>` and `<REPORT>` in
  its own prose ("Substitute `<OBJECT>` (…)", "## Building `<FILES>`"). A replace-all pastes
  the whole Deliverables block and the file list into every mention. Three of twenty-two
  readers reported the prompt as garbled or duplicated; all still resolved the real values,
  so nothing failed loudly.

## seams-scan-test-globs-undefined
- skills: [ac-plan]
- impact: M
- frequency: every-run
- perceptibility: silent
- recurrence: 1
- related: [seams-reader-template-names-its-own-blanks]
- first_seen: 2026-09-18
- last_seen: 2026-09-18
- stage: ac-plan
- status: open
- proposed_fix: give step 4 one derivation for the TEST half, beside `touchers.sh derive` for
  the SOURCE half: which roots are searched (hooks/ included), and match on `<dir>/<stem>`
  when the stem is generic (`SKILL`).
- narrative: step 4 says "plus the repo's test globs" and the reader prompt says the conductor
  passes them in, but no tool derives the TEST list. The conductor improvised a stem grep: a
  bare `SKILL` stem matched 39 unrelated files, `hooks/` was never searched so a guard's own
  suite was missed, and one reader flagged that its given list omitted the test its
  deliverable named. Each miss surfaces only if a reader happens to notice.

## approve-path-regex-reads-mentions-as-deliverables
- skills: [ac-plan]
- impact: S
- frequency: frequent
- perceptibility: loud
- recurrence: 1
- related: [plan-approve-prefix-matches-seams-header]
- first_seen: 2026-09-18
- last_seen: 2026-09-18
- stage: ac-plan
- status: open
- proposed_fix: have `plan-approve.sh`'s seams-incomplete check read only the bolded or
  first-mentioned artifact paths of each Deliverables bullet, or accept an explicit
  `(cited, not delivered)` marker.
- narrative: the seams-incomplete check extracts every path-shaped token in `## Deliverables`
  and demands a Seams row for each. A deliverable that cites a fact by path — a misspelled
  store name it corrects, the lint runner, a canon file, an env-var value — is refused as an
  uncovered deliverable. Five rewordings were needed on one plan; the refusal is loud, the
  cost is prose bent around a regex.

## plan-approve-prefix-matches-seams-header
- skills: [ac-plan, ac-polish]
- impact: M
- frequency: occasional
- perceptibility: silent
- recurrence: 1
- related: [approve-path-regex-reads-mentions-as-deliverables]
- first_seen: 2026-09-18
- last_seen: 2026-09-18
- stage: ac-plan
- status: promoted
- proposed_fix: anchor the `## Seams` match in `skills/_tools/plan-approve.sh` (both the
  no-seams refusal and the section reader's Seams calls). Promoted: deliverable D9 of
  `_plans/2026-09-18-seams-bead-lifecycle.md`.
- narrative: the approval script matches section headers by prefix, and a seams-mode hand-off
  carries three generated sections titled `## Seams — …`. Run on that file, the script would
  digest reader evidence as the plan's own Seams table and pass the seams-incomplete check on
  it. Worked around by renaming the generated headers in the plan copy.

## deliverable-set-moves-after-the-seams-scan
- skills: [ac-plan]
- impact: M
- frequency: occasional
- perceptibility: silent
- recurrence: 1
- related: [diet-fixpoint-unbounded-with-stateless-readers]
- first_seen: 2026-09-18
- last_seen: 2026-09-18
- stage: ac-plan
- status: open
- proposed_fix: say in step 7 that a cut which makes a new file a deliverable owes that file a
  seams reader before the next round, and that Seams rows quoting a retired draft carry a
  "Deliverables binds" note — or regenerate the rows from the final text.
- narrative: step 4 scans the DRAFTED deliverable list, then steps 6–8 change it. Five objects
  became deliverables after the scan (a lint check, a skill spine, a canon template, the
  capture guard, the approval script), each needing a late reader, and two of those late
  readers found P0 claims. Meanwhile the Seams rows kept quoting the draft the first readers
  saw, so three test rows contradicted the final Deliverables until a diet reader caught it.

## see seams-reader-stance-cannot-write-report in ac-polish
- pointer: primary entry lives in `skills/ac-polish/FRICTIONS.md`; not re-counted here.
- local manifestation: `references/plan-seams-reader.md` also says "Write the report to
  `<REPORT>`" and step 4 spawns read-only readers; three of twenty-two declined to write, so
  the conductor transcribed their hand-back into the report path by hand.
