---
name: ac-implement
description: 'Work an ac2 epic''s bead queue as a SWARM — you coordinate, spawned workers claim, flight check, RED, implement, self-review, close gate, next bead. Defaults to width 3, uncapped, until the qualifying beads are exhausted. Triggers: "ac2 implement", "work the ac2 beads", "run the ac2 loop", "swarm the ac2 beads", "ac2 swarm".'
---

# ac-implement — beads in, committed and closed work out

## I/O Contract

|                  |                                                                              |
| ---------------- | ---------------------------------------------------------------------------- |
| **Input**        | `<epic>` — its refined beads on the board. Optional: `--width N`, `--cap N`     |
| **Output**       | Commits on trunk, beads closed through a gate that can refuse                 |
| **Artifacts**    | Flight receipts (`<git-common-dir>/ac-flight/`), the run ledger, close receipts |
| **Verification** | `close-gate.sh` per bead; the batch CI run + `ac-review` per batch            |

**The prompt IS the skill.** `references/worker.md` (mandatory load) is the executable loop;
this file is its frame. Doctrine: `skills/ac-pipeline/SKILL.md`. Bead and commit canon:
`beads-standards` and `ac-pipeline/references/` BY POINTER — restated nowhere here.

## What this skill does NOT do

`flight-check.sh` (claim), `swarm-commit.sh` (commit) and `close-gate.sh` (close) refuse on the
worker's behalf, and each prints the class it refused on. Enumerating those classes here would
be the second, drifting copy the scripts exist to prevent: call the script, read its refusal,
route on the class it names.

## Defaults — a swarm, and one procedure for every width

**`ac2 implement <epic>` spawns a swarm at WIDTH 3, UNCAPPED, and runs until the qualifying
beads are exhausted.** There is no mode flag and no second procedure: the invoking session is
always the coordinator and never a worker, at every width. Two procedures would be two things
to keep true.

| override | effect |
| --- | --- |
| `--width N` | spawn N workers instead of 3. `--width 1` still SPAWNS one; it does not turn you into the worker |
| `--cap N` | each worker stops after N closes. Default is uncapped — **the queue is the budget** |

A cap is for bounding a run you are watching, not for pacing: uncapped, a worker that finds the
queue dry exits, which is the correct end. Capped, it stops with beads still waiting.

## The procedure — you coordinate, you do not work

**You never pick a bead, never review code, never edit a file.** Coordination lives in `br`
claims and the beads' own `## Consumes` / `## Delivers`, not in you. A coordinator that starts
working is a worker that has stopped coordinating.

**Phase 0 — orient.** Assert trunk. Count the eligible pool using worker.md §1's filter
VERBATIM — a coordinator filter that differs from the worker's reports a pool the workers
cannot actually claim — and additionally drop `issue_type: epic`, which the label filter alone
misses (measured: a finished epic sat pickable because it carried the type but not the label).
Register with Agent Mail; install the pre-commit guard once — workers do not install it.

**Phase 1 — spawn, then wait.** Spawn `width` workers whose prompt is `references/worker.md`
VERBATIM — and, ONLY if `--cap N` was given, one appended line naming the cap. Verbatim means
verbatim: a paraphrased loop is a different loop, and the worker cannot tell which one it got. Then WAIT: do not poll `br`, do not read worker transcripts, do not work beads. The
pool GROWS as a chain unlocks, so a worker that finds it dry and exits is correct, not idle —
spawn a replacement only when ready beads outnumber live workers.

**Phase 2 — close-out.** Three of its steps leave NO TRACE when they go wrong, so they are a
script, not a checklist:

    git fetch origin                                    # yours; the gate never fetches
    bash skills/ac-implement/scripts/coordinator.sh --run <run-id>

It refuses `LEDGER-STALE` (origin moved, so flushing would silently overwrite another
writer's closes), `ORPHANS` (a claim still held by a worker of this run that has returned),
or `LEDGER-WRITE` (the flush produced nothing, or the commit did not land). Act on the class
it names; do not route around it. It hands the commit itself to `swarm-commit.sh`, so there
is still exactly one committer.

Then, and only after it exits 0:

1. **Batch CI on the committed tree, then `ac-review`** (different model from the workers).
   The workers ran bead-scoped checks only; the repo-wide gates are authoritative HERE and
   nowhere else, because only here is the tree free of half-finished sibling edits.
2. **Telemetry.** Report width, wall time, and gate-wait vs work time. The constitution drops
   the default width to 1 if two tuning sessions show no throughput over width 1 — that needs
   a number, and this is where the number comes from.
3. **Release reservations and deregister** every worker identity, including any you swept.

## The exhaust rule

Discovered PRODUCT work goes to the board with `discovered-from: <bead>`. Process observations
go to the family ledger, never to a new bead about ourselves — self-beads were 39% of the old
board. Every finding writes its `VERDICT:` and its catch-stage label even when it was fixed
in-batch: the fix may be in-batch, the label never is. Then land the plane.

