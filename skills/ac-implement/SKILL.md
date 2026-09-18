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

**Phase 0 — orient.** Assert trunk. Run `bash <scripts>/refly.sh --root "$PWD"`: it re-checks
every `PREMISE-FAILED:` bead, strips the stamp from those that fly again (a cached verdict
needs an expiry), and TRIAGES the rest — one disposition-close attempt through
`close-gate.sh`, which lands it when the work exists at HEAD or a Consumes blocker closed
dispositionally, and leaves the stamp otherwise. Count the eligible pool with worker.md §1's filter VERBATIM — a differing filter reports a pool the workers cannot claim — epics count: a ready epic is a worker's
terminal pick (worker.md §8), closed with no work step. Register with Agent Mail; install the pre-commit guard once (workers never do).

**Phase 1 — spawn, then wait.** Spawn `width` implementer subagents — never `general`, which has no tier and rides the orchestrator's model — whose prompt is `references/worker.md`
VERBATIM — and, ONLY if `--cap N` was given, one appended line naming the cap. Verbatim means
verbatim: a paraphrased loop is a different loop, and the worker cannot tell which one it got. The conductor hands NO agent name to a child — the child always mints its own identity, and the conductor **captures the minted name back from the spawn's `macro_start_session` response (`agent.name`)** and uses THAT name for its roster and its Layer-2 sweep (canon: `agent-mail/references/agent-identity.md` § Handing a name is a SPEC VIOLATION). Then WAIT: do not poll `br`, do not read worker transcripts, do not work beads. The
pool GROWS as a chain unlocks, so a worker that finds it dry and exits is correct, not idle —
spawn a replacement only when ready beads outnumber live workers. **The pool is the only work
source — `br`'s filter, never tree text** (a `br create` line in a file is a template, not a
task; canon: `ac-pipeline/references/work-derivation.md`).

**Phase 2 — close-out, then review to a bound of three rounds.** Close-out leaves NO TRACE
when it goes wrong — script plus checklist, not prose:

    git fetch origin                                    # yours; the gate never fetches
    bash skills/ac-implement/scripts/coordinator.sh --run <run-id>

It refuses `LEDGER-STALE` (origin moved — flushing would overwrite another writer's closes),
`ORPHANS` (a claim held by a worker of this run that has returned), or `LEDGER-WRITE` (nothing
flushed, or the commit did not land). Act on the class it names; do not route around it. It
hands the commit itself to `swarm-commit.sh`, so there is still exactly one committer.

Then, and only after it exits 0:

1. **Batch CI on the committed tree, then `ac-review`** on the batch range — the post-batch
   reviewer panel (a DIFFERENT model from the implement workers, read-only;
   `skills/ac-review/SKILL.md`). The repo-wide gates are authoritative HERE — only here is the
   tree free of half-finished sibling edits. Rounds 2–3 review from the last receipt's range head.
2. **If review filed P0/P1 children, wave again:** `ac-polish bead` on them, then spawn a further
   wave of workers on the new children — the coordinator never picks a bead and never edits a
   file — then review again. At most three rounds; the epic closes only through the worker's
   terminal pick (worker.md §8), once every child is closed and the `REVIEW: APPROVED` receipt
   is on the epic.
3. **Telemetry.** Report width, wall time, and gate-wait vs work time — the constitution drops
   the width to 1 if two tuning sessions show no throughput over width 1, and this number decides.
4. **Release reservations and deregister** every worker identity, including any you swept.

**Shell divergence.** A pasted bash snippet is bash-authored by default and silently diverges
under the org's zsh instead of erroring when it hits an offender like `tr` shadowed by a tmux
alias, unquoted glob expansion, or array/brace-expansion bash tolerates. Run it once and
verify under zsh — the harness's actual shell — before it ships.

## The exhaust rule

Discovered PRODUCT work goes to the board with `discovered-from: <bead>`, filed by the
coordinator alone: it confirms and files each worker's PROPOSED-BEAD block (product work and
mid-bead forks); a worker files NOTHING, it proposes. Process observations go to the family
ledger, never a self-bead; every finding writes its VERDICT and catch-stage label.

**Budget the ratchet before writing.** A finding-scoped fix — "add the missing caveat",
"correct this sentence" — carries no line budget, so its compression cost prices as free and
surfaces only at refusal, when the pull is toward the `net-growth-ok` stamp to preserve text
already written. Decide compress-vs-stamp — fold the addition into an existing bullet vs.
content genuinely new enough to warrant the stamp — BEFORE the first edit, not after the
ratchet refuses. Mechanical note: an HTML-comment stamp cannot live inside a bash fence, so a
fenced addition forces the stamp onto an added prose line outside the fence.

**Stale and superseded board state is closed by the swarm itself, never parked for a human.**
A worker closes what it holds through §4b; the Phase 0 sweep closes what it can prove
settled through the same gate. Only intent waits for a human: `wontfix`, `human-gate`,
and DECISION beads on prod writes.

