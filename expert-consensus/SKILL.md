---
name: expert-consensus
description: Send one prompt to multiple AI models. Get one synthesized answer.
version: 1.0.0
tools: [openrouter.py, panel.json]
---

# Expert Consensus — Multi-Model AI Synthesis

Send one prompt to a panel of the world's best AI models. Get one synthesized answer.

## How It Works

1. **Fan out** — your prompt goes to all enabled models in parallel
2. **Collect** — each model responds independently
3. **Synthesize** — `--synthesize` merges into a single consensus, noting agreement and disagreement

## The Panel (Feb 2026)

| Alias | Model | Provider | Strength |
|-------|-------|----------|----------|
| `claude` | Opus 4.6 | Anthropic | Deepest reasoning, edge cases |
| `gpt` | GPT-5.2 | OpenAI | Strong all-round, structured output |
| `gemini` | Gemini 3 Pro | Google | Creative connections, multimodal |
| `deepseek` | DeepSeek R1 | DeepSeek | Best open-source reasoning |
| `grok` | Grok 4 | xAI | Contrarian, evidence citations |
| `llama` | Llama 4 Maverick | Meta | 128-expert MoE, multimodal |
| `kimi` | Kimi K2.5 | Moonshot | Best value, deep domain knowledge |
| `glm` | GLM-5 | ZHIPU | Factual accuracy, catches errors |
| `qwen` | Qwen 3.5 397B | Alibaba | Native multimodal, 201 languages |

Default: 5 enabled (claude, gpt, gemini, deepseek, grok). Toggle the rest in `panel.json`.

## Setup

```bash
pip install openai
export OPENROUTER_API_KEY=sk-or-...  # https://openrouter.ai/keys
chmod +x openrouter.py
```

## Quick Start

### Ask one model

```bash
openrouter "Explain monads in 3 sentences" -m claude
```

### Fan out to the panel

```bash
openrouter --all "What are the 3 most important principles of API design?"
```

### Fan out + synthesize into consensus

```bash
openrouter --all --synthesize "What makes a great API?"
```

### Save responses to a directory

```bash
openrouter --all --synthesize "Compare React vs Svelte" -o /tmp/results/
# Creates claude.md, gpt.md, ..., synthesis.md
```

## Configuring Your Panel

Edit `panel.json` next to the script, or generate a fresh one:

```bash
openrouter --init-panel    # Generate panel.json with defaults
openrouter --panel         # Show current team
```

Toggle `"enabled": true/false` to add/remove models:

```json
[
  {"alias": "claude", "model": "anthropic/claude-opus-4.6", "enabled": true, ...},
  {"alias": "llama",  "model": "meta-llama/llama-4-maverick", "enabled": false, ...}
]
```

**Add a new model:** Append an entry with any alias and OpenRouter model ID.

**Remove a model:** Set `"enabled": false` (keeps config for re-enabling later).

**Update a model:** Change the `"model"` field to a newer version.

## Consensus Patterns

### Pattern 1: Quick Consensus

Disable all but your top 3 in `panel.json`, then:

```bash
openrouter --all --synthesize "Your question"
```

### Pattern 2: Full Panel (all 9)

Enable all models in `panel.json`, then:

```bash
openrouter --all --synthesize "Your question" -v
```

### Pattern 3: Stress Test an Idea

```bash
openrouter "Devil's advocate: why is [idea] a bad idea?" -m grok --no-stream
openrouter "What risks does [idea] miss?" -m glm --no-stream
openrouter "Steel man the case against [idea]" -m deepseek --no-stream
```

### Pattern 4: Custom Synthesis Model

```bash
openrouter --all --synthesize --synth-model gpt "Your question"
```

## CLI Reference

```bash
openrouter "prompt" -m claude                        # Single model
openrouter "prompt" --image photo.png -m gemini      # Vision
openrouter "prompt" -m claude --web                  # Web search
openrouter --file prompt.md -m gpt --no-stream       # File input
echo "prompt" | openrouter -m deepseek               # Pipe
openrouter "prompt" -m claude --fallback gpt deepseek # Fallbacks
openrouter "prompt" -m gpt --json-mode               # JSON output
openrouter --all "prompt"                            # Fan out to panel
openrouter --all --synthesize "prompt"               # Fan out + synthesize
openrouter --all --synthesize "prompt" -o /tmp/out/  # + save results
openrouter --panel                                    # Show panel
openrouter --init-panel                               # Generate panel.json
openrouter --aliases                                  # Show aliases
openrouter --list-models anthropic --pricing         # Browse models
```

## Checking for Newer Models

```bash
openrouter --list-models anthropic --pricing
openrouter --list-models openai --pricing
openrouter --list-models google --pricing
openrouter --list-models deepseek --pricing
openrouter --list-models meta-llama --pricing
openrouter --list-models x-ai --pricing
openrouter --list-models moonshotai --pricing
openrouter --list-models z-ai --pricing
openrouter --list-models qwen --pricing
```

If a newer flagship is available, update `panel.json`.

## Variants

Append with colon to any alias:

| Variant | Effect |
|---------|--------|
| `:online` | Web search enabled |
| `:nitro` | Throughput-optimized |
| `:floor` | Price-optimized |
| `:free` | Free tier |
| `:extended` | Extended context |

Example: `openrouter "Search for X" -m claude:online`

## Tips

- `--all` runs models in parallel (ThreadPoolExecutor) — fast even with 9 models
- `--synthesize` feeds all responses to one model to produce structured consensus
- Use `-v` (verbose) to see timing and token counts per model
- `-o DIR` with `--all` saves each response as `alias.md` in that directory
- Diversity beats quantity — 4 different providers > 4 models from one provider
- Default model is Claude Opus 4.6 when no `-m` specified
