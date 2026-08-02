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
- **Speak ASD-STE100:** report to Craig in Simplified Technical English — one idea per
  sentence · max 20 words · active voice · simple tenses · one word = one meaning · no
  gerund stacks. Lead with the answer; full picture in the fewest words. Operator voice
  only (reports, summaries, chat) — never audience content.
- **Least-change edits:** reach the outcome with less, not more. Before adding lines,
  files, options or abstractions, ask what this replaces. Delete what the change makes
  dead. Volume is not value.
