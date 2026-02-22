---
name: openrouter
description: Access 400+ AI models from any agent. Discover, select, and query the right model for any task.
version: 1.0.0
tools: [openrouter-cli (pip)]
---

# OpenRouter

Query any AI model from the terminal. One tool, every model.

## Prerequisites

```bash
pip install openrouter-cli
export OPENROUTER_API_KEY=sk-or-v1-...
```

Get a key at https://openrouter.ai/keys

Verify: `or --version`

## Core Usage

```bash
# Query a model
or "Your prompt here" -m <model_id> --raw

# Pipe input
echo "text" | or -m <model_id> -s "Summarize" --raw

# From file
or --file input.md -m <model_id> --raw

# JSON output for structured data
or "Extract entities" -m <model_id> --json-mode --raw

# Full JSON response (includes tokens, cost, timing)
or "Query" -m <model_id> --format json
```

Always use `--raw` when capturing output — it suppresses formatting and metadata, giving clean content for piping or saving.

## Model Selection

**Never hardcode model IDs.** Models change frequently. Use the discovery commands to find the right model at runtime.

### Step 1: Identify what you need

| Need | Selection strategy |
|------|-------------------|
| Best quality, cost doesn't matter | `or --top` → pick from Flagship |
| Cheapest that works | `or --list-models --pricing --sort price` → pick cheapest with adequate context |
| Largest context window | `or --list-models --pricing --sort context` → pick from top |
| Specific provider | `or --list-models <provider> --pricing` (e.g., `anthropic`, `google`, `openai`) |
| Reasoning/math/logic | `or --top` → pick from Reasoning |
| High throughput / low latency | `or --top` → pick from Speed & Value |
| Open source / self-hostable | `or --top` → pick from Open Source |
| Web search capability | Append `:online` to any model ID |

### Step 2: Discover current best models

```bash
# Curated top picks with live pricing — start here
or --top

# Filter to a provider
or --list-models anthropic --pricing

# Sort by price (cheapest first)
or --list-models --pricing --sort price

# Sort by context window (largest first)
or --list-models --pricing --sort context

# Get details on a specific model
or --model-info <model_id>
```

### Step 3: Use the model

```bash
or "Your prompt" -m <model_id_from_discovery> --raw
```

### Model variants

Append to any model ID with a colon:

| Variant | When to use |
|---------|-------------|
| `:online` | Need web search / current information |
| `:nitro` | Need maximum throughput |
| `:floor` | Need minimum cost |
| `:free` | Zero-cost tier (rate limited) |
| `:extended` | Need extra-long context |

Example: `or "Latest news on X" -m google/gemini-2.5-pro:online --raw`

## Agent Patterns

### Pick the best model for a task

```bash
# 1. Check what's currently top-tier
or --top

# 2. Pick model ID from the output
# 3. Use it
or "Your task" -m <chosen_model_id> --raw
```

### Multi-model consensus

```bash
# Fan out to multiple models in parallel
for model_id in $(or --top 2>&1 | grep -oP '^\s{4}\S+/\S+' | head -4 | tr -d ' '); do
  or "Your question" -m "$model_id" --raw -o "/tmp/response-$(echo $model_id | tr '/' '-').md" &
done
wait
# Then synthesize the responses
```

### Cost-optimized bulk processing

```bash
# Find cheapest model
cheap_model=$(or --list-models --pricing --sort price 2>&1 | grep -v 'free\|varies\|Models:' | head -1 | awk '{print $1}')

# Use it for bulk work
for f in docs/*.md; do
  or --file "$f" -m "$cheap_model" -s "Summarize in 3 bullets" --raw -o "summaries/$(basename $f)"
done
```

### Structured extraction

```bash
# JSON mode for structured output
or "Extract all names and roles from this text: ..." -m <model_id> --json-mode --raw

# With JSON schema validation
or "Extract entities" -m <model_id> --json-schema schema.json --raw
```

### Web-augmented queries

```bash
# Plugin-based web search
or "What happened in AI this week?" -m <model_id> --web --raw

# Provider-native search via variant
or "Current weather in Amsterdam" -m <model_id>:online --raw
```

### Vision / multimodal

```bash
or "Describe this image" --image screenshot.png -m <model_id> --raw
or "Compare these designs" --image a.png --image b.png -m <model_id> --raw
```

### PDF analysis

```bash
or "Summarize this paper" --pdf paper.pdf -m <model_id> --raw
```

### With reasoning

```bash
# Effort levels: xhigh, high, medium, low, minimal, none
or "Prove this theorem" -m <model_id> --reasoning high --raw

# Hide reasoning from output (use internally only)
or "Solve this" -m <model_id> --reasoning high --reasoning-exclude --raw
```

### Fallback chains

```bash
# Auto-failover: if primary fails, try next
or "Query" -m <primary_model> --fallback <backup1> <backup2> --raw
```

## Output Modes

| Flag | Use when |
|------|----------|
| `--raw` | Capturing output in scripts or piping |
| `--format json` | Need metadata (tokens, cost, timing, model used) |
| `-o file.md` | Save directly to file |
| `-v` | Debugging — shows model, tokens, cost, time on stderr |

## Key Flags Reference

| Flag | Description |
|------|-------------|
| `-m MODEL` | Model ID or alias, with optional :variant |
| `-s PROMPT` | System prompt |
| `-f FILE` | Load prompt from file |
| `--raw` | Content only, no formatting |
| `--format json` | Full JSON response |
| `-o PATH` | Save to file |
| `--web` | Enable web search |
| `--image FILE` | Attach image (repeatable) |
| `--pdf FILE` | Attach PDF (repeatable) |
| `--json-mode` | Request JSON output |
| `--json-schema FILE` | Validate against schema |
| `--reasoning EFFORT` | Reasoning tokens (xhigh/high/medium/low) |
| `--fallback M1 M2` | Fallback model chain |
| `--max-tokens N` | Limit output length |
| `-t TEMP` | Temperature (0.0-2.0) |
| `--top` | Show curated top models |
| `--list-models` | Browse model catalog |
| `--pricing` | Show prices |
| `--sort price\|context` | Sort model list |
