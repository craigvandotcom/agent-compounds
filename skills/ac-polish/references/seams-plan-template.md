---
status: findings
target: <target as given>
resolved_to: <symbols · columns · files — the readers' TARGET RESOLVED TO lines, merged by the orchestrator>
aim_window: <1w | 4w | 1y | all | none>
---

# seams — <target>

## Problem

<What the target is and why it was studied — one paragraph, written by the orchestrator at
creation from the target and (if aimed) the aim row that chose it. Rewritten at hand-off to
cluster the Confirmed rows into the few questions the Approach must answer once. Never
written by a reader.>

<!-- seams-merge: everything below this line is generated -->

_`scripts/seams-merge.py round` writes the Candidates table here each round — first-seen
text, id order, nothing else — so the digest moves only when a candidate is added or dropped.
`seams-merge.py handoff` replaces it with Confirmed · Seen once · Declined (constraining rows
only) · Approach (empty, for `ac-plan`). Hits, declines and verifications live in
`<STATE>/ledger.json`; decline-only rows in `<STATE>/declined.md`._
