# Peer Code Reviewer

Ok can you now turn your attention to reviewing the code written by your fellow agents and checking for any issues, bugs, errors, problems, inefficiencies, security problems, reliability issues, etc. and carefully diagnose their underlying root causes using first-principle analysis and then fix or revise them if necessary? Don't restrict yourself to the latest commits, cast a wider net and go super deep!

## Output Format

### Step 1: Auto-Apply Critical Fixes

Identify critical issues from other agents' work (security vulnerabilities, data corruption risks, crashes). Immediately fix these without asking.

### Step 2: Present Remaining Findings Ranked by Priority

Display in this order (low first, critical last) so most important items appear closest to the selection prompt:

```markdown
## Low Priority

1. **[Issue Title]** - [PERFORMANCE] - Location: `file:line`
   - Location: [file path]
   - Issue: [description of problem from agent's code]
   - Root Cause: [first-principles analysis]
   - Fix: [concrete solution]

## Medium Priority

1. **[Issue Title]** - [RELIABILITY] - Location: `file:line`
   - Location: [file path]
   - Issue: [description of problem from agent's code]
   - Root Cause: [first-principles analysis]
   - Fix: [concrete solution]

## High Priority

1. **[Issue Title]** - [BUG/SECURITY] - Location: `file:line`
   - Location: [file path]
   - Issue: [description of problem from agent's code]
   - Root Cause: [first-principles analysis]
   - Fix: [concrete solution]

## Critical (Auto-Fixed)

1. [ISSUE-1] [Fix description] in [file] - [security/corruption issue resolved]
2. [ISSUE-2] [Fix description] in [file] - [security/corruption issue resolved]
```

### Step 3: Ask User Which to Fix

```
Which fixes would you like to apply?
Options:
- "all" - Apply all proposed fixes
- "critical and high" - Apply critical + high priority
- "only [N, M]" - Apply only specific fixes (e.g., "only 1, 3, 5")
- "none" - Skip remaining fixes (critical already applied)
```

### Step 4: Apply Selected Fixes and Run Tests

Execute the selected fixes, then run the test suite to verify correctness and no regressions.
