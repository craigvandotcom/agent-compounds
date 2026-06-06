# Test Coverage Gap Finder

Analyze the codebase to identify the most critical untested code paths. Don't just look at line coverage metrics; think about which functions, branches, and edge cases would cause the most damage if they broke silently. Prioritize: error handling paths, boundary conditions, state transitions, integration points between modules, and any code that handles money, authentication, or user data. For each gap you find, explain why it's dangerous to leave untested and write a concrete test case that would catch a regression. Focus on the tests that provide the most confidence per line of test code.

## Output Format

### Step 1: Auto-Apply Critical Path Tests

Identify gaps in critical paths (authentication, payment, data loss scenarios) that are non-negotiable for system reliability. Immediately write and add these tests without asking.

### Step 2: Present Remaining Findings Ranked by Priority

Display in this order (low first, critical last) so most important items appear closest to the selection prompt:

```markdown
## Low Priority

1. **[Function/Module Name]** - [EDGE_CASE] - Location: `file:line`
   - Location: [file path]
   - Gap Description: [what's untested]
   - Blast Radius: [impact if this breaks]
   - Test Case: [concrete test to add]

## Medium Priority

1. **[Function/Module Name]** - [ERROR_PATH/INTEGRATION] - Location: `file:line`
   - Location: [file path]
   - Gap Description: [what's untested]
   - Blast Radius: [impact if this breaks]
   - Test Case: [concrete test to add]

## High Priority

1. **[Function/Module Name]** - [CRITICAL_PATH] - Location: `file:line`
   - Location: [file path]
   - Gap Description: [what's untested]
   - Blast Radius: [HIGH - would cause production issues]
   - Test Case: [concrete test to add]

## Critical (Auto-Added)

1. [TEST-1] [Test description] added to [file] - Covers [critical path]
2. [TEST-2] [Test description] added to [file] - Covers [critical path]
```

### Step 3: Ask User Which to Add

```
Which test cases would you like to add?
Options:
- "all" - Add all proposed test cases
- "critical and high" - Add critical + high priority
- "only [N, M]" - Add only specific tests (e.g., "only 1, 3, 5")
- "none" - Skip remaining tests (critical already added)
```

### Step 4: Add Selected Tests and Run Suite

Write the selected test cases, add to appropriate test files, then run the test suite to verify all tests pass.
