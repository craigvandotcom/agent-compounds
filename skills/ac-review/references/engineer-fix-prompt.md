# Engineer Fix Prompt

<!-- mirror: ac-pipeline/references/delegation-contract.md § Child-spawn preamble -- edit there first -->

**Conductor: paste the block below VERBATIM at the head of EACH of the one `Task(...)`
prompt in this file, above its `First: read AGENTS.md` line, substituting the child's
minted `AGENT_NAME`.** It is the child-side environment contract and a pointer to it is
explicitly insufficient (canon § Child-spawn preamble) — a preamble that stays in this
header and never enters the constructed prompt has not been delivered to any child.

ENVIRONMENT CONTRACT (non-negotiable):
- WAIT for your own long-running commands in-shell (foreground, generous Bash
  timeout, or a foreground until-loop). Never arm a Monitor on your own command
  and end your turn — if a completion event already fired, read it and CONTINUE.
- Agent Mail: CHECK whether you hold `mcp__mcp-agent-mail__*` tools — assume neither way.
  Usually you do NOT: then don't try to register, and your conductor owns reservations.
  Either way, export the `AGENT_NAME` it gave you in each commit's own shell.
- Touching beads (`br`/`bv`)? The canon is `beads-standards` (+ its
  reference/bead-conventions.md for pipeline contracts) — read before inventing usage.
- After every push: verify origin SHA == local HEAD before proceeding.
- A guard block (dcg / pre-commit) means CHANGE APPROACH, never bypass. To DISCARD
  a change: `git checkout HEAD -- <path>` AND unscoped `git stash` are both blocked —
  use scoped `git stash push -- <paths>`; to read a pristine file, `git show <ref>:<path>`.
  Destructive commands (rm / find -delete) take FULLY-LITERAL paths: resolve
  first (`ls -d`), then paste literals — never `$VAR`, `$( )`, or a loop var.
  /tmp literals + distinctive /tmp globs are allowed; home/repo `rm -rf` never
  is — `git rm` if tracked, else gitignore-and-flag or ask the human.
- Shared checkout: commit your bead's files (pathspec-scoped) the INSTANT its
  ACs verify — minimal working-tree dwell; run `br` from the bead-board repo root.
- Autonomous run: never AskUserQuestion — Exhaust Rule.
- Return a structured `friction:` block (stage/cost/lesson/class; `[]` if clean).

The sub-agent prompt for applying a fix list. Used three times: Phase 4 (AUTO_FIX),
Phase 7 (AUTO_IMPLEMENT after conductor triage), and Phase 7 (user-approved decisions).
Substitute `{INTENT}`, `{FIXES}`, `{CMD_TEST/LINT/TYPECHECK}`, `{ARTIFACTS_DIR}`.

```
Task(subagent_type: "general-purpose", model: "sonnet", prompt: """
First: read AGENTS.md for project context.

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
