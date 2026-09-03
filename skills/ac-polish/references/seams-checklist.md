# seams-checklist — how to trace one object, and what its map is allowed to mean

The loop that runs this (K trace readers per round, merge by `stage × path`, fixpoint when a
round adds no edge) is `ac-polish/workflows/seams.md`. This file is the lens: the stages, the
command shapes that find them, and the rules that turn a map into seams. It is systems
engineering's oldest move — enumerate the components and their interfaces FIRST (the N²
chart), then judge the interfaces — done cheaply, by `rg`, at study time.

## The object, not the area

A trace has one subject: a column, a type, a component's state, a record. "Images in food
entries" is an area; `foods.image_urls` and its writers is an object. The orchestrator resolves
the area to the heaviest object before any reader runs (workflow § TARGET); the reader traces
that object and nothing else. Follow the object's DATA — who writes it, moves it, stores it,
reads it, deletes it. Do not follow the import graph. Exclude prose paths (docs, plans,
backlog, memory, changelogs, snapshots, lockfiles, generated types).

## The stages — each found by a command

| stage | what to find | command shape |
|---|---|---|
| `create` | where the object first comes to exist | `rg -n "(insert\|create\|new .*<Type>\|<symbol>\s*[:=])" --type ts -g '!**/*.test.*'` |
| `transport` | where it moves between stores — upload, handoff blob, queue, message | `rg -n "(upload\|enqueue\|sessionStorage\|Preferences\|postMessage).*<symbol>"` |
| `store` | the schema and every persistence write | `rg -n "<column>" supabase/ lib/db/ --type sql --type ts` |
| `read` | every consumer of the stored shape | `rg -n "<symbol>" -g '!**/*.test.*' -g '!**/__tests__/**' app features lib` |
| `update` | every mutation after creation | `rg -n "(update\|upsert\|patch\|set)[^;]*<symbol>"` |
| `delete` | where the record goes away | `rg -n "(delete\|remove)[^;]*<symbol>"` |
| `cleanup` | what reclaims what delete leaves behind — blobs, caches, cron | `rg -n "<symbol>" app/api/cron scripts` |

Every row: `path:line` · role · upstream · downstream · contract · found-by. The contract is the
thing that would FAIL if this edge drifted — a type, an assertion, a test path — or `none`. Say
`none` when it is true; it is the most useful cell on the map.

## What the map means — rules, not opinions

- **Hole** — a core stage with no row. Nobody cleans up, nobody deletes. Derived by the script.
- **Competing writers** — two or more paths at `create`, `update` or `delete` with no shared
  primitive they route through. Last write wins; nothing asserts the shape. Derived.
- **Unasserted edge** — `contract = none`. Drift is silent by construction. Derived.
- **Shape divergence** — writers and readers naming different shapes for one thing (a column
  and its fallback). Reader diagnosis: cite both edges.
- **Duplicated stage** — one stage implemented twice (two upload paths). The chokepoint
  opportunity. Reader diagnosis.
- **Dead state** — written and never read. Reader diagnosis: name the writer edges.
- **Silent failure** — an edge whose failure no user, log or test would notice. Reader
  diagnosis: say what a user sees, and does not see.

Reader diagnoses are ordered by how many readers reached them — a salience signal for the
human, never a gate. The map's facts are validated by re-running `found-by`; the diagnosis is
judgement over shared facts, which is the only kind two readers can meaningfully disagree on.
