---
name: multi-model
description: Use when a task needs a specific AI model or several weighing in on one question — query Claude, GPT, Gemini, Grok or DeepSeek directly, or get a multi-model panel synthesized into one answer on OpenRouter Fusion. Triggers on "query a model", "which model for", "use OpenRouter", "ask GPT/Gemini/Grok directly", "run this on <model>", "ask the experts", "model consensus", "panel of AI models", "second opinion from other AIs". NOT for UI/design options (ui-brainstorm), forensic idea critique (ac-idea-lab), or Anthropic API/model reference (claude-api).
tools: [openrouter (infrastructure/tools)]
---

> **Generic skill — method only, zero app facts.** This skill is symlinked from
> agent-compounds and shared across consuming apps. It contains technique and
> patterns, not project specifics. **App specifics (project refs, schema names,
> domain rules, feature flows, env values) → read this app's
> `.claude/skills/CORE/SKILL.md`** (and the `AGENTS.md` summary it indexes).
> Do not add app-specific facts to this file — they belong in CORE.

# Multi-Model

Query any AI model from the terminal, or put several models on one question and
land a single synthesized answer. One tool (`openrouter`), one router.

## When to Use

- A task needs one specific non-default model (quality, cost, or capability)
- An important decision benefits from independent perspectives
- A research question where model blind spots matter
- Higher confidence than any single model provides

## Two Modes

**Direct query** — one model, one answer:

```bash
openrouter "Your prompt" -m claude --raw
```

**Panel synthesis** — several models, one answer, in priority order:

1. **OpenRouter Fusion** (native panel + judge in one call) — `workflows/fusion.md`
2. **Manual fan-out + you synthesize** (fusion unavailable or panel must be
   custom) — the fan-out recipe in `workflows/fusion.md`, judged with
   `references/synthesis-directive.md`

## Reading Order

- `references/openrouter-cli.md` — the CLI: configured models, variants,
  discovery, freshness check, flag reference. Read before first use.
- `workflows/fusion.md` — the panel workflow. Read when synthesizing.
- `references/synthesis-directive.md` — how to judge panel output. Read with
  the workflow; it is the standard the synthesis answers to.

## Prerequisites

```bash
export OPENROUTER_API_KEY=sk-or-...   # https://openrouter.ai/keys
openrouter --aliases                  # verify the CLI is on PATH
```

## Defaults

| Need | Reach for |
|------|-----------|
| General quality work | `claude` (see catalog for current ID) |
| Budget / bulk | `gemini-flash` or `gpt-mini` |
| Reasoning / math | `o3` or `claude --reasoning high` |
| Web-augmented | any model + `--web` |
| Vision | direct per-model call (fusion does not take images) |
| Panel | `openrouter/fusion`, or the fan-out recipe |
