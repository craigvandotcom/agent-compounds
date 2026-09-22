# Review Report Template

One report per hand-run review. The operator runs `ac-review <range>` and writes the
report into `.claude/reviews/`. Nothing advances a mark and nothing machine-reads this
file: a batch is everything since the last `v*` tag, and where one ends is not this
report's business.

`**Range:**` records what was reviewed and nothing more. It is MANDATORY in every report,
and it is read by a human: `**Range:** <base-sha>..<head-sha>` — **full 40-char SHAs**, one
pair, nothing else on the line. A diff that is not a contiguous `A..B` gets one line per
contiguous span.

```markdown
# Review Report: [Range or Feature Name]

**Date:** YYYY-MM-DD
**Range:** {BASE_SHA}..{HEAD_SHA}
**Plan:** {plan path or "none"}
**Panel:** {the lenses that actually ran — correctness, test-quality, and security or contracts}
**Verify round:** {confirmed/refuted counts, or "none (no Critical/High)"}
**Degraded:** {no | solo (trigger=…; lenses=…) — REQUIRED in both states, `ac-pipeline/references/degraded-mode.md` § 3}

---

## Summary

{1-3 sentences on what was reviewed and what the review found.}

## Beads in range

{The beads this range closed, with IDs and titles — the correctness lens checks each
closed bead's GREEN against this diff. "none" otherwise.}

## Changes

{diff stats summary — files changed, insertions, deletions. Derive from
`git diff --stat {BASE_SHA}..HEAD`.}

## Test Coverage

{Quality-gate results — tests passing, lint clean, type-check clean; or "not run (hand
review)".}

## Review

### Defects

{Each confirmed Critical/High finding, one per line: title, `file:line`, the reproducing
command, and the bead id it was filed as. "none" otherwise.}

### Hardening

{One line per hardening finding — real but not demonstrated, or reachable only through a
contrived precondition. A refuted finding stays here with the verifier's reason and the
probe output; it is never deleted. Imagined problems end here and never become a bead.}

### Checked, nothing found

{One line per lens saying what it checked. Silence is not coverage.}

**VERDICT:** {APPROVED | NEEDS_DECISION}

## Plan fidelity

{Does the diff still match the plan's `## Vision` and `## Out of scope`? Name any drift
with its probe — the net line change on the plan's named files after its last deliverable
commit. "No drift" otherwise.}

## Known post-merge tails

{beads labeled `post-merge` that are still open — they cannot close until this code is
live, so they are listed here rather than silently dropped. Populate with
`br list --json --limit 0 | jq '[.issues[] | select(.status != "closed") | select((.labels // []) | index("post-merge")) | {id, title}]'`;
format as a checklist: `- [ ] {id}: {title}`. Omit this section entirely if the query
returns an empty list.}

## Also carried (not this range's beads)

{Run `git log --oneline {BASE_SHA}..HEAD` + `git diff --stat {BASE_SHA}..HEAD` and list any
change beyond the range's headline scope: `- {commit-or-file}: {what it is} ({why / bead})`.
Note any deliberate EXCLUSION with its reason (`WIP`/CI-fail/gitleaks/scope). Omit only
after you have actually diffed to confirm the range carries nothing else.}

## Friction

{Machinery that misbehaved or cost time this run — deduplicated, recurrence-counted. Its
home is the skill's `FRICTIONS.md`; this section carries the summary. "none" otherwise.}
```
