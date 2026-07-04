# Memory context — load alongside the user prompt

Before drafting a response, load memory context:

```bash
qmd search "<task keywords>" --limit 5
```

- Run a search (task = 2-6 word summary of the user prompt above)
- Review results: facts, rules, decisions, recipes relevant to this task
- Check if worldview principles apply to this task
- Integrate into working context before acting
- If the task touches prior work, widen the search and check hits carefully

**qmd is the memory substrate — the recall hook also injects relevant facts on
matching prompts, but an explicit search catches what the hook misses.**

**Order of operations:** If the user prompt is a scheduled heartbeat, run the heartbeat's first Takeoff step (`date`, or read soul.md) first, then this `qmd search` call, then continue the heartbeat sequence. This memory load is supplementary context — it does NOT replace executing the user prompt.

---

## Knowledge Base Search (qmd)

**When to use qmd tools:**
- User asks about past writing, notes, or research
- Query needs semantic understanding ("concepts related to X")
- Search across PKM vault (knowledge/) or system docs (.claude/)
- Finding specific files or content across 1,400+ documents

**Available tools:** qmd CLI via Bash — `qmd search "X" --json`, `qmd query "X" --json`, `qmd get "path"`, `qmd status`

**Collections:**
- `knowledge` - PKM vault (1,114 docs: projects, journals, research)
- `system` - PAI docs (318 docs: skills, agents, architecture)

**Use qmd when:** User query contains research/discovery intent
**Skip qmd when:** Only need session context (cm handles this)

---

## Core Protocol

**Read:** `.claude/skills/CORE/SKILL.md` (complete identity, capabilities, subagent rules)

**Execution default:** Direct execution using tools/MCPs. Delegate strategically for context isolation, parallel work, specialized depth.

**Git (root only):** After ANY file changes in `the repo root`, commit + push. Skip submodules.

---

## Mandatory Delegation

**`.claude/` directory changes → architect subagent (NO EXCEPTIONS)**
Includes: skills, agents, hooks, memory, settings. Architect understands progressive disclosure. File reads OK, edits require architect.

---

## Subagent Quick Reference

| Subagent | Mandatory For | Don't Use When |
|----------|---------------|----------------|
| architect | ANY `.claude/` modifications | Reading docs only |
| _(content)_ | Content tasks → use `/project content` to switch context (no root subagent) | Quick notes, bullet lists |
| strategist | Full planning with frameworks | Quick goal lookup, simple task |
| researcher | Multi-source deep investigations | Single WebSearch, reading one file |
| administrator | Complex multi-step life ops | Single message/email/task |
| advisor | Complex life decisions | Simple preference questions |
| librarian | Bulk PKM operations | Filing single document |

**Details:** `.claude/skills/CORE/subagent-usage.md`

---

## Workflow Reminder

**Complex tasks (5+ steps):** Generate workflow first, decide delegation per step.

**Context principle:** "If I only need OUTPUT, delegate. If I need to SEE THE WORK, execute directly."

---

## Navigation Lost?

If unsure what to do or where to find information:

1. **Check decision tree:** `.claude/skills/CORE/SKILL.md` (Decision Tree: When Uncertain section)
2. **Use quick nav table:** `.claude/skills/CORE/SKILL.md` (Quick Navigation section)
3. **Search knowledge base:** qmd CLI via Bash (`qmd search "X" --json`)
4. **Check memory context:** `qmd search "<task keywords>" --limit 5`
5. **Ask Craig:** When architecture isn't clear

**Common confusion points:**
- "What skill handles X?" → `pai/reference/skills-inventory.md`
- "Where do I schedule jobs?" → `admin/workflows/calendar-management.md`
- "Which subagent for this task?" → CORE decision tree
- "How do I build a workflow?" → `pai/workflows/build-workflow.md`
