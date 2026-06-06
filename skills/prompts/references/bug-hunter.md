# The Bug Hunter

I want you to sort of randomly explore the code files in this project, choosing code files to deeply investigate and understand and trace their functionality and execution flows through the related code files which they import or which they are imported by. Once you understand the purpose of the code in the larger context of the workflows, I want you to do a super careful, methodical, and critical check with "fresh eyes" to find any obvious bugs, problems, errors, issues, silly mistakes, etc. and then systematically and meticulously and intelligently correct them. Be sure to comply with ALL rules in the project's configuration files (CLAUDE.md, AGENTS.md, or equivalent) and ensure that any code you write or revise conforms to the project's established coding standards and best practices.

---

## Output Format

### Step 1: Auto-Apply Critical Bug Fixes

Identify bugs that are non-negotiable correctness issues (crashes, data corruption, security vulnerabilities). Immediately fix these without asking.

### Step 2: Present Remaining Findings Ranked by Priority

Display in this order (low first, critical last) so most important items appear closest to the selection prompt:

```markdown
## Low Priority

1. **[Bug Title]** - [QUALITY] - Location: `file:line`
   - Location: [file path]
   - Issue: [description of bug/problem]
   - Fix: [concrete solution]

## Medium Priority

1. **[Bug Title]** - [EDGE_CASE] - Location: `file:line`
   - Location: [file path]
   - Issue: [description of bug/problem]
   - Fix: [concrete solution]

## High Priority

1. **[Bug Title]** - [BUG/LOGIC_ERROR] - Location: `file:line`
   - Location: [file path]
   - Issue: [description of bug/problem]
   - Fix: [concrete solution]

## Critical (Auto-Fixed)

1. [BUG-1] [Fix description] in [file] - [crash/corruption issue resolved]
2. [BUG-2] [Fix description] in [file] - [crash/corruption issue resolved]
```

### Step 3: Ask User Which to Fix

```
Which bugs would you like to fix?
Options:
- "all" - Apply all proposed fixes
- "critical and high" - Apply critical + high priority
- "only [N, M]" - Apply only specific fixes (e.g., "only 1, 3, 5")
- "none" - Skip remaining fixes (critical already applied)
```

### Step 4: Apply Selected Fixes and Run Tests

Execute the selected fixes, then run the test suite to verify bugs are resolved and no regressions introduced.
