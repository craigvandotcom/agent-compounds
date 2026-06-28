# Reviewer Prompt Template

The shared prompt for all four Phase-2 reviewers. Spawn one Task **per dimension**
(security, performance, architecture, correctness), all in a **single message**
(parallel). Fill the `{...}` placeholders from the dimension's row in
`review-dimensions.md`, and substitute `{DIFF}`, `{ARTIFACTS_DIR}`, and `{ROUND}`
(`1` for the Phase-2 pass, `2` for a Phase-5.5 verification round).

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

Write findings as **JSON only** (no prose, no markdown around it) to
{ARTIFACTS_DIR}/round-{ROUND}-{ROLE}.json — it is machine-read for deterministic consensus:

{
  "reviewer": "{ROLE}",
  "round": {ROUND},
  "findings": [
    {
      "title": "<short title>",
      "severity": "Critical|High|Medium",
      "file": "path/to/file",
      "line": <line number>,
      "category": "<stable kebab-case defect-class slug — the consensus key>",
      "evidence": "<what you found>",
      "fix": "<specific change needed>",
      "auto_fixable": true
    }
  ]
}

- `category` is the **consensus key**: pick the slug another reviewer would choose for the
  SAME underlying issue at the same file:line (e.g. `sql-injection`, `n+1-query`,
  `missing-await`, `unhandled-rejection`). Name the defect class, not your wording — that is
  how same-round and cross-round consensus are detected.
- Limit: top 7 findings. Skip Low severity. If nothing found, emit
  `{"reviewer":"{ROLE}","round":{ROUND},"findings":[]}`.
- Emit ONLY the JSON object — a parser reads this file; any prose breaks it.
""")
```

Notes:
- `{SKILL_HINT}` is optional — include only if the Phase-1 skill routing found a relevant skill for that dimension (e.g. `Read .claude/skills/<security-skill>/SKILL.md for security patterns.`). Omit the line otherwise.
- `{ROLE}` is the lowercase dimension name used both in the prose and the output filename (`round-{ROUND}-security.json`, etc.).
</content>
