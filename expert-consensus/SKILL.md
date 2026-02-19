---
name: expert-consensus
description: Send one prompt to multiple AI models. Get one synthesized answer.
version: 1.0.0
tools: [openrouter.py, expert-panel.json]
---

# Expert Consensus

Fan out one prompt to a panel of frontier AI models in parallel, then synthesize into a single consensus answer.

## When to Use

- Important decisions that benefit from multiple perspectives
- Research questions where model blind spots matter
- Stress-testing an idea against diverse reasoning styles
- Any time you want higher confidence than a single model provides

## Workflow

1. Run the fan-out from this skill's directory:

```bash
python3 {skill_dir}/openrouter.py --all "The user's question"
```

Where `{skill_dir}` is the path to this skill directory (e.g., `.claude/skills/expert-consensus`).

2. Read all model responses from stdout.

3. Synthesize the responses yourself using the Synthesis Directive below.

## Script Reference

Both `openrouter.py` and `expert-panel.json` live in this skill directory. The script resolves its config relative to itself, so it works from any working directory.

| Flag | Effect |
|------|--------|
| `--all` | Fan out to all enabled models |
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

### Models

Run `python3 openrouter.py --panel` to see the current team. All models are configured in `expert-panel.json` — edit that file to update model IDs, add new models, or toggle enabled/disabled.

Append `:online`, `:nitro`, `:floor`, `:free`, or `:extended` to any alias for variants.

## The Synthesis Directive

You are not combining. You are not averaging. You are not selecting the best response and polishing it. You are using multiple independent views of the same question to reconstruct the answer they were all reaching toward.

### How You See

- When multiple models say the same thing in different words, that is high-confidence signal. State it once, precisely.
- When one model captures something no other mentions — and it's clearly correct — that is the sharpest insight in the set. Treasure it.
- When one model confidently states something that contradicts the weight of the others, that is noise. Remove it cleanly.
- When no model addresses something that obviously matters, fill the gap yourself.
- When a model's best contribution is its framework — not its facts — adopt the structure.
- When one model makes a specific factual claim (citation, statistic, date) that no other corroborates, treat it as unverified. Include only if plausible from the other responses.

### How You Resolve Disagreement

- First: check if it's real. Most contradictions dissolve when sources are talking about different scopes or levels of abstraction. Find the deeper level where both are true.
- If real: which position survives first-principles reasoning and the weight of independent evidence?
- If genuinely balanced: name the disagreement precisely, explain what would resolve it, and move on. Uncertainty is honest. Vagueness is not.

### How You Write

- Density over length. Every sentence earns its place. Half the length, twice the insight.
- Precision over hedging. Not "it could be argued that X" — say "X is true when Y, false when Z."
- Find the organizing principle that makes everything obvious in retrospect.
- If the truth is surprising or uncomfortable — state it. You are here to be right, not safe.

### Output Structure

**Consensus** — The synthesized answer. The document all models were trying to write.

**Agreement (High Confidence)** — Where models converge. State each point once with conviction.

**Disagreement** — Where models genuinely diverge. Each position, and what resolves it.

**Unique Insights** — Points only one model caught that add real value.

## Configuration

- **API key**: `OPENROUTER_API_KEY` environment variable (get one at https://openrouter.ai/keys)
- **Models**: `expert-panel.json` next to the script — array of models with alias, model ID, enabled flag, and strength description

To regenerate a fresh default: `python3 openrouter.py --init-panel`
