# polish · load mode — DRAFT PLACEHOLDER (mvp, not yet run)

The loop is in `ac-polish/SKILL.md` and is the same in every mode. This file supplies only
what load mode binds. **Status: draft.** No round has run under it; the checklist's oracles are
named but not all exist yet. Run seams first — load takes a seams map as its input.

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
| **READERS** | one per load per round (time · trust · money), in parallel, each sent the seams map and its own oracle set; each fills ONLY its column, for EVERY edge on the map — no row quota, no exploration |
| **VALIDATE** | every cited oracle re-runs (`--validate`); a cell no command reproduces is dropped |
| **STAMP** | `polish-fixpoint.sh --mode load` — `load_` frontmatter keys beside `seams_` |

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

## Out of scope — on purpose

Fixing anything. Re-tracing edges. Style. Taste. Anything the seams map does not carry: if an
edge is missing, that is a seams re-run, not a load finding.

## Hand-off

Same as seams: the three load columns, the three unmeasured lists ranked by flow-map rate
(the hot path first), and an empty Approach for `ac-plan`. Copies beside the seams map as
`_docs/seams/<object>/load.md`, stamped with the seams map's traced-at commit.
