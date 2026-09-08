# polish · load mode — DRAFT (loop decided 2026-09-08; machinery not yet built, never run)

The loop is in `ac-polish/SKILL.md` and is the same in every mode. This file supplies only
what load mode binds. **Status: draft.** No round has run under it; the stamp and merge
machinery does not exist yet. Run seams first — load takes a seams map as its input.

Seams asks where an object can fail SILENTLY. Load asks what each mapped seam COSTS when it is
working: **time** (performance), **trust** (security), **money** (cost). Three loads, one map.
Nothing here is a new trace; every row load reads is a row seams already found and validated,
so a load run is bounded by construction and never discovers new edges.

## Bindings

| knob | load mode |
| --- | --- |
| **TARGET** | a kept seams map: `_docs/seams/<object>/map.json` (or a `_plans/…-seams-…md` still carrying its maps) |
| **ARTIFACT** | `<STATE>/load.md` — the seams map's edges, each with three load cells: `time` · `trust` · `money`, and a `sensor` per cell (what measures it) or `none` |
| **CHECKLIST** | `references/load-checklist.md` — the three loads, their oracles, and the derived findings |
| **READERS** | ONE reader per round — not three: the loads are independent columns with no disagreement mechanism, and a bounded fill needs no lens split. The reader is sent `references/load-checklist.md` and the seams map (`_docs/seams/<object>/map.json`), fills EVERY load column for EVERY edge on the map — no row quota, no exploration — and quotes each edge key VERBATIM from the map; the merge matches cells to edges on that exact key, never on path:line (readers do not cite stable lines — seams measured this). A cell it cannot name a command for is `unmeasured`, never a guess |
| **VALIDATE** | every cited oracle re-runs (`--validate`); a cell no command reproduces is dropped. The round's delta = dropped cells + changed cells |
| **STAMP** | `polish-fixpoint.sh --mode load` on `<STATE>/load.md` — `load_` frontmatter keys (derived from the mode, like `seams_`); the `unmeasured-*` counts also land in the kept `map.json` beside `seams_load` |

## What a load cell is

Per edge (one map row), per load, ONE of: a measured number with its oracle (a benchmark, a
bundle line, a query plan, a billing line, an auth check) · `n/a` with the reason (this edge
carries no such load) · `unmeasured` (the load is real and nothing measures it — that is the
finding). Guesses are not cells. A reader that cannot name the command writes `unmeasured`.

## Derived findings — the three questions, one per load

- **time**: an edge on the hot path (the flow map's ≥1 Hz steps) with `unmeasured` time — no
  budget, no benchmark, no trace span. Oracle shapes: a perf test, a Lighthouse/bundle line,
  `EXPLAIN`, an `os_signpost`/`performance.mark` span.
- **trust**: an edge whose boundary row has producer ≠ `internal` (user · external · tenant)
  with `unmeasured` trust — nothing validates, authorises or rate-limits it. This is the seams
  `untrusted input` row seen again with its oracle demanded (a schema, an RLS policy, an auth
  test). Internal edges are `n/a` by default.
- **money**: an edge that calls a metered thing (a model, a storage write, a third-party API,
  a cron) with `unmeasured` money — no per-call cost line, no cap, no alert. Oracle shapes: a
  billing export line, a rate-limit config, a `max_tokens`/`limit` argument, a budget alert.

`load_` frontmatter carries the counts: `unmeasured-time=` · `unmeasured-trust=` ·
`unmeasured-money=` · `edges=`. The Approach the plan derives is the same shape as seams': every
real load either has a BUDGET (a number the code enforces) or a SENSOR (something that goes red
when it is exceeded). A load with neither is decoration.

## Stop — a round that changes no cell

The fixpoint keys on **(edge key, load) → cell content**, exactly as the cells are quoted from
map.json — never on `file:line` or position. Round 1 fills every cell; a dropped cell (its oracle
did not reproduce) or a changed cell is the round's delta; the next round re-fills the gaps with
runnable commands. A round with ZERO changed and ZERO dropped cells stamps. Two rounds is
normal. A reader report that does not name every edge on the map × every load is NOT-GATED — the
round did not happen: resume the reader, re-merge. Partial coverage must never stamp: the stamp
claims "every mapped seam carries a cell for time, trust and money", and a missing edge would
make it a lie.

## Out of scope — on purpose

Fixing anything. Re-tracing edges. Style. Taste. Anything the seams map does not carry: if an
edge is missing, that is a seams re-run, not a load finding.

## Hand-off

Same shape as seams: the three load columns, the three unmeasured lists ranked by flow-map rate
(the hot path first), and an empty Approach for `ac-plan`. Copies beside the seams map as
`_docs/seams/<object>/load.md`, stamped with the seams map's traced-at commit; the counts land
in that object's `map.json` beside `seams_load` — the re-run instrument is the same: re-load
after the fix and compare the three numbers.
