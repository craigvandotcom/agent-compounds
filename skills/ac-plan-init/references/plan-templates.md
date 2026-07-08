# Plan Document Templates

Phase 3 selects a template by complexity and writes `_plans/YYYY-MM-DD-HHMM-[feature].md`. Phase 2 working templates (tool-verification checklist, YAML test specs, baseline-vs-target) are at the end of this file.

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
**Journeys touched:** [name each from `CORE/journeys/`, or "none"; a new user-facing surface adds/updates a registry entry — schema: `_shared/verification-gate.md` §Journey registry]

## Assumptions

<!-- From the clarify step: decisions made absent an answer + any question that would change the plan. For MINIMAL, often one load-bearing assumption — or "none; the diff is unambiguous". -->

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

Each step states its own **Done when:** — a verifiable check (a test, a command, an observable result), not "looks done."

1. [Step 1] — **Done when:** [verifiable check]
2. [Step 2] — **Done when:** [verifiable check]
3. [Step 3] — **Done when:** [verifiable check]

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
**Journeys touched:** [name each from `CORE/journeys/`, or "none"; a new user-facing surface adds/updates a registry entry — schema: `_shared/verification-gate.md` §Journey registry]

## Assumptions

<!-- From the clarify step (ac-plan-init): decisions made absent an answer + the questions that would change the plan if answered differently. Refinement/review pressure-test THESE, not hidden assumptions. -->

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

Each phase states a **Done when:** — a verifiable completion check (a test passing, a command's output, an observable behavior) the implementer can self-check, not a judgment call.

### Phase 1: [Foundation]
**Done when:** [verifiable check]

### Phase 2: [Core Logic]
**Done when:** [verifiable check]

### Phase 3: [UI/Integration]
**Done when:** [verifiable check]

### Phase 4: [Testing]
**Done when:** [verifiable check]

## Risks & Mitigations

[What could go wrong]
```

## For A LOT complexity

All sections from MORE, plus:

- Decision log (alternatives considered)
- Phased rollout plan
- Detailed test matrix
- Dependencies/blockers

---

# Phase 2 working templates

Used during SKILL.md Phase 2 (validation baseline), before the plan doc is written. Fill these as instructed at Steps 3, 5, and 6.

## Phase 2 Step 3 — Tool Verification Checklist

```markdown
## Tool Verification Checklist

### Unit/Integration Tests

- [ ] Run project test command (see AGENTS.md > Project Commands > Test)
- [ ] Result: [X passing / Y failing]
- [ ] Status: Can run tests | BLOCKED

### Browser Access (if available)

- [ ] Navigate to: /[relevant-page]
- [ ] Result: [Can access | Cannot access]
- [ ] Status: Can browse | BLOCKED | N/A

### Dev Server

- [ ] Check: dev server running (see AGENTS.md > Project Commands > Dev server)
- [ ] Result: [Running | Not running]
- [ ] Status: Accessible | BLOCKED

### API Endpoints (if applicable)

- [ ] Endpoint: /api/[endpoint]
- [ ] Result: [Response code]
- [ ] Status: Reachable | BLOCKED
```

## Phase 2 Step 5 — Test Specifications (YAML skeleton)

```yaml
## Test Specifications

test_specs:
  silver_bullet:
    file: '[test-file-path]'
    type: 'Journey' # Journey | Screenshot | API | Performance | Custom
    description: '[What this test verifies]'
    assertions:
      - '[First assertion]'
      - '[Second assertion]'
      - '[Third assertion]'

  supporting_tests:
    - name: '[Test 1 Name]'
      file: '[unit-test-file-path]'
      type: 'Unit'
      description: '[What it verifies]'
      cases:
        - '[happy path]'
        - '[edge case]'
        - '[error case]'

    - name: '[Test 2 Name]'
      file: '[integration-test-file-path]'
      type: 'Integration'
      description: '[What it verifies]'
      cases:
        - '[case 1]'
        - '[case 2]'
```

## Phase 2 Step 6 — Baseline vs Target

```markdown
## Baseline vs Target

| Aspect         | Current State      | Target State        |
| -------------- | ------------------ | ------------------- |
| [Feature area] | [What exists now]  | [What should exist] |
| [Behavior]     | [Current behavior] | [Desired behavior]  |
| [Test status]  | [Current coverage] | [Expected coverage] |
```
