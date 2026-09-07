# The openrouter CLI

One tool, every model. The CLI lives in `infrastructure/tools` and is on `PATH`
via `tools/bin/`. Key: `OPENROUTER_API_KEY`.

Verify before first use: `openrouter --aliases`

## Model Policy

**Approved providers (use ONLY these unless the user specifies otherwise):**
Anthropic (Claude) · Google (Gemini) · OpenAI (GPT, o-series) · xAI (Grok) ·
DeepSeek (panel diversity).

### Configured Models

The table is a curated snapshot, never the catalog. The freshness check below
is REQUIRED before each non-aliased use.

| Tier | Alias | Model ID | $/M prompt | $/M completion |
|------|-------|----------|-----------|---------------|
| Quality | `claude` | `anthropic/claude-sonnet-4.6` | $3.00 | $15.00 |
| Quality | `opus` | `anthropic/claude-opus-4.6` | $5.00 | $25.00 |
| Quality | `gpt` | `openai/gpt-5.4` | $2.50 | $15.00 |
| Quality | `gemini` | `google/gemini-3.1-pro-preview` | $2.00 | $12.00 |
| Quality | `grok` | `x-ai/grok-4.20` | $2.00 | $6.00 |
| Speed/cost | `gemini-flash` | `google/gemini-2.5-flash` | $0.30 | $2.50 |
| Speed/cost | `gpt-mini` | `openai/gpt-5.4-mini` | $0.75 | $4.50 |
| Reasoning | `o3` | `openai/o3` | best pure reasoning | — |
| Reasoning | `o4-mini` | `openai/o4-mini` | fast reasoning | — |

### Freshness Check (REQUIRED before each use)

1. `openrouter --list-models <provider> --pricing`
2. Compare the latest model against the configured ID above.
3. A newer model exists → ask the user before switching; if approved, note that
   this file needs the update. Declined → proceed with the configured model.
4. No newer model → proceed.

**Exception:** chained scripted calls may skip the check and use the alias.

### Verify an unlisted model ID

Substituting an ID from memory without verifying has caused wasted spend
(model 404 → fallback → meaningless run). "Available in codebase" ≠ "available
on OpenRouter".

```bash
curl -s -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  https://openrouter.ai/api/v1/models | jq -r '.data[].id' | grep -F "<model-id>"
openrouter --model-info <model-id>
```

## Model Variants

Append to any model ID with a colon: `:online` (web search), `:nitro`
(throughput), `:floor` (cost), `:free` (rate-limited), `:extended` (long
context). Example: `openrouter "Latest news on X" -m gemini:online --raw`.

## Core Usage

```bash
openrouter "Your prompt here" -m <model_id> --raw      # query a model
echo "text" | openrouter -m <model_id> -s "Summarize" --raw
openrouter --file input.md -m <model_id> --raw
openrouter "Extract entities" -m <model_id> --json-mode --raw
openrouter "Query" -m <model_id> --format json         # tokens, cost, timing
```

Always use `--raw` when capturing output — clean content for piping.

### Agent patterns

```bash
# Parallel fan-out (the manual panel is in workflows/fusion.md)
for model_id in claude gemini gpt grok; do
  openrouter "Your question" -m "$model_id" --raw -o "/tmp/response-$model_id.md" &
done; wait

# Bulk
for f in docs/*.md; do
  openrouter --file "$f" -m gemini-flash -s "Summarize in 3 bullets" --raw \
    -o "summaries/$(basename $f)"
done

# Vision (direct per-model only — fusion does not accept image input)
openrouter "Describe this image" --image screenshot.png -m gemini --raw

# PDF
openrouter "Summarize this paper" --pdf paper.pdf -m claude --raw

# Reasoning
openrouter "Prove this theorem" -m o3 --raw
openrouter "Solve this" -m claude --reasoning high --raw

# Fallback chain
openrouter "Query" -m claude --fallback gemini gpt grok --raw
```

## Flag Reference

| Flag | Effect |
|------|--------|
| `-m MODEL` | Model ID or alias, with optional `:variant` |
| `-s PROMPT` | System prompt |
| `-f FILE` | Load prompt from file |
| `--raw` | Content only, no formatting |
| `--format json` | Full JSON response |
| `-o PATH` | Save to file |
| `--web` | Web search |
| `--image FILE` / `--pdf FILE` | Attachments (repeatable) |
| `--json-mode` / `--json-schema FILE` | Structured output |
| `--reasoning EFFORT` | xhigh/high/medium/low |
| `--fallback M1 M2` | Failover chain |
| `--max-tokens N` / `-t TEMP` | Sampling |
| `--list-models` / `--top` / `--pricing` / `--sort price\|context` | Discovery |
| `--credits` / `--key-info` / `--generation-info ID` | Account |
