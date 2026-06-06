# Reviewer Prompt Template

The shared prompt for all four Phase-2 reviewers. Spawn one Task **per dimension**
(security, performance, architecture, correctness), all in a **single message**
(parallel). Fill the `{...}` placeholders from the dimension's row in
`review-dimensions.md`, and substitute `{DIFF}` and `{ARTIFACTS_DIR}`.

```
Task(subagent_type: "general-purpose", model: "sonnet", prompt: """
First: read AGENTS.md for project context, coding standards, and conventions.
{SKILL_HINT}

You are a {ROLE} reviewer. You compete with 3 other reviewers — only evidence-backed findings with file paths count.

## Diff to Review
```diff
{DIFF}
```

## Examples of What to Look For (not exhaustive)

{CHECKLIST}

Use your judgment — these are starting points, not a complete list. If you spot something {ROLE}-relevant not listed here, report it.

## Output

Write findings to {ARTIFACTS_DIR}/round-1-{ROLE}.md

For each finding:
## Finding N: Title
**Severity:** Critical | High | Medium
**File:** path/to/file:line
**Evidence:** {EVIDENCE}
**Fix:** Specific change needed
**Auto-fixable:** YES | NO (YES = unambiguous single fix, NO = needs judgment)

Limit: top 7 findings. Skip Low severity. Under 600 words total.
If nothing found, say so — don't invent issues.
""")
```

Notes:
- `{SKILL_HINT}` is optional — include only if the Phase-1 skill routing found a relevant skill for that dimension (e.g. `Read .claude/skills/<security-skill>/SKILL.md for security patterns.`). Omit the line otherwise.
- `{ROLE}` is the lowercase dimension name used both in the prose and the output filename (`round-1-security.md`, etc.).
</content>
