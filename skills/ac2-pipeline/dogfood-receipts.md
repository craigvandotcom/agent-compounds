# ac2 dogfood receipts

The ac2 pipeline run against its own artifacts, with the expectation registered BEFORE the
run. An unregistered expectation can be met by any outcome, which is why the pre-registration
lands in its own commit, ahead of the receipt it will be judged against.

This file is the committed home for both halves. The plan file is gitignored and cannot host
either — a receipt nobody can diff is not a receipt.

---

## Dogfood #1 — ac2-polish on the plan that specified it

**Bead:** ac-v1vo
**Subject:** `_plans/2026-08-27-0211-ac2-pipeline.md` (369 lines)
**Engine under test:** `skills/ac2-polish/SKILL.md` + `skills/_tools/polish-fixpoint.sh`
**Checklist:** `skills/ac2-polish/references/plan-checklist.md`

### PRE-REGISTRATION — written and committed BEFORE the run

**Expectation: ZERO CHANGES.**

The subject plan already survived 11 fresh-context polish rounds, a Genius/Alien/Minimalist
tribunal, a 17-ledger frictions sweep, a 47-entry frictions disposition, and a lossless trim.
If `ac2-polish` is calibrated, it finds nothing. That is the prediction on the record.

**How this run can come out FALSE, stated in advance so no outcome can be claimed as a pass
after the fact:**

- Any finding at all falsifies "zero changes". The run is then judged on the CLASSIFICATION,
  not on the count.
- A finding classified as a **real defect the process missed** means the ceremony that
  produced this plan had a hole. That hole is a FRICTIONS entry against the PROCESS, not
  merely a plan edit.
- A finding classified as a **checklist artifact** means the checklist asked something that
  does not discriminate. That indicts the CHECKLIST and lands as a plan-checklist or
  bead-checklist correction.
- A run reporting "N findings" without classifying every one of them has produced nothing
  usable, and fails regardless of N.

**Calibration control, registered in advance.** Zero findings is only meaningful if the
engine can find anything. Before trusting a zero, a deliberate contradiction is injected
into a COPY of the plan — two acceptance criteria that cannot both hold — and a fresh reader
must CATCH it. If the injected contradiction is not caught, the engine is uncalibrated and a
zero-finding result is worthless rather than reassuring.

**Batch-4 fresh-reader check.** The plan's frontmatter records that batch 4 was
conductor-applied ahead of the human ruling and names this run as its fresh-reader check.
Any batch-4 material this run flags carries extra weight.

**Known bias, and the countermeasure.** The party running this is invested in the plan, and
the cheap way out is to reclassify a real defect as a checklist artifact. The countermeasures
are the fresh-context reader (which has not read this plan before) and the injected-mutation
control above.

**The plan file is NOT retired by this bead.** Retirement happens only after this receipt.

<!-- RECEIPT APPENDED BELOW IN A LATER COMMIT -->

### RECEIPT — run of 2026-08-27

**VERDICT: the pre-registered expectation is FALSIFIED. Round 2 found 3 findings, all real
defects. This is a PASS of the test and a FAIL of the prediction, and the difference is the
point — an unregistered expectation could have absorbed either outcome.**

**Calibration control — PASSED, and it ran FIRST.** A copy of the plan was given two success
criteria that cannot both hold (family total <=800 lines across seven skills; each skill
>=150 lines, i.e. >=1,050). A fresh reader caught it three ways: the arithmetic
impossibility, the clash with the plan's own `<=120` per-file guidance, and the
unimplementability against the Phase-1 lint assertion. The engine can find things, so the
findings below are not an artefact of an over-eager reader — and a zero would have meant
something.

**Rounds.** Fresh, stateless, severity-gated reader per round; the engine was driven with
`--dry-run` so the run wrote nothing to the (gitignored) plan.

| Round | Reader verdict | Engine verdict | Artifact digest |
|---|---|---|---|
| 1 | NO FINDINGS | `REFUSED round-1-clean` | `3622472a76ee1497` |
| 2 | 3 findings | loop STOPPED — not a fixpoint | `3622472a76ee1497` (unchanged) |

**NO STAMP WAS TAKEN, and refusing it is the finding that matters most.** The artifact digest
is byte-identical across both rounds, so `polish-fixpoint.sh` would have reported `STAMPED` at
round 2 had it been asked. It measures the ARTIFACT diff, and the dispositions for these
findings land in the ledger rather than in a plan that is about to be retired — so a
diff-empty round would have certified "clean" over three unfixed real defects. That is exactly
the false green this pipeline exists to stop, so the loop was stopped by hand instead.
**Recorded as a limitation of the engine, not a footnote:** an empty artifact diff is not
evidence of an empty finding set whenever findings are dispositioned somewhere other than the
artifact. The engine needs the round's finding COUNT as an input, not just the digest.

**Findings and classifications** — 3 findings, 3 classifications, 0 unclassified.

1. **Phase 1 orders the constitution before its enabler.** REAL DEFECT the process missed.
   The plan reads "`ac2-pipeline` (the constitution, written first…)", but writing
   `skills/ac2-pipeline/SKILL.md` trips lint Check 14 until ac-g2v4's ac2-creation rule
   lands. Verified live this session: ac-g2v4 shipped first (`c00fd1f`), after which the
   constitution's own commit passed Check 14 via the `ac2-creation` branch. Refine rounds 3-4
   found this and repaired the BEAD graph; the plan text was never swept.
   → landed: `skills/ac2-pipeline/FRICTIONS.md`
     § refine-corrections-land-in-the-beads-and-never-reach-the-plan

2. **Resolved precursors still carried as live assumptions.** REAL DEFECT, same root cause.
   `ac-on0y.1/.2/.4` are all `closed` and the frontmatter says so, while the body keeps them
   as assumptions with detection rules ("if .2 slips, Phase 2 waits") that can no longer fire.
   A resolved assumption with a dead detection rule is stale content asserting a live risk.
   → landed: same ledger entry (recurrence 2 — two instances of one hole in one run)

3. **The cutover slate archives the sole writer of `refined`.** REAL DEFECT the process missed,
   and the highest-impact of the three. Phase 4 moves every absorbed ac-* skill to
   `_archive/skills/`; ac-bead-refine is in ac2-polish's Absorbs column; and
   `stamp-refined.sh` — which the plan itself designates the sole sanctioned writer of
   `refined` — lives in `skills/ac-bead-refine/scripts/`, while ac2's batch-boundary filter
   still requires `refined`. No phase relocates it. Verified: the file is at that path and
   the Phase-4 slate enumerates other relocations but not this one.
   → landed: `skills/ac2-pipeline/FRICTIONS.md`
     § cutover-slate-archives-a-gate-the-new-pipeline-still-depends-on

**Checklist artifacts: none.** No finding was traceable to a question that failed to
discriminate, so no correction was made to `plan-checklist.md` or `bead-checklist.md`. The
opposite result is on the record instead: this plan had already survived 11 fresh-context
polish rounds and a Genius/Alien/Minimalist tribunal, and `plan-checklist.md` § 4
(sequencing) and § 3 (assumptions) surfaced three real defects at round 2. That is evidence
FOR the new checklist, and it is also why "zero findings" was the wrong prediction.

**Batch-4 fresh-reader check.** No finding traces to amendment batch 4; the two root causes
are the plan/bead sweep gap and the cutover slate, neither of which is batch-4 material.
Batch 4 is checked and clear — recorded as a reasoned "checked, no finding", not as silence.

**Bias disclosure.** The party running this authored ac2-polish, ac2-beadify, ac2-plan and the
constitution earlier in the same session, and had every incentive to classify these as
checklist artifacts. All three were classified as real defects and all three were verified
against live truth (the board, the filesystem, and this session's own commits) before
classification.

**The plan file was NOT retired and NOT edited.** It still exists at
`_plans/2026-08-27-0211-ac2-pipeline.md`, unchanged at digest `3622472a76ee1497`.
