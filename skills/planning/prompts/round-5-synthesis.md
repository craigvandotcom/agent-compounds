# Round 5: SYNTHESIS (Integration)

**Lens:** Integrative, balancing, decisive
**Mindset:** "What's the best version combining all perspectives?"

---

## Prompt Template

````markdown
# Plan Refinement Round 5: SYNTHESIS (Integration)

## Your Mindset

You've seen this plan through four different lenses:

1. **Accuracy** (does it match reality?)
2. **Architecture** (is it systemically sound?)
3. **Innovation** (what else could we do?)
4. **Robustness** (how could it fail?)

Now integrate the best insights from all rounds into a coherent, final plan.

## Round Summaries

### Round 1 (Accuracy) Key Findings:

{{ROUND_1_SUMMARY}}

### Round 2 (Architecture) Key Findings:

{{ROUND_2_SUMMARY}}

### Round 3 (Innovation) Top Ideas:

{{ROUND_3_TOP_IDEAS}}

### Round 4 (Robustness) Critical Risks:

{{ROUND_4_KEY_RISKS}}

## Current Plan (Post-Round 4)

```markdown
{{PLAN_CONTENT}}
```
````

## Your Task

### Synthesis Matrix

For each major section of the plan, integrate insights from all rounds:

| Plan Section | Accuracy Fix | Arch Improvement | Innovation | Robustness |
| ------------ | ------------ | ---------------- | ---------- | ---------- |
| [section 1]  | [from R1]    | [from R2]        | [from R3]  | [from R4]  |
| [section 2]  | [from R1]    | [from R2]        | [from R3]  | [from R4]  |

### Conflict Resolution

Where round recommendations conflict, make a decision:

| Conflict   | Option A    | Option B    | Decision | Rationale |
| ---------- | ----------- | ----------- | -------- | --------- |
| [conflict] | [R2 says X] | [R3 says Y] | [choice] | [why]     |

### Final Enhancements

Produce the definitive set of changes that:

1. Maintain accuracy (R1)
2. Strengthen architecture (R2)
3. Incorporate best innovations (R3)
4. Ensure robustness (R4)

**[FINAL-N]: [Enhancement Title]**

**Origin:** Round [N] + Round [M]
**What:** [Specific change]
**Why:** [Combined rationale from multiple rounds]

**Final Changes (git-diff):**

```diff
--- a/.claude/plans/{{PLAN_FILE}}
+++ b/.claude/plans/{{PLAN_FILE}}
@@ -XX,YY +XX,YY @@
-[before synthesis]
+[after synthesis]
```

### Final Assessment

| Quality Gate | R1              | R2          | R3  | R4            | Final | Improvement |
| ------------ | --------------- | ----------- | --- | ------------- | ----- | ----------- |
| Accuracy     | {{R1_ACCURACY}} | -           | -   | -             | [X]   | +[X]        |
| Architecture | -               | {{R2_ARCH}} | -   | -             | [X]   | +[X]        |
| Innovation   | -               | -           | [X] | -             | [X]   | +[X]        |
| Robustness   | -               | -           | -   | {{R4_ROBUST}} | [X]   | +[X]        |
| Overall      | [X]             | [X]         | [X] | [X]           | [X]   | +[X]        |

### Readiness Declaration

**Plan Status:** [READY FOR IMPLEMENTATION | NEEDS ANOTHER CYCLE]

**If ready:**

- Confidence level: [0-100%]
- Primary strength: [one sentence]
- Watch out for: [key implementation risk]

**If not ready:**

- Blocking issue: [what needs resolution]
- Recommended action: [what to do]

```

---

## Variables to Inject

| Variable | Source |
|----------|--------|
| `{{ROUND_1_SUMMARY}}` | Key findings from Round 1 |
| `{{ROUND_2_SUMMARY}}` | Key findings from Round 2 |
| `{{ROUND_3_TOP_IDEAS}}` | Top 5 ideas from Round 3 |
| `{{ROUND_4_KEY_RISKS}}` | Critical risks from Round 4 |
| `{{PLAN_CONTENT}}` | Plan after Round 4 hardening |
| `{{PLAN_FILE}}` | Plan filename for diff headers |
| `{{R1_ACCURACY}}` | Round 1 accuracy score |
| `{{R2_ARCH}}` | Round 2 architecture score |
| `{{R4_ROBUST}}` | Round 4 robustness score |

---

## Expected Output

- Synthesis matrix showing integration across rounds
- Conflict resolution decisions with rationale
- Final enhancement set with git-diff format
- Final assessment table showing improvement trajectory
- Clear readiness declaration

---

## Notes

This round resolves tensions between earlier rounds. When Round 3 (innovation) conflicts with Round 4 (robustness), make a deliberate choice rather than trying to include both.

The goal is a coherent, implementable plan—not a kitchen sink of all suggestions.

Inspired by Jeffrey Emanuel's "Multi-Model Synthesis" pattern, adapted for multi-perspective rather than multi-model synthesis.
```
