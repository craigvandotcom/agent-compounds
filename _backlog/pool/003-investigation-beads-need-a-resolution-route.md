---
status: captured
type: feature
size: S
horizon: next
source: human
dependencies: []
---

# bead-capture-guard — an `investigation` bead must name how it resolves

One-line intent: stop `investigation` being a dead-end escape hatch; a bead nothing consumes
should never reach the board.

## Evidence (one consumer app, measured 2026-10-05)

- `hooks/bead-capture-guard.py` puts `investigation` in `PROBE_EXEMPT_TYPES` and its refusal
  text tells a probe-less filer to use it ("files the bead as `investigation` — the type that
  says so").
- No pipeline stage consumes `investigation`: the swarm picks only refined probe-bearing beads;
  ac-polish will not author a probe or root cause. One session filed 10 such beads; all
  needed an `/ac-plan` round to recover. 10 of 10 open investigation beads on that board came
  from this path.

## Scope

- In `bead-capture-guard.py`: an `investigation` create must carry a `Resolves via:` line
  naming the consuming stage (`ac-plan` · `ac-backlog pool` · `curator` · `human`) and an
  owner; otherwise BLOCK with a message pointing at `ac-backlog` shape routing
  (small+clear → buildable bead with probe; fuzzy → backlog pool).
- Refusal text: stop recommending `investigation` as the default for "cannot name a probe";
  recommend the pool instead.
- One RED/GREEN case per branch in `hooks/bead-capture-guard.test.py`.
- Out of scope: auto-converting existing investigation beads.

## Done when

- `br create --type investigation` without `Resolves via:` is blocked; with it, allowed;
  `hooks/bead-capture-guard.test.py` green.
