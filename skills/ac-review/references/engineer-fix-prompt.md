# Engineer Fix Prompt

The sub-agent prompt for applying a fix list. Used three times: Phase 4 (AUTO_FIX),
Phase 7 (AUTO_IMPLEMENT after conductor triage), and Phase 7 (user-approved decisions).
Substitute `{INTENT}`, `{FIXES}`, `{CMD_TEST/LINT/TYPECHECK}`, `{ARTIFACTS_DIR}`.

```
Task(subagent_type: "general-purpose", model: "sonnet", prompt: """
Read AGENTS.md for project context.

## Your Task

{INTENT}

## Fixes to Apply

{FIXES}   ← numbered list with file, line, and the exact change

## After All Fixes

Run the project's checks (from AGENTS.md > Project Commands):
{CMD_TEST} && {CMD_LINT} && {CMD_TYPECHECK}

## Output

Write results to {ARTIFACTS_DIR}/auto-fix-result.md:
- Files modified (with paths)
- Fixes applied (reference finding numbers)
- Check results (test, lint, type-check — all must pass)
- Any fixes that couldn't be applied (and why)
""")
```

`{INTENT}` per call:
- **Phase 4 (AUTO_FIX):** `Apply these fixes exactly as specified. Do NOT modify NEEDS_DECISION items.`
- **Phase 7 (AUTO_IMPLEMENT):** `Apply these fixes — each has been validated by the conductor as a clear technical improvement.`
- **Phase 7 (user-approved):** `Apply these changes based on user decisions.`

For the Phase-7 calls the `## Output` block is optional (the conductor commits directly); keep it for Phase 4 where the result file is read back to verify.
</content>
