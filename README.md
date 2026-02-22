# Agent Compounds

Tools and skills that compound. Each builds on the last.

Drop into `.claude/` for Claude Code, or use standalone from the terminal.

## Skills

| Skill | What it does |
|-------|-------------|
| **[openrouter](./skills/openrouter/)** | Access 400+ AI models. Discover, select, and query the right model for any task |
| **[expert-consensus](./skills/expert-consensus/)** | Fan out one prompt to multiple AI models, synthesize into consensus |

## Commands

_Coming soon._

## Prompts

_Coming soon._

## Sub-Agents

_Coming soon._

## Quick Start

1. `export OPENROUTER_API_KEY=sk-or-...` ([get one here](https://openrouter.ai/keys))
2. `pip install openrouter-cli` (for openrouter skill) or `pip install openai` (for expert-consensus)
3. Copy into your project:

```bash
cp -r skills/expert-consensus /path/to/your/project/.claude/skills/
```

4. Use in Claude Code:

```
/expert-consensus What makes a great API?
```

Claude Code discovers the `SKILL.md` automatically. Toggle models in `expert-panel.json`.

## Philosophy

- **Compound, don't collect** — each skill should make the next one more valuable
- **SKILL.md is the interface** — human-readable reference that doubles as AI context
- **Standalone by default** — no frameworks, no setup wizards
- **One config file** — `expert-panel.json` has everything

## License

MIT
