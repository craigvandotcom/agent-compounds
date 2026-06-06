# API Contract Validator

Systematically verify that every API endpoint, function interface, or module boundary in this project actually implements what it claims to. Check that request/response shapes match their type definitions or documentation. Check that documented parameters are actually accepted and undocumented ones aren't silently ignored. Check that error responses match their documented format. Check that status codes are semantically correct. For any discrepancy found, determine whether the code or the documentation is "right" based on apparent intent and usage patterns, then fix whichever is wrong. API contracts are promises; broken promises are bugs.

---

## Output Format

### Step 1: Auto-Apply Critical Contract Violations

Identify contract violations that break existing integrations or expose security issues (undocumented endpoints accepting dangerous input, wrong status codes hiding errors). Immediately fix these without asking.

### Step 2: Present Remaining Findings Ranked by Priority

Display in this order (low first, critical last) so most important items appear closest to the selection prompt:

```markdown
## Low Priority

1. **[Endpoint/Interface]** - [INCORRECT] - Location: `file:line`
   - Endpoint/Interface: [API path or function signature]
   - Issue: [discrepancy between code and docs]
   - Which Is "Right": [code/docs - based on usage patterns]
   - Fix: [update code or update docs]

## Medium Priority

1. **[Endpoint/Interface]** - [MISSING/UNDOCUMENTED] - Location: `file:line`
   - Endpoint/Interface: [API path or function signature]
   - Issue: [missing documentation or undocumented parameter]
   - Which Is "Right": [code/docs - based on usage patterns]
   - Fix: [add docs or remove code]

## High Priority

1. **[Endpoint/Interface]** - [MISMATCH] - Location: `file:line`
   - Endpoint/Interface: [API path or function signature]
   - Issue: [type mismatch, wrong status code, error format broken]
   - Which Is "Right": [code/docs - based on usage patterns]
   - Fix: [concrete fix to align code and contract]

## Critical (Auto-Fixed)

1. [CONTRACT-1] [Fix description] in [endpoint] - [security/integration issue resolved]
2. [CONTRACT-2] [Fix description] in [endpoint] - [security/integration issue resolved]
```

### Step 3: Ask User Which to Fix

```
Which contract violations would you like to fix?
Options:
- "all" - Apply all proposed fixes
- "critical and high" - Apply critical + high priority
- "only [N, M]" - Apply only specific fixes (e.g., "only 1, 3, 5")
- "none" - Skip remaining fixes (critical already applied)
```

### Step 4: Apply Selected Fixes and Verify Contracts

Execute the selected fixes, then run integration tests to verify API contracts are now correctly implemented.
