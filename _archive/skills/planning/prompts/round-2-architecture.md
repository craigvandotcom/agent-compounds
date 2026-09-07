# Round 2: IN-THE-LARGE (Architecture & System)

**Lens:** Panoramic, seeing the forest
**Mindset:** "What are the system-wide implications?"

---

## Prompt Template

````markdown
# Plan Refinement Round 2: IN-THE-LARGE (Architecture & System)

## Your Mindset

Step back from the implementation details. You are now a systems architect looking at the big picture. You care about patterns, boundaries, integration points, and how this change ripples through the system.

**You are NOT proposing alternatives yet.** That comes in Round 3. Right now, you're asking: "What are the weakest parts of this plan from a systems perspective?"

## Codebase Context

{{CODEBASE_CONTEXT}}

## Current Plan (Post-Round 1)

```markdown
{{PLAN_CONTENT}}
```
````

## Your Task

Analyze the plan through an architectural lens:

### System Weaknesses Analysis

Based on everything you've seen, what are the weakest/worst parts of this plan from a systems perspective?

Consider:

1. **Component Boundaries**
   - Are responsibilities clearly separated?
   - Are there hidden dependencies between components?
   - Does this create circular dependencies?

2. **Integration Points**
   - How does this change affect other parts of the system?
   - What components consume what this plan produces?
   - What breaks if this plan's assumptions are wrong?

3. **Data Flow**
   - Is the data model coherent with existing patterns?
   - Are there state management implications?
   - Does this create data duplication or inconsistency risks?

4. **Error Propagation**
   - How do failures in this feature affect the rest of the system?
   - Are error boundaries well-defined?
   - Is there proper isolation?

5. **Scalability Considerations**
   - Does this approach scale with the existing architecture?
   - Are there performance cliffs?
   - What happens at 10x, 100x scale?

### Ripple Effect Analysis

| This Plan Changes | Which Affects          | Risk Level   |
| ----------------- | ---------------------- | ------------ |
| [component/file]  | [dependent components] | LOW/MED/HIGH |

### Architectural Improvements

For each weakness identified, provide:

**[ARCH-N]: [Architectural Concern]**

**The Weakness:** [What's wrong from a systems perspective]
**Why It Matters:** [Consequences if not addressed]
**Evidence:** [What in the codebase context supports this concern]

**Proposed Changes (git-diff):**

```diff
--- a/.claude/plans/{{PLAN_FILE}}
+++ b/.claude/plans/{{PLAN_FILE}}
@@ -XX,YY +XX,YY @@
-[old approach]
+[architecturally sounder approach]
```

### Round 2 Score

| Aspect                    | Score (1-10) | Notes |
| ------------------------- | ------------ | ----- |
| Component boundaries      | [X]          |       |
| Integration clarity       | [X]          |       |
| Data flow coherence       | [X]          |       |
| Error handling design     | [X]          |       |
| Scalability consideration | [X]          |       |

**Overall Architecture:** [X]/10

**Biggest Systemic Risk:** [One sentence summary]

```

---

## Variables to Inject

| Variable | Source |
|----------|--------|
| `{{CODEBASE_CONTEXT}}` | Output from code-explorer agents (may be refreshed or reused from R1) |
| `{{PLAN_CONTENT}}` | Plan after Round 1 corrections |
| `{{PLAN_FILE}}` | Plan filename for diff headers |

---

## Expected Output

- System weaknesses identified with severity
- Ripple effect analysis table
- Architectural improvements with git-diff format
- Score table for tracking
- Summary of biggest systemic risk
```
