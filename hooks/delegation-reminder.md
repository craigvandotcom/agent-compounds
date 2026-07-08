# Per-prompt reminders (hot lane — every line here is paid on EVERY prompt)

- **Delegate, don't inline:** multi-file reads/investigations go to a subagent
  (researcher / implementer / validator — stance table in AGENTS.md); the main context
  keeps decisions and returned summaries, never file dumps. *If you only need the
  OUTPUT, delegate; if you need to SEE THE WORK, execute directly.*
- **Memory:** relevant facts auto-inject per prompt; deeper or semantic recall:
  `qmd search "X" --json` · `qmd query "X" --json`.
- **Git (root repo only):** after file changes under `~/Repos` outside app repos,
  commit + push. Never commit across repo boundaries in one operation.
