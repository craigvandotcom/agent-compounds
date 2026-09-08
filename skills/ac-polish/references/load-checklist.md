# load-checklist — DRAFT — three loads on every mapped seam, and what each cell is allowed to mean

The loop is `ac-polish/workflows/load.md`. This file is the lens per load: what the reader
measures, the command shapes, and the derived finding. **Every question names its oracle.** A
cell this file cannot fill with a COMMAND is `unmeasured`, never a guess.

## The input, fixed

A load run reads ONE seams map and fills three columns against its rows. It adds no rows. The
seams map is the fence: an edge not on it does not exist here. If the map is stale (its
`traced_at` commit is behind the fenced files — see `aim.sh status`), re-run seams first.

Every `rg` shape below is a copy-paste ERE — plain `|` alternation, no escapes. (The seams
checklist's tables forced `\|` for cell escaping; readers pasted it into rg, where it matches a
literal `|` and finds nothing. These shapes are prose, so the pipes are real.)

## time — what this edge costs per occurrence, and how often it occurs

- **rate** — the flow map's step frequency (60 Hz · 5 Hz · 1 Hz · per session · per request) —
  already on the map.
- **a budget the code states** — `rg -n "budget|maxMs|timeout|deadline|≤\s*\d+\s*(ms|µs)" <edge file>`
- **a sensor** — `rg -n "performance\.mark|os_signpost|console\.time|Sentry\.startSpan|EXPLAIN" <edge file>`
  · a perf test naming the edge.
- **a measurement** — run the perf test; the bundle analyzer line; `EXPLAIN ANALYZE` for a query edge.

Cell: `<n> <unit> @ <rate> · budget <n|none> · sensor <what|none>` or `n/a — <why>` or
`unmeasured`. Derived: **hot and unmeasured** — rate ≥ 1 Hz (or per-request) and no budget and
no sensor.

## trust — who produces what crosses this edge, and what checks it

- **producer** — the boundary map's producer cell — already on the map.
- **a validator** — `rg -n "z\.|zod|yup|assert|invariant|typeof .* !==|instanceof" <consumer file>`
- **an authoriser** — `rg -n "auth\.|getUser|session\.|RLS|policy|role" <edge file>`
  · `supabase/migrations/*policy*` for a row edge.
- **a limiter** — `rg -n "rateLimit|throttle|debounce|maxRequests|quota" <edge file>`
- **a test** — a test that sends the wrong shape / the wrong tenant / too many and asserts refusal.

Cell: `producer <internal|user|external|tenant> · validated <what|none> · authorised
<what|none> · limited <what|none>` or `n/a — internal, typed`. Derived: **untrusted and
unchecked** — producer ≠ internal and every check is none. (Internal edges: `n/a` unless the
seams map already flagged them `assumption nothing asserts` — those inherit the finding.)

## money — what this edge spends, and what caps it

- **a metered call** — `rg -n "anthropic|openai|fetch\(.https://|storage\.from|\.upload\(|cron|resend|stripe" <edge file>`
- **a cap in code** — `rg -n "max_tokens|maxTokens|limit:|MAX_|cap|budget" <edge file>`
- **a billing line** — the provider's usage export for the named resource (paste the line, dated).
- **an alert** — a budget alert / spend cap config naming the resource.

Cell: `<resource> · per-call <n|unknown> · cap <what|none> · alert <what|none>` or `n/a —
no metered call`. Derived: **metered and uncapped** — a metered call with no cap and no alert.

## The north star

Every real load on a mapped seam is either BUDGETED (a number the code enforces) or SENSED
(something goes red when exceeded). `load_` counts per map: `unmeasured-time` ·
`unmeasured-trust` · `unmeasured-money`. The fix plan's success criterion is those three
numbers re-derived after the fix — not a slogan.

## Guide words — per edge, per load

HAZOP again, three words each: time — **more** (slower than budget) · **late** (misses its
deadline) · **more often** (rate creep). trust — **other than** (wrong shape) · **more** (too
many) · **whose** (wrong tenant). money — **more** (cost creep) · **none** (cap never fires) ·
**early** (spends before it is needed). Each is a hypothesis; the cell says whether anything
would notice.
