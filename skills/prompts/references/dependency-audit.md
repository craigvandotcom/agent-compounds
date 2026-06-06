# Dependency Audit

Audit all project dependencies thoroughly. For each dependency: check if it's actually used in the codebase (dead dependencies add attack surface and bloat for nothing), check if there are known security vulnerabilities, check if it's significantly outdated and what breaking changes exist between current and latest, and check if multiple dependencies serve the same purpose (pick one and remove the others). Produce a prioritized action list: critical security fixes first, then dead dependency removal, then version updates. For each recommended change, note the risk level and any migration steps required.

## Output Format

### Step 1: Auto-Apply Critical Vulnerability Fixes

Identify dependencies with non-negotiable security vulnerabilities (CVEs with CRITICAL severity). Immediately update or remove these without asking.

### Step 2: Present Remaining Findings Ranked by Priority

Display in this order (low first, critical last) so most important items appear closest to the selection prompt:

```markdown
## Low Priority

1. **[Package Name]** - [OUTDATED] - Current: vX.Y.Z → Latest: vA.B.C
   - Package: [name]
   - Issue: [description]
   - Risk Level: [low/medium/high]
   - Migration Steps: [what needs to change]

## Medium Priority

1. **[Package Name]** - [DEAD/DUPLICATE] - Current: vX.Y.Z
   - Package: [name]
   - Issue: [unused in codebase / duplicates functionality of X]
   - Risk Level: [low/medium/high]
   - Migration Steps: [removal steps / replacement with alternative]

## High Priority

1. **[Package Name]** - [VULNERABILITY] - Current: vX.Y.Z → Safe: vA.B.C
   - Package: [name]
   - Issue: [CVE/vulnerability description]
   - Risk Level: [high]
   - Migration Steps: [update steps + breaking changes if any]

## Critical (Auto-Fixed)

1. [VULN-1] [Package] updated to [version] - [CVE fixed]
2. [VULN-2] [Package] updated to [version] - [CVE fixed]
```

### Step 3: Ask User Which to Apply

```
Which dependency updates would you like to apply?
Options:
- "all" - Apply all proposed updates/removals
- "critical and high" - Apply critical + high priority
- "only [N, M]" - Apply only specific updates (e.g., "only 1, 3, 5")
- "none" - Skip remaining updates (critical already applied)
```

### Step 4: Apply Selected Updates and Run Tests

Execute the selected dependency updates, then run the test suite to verify no regressions introduced.
