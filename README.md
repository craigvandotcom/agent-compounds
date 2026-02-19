# Agent Compounds

Tools and skills that compound. Each builds on the last.

Drop into `.claude/skills/` for Claude Code, or use standalone from the terminal.

## Skills

| Skill | What it does |
|-------|-------------|
| **[expert-consensus](./expert-consensus/)** | Fan out one prompt to multiple AI models, synthesize into consensus |

## Quick Start

```bash
pip install openai
export OPENROUTER_API_KEY=sk-or-...  # https://openrouter.ai/keys

# Fan out to 5 models + synthesize
./expert-consensus/openrouter.py --all --synthesize "Your question"

# Ask one model
./expert-consensus/openrouter.py "Your question" -m claude

# Configure your expert team
./expert-consensus/openrouter.py --panel
```

### As a Claude Code skill

```bash
cp -r expert-consensus /path/to/your/project/.claude/skills/
```

Claude Code discovers the `SKILL.md` automatically.

### Configure your panel

Edit `expert-consensus/panel.json` to enable/disable models:

```bash
./expert-consensus/openrouter.py --init-panel  # Generate fresh config
```

Default: 5 models enabled. 9 available. Toggle `"enabled": true/false` to customize.

## Philosophy

- **Compound, don't collect** — each skill should make the next one more valuable
- **SKILL.md is the interface** — human-readable reference that doubles as AI context
- **Standalone by default** — no frameworks, no setup wizards
- **Configurable** — sensible defaults, easy overrides

## License

MIT
