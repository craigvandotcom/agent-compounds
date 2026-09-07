# Round 3: DIVERGE (Alternatives & Innovation)

**Lens:** Expansive, creative, lateral
**Mindset:** "What are we missing? What else could we do?"

---

## Prompt Template

````markdown
# Plan Refinement Round 3: DIVERGE (Alternatives & Innovation)

## Your Mindset

Forget about validating the plan. Now you're a creative strategist. Your job is to generate alternatives, question assumptions, and find what the plan is missing.

**Be slightly outlandish.** Consider approaches that might seem unconventional. The best ideas often come from exploring the edges.

## Codebase Context

{{CODEBASE_CONTEXT}}

## Current Plan (Post-Round 2)

```markdown
{{PLAN_CONTENT}}
```
````

## Your Task

### Phase 1: Generate Alternatives (Diverge Wide)

Come up with 15-20 ideas for improving or changing this plan. Include:

- Alternative technical approaches
- Features that could be added
- Simplifications that could be made
- Unconventional solutions
- Things that might seem "too simple" or "too complex"

**List format (one-liner each):**

1. [idea]
2. [idea]
   ...
3. [idea]

### Phase 2: Critical Evaluation (Filter)

Go through each idea systematically. Reject ones that:

- Don't actually improve the plan
- Add complexity without proportional value
- Conflict with project constraints
- Are infeasible given the codebase

**For each idea:**

- ✅ KEEP: [brief reason]
- ❌ REJECT: [brief reason]

### Phase 3: Top 5 Expansion

For the 5 best ideas that passed your scrutiny:

**[IDEA-N]: [Title]**

**What it is:** [Concrete, specific, actionable description]
**Why it improves the plan:** [Benefits]
**Possible downsides:** [Risks or tradeoffs]
**Confidence (0-100%):** [How sure are you this improves the project?]

**Implementation (git-diff):**

```diff
--- a/.claude/plans/{{PLAN_FILE}}
+++ b/.claude/plans/{{PLAN_FILE}}
@@ -XX,YY +XX,YY @@
-[current approach]
+[enhanced approach with this idea]
```

### What's Missing?

Beyond incremental improvements, what is this plan fundamentally not considering?

- User scenarios not covered?
- Edge cases not anticipated?
- Integration opportunities missed?
- Simpler alternatives not explored?

### Round 3 Output

**Ideas Generated:** [X]
**Ideas Kept:** [Y]
**Top 5 for Integration:** [list titles]

**Most Innovative Suggestion:** [one sentence]
**Biggest Blind Spot Uncovered:** [one sentence]

```

---

## Variables to Inject

| Variable | Source |
|----------|--------|
| `{{CODEBASE_CONTEXT}}` | Output from code-explorer agents |
| `{{PLAN_CONTENT}}` | Plan after Round 2 improvements |
| `{{PLAN_FILE}}` | Plan filename for diff headers |

---

## Expected Output

- 15-20 ideas generated
- Filtered list with keep/reject rationale
- Top 5 detailed with implementation diffs
- Blind spots identified
- Summary of most innovative suggestion

---

## Notes

This round intentionally breaks from validation mode. The goal is expansion, not verification. Some ideas may seem impractical—that's fine. The filtering phase handles quality control.

Inspired by Jeffrey Emanuel's "Idea Wizard" and "100-to-10 Filter" patterns.
```
