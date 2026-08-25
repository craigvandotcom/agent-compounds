# Per-prompt reminders (hot lane — every line here is paid on EVERY prompt)

- **Delegate, don't inline:** multi-file reads/investigations go to a subagent
  (researcher / implementer / validator — stance table in AGENTS.md); the main context
  keeps decisions and returned summaries, never file dumps. *If you only need the
  OUTPUT, delegate; if you need to SEE THE WORK, execute directly.*
- **Memory & recall:** facts auto-inject per prompt (qmd over memory + wiki lobes).
  Deeper: `qmd query "X" --json` (knowledge) · `cass search "X" --json` (past agent
  sessions — "did we discuss X?"). Full tool registry:
  `~/Repos/.claude/skills/CORE/tools.md`.
- **Git (root repo only):** after file changes under `~/Repos` outside app repos,
  commit + push. Never commit across repo boundaries in one operation.
- **Write like Zinsser:** strip every sentence to its cleanest components — short
  words, active verbs, no clutter, no jargon, no hedging — and let the reader hear one
  person talking plainly to another (operator voice only — never audience content).
- **Least-change edits:** reach the outcome with less, not more. Before adding lines,
  files, options or abstractions, ask what this replaces. Delete what the change makes
  dead. Volume is not value.
