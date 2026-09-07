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
| **TARGET** | an OBJECT, never an area. The user gives an area or nothing: **resolve before any reader runs, with the script, not by hand.** Area → `scripts/aim.sh objects --area '<regex>'` ranks the objects named by or touched from matching files (touchers × layers × writers ÷ tests); take the top row. Nothing → the start prompt below. Then name the object's FLOWS (its edges in time order, e.g. capture → upload → save → display; delete → cleanup) and BOUNDARIES (the interfaces those edges cross). Then run `scripts/aim.sh files --terms '<the object line>'` and paste its `files:` line: the source files that name a term as a whole word, minus tests and dev harnesses — the closed set every reader sweeps. Write all four into the artifact frontmatter as ` · `-separated lists — they are the FENCE the merge enforces every round. Object terms are symbols ONLY (the table-qualified column, the type, the function, the event name), never a path and never the bare column name: a path in `object:` is NOT-GATED, and a column copied under the same name on another table is outside. Confirm BY NAME in ONE prompt, because the names are the fence: *"Object: `foods.image_urls` · `uploadImages` (14 touchers, 5 layers, 3 writers, 1 test). Files: 9 (3 contract-only excluded). Flows: capture → upload → save → display · delete → cleanup. Boundaries: camera→form blob · upload route · foods row. Trace?"* |
| **ARTIFACT** | `<STATE>/plan.md` from `references/seams-plan-template.md`, `<STATE>` = `~/.claude/polish/<repo>/seams-<slug>-<date>/` — OUTSIDE the tree. Below the marker: three maps, exact keys (object `stage × path` · flow `flow × path` · boundary `interface × side × path`), first-seen text, written only by `scripts/seams-merge.py`. Ledger in `<STATE>/ledger.json`. Copied to `_plans/<date>-seams-<slug>.md` at hand-off |
| **CHECKLIST** | `references/seams-checklist.md` — the three lenses, their command shapes, and the rules that turn maps into seams |
| **READERS** | one per lens per round, in parallel (`--lens` selects a subset; default all three), each sent `references/seams-reader-prompt.md` verbatim with `<LENS>`, `<SUBJECT>`, `<FILES>` (the `files:` line, one path per line), `<MAPS>` (the current artifact — facts, so showing it is not contamination), `<CHECKLIST>`, `<REPORT>` (= `<STATE>/reports/r<N>-<lens>.md`) filled. Fresh each round; each sweeps the same FILES and extends and corrects its own map |
| **VALIDATE** | `seams-merge.py round … --validate --repo <root>` re-runs every new edge's `found-by`; an edge no command reproduces is dropped |
| **STAMP** | `polish-fixpoint.sh --mode seams --findings 0` — `seams_` frontmatter keys, so a later `--mode plan` polish keeps its own stamp beside them. `--findings` is 0 in seams mode BY CONSTRUCTION: a reader's findings are its rows, the merge applies every admitted row to the artifact and records the rest as fenced/dropped with a reason, so nothing remains undispositioned after the merge and the digest is the only sensor. Passing `new_edges` as the count makes a clean round unstampable (a round that adds nothing has 0 either way; a round that adds edges moves the digest) |

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
count readers. The round line prints `new_edges=` (the convergence signal), `fenced=` (rows
outside the frontmatter fence, listed beneath with the reason — never new edges), edges per
lens, and the derived and cross-lens seam counts. **A `NOT-GATED` merge means the round did
not happen** — resume that reader, re-merge, then run the gate; a fence line still holding a
template placeholder is one such NOT-GATED. Every artifact change is a round to
`polish-fixpoint.sh`.

A fenced row is the widen-or-split decision, taken by the orchestrator before the next round:
an edge of THIS object under a name the fence lacks → add that name to `object:` and recompute
`files:` with `aim.sh files` (the next round re-admits it; a recorded round is never re-merged);
an edge of another object → leave it fenced, and if it keeps arriving, that object is its own
run. Rows the round line reports as `dropped` failed `--validate`: the reader's found-by did not
reproduce — usually a `\|` alternation or a grep flag passed to rg — and the next round's reader
re-finds the edge with a command that runs.

## Stop — a round that adds no edge to any map

Digest unchanged at round ≥ 2 → the script stamps: three independent traces swept the same
files and found nothing the maps lacked. Two or three rounds is normal (about nine readers). A
run still adding edges past five rounds has an area for a target — split it (each heavy flow or
boundary is its own run), never loop on. The `files:` line is what makes convergence reachable:
the grid is finite, so growth can only come from the fenced files, and a round that adds nothing
means the sweep is complete (the 2026-09-06 MotionFrame run, fenced by file names alone, added
50 · 9 · 8 · 4 · 7 edges — 13 of 80 in files that never named the object, 11 in tests and dev
harnesses; the 2026-09-07 rerun under `files:` added 25 · 20 · 12 · 10 · 5 with nothing fenced
or dropped — the tail is reader coverage per round, see FRICTIONS
`seams-sweep-coverage-is-unmeasured`).

## The kept asset — `_docs/seams/<object>/`

The maps outlive the plan. The plan is consumed by `ac-plan` and archived; the maps are what
the next engineer reads before touching the object, and what a re-trace compares against to
prove a fix. Different lifecycles, different files. At hand-off the merge also writes:

- `map.json` — the ledger: every edge, its key, first-seen text, found-by, the fence, the
  `seams_load` counts, and `traced_at` (the repo HEAD sha the maps were traced against). This
  is the source of truth; nothing else is edited by hand.
- `map.html` — rendered FROM `map.json`: the N² grid (fenced files down, seven stages across,
  filled cells linked to `path:line`, empty cells visible — the empty cells are the finding),
  the flow map as an ordered step list with its sensors marked, the boundary map as an ICD
  table, and the load counts. One self-contained file, no CDN; a human reads this before a
  build. A markdown twin is optional — the html carries the tables as text already.

A kept map with no re-trace scheduled is decoration (the assurance doctrine). The re-trace is
the seams run's own success criterion: run it again after the fix, compare `seams_load`.

## Stale maps announce themselves — `aim.sh status`

`aim.sh status` lists every `_docs/seams/*/map.json` with three columns: the object, its
`traced_at` sha, and **drift** = the number of commits since `traced_at` that touched any file
on that map's `files:` line (`git log --oneline <traced_at>..HEAD -- <files>`). Drift 0 means
the map still describes the code. Drift > 0 lists the touching commits, so the reader knows
which files moved. A map whose drift crosses a threshold (default 5 commits, or any commit to
a `create`-stage file) is printed under **STALE — re-trace before relying on it**. That is the
whole mechanism: the map carries the sha it was true at, git knows what moved since, and the
listing does the subtraction. No cron, no hook — a read-only command the orchestrator runs at
the start of a seams or load run and the human runs whenever they open the binder.

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
