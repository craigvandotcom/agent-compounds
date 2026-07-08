---
name: openrouter
description: Use when a task needs a specific or non-default AI model — Claude, GPT, Gemini, Grok, DeepSeek, or another of 400+ models via OpenRouter. Triggers on "query a model", "which model for", "use OpenRouter", "list available models", "ask GPT/Gemini/Grok directly", "run this on <model>", "switch model for this task", "non-default model".
tools: [openrouter (infrastructure/tools)]
---

> **Generic skill — method only, zero app facts.** This skill is symlinked from
> agent-compounds and shared across consuming apps. It contains technique and
> patterns, not project specifics. **App specifics (project refs, schema names,
> domain rules, feature flows, env values) → read this app's
> `.claude/skills/CORE/SKILL.md`** (and the `AGENTS.md` summary it indexes).
> Do not add app-specific facts to this file — they belong in CORE.

# OpenRouter

Query any AI model from the terminal. One tool, every model.

## Model Policy

**Approved providers (use ONLY these unless user specifies otherwise):**
- Anthropic (Claude)
- Google (Gemini)
- OpenAI (GPT, o-series)
- xAI (Grok)
- DeepSeek (consensus-diversity panelist via expert-consensus)

### Configured Models (last verified: 2026-06-11)

#### Quality Tier (complex reasoning, analysis, generation)

| Provider | Model ID | Alias | Released | $/M prompt | $/M completion |
|----------|----------|-------|----------|-----------|---------------|
| Anthropic | `anthropic/claude-sonnet-4.6` | `claude` | 2026-03 | $3.00 | $15.00 |
| Anthropic | `anthropic/claude-opus-4.6` | `opus` | 2026-03 | $5.00 | $25.00 |
| OpenAI | `openai/gpt-5.4` | `gpt` | 2026-03 | $2.50 | $15.00 |
| Google | `google/gemini-3.1-pro-preview` | `gemini` | 2026-03 | $2.00 | $12.00 |
| xAI | `x-ai/grok-4.20` | `grok` | 2026-03 | $2.00 | $6.00 |

#### Speed & Cost Tier (bulk work, simple tasks, scripting)

| Provider | Model ID | Alias | Released | $/M prompt | $/M completion |
|----------|----------|-------|----------|-----------|---------------|
| Google | `google/gemini-2.5-flash` | `gemini-flash` | 2025-12 | $0.30 | $2.50 |
| xAI | `x-ai/grok-4.20` | `grok` | 2026-03 | $2.00 | $6.00 |
| OpenAI | `openai/gpt-5.4-mini` | `gpt-mini` | 2026-03 | $0.75 | $4.50 |

#### Reasoning Tier (math, logic, multi-step problems)

| Provider | Model ID | Alias | Notes |
|----------|----------|-------|-------|
| OpenAI | `openai/o3` | `o3` | Best for pure reasoning |
| OpenAI | `openai/o4-mini` | `o4-mini` | Fast reasoning, lower cost |
| Any | Any model + `--reasoning high` | - | Extended thinking on supported models |

### Freshness Check (REQUIRED before each use)

Before calling any model, the agent MUST:

1. Run `openrouter --list-models <provider> --pricing` for the chosen provider
2. Compare the latest available model against the configured model above
3. **If a newer model exists from the same provider:**
   - Ask the user: "Found newer model `<new_id>` from `<provider>` (configured: `<old_id>`). Replace in policy?"
   - If user approves, use the newer model AND note it needs updating in this file
   - If user declines, proceed with the configured model
4. If no newer model exists, proceed with the configured model

**Exception:** For quick/scripted calls where the agent is chaining many requests, skip the freshness check and use the alias directly. The aliases are maintained in `openrouter.py` and updated periodically.

### Default Selection

| Task type | Default pick |
|-----------|-------------|
| General quality work | `claude` (Sonnet 4.6) |
| Budget/bulk processing | `gemini-flash` or `gpt-mini` |
| Structured extraction / JSON | `gpt-mini` |
| Reasoning / math | `o3` or `claude --reasoning high` |
| Web search needed | Any model + `--web` or `:online` variant |
| Second opinion / consensus | Fan out to one from each provider |

## Prerequisites

```bash
# openrouter is provided by infrastructure/tools (already in PATH via tools/bin/)
export OPENROUTER_API_KEY=sk-or-v1-...
```

Get a key at https://openrouter.ai/keys

Verify: `openrouter --aliases`

## Core Usage

```bash
# Query a model
openrouter "Your prompt here" -m <model_id> --raw

# Pipe input
echo "text" | openrouter -m <model_id> -s "Summarize" --raw

# From file
openrouter --file input.md -m <model_id> --raw

# JSON output for structured data
openrouter "Extract entities" -m <model_id> --json-mode --raw

# Full JSON response (includes tokens, cost, timing)
openrouter "Query" -m <model_id> --format json
```

Always use `--raw` when capturing output — it suppresses formatting and metadata, giving clean content for piping or saving.

## Model Discovery

### Verify before use

**The "Configured Models" table is a curated snapshot, not exhaustive.** OpenRouter has 400+ models and the catalog updates frequently. The codebase config in `lib/ai/models.ts` (or equivalent) is similarly a curated subset. Before invoking any model ID NOT in those tables, verify it exists on the live OpenRouter catalog:

```bash
# Quick exact-match check
curl -s -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  https://openrouter.ai/api/v1/models | jq -r '.data[].id' | grep -F "<model-id>"

# Or via the openrouter CLI
openrouter --model-info <model-id>
```

Substituting model IDs from codebase config or memory without verifying against the live catalog has caused wasted spend (model 404 → fallback → meaningless comparison run). "Available in codebase" ≠ "available on OpenRouter."

```bash
# Curated top picks with live pricing
openrouter --top

# Filter to a provider
openrouter --list-models anthropic --pricing

# Sort by price (cheapest first)
openrouter --list-models --pricing --sort price

# Sort by context window (largest first)
openrouter --list-models --pricing --sort context

# Get details on a specific model
openrouter --model-info <model_id>

# Show all aliases
openrouter --aliases

# Model variants
openrouter --variants
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

Example: `openrouter "Latest news on X" -m gemini:online --raw`

## Agent Patterns

### Multi-model consensus

```bash
for model_id in claude gemini gpt grok; do
  openrouter "Your question" -m "$model_id" --raw -o "/tmp/response-$model_id.md" &
done
wait
```

### Cost-optimized bulk processing

```bash
for f in docs/*.md; do
  openrouter --file "$f" -m gemini-flash -s "Summarize in 3 bullets" --raw -o "summaries/$(basename $f)"
done
```

### Structured extraction

```bash
openrouter "Extract all names and roles" -m gpt-mini --json-mode --raw
openrouter "Extract entities" -m gpt-mini --json-schema schema.json --raw
```

### Web-augmented queries

```bash
openrouter "What happened in AI this week?" -m claude --web --raw
openrouter "Current weather in Amsterdam" -m gemini:online --raw
```

### Vision / multimodal

```bash
openrouter "Describe this image" --image screenshot.png -m gemini --raw
openrouter "Compare these designs" --image a.png --image b.png -m claude --raw
```

### PDF analysis

```bash
openrouter "Summarize this paper" --pdf paper.pdf -m claude --raw
```

### With reasoning

```bash
openrouter "Prove this theorem" -m o3 --raw
openrouter "Solve this" -m claude --reasoning high --raw
openrouter "Quick logic" -m claude --reasoning high --reasoning-exclude --raw
```

### Fallback chains

```bash
openrouter "Query" -m claude --fallback gemini gpt grok --raw
```

### Account management

```bash
openrouter --credits
openrouter --key-info
openrouter --generation-info gen_abc123
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
| `--credits` | Show account credit balance |
| `--key-info` | Show API key info and rate limits |
| `--generation-info ID` | Inspect generation stats |
