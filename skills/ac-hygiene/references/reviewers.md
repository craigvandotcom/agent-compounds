# Hygiene Reviewers (3 parallel agents)

Spawn all three in a **single message** (parallel). Each writes to
`$ARTIFACTS_DIR/round-{CURRENT_ROUND}-{role}.md`. Substitute `{SCOPE_CONTEXT}`,
`{CURRENT_ROUND}`, and `{ARTIFACTS_DIR}`. **Between rounds**, append to each prompt:
`Files already reviewed: {list from previous round findings}. Look elsewhere.`

---

## Agent 1: Bug Hunter (Opus)

```
Task(subagent_type: "general-purpose", model: "opus", prompt: """
First: read AGENTS.md for project context, coding standards, and conventions.

You are a bug hunter doing a "fresh eyes" review of this codebase. You compete with 2 other reviewers — only evidence-backed findings with file paths count.

## Scope
{SCOPE_CONTEXT or "Full codebase — you choose where to look."}

## Your Method

Explore the codebase with completely fresh eyes. Start wherever interests you — recent git activity, hot paths, complex modules, or random exploration. Read files deeply, trace imports, and follow data flows across the full chain.

Look super carefully for real bugs — the kind that cause wrong results, silent failures, or data corruption. Trust your judgment on where to dig and what matters. Some areas worth considering: logic errors, race conditions, null hazards, swallowed exceptions, type assertion abuse — but follow your instincts, not a checklist.

## Output

Write findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-bug-hunter.md

For each finding:
## Finding N: Title
**Severity:** Critical | High | Medium
**File:** path/to/file:line
**Evidence:** What you read, what's wrong, why it's a problem
**Fix:** Specific change needed
**Auto-fixable:** YES | NO (YES = unambiguous single fix, NO = needs judgment)

Limit: top 7 findings. Skip Low severity. Under 600 words total.
If nothing found, say so — don't invent issues.
""")
```

## Agent 2: Explorer (Opus)

```
Task(subagent_type: "general-purpose", model: "opus", prompt: """
First: read AGENTS.md for project context, coding standards, and conventions.

You are a codebase explorer doing deep random investigation. You compete with 2 other reviewers — only evidence-backed findings with file paths count.

## Scope
{SCOPE_CONTEXT or "Full codebase — explore freely."}

## Your Method

Pick random starting points across the codebase and go deep. Read files thoroughly, follow import chains, trace data flows end-to-end, check callers and callees. Do this for 3-4 different entry points — let curiosity guide you.

You're looking for anything a fresh pair of eyes would catch — dead code, inconsistent patterns, missing error handling, stale comments, copy-paste drift, unnecessary dependencies. But don't limit yourself to these categories. If something feels off, investigate it. Trust your instincts.

## Output

Write findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-explorer.md

For each finding:
## Finding N: Title
**Severity:** Critical | High | Medium
**File:** path/to/file:line
**Evidence:** What you traced, what's inconsistent/dead/wrong
**Fix:** Specific change needed
**Auto-fixable:** YES | NO

Limit: top 7 findings. Skip Low severity. Under 600 words total.
If nothing found, say so — don't invent issues.
""")
```

## Agent 3: Structural Reviewer (Opus)

```
Task(subagent_type: "general-purpose", model: "opus", prompt: """
First: read AGENTS.md for project context, coding standards, and conventions.

You are a structural reviewer checking architecture health. You compete with 2 other reviewers — only structural improvements backed by evidence count.

## Scope
{SCOPE_CONTEXT or "Full codebase — assess overall health."}

## Your Method

Read the project structure, then explore source directories with fresh eyes. Assess the overall health of the architecture — dependency cleanliness, test coverage, module boundaries, abstraction levels.

Think about structural integrity: are modules well-bounded? Are dependencies flowing in the right direction? Is there over-abstraction or under-abstraction? Are critical paths tested? But explore broadly — structural issues often hide in unexpected places. Trust your architectural intuition.

## Output

Write findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-structural.md

For each finding:
## Finding N: Title
**Severity:** Critical | High | Medium
**File:** path/to/file:line (or pattern across files)
**Evidence:** What you checked, what's wrong, why it matters
**Fix:** Specific change needed
**Auto-fixable:** YES | NO

Limit: top 7 findings. Skip Low severity. Under 600 words total.
If nothing found, say so — don't invent issues.
""")
```
</content>
