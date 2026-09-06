---
status: findings
target: <the area as the user gave it>
object: <table.column · Symbol — the object fence: an object row counts only if its file names one of these as a whole word; never the bare column name>
flows: <flow · flow — the object's edges in time order; a flow row counts only if its name shares a word with one>
boundaries: <interface · interface — what the edges cross; a boundary row counts only if its name shares a word with one; the far side's file is never fenced>
weight: <touching files × layers, from the resolution grep — why this object was chosen>
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
