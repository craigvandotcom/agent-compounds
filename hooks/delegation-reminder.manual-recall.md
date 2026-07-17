# Memory context — load alongside the user prompt

This harness receives no per-prompt hook injection — pull recall MANUALLY before
drafting a response:

```bash
qmd search "<task keywords>" --limit 5
```

- Run a search (task = 2-6 word summary of the user prompt above)
- Review results: facts, rules, decisions, recipes relevant to this task
- If the task touches prior work, widen the search and check hits carefully
- Integrate into working context before acting

**The full recall stack (know these cold):** `qmd query "X" --json` (knowledge +
memory + wiki lobes) · `cass search "X" --json` (past agent-session transcripts —
"did we discuss X?") · `cm context "<task>" --json` (procedural playbook rules).
Full tool registry: `~/Repos/.claude/skills/CORE/tools.md`.

**Order of operations:** If the user prompt is a scheduled heartbeat, run the
heartbeat's first Takeoff step (`date`, or its named first step) first, then this
recall pull, then continue the heartbeat sequence. Memory load is supplementary
context — it does NOT replace executing the user prompt.

---

## Knowledge base (qmd)

Collections span the PKM vault (`knowledge/`), system docs, memory substrates, wiki
synthesis pages, and per-app lobes — `qmd status` lists them all with doc counts.

**Use qmd when:** the query needs past writing/notes/research, semantic understanding
("concepts related to X"), or any search across the vault.
**Use cass when:** the question is about a past SESSION ("did we discuss/decide X?").
**Use cm when:** starting a task that likely has procedural rules from prior runs.

---

## Core Protocol

**Read:** `~/Repos/.claude/skills/CORE/SKILL.md` (identity, capabilities, quick-nav)
**Doctrine:** `~/Repos/AGENTS.md` (delegation stances, memory routing, tool inventory)

**Git (root repo only):** after file changes under `~/Repos` outside app repos,
commit + push. Never commit across repo boundaries in one operation.

---

## Delegation — the three stances

Delegate non-trivial work to a subagent by stance (all defined in `.claude/agents/`):

| Stance | Use for | Never for |
|--------|---------|-----------|
| **researcher** | read-only investigation (brain → code → web), returns cited summary | making changes |
| **implementer** | scoped execution of an approved plan/spec | planning, verification |
| **validator** | adversarial review/audit against rubrics & tests | fixing what it finds |

**Context principle:** "If I only need OUTPUT, delegate. If I need to SEE THE WORK,
execute directly." The orchestrator holds decisions; subagents hold file contents.

---

## Navigation lost?

1. **Quick-nav table:** `~/Repos/.claude/skills/CORE/SKILL.md`
2. **Skill inventory:** `~/Repos/.claude/skills/pai/reference/skills-inventory.md`
3. **Search the knowledge base:** `qmd search "X" --json`
4. **Search past sessions:** `cass search "X" --json`
5. **Ask Craig** when architecture isn't clear
