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
