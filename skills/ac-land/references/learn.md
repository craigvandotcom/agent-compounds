# ac-land Phase 2 — learn mechanics

<!-- mirror: ac-pipeline/references/delegation-contract.md § child-spawn preamble -- edit there first -->

## Spawn the retrospective analyst

Child-spawn contract: `ac-pipeline/references/delegation-contract.md` — verbatim preamble, bounded waits, structured returns.

Spawn the retrospective analyst using the prompt in **`references/retrospective-prompt.md`** (substitute the resolved `<ARTIFACTS_DIR>`). It reads session artifacts + the workflow/skill files, reports what worked / what did not / patterns, and proposes evidence-backed system-upgrade opportunities under a strict minimum-waste bar.

> **Loop-exit (multi-wave):** when `$ARTIFACTS_DIRS` is set (Phase 0 found several wave dirs for this `RUN_ID`), substitute **all** of them so the retrospective spans the whole loop session — every wave's `progress.md` — not just the last wave. A single-wave land has one dir and behaves as before.

## Conductor reviews the retrospective

Read `<ARTIFACTS_DIR>/retrospective.md` (use the resolved path from Phase 0). Apply the minimum bar: did this issue cause real waste THIS session? Drop anything that's "interesting but theoretical." Keep only items where you can point to a specific moment where time or resources were lost because the information wasn't available upfront.

Mark ledger task 5 `completed`; `TaskUpdate` task 6 `in_progress`.