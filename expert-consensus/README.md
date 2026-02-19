# Expert Consensus

Send one prompt to multiple AI models. Get one synthesized answer.

## Setup

1. `export OPENROUTER_API_KEY=sk-or-...` (get one at [openrouter.ai/keys](https://openrouter.ai/keys))
2. `pip install openai`
3. Toggle models in `expert-panel.json`

### As a Claude Code skill (recommended)

```bash
cp -r expert-consensus /path/to/your/project/.claude/skills/
```

Then use: `/expert-consensus What makes a great API?`

The agent fans out to all models, reads responses, and synthesizes the consensus itself.

### Standalone (terminal)

```bash
# Fan out + synthesize via OpenRouter
./openrouter.py --all --synthesize "What makes a great API?"

# Single model
./openrouter.py "Your question" -m anthropic/claude-opus-4.6

# See your expert team
./openrouter.py --panel
```

## Configure

Models are in `expert-panel.json`. Toggle `"enabled": true/false` to add or remove models. Any [OpenRouter model ID](https://openrouter.ai/models) works.

```json
{
  "models": [
    {"alias": "claude", "model": "anthropic/claude-opus-4.6", "enabled": true, ...},
    {"alias": "llama",  "model": "meta-llama/llama-4-maverick", "enabled": false, ...}
  ]
}
```

See [SKILL.md](./SKILL.md) for full reference.
