---
name: ac2-implement
description: 'Work the ac2 bead queue — claim, flight check, RED, implement, fresh-eyes self-review, close gate, next bead. Ships at N=1: the invoking session runs the worker prompt and owns the batch boundary. Triggers: "ac2 implement", "work the ac2 beads", "run the ac2 loop". For the legacy conductor use ac-loop / ac-implement.'
---

# ac2-implement — beads in, committed and closed work out

## I/O Contract

|                  |                                                                              |
| ---------------- | ---------------------------------------------------------------------------- |
| **Input**        | An ac2 epic's refined beads on the board (`ac2-beadify` compiled them)        |
| **Output**       | Commits on trunk, beads closed through a gate that can refuse                 |
| **Artifacts**    | Flight receipts (`<git-common-dir>/ac2-flight/`), the run ledger, close receipts |
| **Verification** | `close-gate.sh` per bead; the batch CI run + `ac2-review` per batch            |

**The prompt IS the skill.** `references/worker.md` (mandatory load) is the executable loop;
this file is its frame. Doctrine: `skills/ac2-pipeline/SKILL.md`. Bead and commit canon:
`beads-standards` and `ac-pipeline/references/` BY POINTER — restated nowhere here.

## What this skill does NOT do

Three refusals live in scripts, and no prose here re-implements what they already refuse:

| script | refuses |
| ------ | ------- |
| `scripts/flight-check.sh` | a claim whose premises no longer hold, or whose ACs are already green (no RED, no causal claim) |
| `scripts/swarm-commit.sh` | a commit outside the lane, without identity, with an unscoped pathspec, or with an inline message |
| `scripts/close-gate.sh` | a close with no RED receipt, a changed test, a probe that never went GREEN, unasserted coverage, or an unverified write |

A worker that re-checks these by hand has added a second, drifting copy of the rule. Call the
script; read its refusal; route on the class it names.

## N=1 — the coordinator is deferred, not missing

The invoking session IS the worker. It owns the batch boundary, the CI and review trigger,
the ledger and the telemetry rollup. The throughput layer — spawn/replace, liveness, mail
reservations, roster — is a DEFERRED Calibration in the constitution and is built only when
telemetry shows a batch whose wall time is worker-count-bound rather than gate-bound. Do not
build it here, and do not simulate it with prose.

## Procedure

1. **Load `references/worker.md`** and run it. It is written to be executed, not summarised.
2. **Work beads until the budget is spent** — one bead at a time, trunk-direct, each close
   through `close-gate.sh`.
3. **At the batch boundary**, derive the batch from the committed `.beads/issues.jsonl`, never
   from `br ready` alone (measured non-deterministic, and it stabilised on a WRONG count).
4. **Hand off to `ac2-review`** — a different model from the workers, post-batch, on the
   committed tree. A batch that ends with the worker's own verdict has had no independent eyes,
   and the party optimising against the measure does not get to record the verdict.

## The exhaust rule

Discovered PRODUCT work goes to the board with `discovered-from: <bead>`. Process observations
go to the family ledger, never to a new bead about ourselves — self-beads were 39% of the old
board. Every finding writes its `VERDICT:` and its catch-stage label even when it was fixed
in-batch: the fix may be in-batch, the label never is. Then land the plane.

## The rule this skill holds itself to

Every command `references/worker.md` spells is executed once against the live harness before it
ships, and the execution is recorded as an `EXEC-PROOF:` comment on the bead that shipped the
change. A prompt full of commands nobody ran is a scar list with better formatting.
