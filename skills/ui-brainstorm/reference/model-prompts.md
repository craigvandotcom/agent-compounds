# Model Prompts Reference

Exact prompts for each phase of UI brainstorm workflow.

**Vision-native models:** All models receive actual screenshot directly (no text bridges).

---

## Phase 1: Idea Generation Prompts

### Claude Opus 4.6 Prompt (Native Vision)

```markdown
CONTEXT: [User's context about what needs improvement]

SCREENSHOT: [Attach screenshot]

TASK: Generate 5 UI/UX improvement ideas for this interface.

For each idea:

1. Title (3-5 words)
2. Description (2-3 sentences explaining the change)
3. Score against design rubric:
   - Visual Appeal (1-5): Does it look professional and engaging?
   - Usability (1-5): Is it intuitive and accessible?
   - Brand Alignment (1-5): Does it match brand identity?
   - Innovation (1-5): Does it differentiate from competitors?
   - Feasibility (1-5): Can it be implemented reasonably?

FORMAT:

## Idea [N]: [Title]

**Description:** [explanation]
**Rubric Scores:**

- Visual Appeal: [score] - [justification]
- Usability: [score] - [justification]
- Brand Alignment: [score] - [justification]
- Innovation: [score] - [justification]
- Feasibility: [score] - [justification]
  **Total:** [sum]

CONSTRAINTS:

- Each idea must be distinct (no variations of same concept)
- Focus on user impact, not technical implementation
- Justify each rubric score with specific reasoning
- Think from user's perspective (what improves their experience?)
```

---

### Gemini 3.1 Pro Prompt (Vision via OpenRouter)

**Model:** `google/gemini-3.1-pro-preview`

**CLI Usage:**

```bash
openrouter --file /tmp/gemini-prompt.txt --image [screenshot-path] -m gemini --max-tokens 2000 --raw -o /tmp/gemini-ideas.md
```

**Prompt:**

```markdown
CONTEXT: [User's context]

TASK: Generate 5 UI/UX improvement ideas for this interface.

For each idea:

1. Title (3-5 words)
2. Description (2-3 sentences)
3. Score against design rubric:
   - Visual Appeal (1-5): Professional and engaging?
   - Usability (1-5): Intuitive and accessible?
   - Brand Alignment (1-5): Matches brand identity?
   - Innovation (1-5): Differentiates from competitors?
   - Feasibility (1-5): Can be implemented reasonably?

FORMAT:

## Idea [N]: [Title]

**Description:** [explanation]
**Rubric Scores:**

- Visual Appeal: [score] - [justification]
- Usability: [score] - [justification]
- Brand Alignment: [score] - [justification]
- Innovation: [score] - [justification]
- Feasibility: [score] - [justification]
  **Total:** [sum]

CONSTRAINTS:

- Each idea must be distinct
- Focus on user impact
- Justify each score
- Think from user's perspective
```

---

### Grok 4.20 Prompt (via OpenRouter)

**Model:** `x-ai/grok-4.20-beta`

**CLI Usage:**

```bash
openrouter --file /tmp/grok-prompt.txt --image [screenshot-path] -m grok --max-tokens 2000 --raw -o /tmp/grok-ideas.md
```

**Prompt:**

```markdown
CONTEXT: [User's context]

TASK: Generate 5 UI/UX improvement ideas for this interface.

For each idea:

1. Title (3-5 words)
2. Description (2-3 sentences)
3. Score against design rubric:
   - Visual Appeal (1-5): Professional and engaging?
   - Usability (1-5): Intuitive and accessible?
   - Brand Alignment (1-5): Matches brand identity?
   - Innovation (1-5): Differentiates from competitors?
   - Feasibility (1-5): Can be implemented reasonably?

FORMAT:

## Idea [N]: [Title]

**Description:** [explanation]
**Rubric Scores:**

- Visual Appeal: [score] - [justification]
- Usability: [score] - [justification]
- Brand Alignment: [score] - [justification]
- Innovation: [score] - [justification]
- Feasibility: [score] - [justification]
  **Total:** [sum]

CONSTRAINTS:

- Each idea must be distinct
- Focus on user impact
- Justify each score
- Think from user's perspective
```

---

## Phase 2: Cross-Pollination Ranking Prompts

### Base Ranking Prompt (All Models)

```markdown
TASK: Rank these 15 UI/UX improvement ideas from best (1) to worst (15).

[Paste all 15 anonymized ideas]

RANKING CRITERIA:
Consider all 5 rubric dimensions:

- Visual Appeal (20%)
- Usability (30%)
- Brand Alignment (15%)
- Innovation (20%)
- Feasibility (15%)

OUTPUT FORMAT:

1. Idea [N] - [Brief rationale for ranking]
2. Idea [N] - [rationale]
3. Idea [N] - [rationale]
   ...
4. Idea [N] - [rationale]

OPTIONAL: New Ideas Inspired
If seeing these ideas sparked new concepts, list them:

- [New idea title]: [brief description]

CONSTRAINTS:

- Use each rank exactly once (no ties)
- Focus on user impact, not implementation complexity
- Consider cross-dimensional balance (e.g., a 4/5 in Usability might beat 5/5 in Visual Appeal)
- Justify rankings beyond just repeating original scores
- Think holistically about which ideas would most improve user experience
```

---

### Claude Opus 4.6 Ranking Prompt

```markdown
[Base ranking prompt above]

ADDITIONAL CONTEXT:
You previously generated 5 of these 15 ideas, but they are now anonymized.
Rank ALL ideas objectively, including your own. Don't favor ideas just because you created them.
Focus on which would truly deliver most user value.
```

---

### Gemini 3.1 Pro Ranking Prompt

**CLI Usage:**

```bash
openrouter --file /tmp/gemini-ranking-prompt.txt -m gemini --max-tokens 2000 --raw -o /tmp/gemini-rankings.md
```

**Prompt:**

```markdown
[Base ranking prompt above]

ADDITIONAL CONTEXT:
You previously generated 5 of these 15 ideas, but they are now anonymized.
Rank ALL ideas objectively, including your own. Don't favor ideas just because you created them.
Focus on which would truly deliver most user value.
```

---

### Grok 4.20 Ranking Prompt

**CLI Usage:**

```bash
openrouter --file /tmp/grok-ranking-prompt.txt -m grok --max-tokens 2000 --raw -o /tmp/grok-rankings.md
```

**Prompt:**

```markdown
[Base ranking prompt above]

ADDITIONAL CONTEXT:
You previously generated 5 of these 15 ideas, but they are now anonymized.
Rank ALL ideas objectively, including your own. Don't favor ideas just because you created them.
Focus on which would truly deliver most user value.
```

---

## Phase 4: Synthesis Prompt

### Meta-Model Synthesis (Claude Opus)

```markdown
CONTEXT: UI brainstorm for [project] has completed 3 phases:

1. Generated 15 ideas from 3 AI models (Claude/GPT/Gemini)
2. Each model ranked all 15 ideas
3. Calculated Borda count consensus scores

YOUR TASK: Synthesize findings into actionable report.

INPUT DATA:

## Consensus Rankings

[Paste from Phase 3 - top 5 ideas with scores, ranks, descriptions]

## Controversial Ideas (High Variance)

[Paste high-variance ideas with dissent analysis]

## Original Context

**Screenshot:** [path]
**User's Problem:** [original request]

---

SYNTHESIS REQUIREMENTS:

1. **Top 3-5 Ideas Section**
   For each top idea:
   - Why did consensus form? (What did all models see?)
   - Key tradeoffs (What sacrifices does this make?)
   - Implementation complexity (High/Medium/Low)
   - User impact (specific outcomes expected)

2. **Controversial Ideas Worth Discussing**
   For each high-variance idea:
   - What caused disagreement?
   - Minority perspective worth considering
   - When this approach might be right

3. **Synthesized Recommendation**
   - Primary recommendation (single best path forward)
   - Alternative if constraints change
   - Red flags to watch during implementation

4. **Next Steps Checklist**
   - [ ] Immediate actions
   - [ ] Design mockups needed
   - [ ] User testing considerations
   - [ ] Technical feasibility checks

FORMAT: Use markdown with clear sections, bullet points, and tables where helpful.

TONE: Direct, actionable, mobile-friendly (short paragraphs, generous whitespace).

FOCUS: Be decisive. Don't hedge. Provide clear recommendation based on consensus data.
```

---

## Phase 5: Refinement Prompt

### Variation Generation

```markdown
ORIGINAL WINNING IDEA:
[Paste winning idea from Phase 4]

USER CONSTRAINTS:
[What user wants adjusted - e.g., "make it work on mobile", "reduce implementation time", "increase visual impact"]

REFINEMENT TASK:
Generate 3 variations of the winning idea that address constraints.

For each variation:

1. Title (variation on original)
2. What changed from original
3. How it addresses constraint
4. Tradeoffs introduced
5. Updated rubric scores

FORMAT:

## Variation 1: [Title]

**Changes from Original:** [list]
**Constraint Addressed:** [how]
**New Tradeoffs:** [what's sacrificed]
**Updated Rubric:**

- Visual Appeal: [score] - [justification]
- Usability: [score] - [justification]
- Brand Alignment: [score] - [justification]
- Innovation: [score] - [justification]
- Feasibility: [score] - [justification]
  **Total:** [sum]

CONSTRAINTS:

- Stay true to original idea's core vision
- Make minimal changes to address constraint
- Maintain or improve total rubric score
- Justify all tradeoffs clearly
```

---

### Controversial Idea Deep Dive

```markdown
CONTROVERSIAL IDEA:
[Paste high-variance idea from Phase 4]

DISAGREEMENT DATA:

- Claude ranked: [X] ([points] points)
- GPT ranked: [Y] ([points] points)
- Gemini ranked: [Z] ([points] points)
- Variance: [value]

DEEP DIVE TASK:
Analyze why models disagreed and when this idea might be right.

OUTPUT STRUCTURE:

## Disagreement Root Cause

[What fundamental assumption differs across models?]

## Proponent Case (Best Argument For)

[Synthesize strongest rationale from top-ranking model]

## Opponent Case (Best Argument Against)

[Synthesize strongest rationale from bottom-ranking model]

## Conditions for Success

[Specific circumstances where this idea would win]

## De-Risking Strategy

[How to test/validate before full implementation]

## Modified Version

[Compromise that addresses opponent concerns while keeping proponent vision]

GOAL: Help user understand if this controversial idea is worth pursuing despite lack of consensus.
```

---

## Prompt Engineering Notes

### Why These Prompts Work

**Explicit formatting:**

- Models know exact structure expected
- Reduces ambiguity
- Makes aggregation easier

**Rubric-first scoring:**

- Forces structured thinking
- Prevents vague "looks good" responses
- Enables comparison across models

**Anonymization context:**

- Models told ideas are anonymized
- Reduces ego bias (ranking own ideas higher)
- Improves objectivity

**Justification requirements:**

- "Brief rationale" forces thinking
- Reveals what models value
- Helps synthesize later

**Constraint clarity:**

- Distinct ideas (no variations)
- User impact (not technical)
- No ties in ranking
- Prevents common mistakes

---

### Adaptation Guidelines

**For Domain-Specific Brainstorms:**

**Example: Mobile App UI**

```markdown
ADDITIONAL CONSTRAINTS:

- Mobile-first (320px-428px viewport)
- Touch targets ≥44px
- Single-hand usability
- Offline-first considerations
```

**Example: Enterprise Dashboard**

```markdown
ADDITIONAL CONSTRAINTS:

- Data density important
- Keyboard navigation essential
- Accessibility (WCAG AAA)
- Information hierarchy for complex data
```

**Example: Marketing Landing Page**

```markdown
ADDITIONAL CONSTRAINTS:

- Conversion-focused
- Above-the-fold impact
- Loading speed critical
- Brand differentiation from competitors
```

---

### Rubric Weight Customization

**Add to generation prompts:**

```markdown
RUBRIC WEIGHTS (adjusted for this project):

- Visual Appeal: 25% (increased - brand relaunch)
- Usability: 30%
- Brand Alignment: 10%
- Innovation: 25% (increased - competitive pressure)
- Feasibility: 10%

Weight your ideas toward these priorities.
```

**Add to ranking prompts:**

```markdown
RANKING WEIGHTS:
When comparing ideas, prioritize:

1. Visual Appeal (25%) - Most important
2. Innovation (25%) - Equally important
3. Usability (30%)
4. Feasibility (10%)
5. Brand Alignment (10%) - Least important

This is a competitive relaunch - differentiation matters more than safety.
```

---

## Copy-Paste Checklist

Before running prompts:

**Phase 1:**

- [ ] User context inserted
- [ ] Screenshot attached (Claude) or analysis pasted (GPT/Gemini)
- [ ] Rubric weights adjusted if needed
- [ ] Domain constraints added if needed

**Phase 2:**

- [ ] All 15 ideas anonymized and pasted
- [ ] Ranking constraints clear
- [ ] Optional: Self-critique step added

**Phase 4:**

- [ ] Consensus rankings pasted
- [ ] Controversial ideas pasted
- [ ] Original context included
- [ ] Expected output format clear

**Phase 5:**

- [ ] Winning idea pasted
- [ ] User constraints specified
- [ ] Expected variations count set

---

**Version:** 1.0
**Last Updated:** 2026-01-31
