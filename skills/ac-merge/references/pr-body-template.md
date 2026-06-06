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

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```
</content>
