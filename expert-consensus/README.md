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

## Setup

1. `pip install openai`
2. `export OPENROUTER_API_KEY=sk-or-...` (get one at [openrouter.ai/keys](https://openrouter.ai/keys))
3. Toggle models in `config.json`
4. Run: `./openrouter.py --all --synthesize "Your question"`

## Configure

Models are in `config.json`. Toggle `"enabled": true/false` to add or remove models. Any [OpenRouter model ID](https://openrouter.ai/models) works.

```json
{
  "models": [
    {"alias": "claude", "model": "anthropic/claude-opus-4.6", "enabled": true, ...},
    {"alias": "llama",  "model": "meta-llama/llama-4-maverick", "enabled": false, ...}
  ]
}
```

See [SKILL.md](./SKILL.md) for full reference.
