# Error Message Improver

Read through the codebase and find all error messages, error handling, and user-facing error text. For each one, evaluate whether it clearly tells the user (or developer, or calling code) exactly what went wrong, why it went wrong, and what they can do to fix it. Replace vague errors like "Something went wrong" or "Invalid input" with specific, actionable messages that include the actual values that caused the failure, the constraint that was violated, and a concrete suggestion for resolution. Error messages are UI for when things break; treat them with the same care as any other user-facing text.

---

## Output Format

### Step 1: Auto-Apply Critical Error Message Fixes

Identify error messages that actively mislead users or hide real issues (errors that lie about the cause, swallow critical information). Immediately fix these without asking.

### Step 2: Present Remaining Findings Ranked by Priority

Display in this order (low first, critical last) so most important items appear closest to the selection prompt:

```markdown
## Low Priority

1. **[Error Location]** - [VAGUE] - Location: `file:line`
   - Location: [file path]
   - Current Message: "[existing error text]"
   - Improved Message: "[specific, actionable error text with values/constraints/fix]"
   - Why It Matters: [impact on developer/user experience]

## Medium Priority

1. **[Error Location]** - [MISSING_CONTEXT/UNHELPFUL] - Location: `file:line`
   - Location: [file path]
   - Current Message: "[existing error text]"
   - Improved Message: "[specific, actionable error text with values/constraints/fix]"
   - Why It Matters: [impact on developer/user experience]

## High Priority

1. **[Error Location]** - [MISLEADING] - Location: `file:line`
   - Location: [file path]
   - Current Message: "[existing error text]"
   - Improved Message: "[specific, actionable error text with values/constraints/fix]"
   - Why It Matters: [HIGH - actively prevents debugging or sends users down wrong path]

## Critical (Auto-Fixed)

1. [ERROR-1] Error in [file] updated - [was misleading, now accurate]
2. [ERROR-2] Error in [file] updated - [was hiding issue, now exposes it]
```

### Step 3: Ask User Which to Update

```
Which error messages would you like to improve?
Options:
- "all" - Apply all proposed improvements
- "critical and high" - Apply critical + high priority
- "only [N, M]" - Apply only specific improvements (e.g., "only 1, 3, 5")
- "none" - Skip remaining improvements (critical already applied)
```

### Step 4: Apply Selected Improvements and Verify

Execute the selected error message updates, then trigger error paths to verify messages are clear and actionable.
