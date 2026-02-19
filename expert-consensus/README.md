# Expert Consensus

Send one prompt to multiple AI models. Get one synthesized answer.

```
$ openrouter --all --synthesize "What makes a great API?"
Querying 5 models: claude, gpt, gemini, deepseek, grok

============================================================
  CLAUDE (anthropic/claude-opus-4.6)
============================================================

A great API prioritizes consistency, discoverability, and...

============================================================
  GPT (openai/gpt-5.2)
============================================================

The hallmarks of excellent API design are predictability...

  ... (3 more models) ...

============================================================
  SYNTHESIS (anthropic/claude-opus-4.6)
============================================================

## Consensus
All five models converge on three core principles...

## Agreement
- Consistent naming conventions and error formats (5/5)
- Comprehensive documentation with examples (5/5)
- Versioning strategy from day one (4/5)

## Disagreement
- REST vs GraphQL: Claude and GPT favor REST for simplicity,
  Gemini argues GraphQL reduces over-fetching...

## Unique Insights
- Grok: "The best APIs are the ones nobody notices"
- DeepSeek: Rate limiting as a feature, not just protection
```

## Quick Start

```bash
pip install openai
export OPENROUTER_API_KEY=sk-or-...  # https://openrouter.ai/keys

# Single model
./openrouter.py "Your question" -m claude

# Fan out to panel
./openrouter.py --all "Your question"

# Fan out + synthesize into consensus
./openrouter.py --all --synthesize "Your question"
```

## Configure Your Panel

Edit `panel.json` to enable/disable models:

```bash
./openrouter.py --panel           # See current team
./openrouter.py --init-panel      # Generate fresh panel.json
```

Default: 5 models enabled. Toggle `"enabled": true/false` to customize.

See [SKILL.md](./SKILL.md) for full reference.
