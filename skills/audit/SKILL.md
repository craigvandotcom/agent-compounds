---
name: audit
description: Comprehensive audit framework for systematic code quality verification. Use when performing security audits, performance reviews, UI/UX assessments, or test quality checks. Triggers on mentions of audit, review, quality check, pre-deployment verification, vulnerability assessment, or compliance review.
---

> **Generic skill — method only, zero app facts.** This skill is symlinked from
> agent-compounds and shared across consuming apps. It contains technique and
> patterns, not project specifics. **App specifics (project refs, schema names,
> domain rules, feature flows, env values) → read this app's
> `.claude/skills/CORE/SKILL.md`** (and the `AGENTS.md` summary it indexes).
> Do not add app-specific facts to this file — they belong in CORE.

# Audit Framework Skill

**Purpose:** Orchestrate systematic, parallelizable audits across security, performance, UI/UX, and testing domains
**Domain:** Quality assurance, pre-deployment verification, continuous improvement
**Status:** Complete

---

## When to Use This Skill

**Intent Triggers:**

- Performing comprehensive pre-deployment audits
- Running targeted domain audits (security, performance, UI, tests)
- Creating systematic verification checklists
- Generating audit reports for stakeholders
- Identifying auto-fixable vs. manual-fix issues
- Planning remediation sprints

**When NOT to Use:**

- One-off code reviews (use normal review process)
- Real-time debugging (use debugging workflows)
- Feature development (use development skills)

---

## Core Concept: Taskify Format

The audit framework uses a **taskify checklist** format - structured, parallelizable audit items that can be:

- Executed independently or as comprehensive suites
- Run in parallel groups for efficiency
- Auto-fixed when criteria are met
- Tracked with severity and priority
- Blocked by dependencies when needed

**Think of it as:** A systematic quality gate that transforms subjective "code review" into objective, repeatable verification.

---

## Audit Types

| Audit           | Checklist              | Focus Areas                                                       |
| --------------- | ---------------------- | ----------------------------------------------------------------- |
| **Security**    | `security-audit.md`    | OWASP Top 10, auth, crypto, input validation, AI security         |
| **Performance** | `performance-audit.md` | Build size, Core Web Vitals, database queries, mobile performance |
| **UI/UX**       | `ui-audit.md`          | Accessibility, responsiveness, design system, PWA, animations     |
| **Tests**       | `tests-audit.md`       | Coverage, reliability, speed, mock quality, CI/CD pipeline        |
| **QA**          | `qa-audit.md`          | Code smells, technical debt, TypeScript, SOLID, architecture      |

---

## Running Audits

### Individual Audit

**Use when:** Focused verification needed in one domain

```bash
# Example: Run security audit only
Load security-audit.md checklist
Execute items marked CRITICAL/HIGH first
Document findings
Generate remediation tasks
```

**Output:** Domain-specific audit report with findings by severity

### Comprehensive Audit

**Use when:** Full pre-deployment verification needed

```bash
# Run all audits in parallel groups
Parallel Group 1: SEC-001 to SEC-005 (can run concurrently)
Parallel Group 2: PERF-001 to PERF-003 (can run concurrently)
Parallel Group 3: UI-001 to UI-004 (can run concurrently)
Parallel Group 4: TEST-001 to TEST-003 (can run concurrently)
Parallel Group 5: QA-001 to QA-004 (can run concurrently)

# Sequential: Items with "Blocked By" dependencies
```

**Output:** Consolidated audit report across all domains

---

## Taskify Checklist Format

Each audit item follows this structure:

```markdown
### [AUDIT-ID] Item Title

**Description:** What to check/verify
**Severity:** CRITICAL | HIGH | MEDIUM | LOW | INFO
**Auto-fixable:** YES | NO
**Parallel Group:** Group name (items in same group can run concurrently)
**Blocked By:** [AUDIT-ID] (if has dependencies)

**Verification:**

1. Step 1 to verify (specific command or check)
2. Step 2 to verify
3. Step 3 to verify

**Expected Output:** What successful completion looks like

**Deliverable:** What artifact to produce (report, finding, fix)
```

### Field Definitions

**AUDIT-ID Format:**

- Security: `SEC-001`, `SEC-002`, ...
- Performance: `PERF-001`, `PERF-002`, ...
- UI/UX: `UI-001`, `UI-002`, ...
- Tests: `TEST-001`, `TEST-002`, ...

**Severity Levels:**
| Level | Definition | Response Time |
|-------|------------|---------------|
| **CRITICAL** | Immediate exploitation risk, data breach possible | Fix immediately |
| **HIGH** | Significant risk, actively exploitable | Fix this sprint |
| **MEDIUM** | Moderate risk, requires specific conditions | Fix next sprint |
| **LOW** | Minor issue, unlikely exploitation | Fix when convenient |
| **INFO** | Best practice recommendation, no direct risk | Consider for future |

**Auto-fixable Criteria:**

**YES - Can auto-fix:**

- Adding validation schemas (Zod)
- Replacing string concatenation with parameterized queries
- Adding security headers to next.config.mjs
- Removing console.log of sensitive data
- Adding missing ESLint suppressions with justification
- Optimizing images (format, compression)
- Adding accessibility attributes (aria-\*, alt text)

**NO - Needs decision:**

- Architectural changes (auth flow redesign)
- Choosing between libraries (security vs. performance trade-off)
- UX changes (breaking user workflows)
- Unclear validation requirements (business logic decision)
- Breaking API changes

**Parallel Groups:**

Items in the same parallel group can be executed concurrently. Group by:

- Independence (no shared resources)
- Domain separation (security vs. performance)
- Tool compatibility (can run same command simultaneously)

Example:

```markdown
**Parallel Group:** SEC-Input-Validation
```

All items with `SEC-Input-Validation` can run at the same time.

---

## Dependency Management

Use `Blocked By` to establish execution order:

```markdown
### [SEC-002] Verify Auth Middleware Coverage

**Blocked By:** [SEC-001]
```

This means SEC-002 cannot start until SEC-001 is complete.

**Dependency Types:**

1. **Data Dependency:** SEC-002 needs output from SEC-001
2. **Resource Dependency:** Both need same file/tool, run sequentially
3. **Logical Dependency:** Must verify foundation before building on top

---

## Loading Checklists

### On-Demand Loading (Default)

```markdown
Load security-audit.md when security audit requested
Load performance-audit.md when performance audit requested
Load ui-audit.md when UI/UX audit requested
Load tests-audit.md when test audit requested
```

**Token efficiency:** Only load what's needed for the current audit.

### Full Audit Loading

```markdown
Load all four checklists when:

- User requests "comprehensive audit"
- User requests "full pre-deployment audit"
- User requests "run all audits"
```

---

## Execution Workflow

### 1. Plan Phase

```markdown
1. Identify audit type(s) needed
2. Load relevant checklist(s)
3. Identify CRITICAL/HIGH items
4. Map parallel groups
5. Identify dependencies
6. Estimate effort (# of items × avg time per item)
```

**Output:** Execution plan with groups and order

### 2. Execute Phase

```markdown
For each parallel group:

1. Run verification steps
2. Capture actual output
3. Compare to expected output
4. Document finding if mismatch
5. Mark auto-fixable items

For dependent items:

1. Wait for blocker to complete
2. Run verification steps
3. Document findings
```

**Output:** Raw findings data

### 3. Report Phase

```markdown
1. Aggregate findings by severity
2. Calculate auto-fixable count
3. Group by domain (for comprehensive audits)
4. Generate remediation plan
5. Create prioritized task list
```

**Output:** Formatted audit report (see template below)

---

## Audit Report Template

```markdown
## [Audit Type] Audit Report

**Date:** YYYY-MM-DD
**Scope:** [Feature/Component/Full Application]
**Auditor:** Claude (audit skill)
**Duration:** [Execution time]

---

### Executive Summary

[2-3 sentences describing overall quality posture and key findings]

---

### Findings by Severity

| Severity | Count | Auto-fixable |
| -------- | ----- | ------------ |
| CRITICAL | X     | Y            |
| HIGH     | X     | Y            |
| MEDIUM   | X     | Y            |
| LOW      | X     | Y            |
| INFO     | X     | Y            |

**Total Issues:** [Sum]
**Auto-fixable:** [Count] ([Percentage]%)

---

### Detailed Findings

[Individual findings using finding template below]

---

### Remediation Plan

**Immediate (This Week):**

1. [CRITICAL finding 1] - [Estimated effort]
2. [CRITICAL finding 2] - [Estimated effort]

**Short-term (This Sprint):**

1. [HIGH finding 1] - [Estimated effort]
2. [HIGH finding 2] - [Estimated effort]

**Medium-term (Next Quarter):**

1. [MEDIUM finding 1] - [Estimated effort]

---

### Next Steps

1. Address CRITICAL findings immediately
2. Create tasks for HIGH findings
3. Schedule MEDIUM findings for next sprint
4. Document accepted risks for LOW/INFO items

---

### Appendix: Auto-fixable Items

[List of items that can be automatically fixed with proposed fixes]
```

---

## Finding Template

```markdown
### [SEVERITY] [AUDIT-ID] Finding Title

**Location:** `path/to/file.ts:line`
**Category:** [Category name from checklist]
**Severity:** CRITICAL | HIGH | MEDIUM | LOW | INFO
**Auto-fixable:** YES | NO

**Issue:**
Clear description of the problem and why it matters.

**Impact:**
What could go wrong if this is not fixed.

**Verification Steps Executed:**

1. Ran command: `[command]`
2. Output: `[actual output]`
3. Expected: `[expected output]`

**Remediation:**

\`\`\`typescript
// Proposed fix (if auto-fixable)
// OR
// Steps to manually fix
\`\`\`

**Auto-fix Justification:**
[If YES: Why it's safe to auto-fix]
[If NO: What decision is needed]
```

---

## Quick Reference Commands

### Security Audit

```bash
pnpm audit                           # Dependency vulnerabilities
grep -r "password\|secret" --include="*.ts"  # Hardcoded secrets
cat next.config.mjs | grep "headers"  # Security headers
```

### Performance Audit

```bash
pnpm build                           # Build size and chunks
pnpm lighthouse https://...          # Core Web Vitals
pnpm test:coverage                   # Test performance
```

### UI/UX Audit

```bash
axe-core browser extension           # Accessibility
Responsive design mode               # Mobile testing
pnpm test:e2e                        # Visual regression
```

### Tests Audit

```bash
pnpm test:coverage                   # Coverage metrics
pnpm test:ci                         # CI reliability
pnpm test -- --detectLeaks           # Memory leaks
```

### QA Audit

```bash
pnpm type-check                      # TypeScript strict check
pnpm lint                            # ESLint quality check
grep -r ": any" app/ lib/            # Find any types
```

---

## Severity/Priority System

**Priority Calculation:**

```
Priority = (Severity × Impact × Exploitability) / Effort

Where:
- Severity: CRITICAL=5, HIGH=4, MEDIUM=3, LOW=2, INFO=1
- Impact: Data breach=5, Downtime=4, UX degradation=3, Minor issue=2, Cosmetic=1
- Exploitability: Trivial=5, Easy=4, Moderate=3, Hard=2, Very hard=1
- Effort: Hours=1, Days=3, Weeks=5
```

**Example:**

- CRITICAL finding, Data breach impact, Trivial exploitability, 2 hours effort
- Priority = (5 × 5 × 5) / 1 = 125 (Fix immediately)

---

## Common Mistakes

| Mistake                          | Fix                                      |
| -------------------------------- | ---------------------------------------- |
| Running all items sequentially   | Use parallel groups for efficiency       |
| Skipping CRITICAL items          | Always prioritize by severity            |
| Auto-fixing without verification | Test auto-fixes in isolation first       |
| Not documenting accepted risks   | Log LOW/INFO items as decisions          |
| Missing dependencies             | Check "Blocked By" before starting       |
| Generic findings                 | Always include location, code, and steps |

---

## Supporting Documentation

| File                   | When to Read                                |
| ---------------------- | ------------------------------------------- |
| `security-audit.md`    | Security/vulnerability review needed        |
| `performance-audit.md` | Performance optimization needed             |
| `ui-audit.md`          | UI/UX quality verification needed           |
| `tests-audit.md`       | Test quality assessment needed              |
| `qa-audit.md`          | Code quality, maintainability, architecture |

---

## Integration Points

**With CI/CD:**

- Run CRITICAL/HIGH items on every PR
- Run comprehensive audit on pre-release branches
- Block deployment on CRITICAL findings

**With Issue Tracking:**

- Create GitHub issues from findings
- Tag with severity labels
- Link to audit report

**With Monitoring:**

- Track finding trends over time
- Monitor auto-fix success rate
- Alert on new CRITICAL findings

---

**Last Updated:** 2026-02-03
**Version:** 1.1 (Added QA-036 to QA-049: SOLID principles, code smells, code health tracking)
