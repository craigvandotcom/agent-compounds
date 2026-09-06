# seams-checklist — three lenses on one target, and what each map is allowed to mean

The loop (one reader per lens per round, merge by exact key, fixpoint when a round adds no
edge to any map) is `ac-polish/workflows/seams.md`. This file is the lens: what each map
enumerates, the command shapes that find it, and the rules that turn a map into seams. It is
systems engineering's oldest move — enumerate components and interfaces FIRST, judge the
interfaces SECOND — done by `rg` at study time. The object map is the N² chart (structure);
the flow map is the control structure (time and sensing); the boundary map is the contract.

## The target, resolved

A trace has a subject, not an area. The orchestrator resolves the area to the heaviest OBJECT
(touching files × layers) before any reader runs; the object's edges in time order are its
FLOWS; the interfaces those edges cross are its BOUNDARIES. All three lenses aim at the one
target. Follow the object's DATA, never the import graph, and stop at the artifact's fence: a
copy of the value in another store is one boundary row, never a second object. Exclude prose
paths.

## object — the datum, seven stages

| stage | what to find | command shape |
|---|---|---|
| `create` | where it first exists | `rg -n "(insert\|create\|<symbol>\s*[:=])" --type ts -g '!**/*.test.*'` |
| `transport` | moved between stores — upload, handoff blob, queue | `rg -n "(upload\|enqueue\|sessionStorage\|Preferences).*<symbol>"` |
| `store` | schema and persistence writes | `rg -n "<column>" supabase/ lib/db/` |
| `read` | every consumer of the stored shape | `rg -n "<symbol>" -g '!**/*.test.*' app features lib` |
| `update` | every mutation after creation | `rg -n "(update\|upsert\|patch)[^;]*<symbol>"` |
| `delete` | where the record goes away | `rg -n "(delete\|remove)[^;]*<symbol>"` |
| `cleanup` | what reclaims what delete leaves — blobs, caches, cron | `rg -n "<symbol>" app/api/cron scripts` |

Row: `path:line` · role · upstream · downstream · contract (what FAILS on drift — a type, an
assertion, a test path — or `none`) · found-by. Derived: **hole** (a core stage with no row) ·
**competing writers** (≥2 paths at create/update/delete) · **unasserted edge** (contract none).

## flow — one process, ordered steps

Row: flow · step · `path:line` · controller (who decides it happens) · sensor (what tells the
controller it happened) · on-failure (retry · timeout · compensate · surface · swallow · none)
· found-by. Find steps by following the object's transport/store/read edges in the order a
user or job triggers them: `rg -n "<step verb>" <the edge's file>` and the call it makes next.
Derived: **step with no sensor** (the controller acts on a stale model) · **failure not
handled** (none or swallow — the process is left half-done, silently). Reader diagnosis:
**ordering not guaranteed** (two steps that can interleave — a delete during an upload).

## boundary — one interface, two sides

Row: interface · side (producer/consumer, caller/callee) · `path:line` · producer (`internal`
· `user` · `external` · `tenant` — who originates what crosses; read from `req.json()`,
`searchParams`, `fetch('https://…')`, RLS) · assumes (a shape, an order, a presence the other
side is trusted for) · asserts (the type, guard, schema, auth check or test that checks it,
or `none`) · found-by. Find both sides: `rg -n "<type or key>"` on each side of the call, the
blob, the table. Derived: **assumption nothing asserts** · **untrusted input nothing
validates** (producer not internal, asserts none — the one security seam that needs no
threat model) · **half-mapped boundary** (one side on the map).

## Guide words — how a reader generates "what breaks silently" without guessing

HAZOP's move, per edge: what if **none** · **more** · **less** · **late** · **early** · **reversed**
· **other than**? Each is a concrete failure hypothesis; the map says whether anything would
notice it. "Other than" on `update` is the two-shape column; "reversed" between `delete` and
`cleanup` is storage deleted before the row; "less" on `transport` is the partial upload that
shifts every later URL. Exhaustive by construction, and the same seven words every round.

## The north star — what a seams plan is FOR

The system must be unable to fail silently on this object: every dependency is either OWNED
(one place decides the shape) or SENSED (something goes red when it drifts). Per target, the
Approach is done when: competing writers → one owner per mutating stage · unasserted edges → 0
· unsensed steps → 0 · unchecked boundary assumptions → 0 · untrusted inputs nothing validates
→ 0. `seams-merge.py handoff` writes these counts into the plan's frontmatter (`seams_load:`),
so the plan's success criterion is the same numbers after the fix, not a slogan. Ashby: the regulator must have as much
variety as the disturbance. An assertion that cannot go red does not count.

## Across lenses — the ranking

A path that carries a seam in two lenses — an unasserted edge that is also a step with no
sensor, on a boundary with an unchecked assumption — is one seam seen from three angles. The
script lists these first. Reader diagnoses (judgement) are ordered by how many readers reached
them: salience for the human, never a gate. The flow map's steps and sensors are emitted as
the `ac-qa` journey, so the plan ships with the scenario that proves its fix.
