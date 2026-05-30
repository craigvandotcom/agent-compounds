---
name: brainstorming
description: Pre-planning exploration and ideation using divergent-convergent methodology
---

> **Generic skill — method only, zero app facts.** This skill is symlinked from
> agent-compounds and shared across all neoMeta apps. It contains technique and
> patterns, not project specifics. **App specifics (project refs, schema names,
> domain rules, feature flows, env values) → read this app's
> `.claude/skills/CORE/SKILL.md`** (and the `AGENTS.md` summary it indexes).
> Do not add app-specific facts to this file — they belong in CORE.

# Brainstorming Skill

Creative exploration for uncertain problems using Jeffrey Emanuel's 100→10 Filter, Six Thinking Hats, and multi-perspective synthesis.

## When to Load This Skill

- Running `/brainstorm` command
- Uncertain about approach before planning
- Multiple valid solutions need exploration
- Innovation needed beyond obvious approach

## Core Philosophy

> "Don't over-ideate upfront—but when you're stuck, diverge wide before converging."
> — Adapted from Jeffrey Emanuel

Use this skill **before** `/plan-init` when you:

- Don't know what approach to take
- Have competing visions
- Need to validate assumptions
- Want fresh perspective

## Methodology: Discover → Define → Challenge → Synthesize

Four phases with fresh agent context per phase:

| Phase | Name           | Lens                     | Agents            |
| ----- | -------------- | ------------------------ | ----------------- |
| 1     | **DISCOVER**   | Divergent exploration    | 3x Haiku parallel |
| 2     | **DEFINE**     | Convergent filtering     | 1x Sonnet         |
| 3     | **CHALLENGE**  | Escalation + stress test | 1x Opus           |
| 4     | **SYNTHESIZE** | Decision brief           | Orchestrator      |

---

## Phase Details

### Phase 1: DISCOVER (Diverge)

**Purpose:** Gather context + generate raw ideas
**Agents:** 3 parallel code-explorer (Haiku)

- Agent A: Codebase patterns, constraints, prior art
- Agent B: Problem space exploration (what problem really?)
- Agent C: Solution space scan (what approaches exist?)

**Output:** Context brief + 50+ raw ideas (unfiltered)

### Phase 2: DEFINE (Converge)

**Purpose:** Filter and score using Jeffrey's 100→10 criteria
**Agent:** 1x Sonnet (fresh context)

**Scoring Dimensions (0-1000):**

1. Concept Quality - Is the idea fundamentally sound?
2. Human Utility - Does it solve real problems?
3. Implementation Feasibility - Can it be built correctly?
4. Complexity/Debt Ratio - Is the juice worth the squeeze?

**Output:** Ranked list with scores + top 10 detailed + top 3 recommended

### Phase 3: CHALLENGE (Escalation)

**Purpose:** "I know you can do MUCH MUCH MUCH better"
**Agent:** 1x Opus (extended thinking, fresh context)

- Challenge top 3 approaches: What's weak? What's missing?
- Generate enhanced versions or entirely new approaches
- Apply Six Hats stress-testing:
  - **Black Hat:** What could fail? Risks?
  - **Yellow Hat:** What's the upside we're missing?
  - **Green Hat:** What unconventional angle haven't we tried?

**Output:** Refined top 3 + potential breakthrough ideas

### Phase 4: SYNTHESIZE (Decision Brief)

**Purpose:** Compile final brief for user decision
**Agent:** Orchestrator (you)

- Recommended approach + rationale
- 2 alternatives with tradeoffs
- Key decisions needing user input
- Ready for `/plan-init`

**Output:** `.claude/plans/research/YYYY-MM-DD-HHMM-brainstorm-[topic].md`

---

## Output Format

### Brainstorm Brief Template

```markdown
# Brainstorm: [Topic]

**Date:** YYYY-MM-DD
**Status:** Ready for Planning

## Problem Statement

[Clear articulation of what we're trying to solve]

## Discovery Context

[Relevant codebase patterns, constraints, prior art]

## Ideas Explored (Top 10)

| Rank | Idea    | Score | Pros    | Cons    |
| ---- | ------- | ----- | ------- | ------- |
| 1    | [Title] | 850   | [Brief] | [Brief] |
| 2    | ...     | ...   | ...     | ...     |

## Recommended Approach

**Primary:** [Approach title]

**Rationale:** [Why this approach]

**Key elements:**

- [Element 1]
- [Element 2]
- [Element 3]

### Alternatives Considered

**Option B: [Title]**

- When to choose: [Criteria]
- Tradeoffs: [Brief]

**Option C: [Title]**

- When to choose: [Criteria]
- Tradeoffs: [Brief]

## Key Decisions for Planning

- [ ] Decision 1: [Options A vs B]
- [ ] Decision 2: [Options X vs Y]

## Six Hats Stress Test

| Hat                | Finding                    |
| ------------------ | -------------------------- |
| Black (Risks)      | [Key risks identified]     |
| Yellow (Upside)    | [Opportunities identified] |
| Green (Innovation) | [Unconventional angles]    |

## Next Steps

→ `/plan-init` using [recommended approach]
```

---

## Resources

### Prompts

Located in `prompts/`:

| Prompt                 | Purpose                        |
| ---------------------- | ------------------------------ |
| `phase-1-discover.md`  | Parallel exploration prompts   |
| `phase-2-define.md`    | Filtering and scoring prompt   |
| `phase-3-challenge.md` | Escalation and Six Hats prompt |

---

## Integration Points

- **Input:** User describes challenge/uncertainty
- **Output:** Brainstorm brief feeding into `/plan-init`
- **Uses:** Existing code-explorer agents for context

---

## When NOT to Use

- Clear, well-defined tasks (just use `/plan-init`)
- Bug fixes with obvious cause
- Simple improvements (<3 files)
- Tasks with explicit requirements

---

## Sources

- [Jeffrey Emanuel Ideation Methodology](../../planning/research/brainstorm-command-research.md)
- Six Thinking Hats (Edward de Bono)
- Double Diamond Design Process
