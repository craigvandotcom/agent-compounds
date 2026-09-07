# Round 4: CONVERGE (Premortem & Robustness)

**Lens:** Adversarial, skeptical, defensive
**Mindset:** "Imagine this failed. What went wrong?"

---

## Prompt Template

````markdown
# Plan Refinement Round 4: CONVERGE (Premortem & Robustness)

## Your Mindset

It's 6 months in the future. This plan was implemented, and it completely failed. Users are frustrated. The team is debugging late at night. Something went very wrong.

Your job is to figure out what happened—before it happens.

**Be pessimistic.** Look for the ways this could fail that nobody wants to talk about.

## Codebase Context

{{CODEBASE_CONTEXT}}

## Current Plan (Post-Round 3)

```markdown
{{PLAN_CONTENT}}
```
````

## Your Task

### Premortem Analysis

Imagine complete failure. What went wrong?

**Failure Scenario 1: [Title]**

- What happened: [Description of the failure]
- Root cause: [Why it failed]
- Warning signs we missed: [What should have been obvious]
- How to prevent: [Specific plan changes]

**Failure Scenario 2: [Title]**
[Same structure]

**Failure Scenario 3: [Title]**
[Same structure]

### Assumption Audit

What assumptions is this plan making that could be false?

| Assumption     | What If It's Wrong? | Mitigation     |
| -------------- | ------------------- | -------------- |
| [assumption 1] | [consequence]       | [how to hedge] |
| [assumption 2] | [consequence]       | [how to hedge] |

### Edge Cases & Failure Modes

- What happens when the network is slow/unavailable?
- What happens with unexpected user input?
- What happens when dependencies fail?
- What happens under load?
- What happens with stale data?
- What happens when state gets corrupted?

### Integration Risks

- What could break in the existing system?
- What if the migration/rollout goes wrong?
- What's the rollback plan if this fails in production?

### Robustness Improvements

For each failure mode identified, strengthen the plan:

**[ROBUST-N]: [Failure Mode]**

**Risk:** [What could go wrong]
**Current Plan Gap:** [What the plan doesn't address]
**Hardening Measure:** [How to make it robust]

**Proposed Changes (git-diff):**

```diff
--- a/.claude/plans/{{PLAN_FILE}}
+++ b/.claude/plans/{{PLAN_FILE}}
@@ -XX,YY +XX,YY @@
-[original text without protection]
+[hardened approach]
```

### Round 4 Score

| Aspect                | Score (1-10) | Notes |
| --------------------- | ------------ | ----- |
| Failure modes covered | [X]          |       |
| Assumption validation | [X]          |       |
| Edge case handling    | [X]          |       |
| Rollback strategy     | [X]          |       |
| Error recovery        | [X]          |       |

**Overall Robustness:** [X]/10

**Biggest Remaining Risk:** [One sentence]
**Confidence Plan Will Succeed:** [0-100%]

```

---

## Variables to Inject

| Variable | Source |
|----------|--------|
| `{{CODEBASE_CONTEXT}}` | Output from code-explorer agents |
| `{{PLAN_CONTENT}}` | Plan after Round 3 innovations |
| `{{PLAN_FILE}}` | Plan filename for diff headers |

---

## Expected Output

- 3+ concrete failure scenarios with prevention strategies
- Assumption audit table
- Edge case analysis
- Robustness improvements with git-diff format
- Score table
- Confidence assessment

---

## Notes

This round is intentionally pessimistic. The goal is to surface risks that optimistic planning overlooks.

Based on Jeffrey Emanuel's "Premortem Planner" pattern:
> "Imagine we're 6 months in the future and this approach has completely failed. What went wrong?"
```
