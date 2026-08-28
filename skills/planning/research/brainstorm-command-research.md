# Brainstorm Command Research

**Date:** 2026-01-29
**Purpose:** Research proven brainstorming/ideation approaches to inform a `/brainstorm` slash command

---

## Executive Summary

A brainstorm command should precede `/ac2-plan` when you're **uncertain about the approach** or want to **explore possibilities** before committing to a plan. Key insight: Jeffrey Emanuel doesn't have a separate ideation phase—he weaves it throughout development. But for pre-planning uncertainty, a structured brainstorm phase can reduce planning iterations.

**Recommended approach:** Combine Jeffrey's "100→10 Filter" with multi-model competitive brainstorming, structured around proven frameworks (Six Hats, SCAMPER).

---

## Part 1: Jeffrey Emanuel's Ideation Methodology

### Key Finding: No Separate Ideation Phase

Jeffrey's workflow doesn't have formal "ideation before planning." Instead:

- **Ideation starts with a rough concept** (1-2 paragraph initial prompt)
- **Features emerge through iterative "what if?" prompts** during development
- **Major ideation happens mid-project** via competitive brainstorming sessions

**Pattern:** rough concept → plan → implement → "what else could we add?" → ideate → plan → implement

### The 100→10 Filter (Creative Brainstorming)

Jeffrey's core ideation prompt:

```
Ok, now I want you to be super creative and come up with your very best 10 ideas
for what would make this project even more useful and compelling and handy and
powerful and versatile for both human users AND AI agents like yourself.

Before proposing your best 10 ideas, I want you to carefully think of and model
out, project forward, evaluate, a minimum of 100 potential creative ideas, so be
prepared to think for a super long time about all this before responding!!!
```

**Key elements:**

- Request top 10 ideas
- **Require 100+ ideas to be considered first** (forces deep thinking)
- Optimize for both humans AND AI agents
- Focus on useful, compelling, powerful, versatile

### Multi-Model Competitive Analysis

```
I asked a competing coding agent (Gemini 3) about this project to [SAME PROMPT]
and here are its best ideas below; I want you to very carefully consider and
evaluate each of them and then give me your candid evaluation and score them
from 0 (worst) to 1000 (best) as an overall score that reflects:

- How good and smart the idea is
- How useful in practical, real-life scenarios it would be
- How practical it would be to implement correctly
- Whether the utility/advantages justify the increased complexity and tech debt

Use ultrathink.
```

**The competitive loop:**

1. Ask Model A for top 10 ideas
2. Ask Model B for top 10 ideas
3. Have Model C evaluate both sets
4. Select top-ranked ideas across all models
5. Blend best ideas into unified roadmap

### Evaluation Criteria (0-1000 scale)

| Criterion                  | Question                                |
| -------------------------- | --------------------------------------- |
| Concept Quality            | Is the idea fundamentally sound?        |
| Human Utility              | Does it solve real problems for humans? |
| AI Agent Utility           | Does it meaningfully help agents?       |
| Implementation Feasibility | Can it be built correctly?              |
| Complexity/Debt Ratio      | Is the juice worth the squeeze?         |

### Escalation/Refinement ("I Know You Can Do Better")

```
Ok, that's an amazing start but I know you can make this MUCH MUCH MUCH better
across every dimension we discussed. [LIST SPECIFIC IMPROVEMENTS]:

- [Improvement area 1]
- [Improvement area 2]
- [Improvement area 3]

You need to think super hard about how to improve DRAMATICALLY in all of those
categories. Use ultrathink.
```

---

## Part 2: Kieran's Swarm Orchestration (Parallel Brainstorming)

### Potential Architecture

Could spawn 3 parallel brainstorming agents with different lenses:

- **Optimist Agent:** What's the ideal outcome? Best-case scenarios?
- **Critic Agent:** What could go wrong? Edge cases? Risks?
- **Innovator Agent:** What unconventional approaches exist?

Results synthesized by orchestrator.

### Task System Integration

```javascript
TaskCreate({ subject: "Optimist brainstorm", ... })
TaskCreate({ subject: "Critic brainstorm", ... })
TaskCreate({ subject: "Innovator brainstorm", ... })
TaskCreate({ subject: "Synthesis", addBlockedBy: ["1", "2", "3"] })
```

---

## Part 3: Existing Planning Skill Assets

### Round 3: DIVERGE Prompt

Already exists at `planning/prompts/round-3-diverge.md`:

**Phase 1:** Generate 15-20 ideas (alternatives, features, simplifications, unconventional)
**Phase 2:** Filter with ✅ KEEP / ❌ REJECT rationale
**Phase 3:** Top 5 detailed with implementation diffs

This is post-plan divergence. A `/brainstorm` command would be **pre-plan** divergence.

### Gap: Pre-Plan Discovery

Missing workflow for when you:

- Don't know what approach to take
- Have multiple competing visions
- Need to explore the solution space
- Want to validate assumptions before planning

---

## Part 4: Proven Brainstorming Frameworks

### Six Thinking Hats (Edward de Bono)

| Hat    | Focus      | Question                                 |
| ------ | ---------- | ---------------------------------------- |
| White  | Facts      | What data do we have? What's missing?    |
| Red    | Emotions   | How do I feel about this? Gut reaction?  |
| Black  | Caution    | What are the risks? What could go wrong? |
| Yellow | Optimism   | What are the benefits? Best-case?        |
| Green  | Creativity | What alternatives exist? New ideas?      |
| Blue   | Process    | What's our thinking process? Next steps? |

**For AI:** Could prompt Claude to "wear each hat" sequentially.

### SCAMPER Technique

| Letter | Action           | Question                             |
| ------ | ---------------- | ------------------------------------ |
| S      | Substitute       | What can be replaced?                |
| C      | Combine          | What can be merged?                  |
| A      | Adapt            | What can be borrowed from elsewhere? |
| M      | Modify           | What can be changed?                 |
| P      | Put to other use | Other applications?                  |
| E      | Eliminate        | What can be removed?                 |
| R      | Reverse          | What if we did the opposite?         |

### Double Diamond Design

```
DISCOVER → DEFINE → DEVELOP → DELIVER
   ↓          ↓         ↓          ↓
Diverge    Converge   Diverge   Converge
```

**Phase 1 (Discover):** Diverge—explore problem space broadly
**Phase 2 (Define):** Converge—narrow to core problem
**Phase 3 (Develop):** Diverge—explore solutions
**Phase 4 (Deliver):** Converge—select and refine solution

A `/brainstorm` command maps to **Discover + Define** (before planning).

### Reverse Brainstorming

"How could we make this fail?" → Identify failure modes → Invert to find solutions

### Controlled Hallucination for Ideation (CHI)

```
Generate 5 innovative ideas, even if speculative, then rank them by feasibility.
```

Intentionally allow creative "hallucinations" within bounds, then refine.

---

## Part 5: Claude-Specific Best Practices

### Extended Thinking Activation

- "Use ultrathink" (Jeffrey's term)
- "Think step by step about this"
- "Consider at least 100 possibilities before responding"

### Constraint-Based Prompting

The "7-word technique"—forcing concise problem statements improves output quality.

### Iteration Patterns

1. **Time-boxed sprints** with rotating constraints
2. **Working in passes:** outline → variations → evaluate → select
3. **Follow-up drilling:** "Take idea #7 and brainstorm 5 angles"

### Multi-Model Strategy

| Model       | Best For                                |
| ----------- | --------------------------------------- |
| Claude Opus | Creative, nuanced ideas                 |
| GPT-4/o3    | Structured, methodical output           |
| Gemini      | Different perspective, cross-validation |

---

## Part 6: Proposed `/brainstorm` Command Design

### When to Use

- **Before `/ac2-plan`** when uncertain about approach
- **Problem is ambiguous** and needs clarification
- **Multiple valid solutions** and need to explore
- **Innovation needed** beyond obvious approach
- **Stuck** and need fresh perspective

### Workflow Options

#### Option A: Single-Agent Deep Dive (Simple)

1. **Problem Statement** → User describes the challenge
2. **100→10 Generation** → Claude generates 100+ ideas, picks top 10
3. **Evaluation** → Score each idea on 5 criteria (0-1000)
4. **Synthesis** → Recommend top 3 with rationale
5. **Output** → Markdown brief feeding into `/ac2-plan`

#### Option B: Six Hats Sequential (Thorough)

1. **White Hat** → Gather facts about problem/codebase
2. **Green Hat** → Generate creative solutions
3. **Yellow Hat** → Identify benefits of each
4. **Black Hat** → Identify risks/downsides
5. **Red Hat** → Gut feel ranking
6. **Blue Hat** → Synthesize and recommend
7. **Output** → Structured brief for planning

#### Option C: Parallel Multi-Perspective (Powerful)

1. **Spawn 3 agents** with different lenses (Optimist, Critic, Innovator)
2. **Parallel brainstorming** with same problem statement
3. **Synthesis agent** evaluates and blends results
4. **Output** → Comprehensive options brief

#### Option D: Competitive Multi-Model (Jeffrey's Way)

1. **Get ideas from Claude**
2. **Get ideas from GPT (via web)**
3. **Have Claude evaluate both**
4. **Blend best ideas**
5. **Output** → Hybrid roadmap

### Recommended: Hybrid Approach

```
/brainstorm [topic]

Phase 1: DISCOVER (Diverge)
- Extract problem statement
- Gather codebase context (code-explorer agent)
- Generate 50+ raw ideas using SCAMPER + Six Hats prompts

Phase 2: DEFINE (Converge)
- Filter to top 10 using Jeffrey's criteria
- Score each idea (0-1000)
- Identify top 3 approaches

Phase 3: OUTPUT
- Write brainstorm brief to .claude/plans/research/
- List recommended approach + 2 alternatives
- Note key decisions/tradeoffs for user

→ User reviews brief
→ Selects direction (or requests another round)
→ Proceeds to /ac2-plan with clarity
```

### Output Format

`.claude/plans/research/YYYY-MM-DD-HHMM-brainstorm-[topic].md`

```markdown
# Brainstorm: [Topic]

**Date:** YYYY-MM-DD
**Status:** Ready for Planning

## Problem Statement

[Clear articulation of what we're trying to solve]

## Discovery Context

[Relevant codebase patterns, constraints, prior art]

## Ideas Explored (Top 10)

| Rank | Idea | Score | Pros | Cons |
| ---- | ---- | ----- | ---- | ---- |
| 1    | ...  | 850   | ...  | ...  |

## Recommended Approach

**Primary:** [Approach with rationale]

### Alternatives Considered

- **Option B:** [Brief description + when to choose]
- **Option C:** [Brief description + when to choose]

## Key Decisions for Planning

- [ ] Decision 1: [options]
- [ ] Decision 2: [options]

## Next Steps

→ `/ac2-plan` using [recommended approach]
```

---

## Part 7: Implementation Considerations

### Integration Points

- Feeds into `/ac2-plan` (output becomes plan input)
- Could use existing code-explorer agents for context
- Leverages existing planning skill templates

### Model Selection

- **Brainstorming:** Claude Opus (creative, nuanced)
- **Context Gathering:** Haiku (fast, cheap)
- **Evaluation:** Could try multi-model for diversity

### Time Investment

- Quick mode: 10-15 minutes
- Thorough mode: 30-45 minutes
- Full competitive: 1-2 hours (includes manual model switching)

### Triggers

- "Not sure how to approach..."
- "Multiple ways to do this..."
- "Need to explore options..."
- "What's the best way to..."
- Explicit `/brainstorm [topic]`

---

## Sources

### Primary

- Jeffrey Emanuel — Ideation Methodology (agentic-engineering research notes)
- Jeffrey Emanuel — Planning Methodology (agentic-engineering research notes)
- Kieran — Swarm Orchestration Skill (agentic-engineering research notes)
- The DIVERGE prompt — see `prompts/round-3-diverge.md` in the planning skill

### Web Sources

- [AI Brainstorming Generators (Juma)](https://juma.ai/blog/ai-brainstorming-generators)
- [AI Prompt Library - Claude Prompts](https://www.aipromptlibrary.app/blog/claude-ai-prompts-guide)
- [ClickUp Claude AI Prompts](https://clickup.com/blog/claude-ai-prompts/)
- [Claude 7-Word Technique](https://aimensa.com/claude-7-word-prompt-creativity-technique)
- [DreamHost Claude Prompt Techniques](https://www.dreamhost.com/blog/claude-prompt-engineering/)

### Frameworks

- [Double Diamond Design Process (Wikipedia)](<https://en.wikipedia.org/wiki/Double_Diamond_(design_process_model)>)
- Six Thinking Hats (Edward de Bono)
- SCAMPER Technique

---

## Next Steps

1. **Review this research** with Craig
2. **Select approach** (A, B, C, D, or Hybrid)
3. **Create skill file** at `.claude/skills/brainstorming/SKILL.md`
4. **Create command file** for `/brainstorm`
5. **Test on real problem** before general use
