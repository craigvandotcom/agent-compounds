---
skill: ac-bead-refine
created: 2026-07-22
last_pass: 2026-07-22
entries: 2
---

# ac-bead-refine — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

## filed-beads-carry-drifted-anchors-and-false-premises
- skills: [ac-bead-refine]
- impact: M
- frequency: every-run
- recurrence: 1
- related: []
- first_seen: 2026-07-22
- last_seen: 2026-07-22
- stage: ac-bead-refine
- status: open
- proposed_fix: keep (and make explicit in the workflow) the rule that EVERY cited `file:line` anchor and every quoted artifact in a bead must be re-verified against HEAD during refine, and that a falsified premise closes or rewrites the bead rather than being smoothed over. This is not overhead — it is the highest-yield thing refine does, and it paid off on every batch of this run.
- narrative: filed beads carried drifted `file:line` refs at a steady rate of ~3 per batch, every batch (RUN 20260722-085844-39967, 27 beads refined across 3 batches). Several carried outright FALSE premises, not just stale line numbers: bd-iahbm's cited test asserted the OPPOSITE of the claimed behavior; bd-nnzjv quoted a 500 response body that did not exist; bd-vyyaw requested a field the type does not have; bd-zz6ah claimed "all 8" when it was 4 of 8; bd-0q96x said "62 commits" when it was 145. Every one of these would have become wasted or wrong implementation had refine trusted the filing. Downstream sibling fact: `refined-spec-staleness-query-ground-truth-first` (the same class of drift, observed at implement time instead).

## acceptance-criteria-that-cannot-fail
- skills: [ac-bead-refine]
- impact: M
- frequency: occasional
- recurrence: 1
- related: [filed-beads-carry-drifted-anchors-and-false-premises]
- first_seen: 2026-07-22
- last_seen: 2026-07-22
- stage: ac-bead-refine
- status: open
- proposed_fix: add a refine lens that asks of every acceptance criterion "can this check actually FAIL, and does it fail for the RIGHT reason?" Specifically flag (a) grep/pattern-shaped ACs, which encode intent but no structural constraint and both over-match and under-specify; and (b) any AC asserting a numeric DOM property without first establishing that the property is meaningful on the element type in question. Require a bite-proof (demonstrate the check RED) for any AC that is the sole evidence for a bead.
- narrative: two ACs this run specified checks that were vacuously true. bd-ket5c's grep-shaped AC over-matched an unrelated component AND failed to express the real structural constraint (that 212 of 278 DB-only families REQUIRE the fallback be removed) — only reading the call sites plus running a coverage query surfaced it. bd-145wb's AC prescribed `scrollWidth <= clientWidth` on an anchor element, but both are 0 on non-replaced inline elements, so the assertion passes no matter what the page does. A refined AC that cannot fail is worse than no AC: it launders an unverified change as verified.
