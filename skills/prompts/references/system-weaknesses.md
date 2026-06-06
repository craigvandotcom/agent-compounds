# System Weaknesses Analyzer

Based on everything you've seen, what are the weakest/worst parts of the system? What is most needing of fresh ideas and innovative/creative/clever improvements?

## Output Format

### Step 1: Auto-Apply Critical Structural Fixes

Identify weaknesses that represent immediate fragility (missing error handling in critical paths, unsafe data access). Immediately fix these without asking.

### Step 2: Present Remaining Findings Ranked by Priority

Display in this order (low first, critical last) so most important items appear closest to the selection prompt:

```markdown
## Low Priority

1. **[Module/Component]** - [TECHNICAL_DEBT] - Location: `file:line`
   - Location: [file path]
   - Weakness: [description of problem]
   - Impact: [why this matters]
   - Suggested Improvement: [concrete solution]

## Medium Priority

1. **[Module/Component]** - [DESIGN] - Location: `file:line`
   - Location: [file path]
   - Weakness: [description of problem]
   - Impact: [why this matters]
   - Suggested Improvement: [concrete solution]

## High Priority

1. **[Module/Component]** - [STRUCTURAL/FRAGILITY] - Location: `file:line`
   - Location: [file path]
   - Weakness: [description of problem]
   - Impact: [HIGH - blocks extensibility or creates cascading failures]
   - Suggested Improvement: [concrete solution]

## Critical (Auto-Fixed)

1. [WEAK-1] [Structural fix description] in [file] - [issue resolved]
2. [WEAK-2] [Structural fix description] in [file] - [issue resolved]
```

### Step 3: Ask User Which to Improve

```
Which improvements would you like to apply?
Options:
- "all" - Apply all proposed improvements
- "critical and high" - Apply critical + high priority
- "only [N, M]" - Apply only specific improvements (e.g., "only 1, 3, 5")
- "none" - Skip remaining improvements (critical already applied)
```

### Step 4: Apply Selected Improvements and Verify

Execute the selected improvements, then run tests to verify system stability and no regressions.
