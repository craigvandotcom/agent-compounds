# Test registry — fixture for 26-readme-ghosts (must go RED)

Two ghost rows: a plain-text bold name and a link row to a missing dir. The
Dependency table's plain `**openrouter**` must NOT be flagged (not a Skill table).

| Skill | What it does |
|-------|-------------|
| **[real-one](./skills/real-one/)** | exists on disk |
| **ghost-skill** | plain-text row naming a skill that was archived |
| **[dead-link](./skills/dead-link/)** | link row whose target dir was removed |

| Agent | What it does |
|-------|-------------|
| **[researcher](./agents/researcher.md)** | stance, not a skill |

| Dependency | What it provides | Install |
|-----------|-----------------|---------|
| **openrouter** | CLI for multi-model queries | install the CLI |
| **[agent-browser](https://example.com/agent-browser)** | headless browser CLI | npm install |
