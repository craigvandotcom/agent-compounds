---
name: expert-consensus
description: Send one prompt to multiple AI models. Get one synthesized answer.
version: 1.0.0
tools: [openrouter.py, panel.json]
---

# Expert Consensus

Fan out one prompt to a panel of frontier AI models in parallel, then synthesize into a single consensus answer.

## When to Use

- Important decisions that benefit from multiple perspectives
- Research questions where model blind spots matter
- Stress-testing an idea against diverse reasoning styles
- Any time you want higher confidence than a single model provides

## Usage

The script is at `openrouter.py` in this skill directory. Requires `OPENROUTER_API_KEY` env var.

### Core Commands

```bash
# Fan out to all enabled models + synthesize consensus (most common)
python3 openrouter.py --all --synthesize "Your question"

# Fan out without synthesis (raw responses only)
python3 openrouter.py --all "Your question"

# Single model query
python3 openrouter.py "Your question" -m claude

# Save all responses + synthesis to directory
python3 openrouter.py --all --synthesize "Your question" -o /tmp/results/
```

### Options

| Flag | Effect |
|------|--------|
| `--all` | Fan out to all enabled panel models |
| `--synthesize` | Synthesize fan-out into consensus (use with `--all`) |
| `--synth-model MODEL` | Override synthesis model (default: claude) |
| `-m MODEL` | Single model query by alias or full ID |
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

### Model Aliases

| Alias | Model | Strength |
|-------|-------|----------|
| `claude` | anthropic/claude-opus-4.6 | Deepest reasoning, edge cases |
| `gpt` | openai/gpt-5.2 | Strong all-round, structured output |
| `gemini` | google/gemini-3-pro-preview | Creative connections, multimodal |
| `deepseek` | deepseek/deepseek-r1 | Best open-source reasoning |
| `grok` | x-ai/grok-4 | Contrarian, evidence citations |
| `llama` | meta-llama/llama-4-maverick | 128-expert MoE, multimodal |
| `kimi` | moonshotai/kimi-k2.5 | Best value, deep domain knowledge |
| `glm` | z-ai/glm-5 | Factual accuracy, catches errors |
| `qwen` | qwen/qwen3.5-397b-a17b | Native multimodal, 201 languages |

Default: 5 enabled (claude, gpt, gemini, deepseek, grok). Configure in `panel.json`.

Append `:online`, `:nitro`, `:floor`, `:free`, or `:extended` to any alias for variants.

## Patterns

**Quick consensus:** `--all --synthesize "question"` (default 5 models)

**Full panel:** Enable all 9 in `panel.json`, then `--all --synthesize -v "question"`

**Stress test:** Query contrarian models individually — grok for devil's advocate, deepseek for risk analysis, glm for fact-checking.

**Custom synthesis model:** `--all --synthesize --synth-model gpt "question"`

## Panel Configuration

Edit `panel.json` next to the script. Toggle `"enabled": true/false` per model.

To check for newer models: `python3 openrouter.py --list-models <provider> --pricing`
