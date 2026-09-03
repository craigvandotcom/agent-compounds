# polish · seams mode — trace one object, converge on its map, read the seams off it

The loop is in `ac-polish/SKILL.md` and is the same in every mode. This file supplies only
what seams mode binds, and it is a MANDATORY load for a seams run.

Seams mode reads CODE and writes a MAP. K readers trace the same object through the same
stages; the union map is the artifact; the loop ends when a round adds no edge — reachable,
because the edges of one object are finite. The seams are then derived from the map, not
hunted. Nothing is fixed here: the map and its seams go to `ac-plan`, whose Approach is
usually one sentence — give this object one owner at each stage the map shows it lacks.

## Bindings

| knob | seams mode |
| --- | --- |
| **TARGET** | an OBJECT — a column, a type, a component's state, a record — never an area. The user gives an area or nothing: **resolve it before any reader runs.** `rg` the area's nouns for candidate objects; weigh each by touching files × distinct layers (db · service · hook · component · route · cron · test), churn as tiebreaker; take the heaviest; confirm it in ONE prompt: *"Resolved to `foods.image_urls` + writers — 14 files, 5 layers. Trace this?"* No area at all → `scripts/aim.sh --since <window>` ranks files; the human picks one; resolve its object the same way |
| **ARTIFACT** | `<STATE>/plan.md` from `references/seams-plan-template.md`, `<STATE>` = `~/.claude/polish/<repo>/seams-<slug>-<date>/` — OUTSIDE the tree. Below the marker: the MAP, one row per `stage × path`, first-seen text, stage order, written only by `scripts/seams-merge.py`. Ledger in `<STATE>/ledger.json`. Copied to `_plans/<date>-seams-<slug>.md` at hand-off |
| **CHECKLIST** | `references/seams-checklist.md` — the stages, their command shapes, and the rules that turn a map into seams |
| **READERS** | K trace readers per round (default 3), each sent `references/seams-reader-prompt.md` verbatim with `<OBJECT>`, `<CHECKLIST>`, `<REPORT>` (= `<STATE>/reports/r<N>-<letter>.md`) filled. Same object, same stages, independent tracing. Their rows reach ARTIFACT only through MERGE |
| **VALIDATE** | `seams-merge.py round … --validate --repo <root>` re-runs every new edge's `found-by`; an edge no command reproduces is dropped |
| **STAMP** | `polish-fixpoint.sh --mode seams` — `seams_` frontmatter keys, so a later `--mode plan` polish keeps its own stamp beside them |

## MERGE — one command per round, after the K reports land

```
scripts/seams-merge.py round --state <STATE> --artifact <STATE>/plan.md --round <N> \
    --repo <root> --validate <STATE>/reports/r<N>-*.md
```

Edges key on `stage × path` — exact, no fuzzy matching. A named contract beats `none` and the
disagreement is recorded. Reader diagnoses merge on the edges they cite and count readers. The
round line prints `new_edges=` (the convergence signal) and the derived seams so far. **A
`NOT-GATED` merge means the round did not happen** — resume the reader whose report failed to
parse, re-merge, then run the gate. Every artifact change is a round to `polish-fixpoint.sh`.

## Stop — a round that adds no edge

The digest is unchanged, and at round ≥ 2 the script stamps: K readers independently traced
the object and found nothing the map lacked. Two or three rounds is normal. A run that keeps
adding edges past five rounds has the wrong TARGET — an area, not an object — and the fix is to
split it (each heavy downstream consumer is its own object, its own run), not to run more rounds.

## Hand-off

`seams-merge.py handoff` writes Map · Seams derived (holes, competing writers, unasserted edges)
· Seams from reader diagnosis, ordered by reader count · an empty Approach. The orchestrator
writes the Problem paragraph FROM THE MAP, copies the file to `_plans/` with frontmatter naming
rounds and verdict, and hands it to `ac-plan`, which writes the Approach and the remaining ac2
sections and passes it to `ac-polish plan`. Do not finish by reporting success and stopping.
