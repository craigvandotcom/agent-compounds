# Phase 2: DEFINE (Convergent Filtering)

**Lens:** Analytical, evaluative, selective
**Mindset:** "Which ideas are actually worth pursuing?"

---

## Prompt Template

```markdown
# 100→10 FILTER AND SCORING

Read `.claude/skills/brainstorming/SKILL.md` for methodology context.

**Topic:** {{TOPIC}}
**Challenge:** {{CONTEXT}}

**Discovery Context:**
{{DISCOVERY_OUTPUT}}

---

Your job: Filter the 50+ raw ideas down to the top 10 using Jeffrey Emanuel's criteria.

## Step 1: Quick Filter

Go through each idea from the Solution Space Explorer and mark:

- ✅ VIABLE: Could work, worth evaluating further
- ❌ REJECT: Doesn't fit constraints, infeasible, or low value
- Provide brief reason for each rejection

Target: ~20 viable ideas

### Quick Filter Results

| #   | Idea   | Verdict | Reason         |
| --- | ------ | ------- | -------------- |
| 1   | [Idea] | ✅/❌   | [Brief reason] |
| 2   | ...    | ...     | ...            |

**Viable count:** [X] of [Y] ideas passed filter

---

## Step 2: Score Viable Ideas (0-1000)

For each viable idea, score on four dimensions:

### Scoring Rubric

**Concept Quality (0-250)**

- 200-250: Elegant, sound, addresses root cause
- 150-199: Good idea, minor concerns
- 100-149: Workable but has issues
- 50-99: Questionable approach
- 0-49: Fundamentally flawed

**Human Utility (0-250)**

- 200-250: Directly solves real pain, high impact
- 150-199: Useful, moderate impact
- 100-149: Nice to have
- 50-99: Limited benefit
- 0-49: No real user value

**Implementation Feasibility (0-250)**

- 200-250: Clear path, low risk, fits patterns
- 150-199: Achievable with some effort
- 100-149: Challenging but possible
- 50-99: High risk or uncertainty
- 0-49: Likely to fail or massive effort

**Complexity/Debt Ratio (0-250)**

- 200-250: Simple, maintainable, low debt
- 150-199: Reasonable complexity
- 100-149: Some tech debt concerns
- 50-99: High complexity, significant debt
- 0-49: Maintenance nightmare

### Scoring Table

| #   | Idea   | Concept | Utility | Feasible | Debt | TOTAL |
| --- | ------ | ------- | ------- | -------- | ---- | ----- |
| 1   | [Idea] | [X]     | [X]     | [X]      | [X]  | [SUM] |
| 2   | ...    | ...     | ...     | ...      | ...  | ...   |

---

## Step 3: Top 10 Deep Dive

For each of the top 10 by total score:

### [Rank]. [Idea Title] - Score: [X]/1000

**What it is:**
[Concrete, specific description of the approach]

**Why it scores well:**

- Concept: [Why this dimension scored high/low]
- Utility: [Why this dimension scored high/low]
- Feasibility: [Why this dimension scored high/low]
- Debt: [Why this dimension scored high/low]

**Key strengths:**

- [Strength 1]
- [Strength 2]

**Concerns/Risks:**

- [Risk 1]
- [Risk 2]

**Implementation sketch:**
[High-level approach - 3-5 bullet points]

---

## Step 4: Identify Top 3 Recommendations

Select the 3 ideas that best balance value and feasibility for this specific context.

### #1 Recommended: [Title]

**Score:** [X]/1000
**Why primary:**
[2-3 sentences on why this is the best choice given the context]

**Best suited when:**

- [Condition 1]
- [Condition 2]

### #2 Alternative: [Title]

**Score:** [X]/1000
**When to choose instead:**
[Criteria that would make this the better choice]

**Tradeoff vs #1:**
[What you gain/lose by choosing this]

### #3 Alternative: [Title]

**Score:** [X]/1000
**When to choose instead:**
[Criteria that would make this the better choice]

**Tradeoff vs #1:**
[What you gain/lose by choosing this]

---

## Summary

**Ideas evaluated:** [X]
**Passed quick filter:** [Y]
**Top 10 scored:** [Z]
**Top 3 recommended:** [List]

**Key insight from filtering:**
[One sentence about what became clear during this process]
```

---

## Variables to Inject

| Variable               | Source                                          |
| ---------------------- | ----------------------------------------------- |
| `{{TOPIC}}`            | User's brainstorm topic                         |
| `{{CONTEXT}}`          | User's challenge description                    |
| `{{DISCOVERY_OUTPUT}}` | Synthesized output from all 3 Phase 1 explorers |

---

## Expected Output

Single markdown file: `.claude/plans/research/*-brainstorm-filtered-*.md`

Contains:

- Quick filter results (all ideas evaluated)
- Scoring table (viable ideas)
- Top 10 detailed analysis
- Top 3 recommendations with rationale
