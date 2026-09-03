# polish · seams mode — three lenses trace one target; the maps converge; the seams are read off

The loop is in `ac-polish/SKILL.md` and is the same in every mode. This file supplies only
what seams mode binds, and it is a MANDATORY load for a seams run.

Seams mode reads CODE and writes MAPS. Each round one reader per lens — **object** (structure:
the datum through its stages), **flow** (time: the object's edges as processes, with sensing),
**boundary** (contract: the interfaces those edges cross, both sides) — traces the same target.
The union of the three maps is the artifact; the loop ends when a round adds no edge to any of
them, which is reachable because a target's edges are finite. The seams are derived from the
maps, per lens and then across lenses, and go to `ac-plan` with the flow map's steps as the
acceptance journey. Nothing is fixed here.

## Bindings

| knob | seams mode |
| --- | --- |
| **TARGET** | an OBJECT, never an area. The user gives an area or nothing: **resolve before any reader runs, with the script, not by hand.** Area → `scripts/aim.sh objects --area '<regex>'` ranks the objects named by or touched from matching files (touchers × layers × writers ÷ tests); take the top row. Nothing → the start prompt below. Then name the object's FLOWS (its edges in time order, e.g. capture → upload → save → display; delete → cleanup) and BOUNDARIES (the interfaces those edges cross). Confirm all three in ONE prompt: *"Object: `foods.image_urls` (14 touchers, 5 layers, 3 writers, 1 test). Flows: 2. Boundaries: 3. Trace?"* |
| **ARTIFACT** | `<STATE>/plan.md` from `references/seams-plan-template.md`, `<STATE>` = `~/.claude/polish/<repo>/seams-<slug>-<date>/` — OUTSIDE the tree. Below the marker: three maps, exact keys (object `stage × path` · flow `flow × path` · boundary `interface × side × path`), first-seen text, written only by `scripts/seams-merge.py`. Ledger in `<STATE>/ledger.json`. Copied to `_plans/<date>-seams-<slug>.md` at hand-off |
| **CHECKLIST** | `references/seams-checklist.md` — the three lenses, their command shapes, and the rules that turn maps into seams |
| **READERS** | one per lens per round, in parallel (`--lens` selects a subset; default all three), each sent `references/seams-reader-prompt.md` verbatim with `<LENS>`, `<SUBJECT>`, `<MAPS>` (the current artifact — facts, so showing it is not contamination), `<CHECKLIST>`, `<REPORT>` (= `<STATE>/reports/r<N>-<lens>.md`) filled. Fresh each round; each extends and corrects its own map |
| **VALIDATE** | `seams-merge.py round … --validate --repo <root>` re-runs every new edge's `found-by`; an edge no command reproduces is dropped |
| **STAMP** | `polish-fixpoint.sh --mode seams` — `seams_` frontmatter keys, so a later `--mode plan` polish keeps its own stamp beside them |

## The start prompt — only when no target is given

```
AskUserQuestion: "What should ac-seams trace?"
  Where the debt lives      scripts/aim.sh objects                → ranked objects, pick one
  What we just churned      scripts/aim.sh churn --since 1w       → hot files; then objects --area <file>
  Recent drift              scripts/aim.sh churn --since 4w       → same bridge
  Other → an area or object by name                               → objects --area '<regex>'
```

`objects` outputs objects; `churn` outputs files — the `--area` bridge turns a file into the
objects it touches. The human picks ONE row; that is the second and last prompt. Aim runs once
per session; re-aiming inside a loop is a moving target.

## MERGE — one command per round, after the reports land

```
scripts/seams-merge.py round --state <STATE> --artifact <STATE>/plan.md --round <N> \
    --repo <root> --validate <STATE>/reports/r<N>-*.md
```

Each lens merges on its exact key. A named contract beats `none` in the ledger without moving
the digest; the disagreement is recorded. Reader diagnoses merge on the paths they cite and
count readers. The round line prints `new_edges=` (the convergence signal), edges per lens, and
the derived and cross-lens seam counts. **A `NOT-GATED` merge means the round did not happen**
— resume that reader, re-merge, then run the gate. Every artifact change is a round to
`polish-fixpoint.sh`.

## Stop — a round that adds no edge to any map

Digest unchanged at round ≥ 2 → the script stamps: three independent traces found nothing the
maps lacked. Two or three rounds is normal (about nine readers). A run still adding edges past
five rounds has an area for a target — split it (each heavy flow or boundary is its own run),
never loop on.

## Hand-off

`seams-merge.py handoff` writes: the three maps · **seams seen by more than one lens, first**
(a path with an unasserted edge that is also an unsensed step on an unchecked boundary) ·
seams derived per lens (hole · competing writers · unasserted edge · step with no sensor ·
failure not handled · assumption nothing asserts · untrusted input nothing validates ·
half-mapped boundary) · reader diagnoses by
reader count · the **journey** (the flow map's steps and sensors, for `ac-qa`) · an empty
Approach. The orchestrator writes the Problem paragraph FROM THE MAPS, copies the file to
`_plans/` with frontmatter naming rounds and verdict, and hands it to `ac-plan`, which writes
the Approach and the remaining ac2 sections and passes it to `ac-polish plan`. Do not finish
by reporting success and stopping.
