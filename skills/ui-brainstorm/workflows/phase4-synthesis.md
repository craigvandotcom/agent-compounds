# Phase 4: Synthesis Workflow

**Goal:** Create actionable, digestible report from consensus rankings

**Input:** Consensus rankings from Phase 3
**Output:** Final report with top ideas, rationale, tradeoffs, and recommendations

---

## Meta-Model Synthesis

Use Claude Opus (highest reasoning capability) to synthesize findings.

**Why Opus:**

- Superior analysis of multi-model disagreements
- Better at identifying subtle tradeoffs
- Stronger synthesis of competing perspectives

---

## Synthesis Prompt

**Execute in Claude Code (or via openrouter if using Opus tier):**

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
```

---

## Expected Output Structure

Meta-model should produce:

```markdown
# UI Brainstorm Synthesis Report

**Project:** [name]
**Date:** [timestamp]
**Screenshot:** [path]

## Executive Summary

[2-3 sentences: What consensus found, primary recommendation, confidence level]

---

## Top 3 Consensus Ideas

### 1. [Idea Title] (44/45 points, variance: 1.0)

**Why Consensus Formed:**

- All models agreed on high usability impact
- Strong brand alignment with minimal feasibility risk
- Addresses core user pain point directly

**Key Tradeoffs:**

- Reduces visual innovation for reliability
- Requires A/B testing to validate assumptions

**Implementation Complexity:** Medium

- 2-3 day development effort
- Existing component library supports this

**Expected User Impact:**

- 20-30% reduction in task completion time
- Improved accessibility (WCAG AA compliance)

**Next Steps:**

- [ ] Create clickable prototype in Figma
- [ ] Run 5-user usability test
- [ ] Validate with analytics data

---

### 2. [Idea Title] (38/45 points, variance: 6.9)

**Why Consensus Formed:**

- High innovation score across all models
- Differentiates from competitors effectively

**Key Tradeoffs:**

- Gemini noted higher implementation complexity (rank 7)
- Risk: Users may not understand novel pattern

**Implementation Complexity:** High

- 5-7 day development effort
- Requires custom components

**Expected User Impact:**

- Significant brand differentiation
- May require user education/onboarding

**Next Steps:**

- [ ] Prototype to test comprehension
- [ ] Competitive analysis: has anyone done this well?
- [ ] Plan gradual rollout strategy

---

### 3. [Idea Title] (35/45 points, variance: 3.2)

[Continue pattern]

---

## Controversial Ideas Worth Discussing

### Idea [N] - [Title] (28/45 points, variance: 12.3)

**What Caused Disagreement:**

- GPT ranked #14: Cited feasibility concerns (3-week implementation)
- Claude ranked #2: Saw breakthrough innovation potential
- Gemini ranked #5: Middle ground, flagged user testing needs

**Minority Perspective (GPT's concern):**
"While visually compelling, this requires rebuilding core navigation. Implementation risk outweighs innovation value for current sprint priorities."

**When This Might Be Right:**

- If roadmap extends to Q2 (more time available)
- If user testing shows navigation is critical pain point
- If competitor launches similar feature first

**Recommendation:** Archive for future consideration, revisit in 3 months.

---

## Synthesized Recommendation

### Primary Path: Implement Idea 1 + Idea 3

**Rationale:**

- Both have strong consensus (low variance)
- Complementary changes (don't conflict)
- Combined implementation: 5-7 days
- Lower risk, proven patterns

**Timeline:**

- Week 1: Idea 1 (quick win, validates direction)
- Week 2: Idea 3 (builds on momentum)

**Success Metrics:**

- Task completion time (target: -25%)
- User satisfaction score (target: +15%)
- Support tickets (target: -30%)

---

### Alternative Path (if more resources available): Idea 2

**When to choose:**

- Sprint timeline extends to 3 weeks
- Competitive pressure requires differentiation
- User testing validates novel pattern comprehension

**Timeline:**

- Week 1-2: Prototype + user testing
- Week 3: Implementation (if testing succeeds)

---

### Red Flags to Watch

**During Implementation:**

- Scope creep: Stick to original idea, resist "while we're here" additions
- Brand drift: Reference brand guidelines before finalizing visuals
- Accessibility regression: Test with screen readers before launch

**Post-Launch:**

- User confusion: Monitor support tickets for pattern misunderstanding
- Mobile breakage: Test all breakpoints, not just desktop
- Performance: Monitor bundle size if adding new components

---

## Next Steps Checklist

**Immediate Actions:**

- [ ] Review this report with stakeholders
- [ ] Decide: Primary path or Alternative path
- [ ] Create design mockups for chosen idea(s)
- [ ] Schedule user testing session (5 users minimum)

**Design Phase:**

- [ ] Generate mockups (v0.dev, Figma, or screenshot-to-code)
- [ ] Validate against brand guidelines
- [ ] Prototype interactive elements if needed

**Validation Phase:**

- [ ] User testing with chosen idea
- [ ] Accessibility audit (WCAG checklist)
- [ ] Cross-browser testing plan

**Implementation Phase:**

- [ ] Break into tickets/subtasks
- [ ] Assign to sprint backlog
- [ ] Set success metrics baseline (before implementation)

---

## Learnings for Future Brainstorms

**What Worked:**

- [Note patterns that led to consensus]
- [Which rubric criteria mattered most]

**What to Improve:**

- [Where models disagreed most]
- [Rubric weights to adjust]

**Model Performance:**

- Claude: [Tendencies observed]
- GPT: [Tendencies observed]
- Gemini: [Tendencies observed]

**Save to playbook:** `cm context "ui brainstorm" --json`
```

---

## Saving the Report

**File:** `knowledge/2-areas/software/design-critiques/YYYY-MM-DD-[project]-final-report.md`

**Index Update:**

Add entry to `knowledge/2-areas/software/design-critiques/_index.md`:

```markdown
## [Project] - [Date]

**Consensus Winner:** [Idea title]
**Score:** [X/45]
**Status:** [Pending/In Progress/Implemented/Rejected]
**File:** [Link to report]
```

---

## Quality Checks

Before delivering to user:

- [ ] Executive summary is scannable (mobile-friendly)
- [ ] Top 3 ideas clearly articulated
- [ ] Tradeoffs honestly presented
- [ ] Implementation complexity realistic
- [ ] Next steps actionable (not vague)
- [ ] Controversial ideas explored (minority views preserved)
- [ ] Recommendation is decisive (not "it depends")
- [ ] Red flags identified proactively

---

## Common Enhancements

**Optional additions if time allows:**

### Visual Comparison Table

```markdown
| Criterion           | Idea 1 | Idea 2 | Idea 3 |
| ------------------- | ------ | ------ | ------ |
| Visual Appeal       | 4.5/5  | 5/5    | 3.5/5  |
| Usability           | 5/5    | 3.5/5  | 4.5/5  |
| Brand Alignment     | 4/5    | 4.5/5  | 4/5    |
| Innovation          | 3/5    | 5/5    | 3.5/5  |
| Feasibility         | 4.5/5  | 2.5/5  | 4/5    |
| **Consensus Score** | 44/45  | 38/45  | 35/45  |
```

### Decision Matrix

```markdown
## Decision Criteria Comparison

| Factor         | Idea 1 | Idea 2    | Idea 3 | Winner   |
| -------------- | ------ | --------- | ------ | -------- |
| Time to market | 3 days | 7 days    | 3 days | Idea 1/3 |
| User impact    | High   | Very High | Medium | Idea 2   |
| Risk level     | Low    | High      | Low    | Idea 1/3 |
| Cost           | $500   | $2000     | $500   | Idea 1/3 |
```

### Mockup References

```markdown
## Mockup Previews

### Idea 1: [Title]

![Mockup](path/to/mockup.png)
[Link to interactive prototype]

[Repeat for top ideas]
```

---

## Time Estimate

- Meta-model synthesis: 2-3 minutes
- Manual formatting/cleanup: 2 minutes
- Saving and indexing: 1 minute

**Total: ~5-8 minutes**

---

## Delivery to User

**Present report with:**

1. **Executive Summary** (read this first)
2. **Primary Recommendation** (your call to action)
3. **Full Report** (for stakeholder review)
4. **Next Steps** (ready to execute)

**Ask:**

- "Does the primary recommendation align with your constraints?"
- "Should we proceed to mockups, or run refinement round?"
- "Any controversial ideas you want to explore further?"

---

**Next:** `phase5-iteration.md` for refinement support
