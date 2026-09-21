---
status: captured
type: feature
size: M
horizon: later
source: human
dependencies: ["_plans/2026-09-21-1222-ac-review-narrowing.md"]
---

# ac-hygiene — give it the demonstrated-failure bar before it becomes the next review spiral

One-line intent: `ac-hygiene` has the multi-round, fix-in-place shape that made `ac-review` grow machinery,
and once the ac-review plan lands it is the only routine independent read of code.

## Scope

- One bar for a hygiene finding: a demonstrated failure in ordinary operation, or a violated acceptance
  criterion, with a reproducing command. "Could be bypassed" counts only against a real adversary (user
  input, auth, external data, PII, money) — never our own worker.
- Three bins: defect · hardening (a report line, never a fix or a bead) · nothing.
- A verify-only pass on serious findings BEFORE any fix lands; a fix is checked by its own probe and never
  returns to the panel.
- Fix order delete > simplify > tighten an instruction > add code; a fix that adds a guard, mode or option
  waits for Craig's yes.
- Observed machinery misbehaviour → `FRICTIONS.md`; imagined problems die in the report.
- Revisit the round count ("minimum 3 rounds for cross-round consensus") and trunk-direct fixes against
  that bar — each round's fix is new diff for the next round.
- Reconcile the lens count: `skills/ac-hygiene/SKILL.md` says "a 5-lens Opus panel",
  `skills/ac-pipeline/references/schedule.md` says "7-lens panel".

## Notes

- Origin: Craig, in conversation 2026-09-21 — out-of-scope item from the ac-review plan, asked to be
  backlogged.
- Recorded failure of this shape: epic ac-gates-ask-git-eiwk — `close-gate.sh` grew +93 lines over four
  review rounds defending hypothetical bypasses; the round-4 fix caused regression ac-1kfh.
- Depends on `_plans/2026-09-21-1222-ac-review-narrowing.md` landing first: that plan writes the bar down
  in `skills/ac-review/`, and this item should point at it rather than restate it.
- `skills/ac-pipeline/references/review-consensus.md` is shared doctrine `ac-hygiene` mirrors
  (`references/run-loop.md`, `references/run-finalize.md`) — the ac-review plan keeps it for that reason.
- `skills/ac-hygiene/MAINTENANCE.md` already notes its ac-review cross-references "go dead when review
  retires"; they go stale when the ac-review plan lands.
