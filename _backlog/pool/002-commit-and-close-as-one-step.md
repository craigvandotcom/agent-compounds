---
status: captured
type: feature
size: M
horizon: next
source: human
dependencies: []
---

# ac-implement — a bead's commit and its close land together or not at all

One-line intent: finished work that stays marked unfinished is the pipeline's biggest repeat waste; make
"save the code" and "mark the bead done" one step.

## Evidence (one consumer app, measured 2026-10-04)

- `RED` is the dominant flight-check refusal: 30 of 224 receipts in `<git-common-dir>/ac-flight/`
  (CONSUMES 8, ENVIRONMENT 2). A RED at claim mostly means the bead's work already exists at HEAD.
- One swarm run left three beads committed-but-open (`utg43.5` b53d682a5, `uuz1o.8` b25f89de8,
  levels-price 39d797608): the commit landed, then `close-gate.sh` could not run (machine memory/quota
  exhaustion) or refused on a bead-text defect. Every later worker re-claimed, saw GREEN, bounced.
- Recovery cost: refly + a polish pass + a disposition close per bead.

## Scope

- Pick ONE of: (a) close-gate runs before the commit is published, so a commit is only kept when the
  close lands; or (b) `pick.sh` / `refly.sh` detect a bead whose own commit (`(bd-id)` in a subject) is at
  HEAD and route it straight to the §4b disposition close, never to a worker.
- A gate that cannot run (resource exhaustion, NOT-GATED) must leave a durable marker the next pick
  reads, not a silent open bead.
- Out of scope: secrets for probes — ENVIRONMENT is 2/224; beads needing keyring secrets run under
  `with-secrets` in a supervised pass.

## Done when

- A swarm run on a tree where a bead's commit is at HEAD but the bead is open spends zero worker passes
  on it (disposition-closed at pick, or never left open).
