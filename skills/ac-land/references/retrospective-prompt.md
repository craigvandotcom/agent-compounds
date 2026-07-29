# Retrospective Analyst Prompt (Phase 2)

Spawn after landing. Substitute the resolved `<ARTIFACTS_DIR>` from Phase 0.

```
Task(subagent_type: "general-purpose", model: "sonnet", prompt: """
You are a retrospective analyst reviewing a completed bead-work session.

## Session Artifacts

Read these files:
1. <ARTIFACTS_DIR>/progress.md — beads completed, commits, files changed
2. Any <ARTIFACTS_DIR>/bead-*-result.md files — engineer implementation reports
3. AGENTS.md — current project context, conventions, and coding standards

**If a lane's `progress.md` is a stub or header-only** (no beads/commits listed) — common: 10 of 13
lanes in RUN 20260719-102946-27401 — do NOT conclude the lane did no work. Fall back to the batch
review artifacts (`.claude/reviews/batch/*.md`, plus anything staged in `.claude/reviews/pending/`)
and `br show <id>` close reasons to reconstruct that lane's work BEFORE analyzing it. This is a
safety net for the retrospective's own blind spot, not a licence to leave the stubs unfixed.

## Workflow & Skill Files

Read the command files that ran during this session so you can identify workflow friction:
- `.claude/skills/ac-implement/SKILL.md` — the implementation workflow
- `.claude/skills/ac-land/SKILL.md` — this landing workflow

Scan the full skill inventory (AGENTS.md > Available Skills) against the beads implemented. Look for:
- Skill files referenced by beads — read these for domain pattern violations
- Skills that SHOULD have been used but weren't — e.g., a migration bead that didn't leverage the supabase skill, or a component bead that ignored the design-system skill. Flag these as upgrade opportunities.

## Git Context

Run these commands to understand the session's work:
- `git log --oneline -20` — recent commits
- `git diff HEAD~N..HEAD --stat` (where N = number of session commits) — files changed

## Your Analysis

Write your findings to <ARTIFACTS_DIR>/retrospective.md with these sections:

### What Worked
- Patterns that produced clean, fast results
- Bead specs that led to good implementations
- Tools/commands that worked smoothly

### What Didn't Work
- Beads that needed multiple engineer attempts (and why)
- Quality gate failures and their causes
- Friction points in the workflow

### Patterns Observed
- Recurring code patterns across beads
- Common test patterns
- Dependency patterns

### System Upgrade Opportunities

Look across ALL system files — not just MEMORY.md. Each target type has a purpose:

| Target | What belongs here | Example |
|--------|------------------|---------|
| `.claude/skills/*.md` | Workflow steps that caused friction, missing instructions, unclear prompts | "bead-work Phase 1c should remind conductor to scope test runs" — NOTE: shared skills are symlinks into agent-compounds — an edit here changes EVERY app. Confirm scope; app-specific lessons go to the app's CORE instead. |
| `.claude/skills/*.md` | Domain patterns discovered or violated during implementation | "testing skill should document the dotenv-worker quirk" — NOTE: shared skills are symlinks into agent-compounds — an edit here changes EVERY app. Confirm scope; app-specific lessons go to the app's CORE instead. |
| `AGENTS.md` | New conventions, quality gate changes, project-wide rules | "Add convention: never hardcode secrets in test files" |
| `MEMORY.md` | Gotchas and quirks that don't fit the above — last resort, not default | "supabase gen types outputs debug line" |

**MINIMUM BAR for proposing an upgrade:** The issue must have caused measurable waste THIS session — lost time, wasted tokens, incorrect output, or a mistake that had to be fixed. "Sounds like a good idea" or "might help someday" is NOT sufficient. The information must be non-obvious (an experienced engineer wouldn't know it without hitting the problem), and having it documented from the start would have saved real time or resources.

If nothing caused real waste this session, propose zero upgrades. Empty is better than bloat.

For each opportunity that clears the bar, provide:
- **Target:** The specific file path to update
- **Change:** What specifically to add, modify, or remove
- **What it cost us:** Concrete time/resource waste from this session (e.g., "engineer touched 12 unrelated files, conductor spent 10 minutes selectively staging")
- **Evidence:** Specific examples from this session

Prioritize command/skill improvements over MEMORY.md additions. If a learning improves a workflow step, put it in the command file. If it documents a domain pattern, put it in the skill file. MEMORY.md is for one-off quirks only.

Context bloat is the enemy. Prefer refining existing content over adding new content.
If nothing caused real waste, say so — don't invent learnings to fill the report.
""")
```
