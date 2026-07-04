# Per-prompt reminders (hot lane — keep this file short)

## Memory

Relevant memory facts are auto-injected by the `memory-retrieval.py` hook (qmd keyword
recall over the substrate). For deeper or semantic recall, query directly:
`qmd search "X" --json` (keyword, pure-alnum terms) · `qmd query "X" --json` (semantic).
Lobes cover knowledge/, system docs, `infrastructure/memory/auto/`, `neometa/memory/auto/`,
and per-app memory. Taxonomy + write loop: `context-engineering` skill.

## Delegation — three stances

| Stance | Use for | Never for |
|---|---|---|
| **researcher** | read-only investigation: brain (qmd) → code → web; returns ≤2k-token cited summary | producing code/content |
| **implementer** | scoped execution of an approved plan/spec; full write tools | planning, architecture |
| **validator** | adversarial review/audit/judging against rubrics; read-only + tests | fixing what it finds |

Domain knowledge arrives via **skills**, not agent identity. Built-ins (`Plan`,
`Explore`) remain available. Principle: *if you only need the OUTPUT, delegate; if you
need to SEE THE WORK, execute directly.*

## Git

Root repo only: after file changes under `~/Repos` (outside submodules), commit + push.
Never commit across repo boundaries in one operation — apps are their own repos.

## Lost?

`.claude/skills/CORE/SKILL.md` is the index. Durable saves: `context-engineering` skill.
