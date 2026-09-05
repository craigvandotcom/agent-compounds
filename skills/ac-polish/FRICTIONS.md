---
skill: ac-polish
created: 2026-09-02
last_pass: 2026-09-05
entries: 15
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
- recurrence: 2
- related: [seams-fixpoint-never-stamps-on-accumulator]
- first_seen: 2026-09-02
- last_seen: 2026-09-03
- stage: manual
- status: promoted
- proposed_fix: landed in scripts/seams-merge.py with two harness cases: (1) a finding that
  matches a decline-only row now takes over the row's text and class and counts as new;
  (2) two rows match on half of the LARGER file set, not the smaller. Recurrence confirms
  the other half of the fix is necessary, not optional: chain merge+gate in one wrapper
  that refuses to gate a non-zero-exit merge.
- narrative: same run, round 2. A decline-only row keyed on a decline's command paths absorbed
  a real finding, so the artifact carried a candidate with the decline's prose and a blank
  class. Separately, a 2-file candidate matched every finding that cited one of its files,
  so a seam two readers found independently (resolutionState unprotected by the Save merge)
  had no row of its own. The polish gate also STAMPED once against an artifact the merge had
  refused (NOT-GATED on a 5-cell row) because the orchestrator ran the gate anyway; the
  stamp was rolled back and both rounds replayed from the immutable reports.
  Recurred 2026-09-03: the orchestrator ran polish-fixpoint.sh immediately after a merge that
  had refused (NOT-GATED on a malformed row), producing a premature gate record that had to
  be rolled back by hand — the same failure mode, unfixed since first_seen.

## blind-reader-report-strict-parse-failures
- skills: [ac-polish]
- impact: M
- frequency: frequent
- perceptibility: loud
- recurrence: 1
- related: []
- first_seen: 2026-09-03
- last_seen: 2026-09-03
- stage: manual
- status: open
- proposed_fix: replace the strict markdown-table cell parse with a per-cell labelled block
  format, or add a self-lint the reader runs against its own report file before finishing.
- narrative: blind-reader reports failed the strict table-cell parse in roughly 30% of one
  run (9 of 30 reader reports, 2 of 8 verifier reports) — readers fused the seam/locations/
  what-breaks-silently columns into one cell, or left a regex pipe unescaped in a DECLINED
  row. Each failure cost a resume-repair round-trip to the still-running subagent. The
  "count the pipes" instruction in the reader prompt is not sufficient.

## seams-mode-no-convergence-on-domain-sized-target
- skills: [ac-polish]
- impact: L
- frequency: occasional
- perceptibility: misleading
- recurrence: 2
- related: [seams-fixpoint-never-stamps-on-accumulator]
- first_seen: 2026-09-03
- last_seen: 2026-09-05
- stage: manual
- status: open
- proposed_fix: seams mode fits one component; for a domain-sized target the honest normal
  exit is verify-and-hand-off UNSTAMPED, not pushing for a stamp.
- narrative: seams mode's auto-stop rule needs two consecutive rounds with no new rows. On a
  domain-sized target (an orchestrator + an RPC + three caches + their tests), new
  "unasserted" rows kept arriving every round (new-per-round: 3,3,2,3,1,1,1,3,3,2), so the
  gate never fired and the orchestrator had to stop by judgment at round 10.
- recurrence_2 (2026-09-05, `canonical_ingredients.slug`, aim row 1, score 2234): new edges per
  round 97 · 55 · 43 · 58 — non-monotonic at round 4, stopped by judgment, 253 edges, 13
  cross-lens. The target WAS one column; the datum is a slug string copied into eight other
  columns across six tables (`ingredient_aliases.alias_slug`, `families.slug`,
  `personal_zones.ingredient_slug`, `compound_recipes.slug` …). The checklist's "follow the
  DATA, never the import graph" walks readers straight through every copy. Two additions to the
  fix: (1) a SCOPE FENCE in the reader SUBJECT — name the columns that are IN, and state that a
  column holding a copy of the value is a boundary row (one side), never a new object to
  traverse; (2) make the unstamped hand-off an explicit workflow verdict (`ENDED area-target`)
  that records `seams_load` against the declared fence, so the plan's after-count is measured
  on the same scope. The orchestrator on 2026-09-05 initially stopped WITHOUT handing off, which
  this entry already said was wrong — the workflow text still does not say it.

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


## seams-merge-replaced-mid-run
- skills: [ac-polish]
- impact: M
- frequency: rare
- perceptibility: silent
- recurrence: 1
- related: [seams-fixpoint-never-stamps-on-accumulator]
- first_seen: 2026-09-03
- last_seen: 2026-09-03
- stage: manual
- status: open
- proposed_fix: version the ledger schema (top-level `schema:` field) and refuse at load
  a state this implementation did not write. An in-progress run finishes on the
  implementation that started it — frozen input applies to the tool as much as the artifact.
- narrative: a seams run started on the candidates-based merge (round output `new=N
  matched=N contaminated=...`); mid-run the skill was rewritten in place to the lens-based
  design. The new cmd_round cannot read the old ledger; the run's verifier consensus was
  finalized by direct artifact surgery. The workflow also cites `seams-merge.py verify
  --id --reader --verdict`, which no implementation has ever shipped — verifier verdicts
  had to be recorded by hand into the plan.

## gate-stamps-after-not-gated-merge
- skills: [ac-polish]
- impact: H
- frequency: rare
- perceptibility: silent
- recurrence: 1
- related: [seams-merge-replaced-mid-run]
- first_seen: 2026-09-04
- last_seen: 2026-09-04
- stage: manual
- status: open
- proposed_fix: `polish-fixpoint.sh --mode seams` should refuse (NOT-GATED) when
  `<STATE>/ledger.json` records no round N — the merge is the only writer of the round and
  its absence proves the round did not happen. Until then the orchestrator must run merge
  and gate as two commands and branch on the merge's exit code, never on grep output.
- narrative: round 5's `seams-merge.py round` exited 2 NOT-GATED (a reader wrote stage
  `update (dead-end)`), so the artifact did not change; a `merge | grep && gate` chain then
  ran the gate against the unchanged artifact, which read as a clean round ≥ 2 and STAMPED.
  The stamp (3 frontmatter keys, round-5.sha, receipt.txt) was reverted by hand and the
  digest verified equal to round-4.sha before the round was re-run. The gate cannot tell a
  clean round from a round that never happened.

## seams-reader-stance-cannot-write-report
- skills: [ac-polish]
- impact: M
- frequency: occasional
- perceptibility: loud
- recurrence: 1
- related: []
- first_seen: 2026-09-04
- last_seen: 2026-09-04
- stage: manual
- status: open
- proposed_fix: name the reader agent in `workflows/seams.md` READERS and make it one that can
  write outside the repository (a `Write` tool, or Bash unrestricted for paths under
  `~/.claude/polish/`); or have the prompt say "return the report body if you cannot write".
- narrative: the reader prompt says WRITE YOUR REPORT to `<REPORT>`; `researcher` is the
  read-only stance and one of fifteen readers had Bash restricted to read-only, so it returned
  the body inline and the orchestrator transcribed it. Fourteen others wrote via Bash heredoc,
  so the outcome depends on which restriction the stance picks up per spawn.

## seams-path-regex-rejects-root-files
- skills: [ac-polish]
- impact: M
- frequency: occasional
- perceptibility: loud
- recurrence: 2
- related: [seams-reader-stance-cannot-write-report]
- first_seen: 2026-09-05
- last_seen: 2026-09-05
- stage: manual
- status: open
- proposed_fix: let `PATH_RE` in `scripts/seams-merge.py` accept a root-level file with an
  extension (`vercel.json`, `package.json`, `next.config.mjs`) — a cron schedule or a package
  script is a real edge on many objects; today the only way to cite one is to point the path
  cell at the caller file and bury the root file in the role cell.
- narrative: a reader cited `vercel.json:4-6` (the daily sweep schedule) in a MAP row; the merge
  exited NOT-GATED "names no path" because the regex requires a `/`. The round was resumed to
  re-point the row at `app/api/cron/sweep-orphans/route.ts:17`. Same shape recurred for readers
  citing `package.json` scripts.

## seams-found-by-regex-parens-drop-edges
- skills: [ac-polish]
- impact: M
- frequency: frequent
- perceptibility: silent
- recurrence: 1
- related: []
- first_seen: 2026-09-05
- last_seen: 2026-09-05
- stage: manual
- status: open
- proposed_fix: one line in `references/seams-reader-prompt.md`: "in `rg` patterns escape
  parentheses or pass `-F`; a found-by that matches nothing drops the edge." Readers wrote
  `rg -n "checkCompound(name)"` — a regex group — nine times in one round.
- narrative: round 1 of the CompoundCheckResult split merged 19 edges and dropped 9 whose
  found-by did not reproduce; all 9 used unescaped parentheses in an rg pattern. The edges were
  real (readers re-found them in round 2 with `\(`), so the drop cost a round, not correctness.
  The validate step worked as designed; the prompt did not warn the reader.

## seams-boundary-side-key-inflates-new-edges
- skills: [ac-polish]
- impact: M
- frequency: frequent
- perceptibility: misleading
- recurrence: 1
- related: [seams-mode-no-convergence-on-domain-sized-target]
- first_seen: 2026-09-05
- last_seen: 2026-09-05
- stage: manual
- status: open
- proposed_fix: the boundary key is `interface × side × path` and `side` is free text, so a
  fresh reader restating a known file with different side wording mints a "new edge". Split the
  round line into `new_paths=` (a file no lens had) and `new_rows=` (a known file, new key), and
  let the fixpoint read `new_paths` — or key boundary on `interface × role-word × path` where
  role-word is the first token (producer · consumer · caller · callee · db · ts).
- narrative: at round 3 of the `canonical_ingredients.slug` run, 18 of 78 boundary rows were
  the same (interface, path) with different side text — `canonical-writer.ts` alone carried six
  B1 rows. Real growth was still present (57 distinct paths), so the loop's verdict was right,
  but a quarter of the convergence signal was wording.

## seams-aim-score-predicts-non-convergence
- skills: [ac-polish]
- impact: M
- frequency: occasional
- perceptibility: misleading
- recurrence: 1
- related: [seams-mode-no-convergence-on-domain-sized-target]
- first_seen: 2026-09-05
- last_seen: 2026-09-05
- stage: manual
- status: open
- proposed_fix: use the `aim.sh objects` score as a pre-split trigger in workflows/seams.md
  § TARGET — above ~1000 (or `touchers` above ~250) resolve to a NAMESPACE and pick one
  column-plus-mint before any reader runs; `aim.sh` could print the warning itself. Better: an
  `aim.sh` kind `namespace` that groups columns sharing a value shape and CHECK regex.
- narrative: `foods.status` (score 712, 293 touchers) stamped in 2 rounds on 2026-09-04;
  `canonical_ingredients.slug` (score 2234, 336 touchers, 133 writers) did not converge in 4
  rounds and cost ~12 opus readers. The score was three times the largest thing that had ever
  stamped, and nothing in the workflow read that as a warning.

## seams-reader-placeholder-and-abbreviated-paths
- skills: [ac-polish]
- impact: L
- frequency: frequent
- perceptibility: loud
- recurrence: 1
- related: [seams-path-regex-rejects-root-files]
- first_seen: 2026-09-05
- last_seen: 2026-09-05
- stage: manual
- status: open
- proposed_fix: two lines in references/seams-reader-prompt.md — "an absent stage is NO ROW,
  never a row whose path cell says `(absent)`" and "never abbreviate a path (`…`); the path cell
  is parsed" — and have `seams-merge.py` name the offending cell text on NOT-GATED so the fix is
  a one-line resume, not a re-read of the report.
- narrative: round 1 of the `canonical_ingredients.slug` run NOT-GATED three times in a row:
  a root file (`middleware.ts:32`), two object rows with `(absent)` as the path (the reader
  encoded the hole finding as a row), and three rows with a migration name shortened to
  `20260809220000_…`. Each was fixed by hand in the report outside the repo; the orchestrator
  editing reader output is exactly the division-of-labour breach the SKILL warns about.

