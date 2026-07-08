# Incidents & rationale — full narratives

Full stories behind rules that appear compressed (rule + one-clause why) in
SKILL.md. Read only when questioning, revising, or defending one of those rules.

## 2026-07-04 — ungrounded "Critical" perf severity rode the auto-fix cascade

Why the Phase-3 conductor check downgrades unquantified Critical/High performance
findings: perf severities are the least grounded review dimension — reviewers
pattern-match allocation/loop shapes without estimating magnitude. Observed
2026-07-04: a "Critical" rating on a ~sub-millisecond map copy whose own cited
numbers contradicted the rating, riding the severity cascade unchallenged. The fix:
a performance finding rated Critical/High whose evidence carries no quantified
impact estimate (N × unit cost weighed against the operation's real budget) is
downgraded to Medium and re-routed through the deferred/design-decision gate, with
the downgrade noted in the report. Correctness/security severities are exempt —
they don't share this pattern-match failure mode.

## Proportional effort — why Phase 5 scales expensive checks to diff risk

ac-review is a branch review, **not** the green-main boundary — the exhaustive run
is the loop-close CI full `test:all` (parallel-execution doctrine §5). Running a
full FORMAT+LINT+TYPECHECK+TEST+BUILD battery on every wave (including docs-only
ones) violates *proportional effort: incremental in the loop, exhaustive at the
boundary*. Hence the Phase-5 rule: cheap checks always; expensive ones (full test,
build) scaled to the diff's risk class via `_shared/verification-gate.md` Step 1.
