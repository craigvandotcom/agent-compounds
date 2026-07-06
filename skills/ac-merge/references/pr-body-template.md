# PR Body Template

Phase 1 constructs the PR body from gathered context (plan, beads, diff stats, quality-gate results).

```markdown
## Summary

{1-3 sentence description of what this wave implements, derived from plan + beads}

## Beads Completed

{list of beads with IDs and titles from br list}

## Changes

{diff stats summary — files changed, insertions, deletions}

## Test Coverage

{quality gate results — tests passing, lint clean, type-check clean}

## Review

{link to .claude/reviews/ report if exists, or "Local review via /ac-review"}

## Known post-merge tails

{beads labeled `post-merge` that are still open — the "Verify All Beads Closed" gate
excludes them deliberately (they can't close until this code is live), so they're
listed here instead of silently dropped. Populate with `br list --json --limit 1000
| jq '[.issues[] | select(.status != "closed") | select((.labels // []) |
index("post-merge")) | {id, title}]'` — format as a checklist: `- [ ] {id}: {title}`.
Omit this section entirely if the query returns an empty list.}

## Also carried (beyond wave scope)

{pipeline-builder Invariant 8 — the branch is the merge unit, so it may carry changes
this wave didn't author (a concurrent session's fix, a scheduled triage/ops commit).
Include them by default; surface them here so nothing ships unseen. Derive from
`git diff --stat main...HEAD` + `git log --oneline main..HEAD` — list any change beyond
the wave's headline scope: `- {commit-or-file}: {what it is} ({why it's here / bead})`.
Note any deliberate EXCLUSION here too, with its reason (`WIP`/CI-fail/gitleaks/scope).
Omit this section entirely if the branch carries nothing beyond its own beads.}

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```
</content>
