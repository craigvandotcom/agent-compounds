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
| **Verification** | `close-gate.sh` per bead; the batch CI run per batch                        |

**The prompt IS the skill.** `references/worker.md` (mandatory load) is the executable loop; this file is its frame. Doctrine: `skills/ac-pipeline/SKILL.md`; bead + commit canon by pointer.

## What this skill does NOT do

`flight-check.sh` (claim), `swarm-commit.sh` (commit) and `close-gate.sh` (close) refuse on the
worker's behalf, each printing the class it refused on. Enumerating those classes here would be
the second, drifting copy the scripts exist to prevent: call the script, read its refusal,
route on the class it names.

## Defaults — a swarm, and one procedure for every width

**`ac2 implement <epic>` spawns a swarm at WIDTH 3, UNCAPPED, and runs until the qualifying beads are exhausted.** There is no mode flag and no second procedure: the invoking session is
always the coordinator and never a worker, at every width; a cap bounds a run you are watching, and an uncapped dry queue is the correct end.

| override | effect |
| --- | --- |
| `--width N` | spawn N workers instead of 3. `--width 1` still SPAWNS one; it does not turn you into the worker |
| `--cap N` | each worker stops after N closes. Default is uncapped — **the queue is the budget** |

## The procedure — you coordinate, you do not work

**You never pick a bead, never review code, never edit a file.** Coordination lives in `br`
claims and the beads' own `## Consumes` / `## Delivers`. A coordinator that starts working
is a worker that has stopped coordinating.

**Phase 0 — orient.** Assert trunk, then assert the deployed agents are current before any worker
spawns: resolve THIS skill's real path (app skills are symlinks; an app root has no `engine/`) — `<scripts>` is its `scripts/` dir, absolute, symlinks resolved — and
run `<ac-root>/engine/deploy.sh "$PWD" --agents all --dry-run` — a `generate` line is a stale agent
whose frozen tool grants waste the wave: print the regenerate command and stop. Run
`bash <scripts>/refly.sh --root "$PWD"`: it re-checks every `PREMISE-FAILED:` bead, strips the
stamp from those that fly again, and TRIAGES the rest — one disposition-close attempt through
`close-gate.sh`, lands when the work exists at HEAD or a Consumes blocker closed dispositionally,
else leaves the stamp. Count the pool with `<scripts>/pick.sh --count` (the workers' own filter);
print the board, `<scripts>/../../ac-board/scripts/board.sh` — it carries CI, docket and
board-truth health. Register with Agent Mail; install the pre-commit guard once (workers never do).

**Phase 1 — spawn, then wait.** Spawn `width` implementer subagents — never `general`, which has no tier and rides the orchestrator's model — whose prompt is `references/worker.md`
VERBATIM — plus one always-appended `SCRIPTS=<the absolute `<scripts>` this file resolved in Phase 0>` line, and, ONLY if `--cap N` was given, one appended line naming the cap, plus one appended line naming this run's id for the worker's `task_description`. Verbatim means
verbatim: a paraphrased loop is a different loop, and the worker cannot tell which one it got. The conductor hands NO agent name to a child — the child always mints its own identity via `macro_start_session`; the conductor builds its roster from agents registered since the run started (`resource://agents/{project_key}` filtered by `task_description`), using THOSE names for its roster and its Layer-2 sweep (canon: `agent-mail/references/agent-identity.md` § Handing a name is a SPEC VIOLATION). Then WAIT: do not poll `br`, do not read worker transcripts, do not work beads. The
pool GROWS as a chain unlocks or beads are refined, so a worker that exits dry is correct, not idle — on EVERY return, respawn `min(pick.sh --count, width) − live`; Phase 2 starts only when none is live and the count reads 0. **The pool is the only work
source — `br`'s filter, never tree text** (a `br create` line in a file is a template, not a
task; canon: `ac-pipeline/references/work-derivation.md`).

**Phase 2 — close-out, then batch CI, then telemetry.** Close-out leaves NO TRACE
when it goes wrong — script plus checklist, not prose:

    git fetch origin                                    # yours; the gate never fetches
    bash <scripts>/coordinator.sh --run <run-id> --actor <name>...  # one per name registered since the run started

It refuses `LEDGER-STALE` (origin moved — flushing would overwrite another writer's closes),
`ORPHANS` (a claim held by a worker of this run that has returned), or `LEDGER-WRITE` (nothing
flushed, or the commit did not land). Act on the class it names; do not route around it. It
hands the commit itself to `swarm-commit.sh`, so there is still exactly one committer.

Then, and only after it exits 0:

1. **Batch CI on the committed tree.** The repo-wide gates are authoritative HERE — only here is
   the tree free of half-finished sibling edits.
2. **Telemetry.** Report width, wall time, and gate-wait vs work time — the constitution drops
   the width to 1 if two tuning sessions show no throughput over width 1, and this number decides.
3. **Release reservations and deregister** every worker identity, including any you swept.

**Shell divergence.** A pasted bash snippet is bash-authored by default and silently diverges
under the org's zsh instead of erroring when it hits an offender like `tr` shadowed by a tmux
alias, unquoted glob expansion, or array/brace-expansion bash tolerates. Run it once and
verify under zsh — the harness's actual shell — before it ships.

## The exhaust rule

Discovered PRODUCT work goes to the board with `discovered-from: <bead>`, filed by the
coordinator alone: it confirms and files each worker's PROPOSED-BEAD block (product work and
mid-bead forks); a worker files NOTHING, it proposes. Process observations go to the family
ledger, never a self-bead; every finding writes its VERDICT and catch-stage label.

**Budget the ratchet before writing.** Check 14 holds this file to net <= 0 against its base and
there is no prose stamp: an addition here buys its own lines by deleting them.

**Stale and superseded board state is closed by the swarm itself, never parked for a human.**
A worker closes what it holds through §4b; the Phase 0 sweep closes what it can prove
settled through the same gate. Only intent waits for a human: `wontfix`, `human-gate`,
and DECISION beads on prod writes.

