# Planning Methodology

Deep dive into the iterative refinement approach based on Jeffrey Emanuel's work.

---

## The Rule of Five

Jeffrey Emanuel discovered that agents produce their best designs, plans, and implementations when forced to review their proposals **4-5 times**, at which point output "converges."

> "It typically takes 4 to 5 iterations before the agent declares that it's as good as it can get."

After convergence, suggestions become incremental. This is the first point where you can moderately trust the output.

---

## Scope Oscillation

The key insight: **each review should come from a different angle**.

> "Each review should be slightly broader and more outlandish than the previous one, or you can do it the opposite order. But you need a mixture of in-the-small and in-the-large reviews."

### In-the-Small Reviews

- Focus on implementation details
- Verify accuracy against actual code
- Check file paths, function signatures, types
- "Does this plan match reality?"

### In-the-Large Reviews

- Focus on system-wide implications
- Examine architectural patterns
- Consider integration points
- "What are the weakest parts?"

Alternating between these perspectives prevents tunnel vision where each round just makes incremental tweaks to the same ideas.

---

## Diverge/Converge Cycles

Borrowed from design thinking's Double Diamond:

### Divergent Thinking (Expanding)

- Generate many options
- Question assumptions
- Explore unconventional approaches
- "What else could we do?"

### Convergent Thinking (Narrowing)

- Validate against reality
- Filter ruthlessly
- Synthesize best ideas
- "What's the right answer?"

Our 5-round structure explicitly alternates:

```
R1: CONVERGE (ground in reality)
R2: CONVERGE (systemic validation)
R3: DIVERGE (explore alternatives)
R4: CONVERGE (stress test)
R5: SYNTHESIZE (integrate)
```

---

## Jeffrey's Planning Prompt

His core prompt for plan refinement:

> "Carefully review this entire plan for me and come up with your best revisions in terms of better architecture, new features, changed features, etc. to make it better, more robust/reliable, more performant, more compelling/useful, etc. For each proposed change, give me your detailed analysis and rationale/justification for why it would make the project better along with the git-diff style changes relative to the original markdown plan."

Key elements:

1. **Review comprehensively** — not just one aspect
2. **Multiple improvement dimensions** — architecture, features, robustness, performance
3. **Require justification** — why is this better?
4. **Git-diff format** — concrete, applicable changes

---

## Idea Generation Pattern

Jeffrey's approach to generating improvements (from "The Idea Wizard"):

1. **Generate 30 ideas** (brief one-liner each)
2. **Critically evaluate each** — reject non-excellent ones with reasons
3. **For survivors, explain in detail:**
   - Concrete, specific, actionable plan
   - Why it's a good improvement
   - Possible downsides
   - Confidence score (0-100%)

The 100-to-10 Filter is more rigorous: generate 100 ideas, keep only the 10 most brilliant.

---

## Premortem Pattern

Before committing to implementation:

> "Imagine we're 6 months in the future and this approach has completely failed. What went wrong? What assumptions did we make that turned out to be false? What edge cases did we miss? What integration issues did we overlook? What would users hate about it? Now, with that pessimistic scenario fresh in your mind, revise the plan to address the most likely failure modes."

This forces consideration of failure modes before they're expensive to fix.

---

## Multi-Perspective Synthesis

When you have insights from multiple angles (or multiple models), synthesize:

> "Carefully analyze their plans with an open mind and be intellectually honest about what they did that's better than your plan. Then come up with the best possible revisions that artfully and skillfully blends the 'best of all worlds' to create a true, ultimate, superior hybrid version."

Applied to our methodology: Round 5 synthesizes insights from Rounds 1-4 into a coherent final plan.

---

## Steady State Detection

Know when to stop refining:

- Are improvements becoming marginal?
- Are scores plateauing (< 0.5 point improvement)?
- Are proposed changes minor tweaks vs substantial improvements?
- Is overall assessment "ready for implementation"?
- Is accuracy score at 10/10?

**If YES to 3+ questions:** Steady state reached, proceed to implementation.

---

## Token Economics

Jeffrey's core insight:

> "It's a lot easier and faster to operate in 'plan space' before we start implementing these things!"

**Planning tokens:** ~20-30k per round, ~100-150k for full 5-round cycle
**Implementation tokens (for bugs):** Often 10-100x more if plan was wrong

The math favors heavy investment in planning quality.
