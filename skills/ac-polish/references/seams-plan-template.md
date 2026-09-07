---
status: findings
target: <the area as the user gave it>
object: <table.column · Symbol · eventName: the object's own names, symbols ONLY, no paths, no dash. A `table.column` term needs both words; never the bare column name>
files: <the output of `aim.sh files --terms '<object line>'`: every source file naming a term as a whole word, minus tests and dev harnesses. The closed set the readers sweep; a row in ANY lens counts only if its file is on this line. Widen by adding a term to `object:` and recomputing>
flows: <flow · flow: the object's edges in time order; a flow row counts only if its name shares a word with one AND its file is on `files:`>
boundaries: <interface · interface: what the edges cross; a boundary row counts only if its name shares a word with one AND its file is on `files:`. A far side that handles the payload without naming it is fenced with its reason: widen with the name it does use>
weight: <touching files × layers, from the resolution grep: why this object was chosen>
aim_window: <1w | 4w | 1y | all | none>
---

# seams — <object>

## Problem

<What the object is and what its life looks like, in one paragraph, written by the
orchestrator at hand-off FROM THE MAPS: which stages exist and which are missing, how many
writers, which steps nobody senses, which assumptions nothing asserts. Never written by a reader.
End with the north star as this object's success criterion: the four `seams_load` counts the
hand-off wrote above — competing writers → one owner per mutating stage · unasserted edges → 0
· unsensed steps → 0 · unchecked assumptions → 0 · untrusted inputs → 0 — re-derived after the
fix, by a trace.>

<!-- seams-merge: everything below this line is generated -->

_`scripts/seams-merge.py round` writes the three maps here each round — object (stage × path)
· flow (flow × path) · boundary (interface × side × path) — first-seen text, exact keys, so the
digest moves only when an edge is added or dropped in any of them. Rows outside the three
fence lines above never reach the maps; the round line lists them with the reason. `seams-merge.py handoff`
replaces them with Maps · Seams seen by more than one lens (first) · Seams derived per lens ·
Seams from reader diagnosis (by reader count) · Journey (from the flow map, for ac-qa) ·
Approach (empty, for `ac-plan`)._
