# Agent Compounds

Tools and skills that compound. Each builds on the last.

Drop into `.claude/skills/` for Claude Code, or use standalone from the terminal.

## Skills

| Skill | What it does |
|-------|-------------|
| **[expert-consensus](./expert-consensus/)** | Send one prompt to 9 flagship AI models, get synthesized consensus |

## Usage

### As a Claude Code skill

```bash
cp -r expert-consensus /path/to/your/project/.claude/skills/
```

Claude Code discovers the `SKILL.md` automatically.

### Standalone

```bash
pip install openai
export OPENROUTER_API_KEY=sk-or-...

# Fan out to all 9 models at once
./expert-consensus/openrouter.py --all "Your question"

# Or ask one model
./expert-consensus/openrouter.py "Your question" -m claude
```

### Configure your panel

Edit `expert-consensus/panel.json` to enable/disable models:

```json
{"alias": "llama", "model": "meta-llama/llama-4-maverick", "enabled": false}
```

## Philosophy

- **Compound, don't collect** — each skill should make the next one more valuable
- **SKILL.md is the interface** — human-readable reference that doubles as AI context
- **Standalone by default** — no frameworks, no setup wizards
- **Configurable** — sensible defaults, easy overrides

## License

MIT
