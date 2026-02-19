---
name: expert-consensus
description: Send one prompt to multiple AI models. Get one synthesized answer.
version: 1.0.0
tools: [openrouter.py, config.json]
---

# Expert Consensus

Fan out one prompt to a panel of frontier AI models in parallel, then synthesize into a single consensus answer.

## When to Use

- Important decisions that benefit from multiple perspectives
- Research questions where model blind spots matter
- Stress-testing an idea against diverse reasoning styles
- Any time you want higher confidence than a single model provides

## Usage

The script is at `openrouter.py` in this skill directory. Configuration is in `config.json`.

### Core Commands

```bash
# Fan out to all enabled models + synthesize consensus (most common)
python3 openrouter.py --all --synthesize "Your question"

# Single model query (any OpenRouter model ID works)
python3 openrouter.py "Your question" -m anthropic/claude-opus-4.6

# Save all responses + synthesis to directory
python3 openrouter.py --all --synthesize "Your question" -o /tmp/results/
```

### Options

| Flag | Effect |
|------|--------|
| `--all` | Fan out to all enabled models |
| `--synthesize` | Synthesize fan-out into consensus (use with `--all`) |
| `--synth-model MODEL` | Override synthesis model (default: first enabled) |
| `-m MODEL` | Single model query by ID or alias |
| `-o PATH` | Save output to file (single) or directory (`--all`) |
| `--no-stream` | Wait for full response instead of streaming |
| `--web` | Enable web search |
| `--image FILE` | Attach image (vision) |
| `--file FILE` | Load prompt from file |
| `--json-mode` | Request JSON output |
| `--fallback M1 M2` | Fallback models if primary fails |
| `-v` | Verbose — show timing and token counts |
| `--panel` | Show current expert team |
| `--aliases` | Show all model aliases |
| `--list-models FILTER --pricing` | Browse available models |

### Models

Run `python3 openrouter.py --panel` to see the current team. All models are configured in `config.json` — edit that file to update model IDs, add new models, or toggle enabled/disabled.

Append `:online`, `:nitro`, `:floor`, `:free`, or `:extended` to any alias for variants.

## Patterns

**Quick consensus:** `--all --synthesize "question"`

**Stress test:** Query contrarian models individually for devil's advocate, risk analysis, fact-checking.

**Custom synthesis model:** `--all --synthesize --synth-model gpt "question"`

## Configuration

- **API key**: `OPENROUTER_API_KEY` environment variable (get one at https://openrouter.ai/keys)
- **Models**: `config.json` next to the script — array of models with alias, model ID, enabled flag, and strength description

To regenerate a fresh default: `python3 openrouter.py --init-config`
