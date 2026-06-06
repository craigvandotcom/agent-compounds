# Dueling Idea Wizards

**Model Selection:** Default models are `opus gemini gpt`. For current best models and alternatives, see `.claude/skills/research/tools/openrouter.md` → "Recommended Model Sets" → "For Idea Generation".

---

Run a competitive idea generation and evaluation workflow using multiple leading models. This automates what would otherwise require manual copy-pasting between AI systems.

**Phase 1: Parallel Idea Generation**

Send the following prompt to 3 models in parallel using OpenRouter. Save each output to a temp file:

```bash
PROMPT="Analyze this project thoroughly. Then come up with your very best ideas for improving it to make it more robust, reliable, performant, intuitive, user-friendly, and compelling. Generate 30 ideas, critically evaluate each one, then winnow to your VERY best 5. For each finalist: explain the idea in detail with concrete implementation steps, justify why it would be a clear improvement, note possible downsides, and rate your confidence (0-100%)."

for model in opus gemini gpt; do
  openrouter "$PROMPT" -m $model --reasoning high --raw -o "/tmp/ideas-$model.md" &
done
wait
```

**Phase 2: Cross-Evaluation**

Have each model score the OTHER models' ideas:

```bash
for judge in opus gemini gpt; do
  for source in opus gemini gpt; do
    [ "$judge" = "$source" ] && continue
    openrouter "Here are improvement ideas from another AI model. Score each from 0-1000 based on: how smart/innovative the idea is, practical real-world utility, implementation feasibility, whether the value justifies added complexity. Be intellectually honest; don't penalize good ideas just because they aren't yours. $(cat /tmp/ideas-$source.md)" \
      -m $judge --reasoning high --raw -o "/tmp/eval-${judge}-rates-${source}.md" &
  done
done
wait
```

**Phase 3: Synthesis**

Feed all evaluations back to your primary model to produce a final ranked list:

```bash
cat /tmp/eval-*.md | openrouter "Here are cross-evaluations from 3 leading AI models scoring each other's improvement ideas. Synthesize these into a single ranked list of the top 10 ideas, weighted by cross-model consensus. Ideas rated highly by multiple models are stronger signals. Produce a final action plan." -m opus --reasoning high -o "/tmp/dueling-wizards-result.md"
```

Review the result at `/tmp/dueling-wizards-result.md`.
