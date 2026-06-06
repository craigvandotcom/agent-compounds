# Plan Document Templates

Phase 3 selects a template by complexity and writes `_plans/YYYY-MM-DD-HHMM-[feature].md`.

| Complexity  | Criteria                              | Template Sections                                                            |
| ----------- | ------------------------------------- | ---------------------------------------------------------------------------- |
| **MINIMAL** | <3 files, clear pattern, 1-2 hours    | Summary, Success Criterion, Implementation, Validation                       |
| **MORE**    | 3-10 files, some decisions, 2-4 hours | All 7 sections (Context, Outcome, Journey, Spec, Success, Phases, Risks)     |
| **A LOT**   | >10 files, architectural, 4+ hours    | All MORE sections + Decision Log, Alternatives, Phased Rollout, Dependencies |

## For MINIMAL complexity

```markdown
---
status: draft
refinement_rounds: 0
source_backlog: _backlog/{version}/{filename}.md
---

# [Feature Name]

## Summary

[1-2 sentences]

**Type:** BUILD | IMPROVE | FIX
**Complexity:** MINIMAL

## Backlog Items (optional)

<!-- Link backlog items this plan addresses, if using a backlog system -->
<!-- e.g., _backlog/XXX-primary-item.md, GitHub issue #123, Jira ticket -->

- (primary item)
- (related, if any)

## Success Criterion

[From Phase 2]

## Test Specifications

[YAML test specs from Phase 2]

## Implementation

1. [Step 1]
2. [Step 2]
3. [Step 3]

## Validation

[How to verify success]
```

## For MORE complexity

```markdown
---
status: draft
refinement_rounds: 0
source_backlog: _backlog/{version}/{filename}.md
---

# [Feature Name]

## Summary

[1-2 sentences]

**Type:** BUILD | IMPROVE | FIX
**Complexity:** MORE

## Backlog Items

- `_backlog/XXX-primary-item.md` (primary)
- `_backlog/YYY-related-item.md` (related, if any)

## Context & Research

[Synthesized from 3 exploration reports]

## Outcome Definition

[What success looks like - from Phase 2 baseline]

## User Journey (if UI)

[Flow description]

## Technical Specification

- API contracts
- Data model changes
- Component structure

## Success Criteria

[From Phase 2 - measurable!]

## Test Specifications

[YAML test specs from Phase 2]

## Implementation Phases

### Phase 1: [Foundation]

### Phase 2: [Core Logic]

### Phase 3: [UI/Integration]

### Phase 4: [Testing]

## Risks & Mitigations

[What could go wrong]
```

## For A LOT complexity

All sections from MORE, plus:

- Decision log (alternatives considered)
- Phased rollout plan
- Detailed test matrix
- Dependencies/blockers
</content>
