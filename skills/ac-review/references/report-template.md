# Review Report Template

One report per shipped batch, ONE template — there is no parallel `.claude/batch-closes/`
home. This file is the **single source of truth** for the shared report sections (Summary,
Beads Completed, Changes, Test Coverage, Known post-merge tails, Also carried); `ac-batch-close`
Phase 5 references these sections rather than re-specifying them, and appends only its own
**Deploy** section — edit the shared sections HERE, not there. Destination is set by the
invocation (C4 mode switch, already built in the `ac-review` rewrite — this template does not
decide it):

- **Batch-close invocation** (`ac-batch-close` passes `report_dest=.claude/reviews/pending/`) →
  writes to `.claude/reviews/pending/YYYY-MM-DD-HHMM-[batch-anchor].md`. This does **not**
  advance the review-mark: `ac-batch-close`'s Act 3 `git mv`s this file into
  `.claude/reviews/batch/` in the same commit that lands the batch-close summary, and that
  single commit is the mark (bd-kudrb — a report committed straight into `batch/` mid-batch
  was returned by the anchor probe as a commit inside its own range). Under trunk-direct this
  report IS the batch's shipped record — there is no PR diff to eyeball, so the PR-body
  sections below carry the weight the PR description used to.
- **Standalone / mid-batch invocation** → writes to `.claude/reviews/YYYY-MM-DD-HHMM-[feature].md`
  (root, does not advance the review-mark). The PR-body sections are optional here: fill
  **Changes**, **Test Coverage**, **Review**; **Beads Completed** / **Known post-merge tails** /
  **Also carried** may read "N/A (standalone review)".

### The `Range:` field is the coverage record — it is MANDATORY in every mode (bd-zl1y5)

Not advancing the review-mark is **not** the same as not counting. The mark
(`.claude/reviews/batch/`) records *acceptance* — that a batch was closed. What has actually been
**reviewed** is computed directory-agnostically by `ac-pipeline/references/board-scan.md` **Scan D**, as the union
of the `Range:` claims in every artifact under `.claude/reviews/**` (root, `pending/`, `publish/`,
`batch/` alike). So this one line is the entire machine-readable coverage record of a review.

- **Format is parsed, not read:** `**Range:** <base-sha>..<head-sha>` — **full 40-char SHAs**, one
  pair, nothing else on the line. Scan D anchors on `Range:` and extracts `[0-9a-f]{7,40}\.\.`;
  prose in this field (`"the families series"`, `"main since Tuesday"`) is silently uncountable.
- **A bead-scoped or partial review still records a range.** If the diff you reviewed is not a
  contiguous `A..B`, emit one `**Range:**` line per contiguous span — every line is unioned.
### The `Panel:` field is the denominator — MANDATORY, and copied from consensus, not memory

**A verdict without a denominator is not a verdict.** Fill `Panel:` verbatim from
`consensus-round-{N}.json`'s `panel_source` / `reviewers_expected` / `panel_skipped` — the
panel that ACTUALLY ran, never the panel you meant to run. Hardcoding a reviewer list here is
what let a run that silently dropped two dimensions (one Critical among them) read as a normal
full review; `consensus.py` now hard-fails on an unconfirmable panel, and this line is how a
degraded-but-legitimate run (`--expect`, a deliberate skip) stays visible after the fact
(bd-axeyx).

- **Omitting it is a silent-false-green**, the same defect family as bd-kudrb: the review really
  happened and the commits still read as unreviewed. Reviews that skipped it are precisely why the
  measured blackout could only be stated as an upper bound ("~88 code-ish, some may be reviewed
  and simply not machine-attributable"). An unfilled field makes the gate unable to tell.

```markdown
# Review Report: [Batch Anchor / Feature Name]

**Date:** YYYY-MM-DD
**Mode:** {batch-close | standalone}
**Range:** {BASE_SHA}..{HEAD_SHA}
**Plan:** {plan path or "none"}
**Panel ({panel_source}):** {reviewers_expected} — skipped: {panel_skipped, or "none"}
**Rounds:** {count}
**Degraded:** {no | solo (trigger=…; lenses=…) — REQUIRED in both states, `ac-pipeline/references/degraded-mode.md` § 3}

---

## Summary

{1-3 sentence description of what this batch shipped, derived from plan + beads. For a
standalone review, describe the diff under review.}

## Beads Completed

{list of beads with IDs and titles from `br list` — the beads this batch closed. Standalone
review with no batch: "N/A (standalone review)".}

## Changes

{diff stats summary — files changed, insertions, deletions. Derive from
`git diff --stat {BASE_SHA}..HEAD` (batch range on main — there is no branch to diff).}

## Test Coverage

{quality-gate results — tests passing, lint clean, type-check clean; Tier 1 CI dispatch
conclusion + SHA if `ac-batch-close` ran it.}

## Review

| Category     | Critical | High | Medium | Auto-Fixed |
| ------------ | -------- | ---- | ------ | ---------- |
| Security     | X        | Y    | Z      | A          |
| Performance  | X        | Y    | Z      | B          |
| Architecture | X        | Y    | Z      | C          |
| Correctness  | X        | Y    | Z      | D          |
| **Total**    | X        | Y    | Z      | E          |

**VERDICT:** {APPROVED | NEEDS_DECISION}

### Auto-Fixed Issues

{list of issues auto-applied with finding IDs}

### Needs Decision

{list of NEEDS_DECISION items — each with the decision bead ID it was filed as}

### All Findings

#### Security
{findings}

#### Performance
{findings}

#### Architecture
{findings}

#### Correctness
{findings}

## Known post-merge tails

{beads labeled `post-merge` that are still open — the pre-close bead-closure gate (the loop's,
upstream of `ac-batch-close`) excludes them deliberately (they can't close until this code is
live), so they're listed here instead of silently dropped. Populate with
`br list --json --limit 1000 | jq '[.issues[] | select(.status != "closed") | select((.labels // []) | index("post-merge")) | {id, title}]'` —
format as a checklist: `- [ ] {id}: {title}`. Omit this section entirely if the query returns
an empty list.}

## Also carried (not this batch's beads)

> **Read this section with extra care under trunk-direct — there is no PR diff to catch an
> omission after the fact.** The commit range is the ship unit, so it may carry changes this
> batch didn't author (a concurrent session's fix, a scheduled triage/ops commit, a foreign
> WIP hunk adopted verbatim). Completeness is the whole point of this section: every such
> change is named here, never silently dropped.

{Derive from `git log --oneline {BASE_SHA}..HEAD` + `git diff --stat {BASE_SHA}..HEAD` — list
any change beyond this batch's headline scope: `- {commit-or-file}: {what it is} ({why it's
here / bead})`. Note any deliberate EXCLUSION here too, with its reason
(`WIP`/CI-fail/gitleaks/scope). Omit this section entirely only if the range carries nothing
beyond this batch's own beads — and only after you have actually diffed to confirm that.}
```
</content>
