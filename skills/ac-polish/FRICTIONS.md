---
skill: ac-polish
created: 2026-09-02
last_pass: 2026-09-02
entries: 5
---

# ac-polish — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     near-duplicate; bump recurrence and last_seen on the existing entry instead. -->

## seams-fixpoint-never-stamps-on-accumulator
- skills: [ac-polish]
- impact: L
- frequency: every-run
- perceptibility: misleading
- recurrence: 1
- related: []
- first_seen: 2026-09-02
- last_seen: 2026-09-02
- stage: manual
- status: promoted
- proposed_fix: discovery ends after two consecutive rounds with no new candidate; consensus by
  given-the-row verifiers, not blind rediscovery; Declined in a sidecar outside the digest;
  artifact in an rg-ignored state dir; one final blind round decides the stamp; unstamped
  hand-off is the normal exit. Landed in workflows/seams.md and references/seams-checklist.md.
- narrative: a 9-round seams run on one target never stamped. The artifact is an accumulator
  (append-only Declined, never-dropped Seen once), so "empty diff" required three
  self-scoped readers to append nothing at all. Rounds 1–3 found 11 seams; rounds 4–9 found
  2 and spent their budget re-finding earlier singletons for consensus. Half the readers'
  repo-wide `rg` surfaced the plan under `_plans/`, weakening every later "independent" hit.
  Checklist question 3 licensed an open-ended class of consistent-today shapes that readers
  flipped between Declined and Seen once every round.

## bead-mode-receipt-lands-on-epic-stamper-reads-children
- skills: [ac-polish]
- impact: L
- frequency: every-run
- perceptibility: loud
- recurrence: 1
- related: []
- first_seen: 2026-09-02
- last_seen: 2026-09-02
- stage: manual
- status: open
- proposed_fix: in bead mode, polish-fixpoint.sh fans the receipt comment out to every
  `<!-- BEAD:id -->` in the artifact, not only to --target; add the case to
  polish-fixpoint.test.sh. Until then the orchestrator copies `<STATE>/receipt.txt` to each
  child with `br comments add <id> -f` before the restamp sweep.
- narrative: bead mode runs per-epic and the gate writes its POLISH-FIXPOINT receipt to the
  --target epic only. stamp-refined.sh reads the receipt from each family-origin bead's own
  comments, so the writeback's restamp sweep refused all 15 children of a stamped epic with
  "no conforming fixpoint receipt". The two tools disagree on where the receipt lives.

## seams-report-path-contaminates-every-reader
- skills: [ac-polish]
- impact: M
- frequency: every-run
- perceptibility: misleading
- recurrence: 2
- related: [seams-fixpoint-never-stamps-on-accumulator]
- first_seen: 2026-09-02
- last_seen: 2026-09-02
- stage: manual
- status: open
- proposed_fix: bind REPORT to a path outside the repo (the job tmp dir) and have the
  orchestrator copy reports into the state dir after each round; or let the reader answer
  "saw the state dir, did not open plan.md" and have seams-merge count that as clean.
- narrative: seams run on "ingredients in food entries" (2026-09-02): all 6 readers across
  rounds 1-2 answered ARTIFACT SEEN: yes because the REPORT path they were handed sits
  beside plan.md in the state dir; the .ignore file stops rg but not the reader noticing
  the file when it writes its report. Every hit is therefore non-counting, no row can reach
  Confirmed through blind consensus, and the whole post-stamp burden moves to verifiers.
  Recurred on "keyboard text input" (2026-09-02): 11 of 12 readers across 4 rounds flagged
  themselves from a bare `ls .claude/polish/` alone (none opened plan.md); the one reader
  that skipped the listing was the only counting hit, and all 10 rows reached Confirmed
  only via 20/20 verifier confirmations.

## seams-merge-location-key-swallowed-distinct-seams
- skills: [ac-polish]
- impact: L
- frequency: every-run
- perceptibility: silent
- recurrence: 1
- related: [seams-fixpoint-never-stamps-on-accumulator]
- first_seen: 2026-09-02
- last_seen: 2026-09-02
- stage: manual
- status: promoted
- proposed_fix: landed in scripts/seams-merge.py with two harness cases: (1) a finding that
  matches a decline-only row now takes over the row's text and class and counts as new;
  (2) two rows match on half of the LARGER file set, not the smaller.
- narrative: same run, round 2. A decline-only row keyed on a decline's command paths absorbed
  a real finding, so the artifact carried a candidate with the decline's prose and a blank
  class. Separately, a 2-file candidate matched every finding that cited one of its files,
  so a seam two readers found independently (resolutionState unprotected by the Save merge)
  had no row of its own. The polish gate also STAMPED once against an artifact the merge had
  refused (NOT-GATED on a 5-cell row) because the orchestrator ran the gate anyway; the
  stamp was rolled back and both rounds replayed from the immutable reports.

## seams-reader-tooling-reformats-repo-test-file
- skills: [ac-polish]
- impact: L
- frequency: every-run
- perceptibility: silent
- recurrence: 2
- related: [seams-report-path-contaminates-every-reader]
- first_seen: 2026-09-02
- last_seen: 2026-09-02
- stage: manual
- status: open
- proposed_fix: tell readers in seams-reader-prompt.md not to run test runners or formatters,
  or have the orchestrator diff the tree after each round and revert formatting-only noise.
- narrative: twice in one seams run a reader left a formatting-only reflow of
  __tests__/unit/compound-expansion-gate.test.ts in the working tree (a vitest or prettier
  invocation). No semantic change; the orchestrator stashed it each time.

