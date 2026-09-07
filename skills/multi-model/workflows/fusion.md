# The Fusion Workflow

Panel synthesis in priority order. Judge every synthesis with
`../references/synthesis-directive.md` — it is the standard the output answers
to.

## Mode 1 — OpenRouter Fusion (native panel + judge)

One call; OpenRouter fans out to a panel and synthesizes server-side.

```bash
openrouter "Your question" -m openrouter/fusion --raw
```

```bash
# Capture to file
openrouter "Your question" -m openrouter/fusion --raw -o /tmp/fusion-answer.md
```

### PROBED — what the probes established

- PROBED: a single `openrouter/fusion` call answers (probe prompt returned
  cleanly). Fusion is live in the catalog: verify with
  `curl -s -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  https://openrouter.ai/api/v1/models | jq -r '.data[].id' | grep fusion`.
- PROBED: the `openrouter` CLI exposes NO panel parameter — it cannot pass
  `analysis_models` or a Fusion plugin `preset`, so the panel composition is
  OpenRouter's default, not yours. A `--fusion-panel` flag is filed as a
  cross-repo bead on infrastructure; until it exists, custom panels use
  Mode 2.
- PROBED: image input through fusion does not return (the call hangs).
  Vision is direct per-model only — see `../references/openrouter-cli.md`.

## Mode 2 — Manual fan-out, you synthesize

When fusion is unavailable, the panel must be custom, or you need the raw
responses:

```bash
Q="The user's question"
for model_id in claude gemini gpt grok deepseek; do
  openrouter "$Q" -m "$model_id" --raw -o "/tmp/panel-$model_id.md" &
done
wait
```

Then read every response and synthesize them yourself under the directive.
Panel composition rule: one model per provider — diversity of training, not
count, is what the consensus buys. Three frontier models from three providers
beat six from two.

### Panel override

To control the panel precisely (cost floor, capability, recency), name the
members explicitly in the loop instead of the default five:

```bash
for model_id in anthropic/claude-sonnet-4.6 google/gemini-3.1-pro-preview \
                openai/gpt-5.4; do
  openrouter "$Q" -m "$model_id" --raw -o "/tmp/panel-$(basename $model_id).md" &
done
wait
```

Freshness check on every non-aliased ID:
`../references/openrouter-cli.md` § Freshness Check.

## Presets

**Quality** — the default. One frontier model per approved provider
(claude, gemini, gpt, grok), fusion if the default panel is acceptable, Mode 2
otherwise. For decisions, research, and anything a human will act on.

**Budget** — flash/mini tier only, cap at three models:

```bash
for model_id in gemini-flash gpt-mini x-ai/grok-4.20; do
  openrouter "$Q" -m "$model_id" --raw -o "/tmp/panel-$model_id.md" &
done
wait
```

Budget mode is for bulk triage and pre-screening, never for a decision a human
will act on — weak panelists produce confident noise, and the directive cannot
rescue inputs that never contained the signal.

## Reading the output

Apply `../references/synthesis-directive.md` § Output Structure verbatim:
Consensus, Agreement (High Confidence), Disagreement, Unique Insights. A
synthesis that does not carry the Disagreement section has hidden a real
divergence — name it or rerun.
