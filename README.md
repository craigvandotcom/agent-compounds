# Agent Compounds

Tools and skills that compound. Each builds on the last.

Drop into `.claude/skills/` for Claude Code, or use standalone from the terminal.

## Skills

| Skill | What it does |
|-------|-------------|
| **[expert-consensus](./expert-consensus/)** | Fan out one prompt to multiple AI models, synthesize into consensus |

## Quick Start

1. `export OPENROUTER_API_KEY=sk-or-...` ([get one here](https://openrouter.ai/keys))
2. `pip install openai`
3. Run:

```bash
# Fan out to 5 models + synthesize
./expert-consensus/openrouter.py --all --synthesize "Your question"

# Ask one model (any OpenRouter model ID works)
./expert-consensus/openrouter.py "Your question" -m anthropic/claude-opus-4.6

# See your expert team
./expert-consensus/openrouter.py --panel
```

### As a Claude Code skill

```bash
cp -r expert-consensus /path/to/your/project/.claude/skills/
```

Claude Code discovers the `SKILL.md` automatically.

## Philosophy

- **Compound, don't collect** — each skill should make the next one more valuable
- **SKILL.md is the interface** — human-readable reference that doubles as AI context
- **Standalone by default** — no frameworks, no setup wizards
- **One config file** — `expert-panel.json` has everything

## License

MIT
