# Phase 1: DISCOVER (Divergent Exploration)

**Lens:** Wide, exploratory, generative
**Mindset:** "What exists? What's possible? What's the real problem?"

---

## Overview

Phase 1 spawns 3 parallel explorers to gather diverse perspectives:

1. **Codebase Patterns Explorer** - What exists in the code?
2. **Problem Space Explorer** - What's the real problem?
3. **Solution Space Explorer** - What approaches are possible?

---

## Explorer A: Codebase Patterns

```markdown
CODEBASE PATTERNS EXPLORER

Read `.claude/skills/CORE/SKILL.md` first for project context.

**Topic:** {{TOPIC}}
**Challenge:** {{CONTEXT}}

Your job: Find existing patterns, constraints, and prior art in this codebase that relate to this topic.

Search for:

1. Similar implementations in features/
2. Related components in components/
3. Relevant utilities in lib/
4. Database patterns in supabase/
5. Any prior approaches to similar problems

Output format:

## Relevant Patterns Found

- [Pattern 1]: [location] - [how it relates]
- [Pattern 2]: [location] - [how it relates]

## Constraints Discovered

- [Constraint 1]
- [Constraint 2]

## Prior Art

- [Any previous attempts or related implementations]

## Technical Considerations

- [Tech stack implications]
- [Dependency considerations]
```

---

## Explorer B: Problem Space

```markdown
PROBLEM SPACE EXPLORER

Read `.claude/skills/CORE/SKILL.md` first for project context.

**Topic:** {{TOPIC}}
**Challenge:** {{CONTEXT}}

Your job: Deeply understand the problem we're trying to solve. Don't jump to solutions—explore the problem itself.

Investigate:

1. What is the user actually trying to accomplish?
2. What pain points exist currently?
3. What are the edge cases and variations?
4. Who else has this problem? How do they solve it?
5. What assumptions are we making?

Generate 15-20 problem-focused questions or observations.

Output format:

## Problem Understanding

[2-3 sentence articulation of the real problem]

## Key Questions

1. [Question about the problem]
2. [Question about users]
   ...15-20 questions

## Assumptions to Validate

- [Assumption 1]
- [Assumption 2]
- [Assumption 3]

## Related Problems

- [Similar problems in this domain]
- [How others have framed this]

## User Scenarios

- [Scenario 1]: [User type] wants to [goal] because [motivation]
- [Scenario 2]: ...
```

---

## Explorer C: Solution Space

```markdown
SOLUTION SPACE EXPLORER

Read `.claude/skills/CORE/SKILL.md` first for project context.
IF UI-related: Also read `.claude/skills/design-system/SKILL.md`

**Topic:** {{TOPIC}}
**Challenge:** {{CONTEXT}}

Your job: Generate as many potential approaches as possible. Quantity over quality—we'll filter later.

Use SCAMPER technique:

- **S**ubstitute: What could we replace?
- **C**ombine: What could we merge?
- **A**dapt: What can we borrow from elsewhere?
- **M**odify: What can we change?
- **P**ut to other use: Other applications?
- **E**liminate: What can we remove?
- **R**everse: What if we did the opposite?

Generate 30+ raw solution ideas. Include:

- Obvious approaches
- Unconventional approaches
- Simple approaches
- Complex approaches
- 'Crazy' approaches

Output format:

## Raw Solution Ideas (30+)

1. [Idea] - [one sentence description]
2. [Idea] - [one sentence description]
   ...30+ ideas

## Categorized Summary

### Simple/Fast (< 1 day)

- [Ideas that could be done quickly]

### Standard/Expected (1-3 days)

- [Ideas that follow typical patterns]

### Innovative/Unconventional

- [Ideas that take a different approach]

### Complex/Ambitious (> 3 days)

- [Ideas that require significant investment]

### Wild Cards

- [Ideas that seem crazy but might work]
```

---

## Variables to Inject

| Variable      | Source                                   |
| ------------- | ---------------------------------------- |
| `{{TOPIC}}`   | User's brainstorm topic                  |
| `{{CONTEXT}}` | User's challenge/uncertainty description |

---

## Expected Output

Each explorer produces a markdown file in `.claude/plans/research/`:

- `*-brainstorm-patterns-*.md`
- `*-brainstorm-problem-*.md`
- `*-brainstorm-solutions-*.md`

Combined: 50+ raw ideas + problem understanding + codebase context
