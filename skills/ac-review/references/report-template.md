# Review Report Template

Phase 6 writes this to `.claude/reviews/YYYY-MM-DD-HHMM-[feature].md`.

```markdown
# Code Review: [Feature/Branch Name]

**Date:** YYYY-MM-DD
**Branch:** {CURRENT_BRANCH}
**Base:** {BASE_BRANCH}
**Plan:** {plan path or "none"}
**Reviewers:** Security, Performance, Architecture, Correctness
**Rounds:** {count}

---

## Summary

| Category     | Critical | High | Medium | Auto-Fixed |
| ------------ | -------- | ---- | ------ | ---------- |
| Security     | X        | Y    | Z      | A          |
| Performance  | X        | Y    | Z      | B          |
| Architecture | X        | Y    | Z      | C          |
| Correctness  | X        | Y    | Z      | D          |
| **Total**    | X        | Y    | Z      | E          |

---

## Auto-Fixed Issues

{list of issues auto-applied with finding IDs}

---

## Needs Decision

{list of NEEDS_DECISION items}

---

## All Findings

### Security
{findings}

### Performance
{findings}

### Architecture
{findings}

### Correctness
{findings}
```
</content>
