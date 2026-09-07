---
description: <WHEN this fires — concrete trigger phrases/conditions, NOT a how-to summary>
---

# /<workflow-name>

**You are the conductor, not the executor.** Coordinate stances, judge gates, finalize.
Do not write the content/code yourself, skip a gate, or exit early.

**MANDATORY FIRST STEP — declare the run ledger:**
```
TaskCreate (one per phase; 5-7 total):
  1. Initialize                  pending
  2. <core phase>                pending
  3. <core phase>                pending
  4. Quality gates               pending
  5. Finalize                    pending
TaskUpdate each → in_progress at phase start, → completed at exit.
Ledger tracks the RUN, never work items.
```
If TaskCreate is unavailable (subagent / fan-out path — no Task tools in your context), the ledger is a FILE: keep it as `progress.md` (+ `$STATE` for captured vars) in the RUN_ID-scoped artifacts dir (`ac-pipeline/references/run-ledger.md`), same one-entry-per-section, advance-as-you-go contract. Sanctioned equivalent, not a deviation.

## Phase 0 · Initialize (<est>)
Set up run ledger + output location (folder / wave branch / plan file). Read inputs.

## Phase 1..N · Core work (<est> each)
For each phase: announce → delegate to a **stance** with the right skill loaded
(researcher / implementer / validator), or a `Workflow` fan-out for deterministic structure →
verify exit criteria → `TaskUpdate → completed`. Parallelize independent steps; sequence
dependent ones.

## Phase N · Quality gates (<est>)
Tag each gate **blocking** (STOP, fix, re-run until PASS) or **warning** (note, continue).
Prefer a classifier-gate (run only what the diff/output warrants). Independent gates in parallel.

## Phase N+1 · Finalize (<est>)
Report what was produced, verify it, and tear down (kill spawned tasks, release locks/identities,
assert clean tree).

---

## Flexibility & Overrides
- "<override 1>" → <how to adapt>
- "<override 2>" → <how to adapt>
- Trust the user's judgment on skipping/adapting steps.

## Troubleshooting
- Agent reports a blocker → <action>
- A gate fails → <action>
- Missing input → <action>
- Resume after interruption → re-read the run ledger (anchor), reconcile with live state.

## Deferred decisions
Simple bounded fork (≤3 options) → `AskUserQuestion`. Anything open-ended → defer it
(a deferred-decision record); never block a long run on a decision.
