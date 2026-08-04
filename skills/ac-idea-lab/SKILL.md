---
name: ac-idea-lab
accessory: true
disable-model-invocation: true
description: Use to deeply work a raw IDEA, framework, concept, or strategy (anything without execution steps yet) — two modes: GENIUS forensic first-principles critique (stress-test, find flaws, distill) and ALIEN paradigm transcendence (escape the frame, cross-domain transplants, expand). Triggers on "review this idea", "stress-test this", "devil's advocate", "critique this concept", "find flaws in this", "first-principles review", "transcend this idea", "go deeper", "push beyond analysis", "alien perspective", "escape local optima", "what am I missing at a deeper level". For a written implementation plan with steps/timelines use ac-plan-lab; for open-ended generation of new options use brainstorming; for a multi-model panel use expert-consensus.
---

# Idea Lab — deep analysis for raw ideas

Two modes for working a raw idea, framework, concept, or strategy (chat artifact, no file):

- **Genius** — forensic first-principles critique: understand it completely, then find the one critical flaw, stress-test every assumption, and reconstruct a sharper version.
- **Alien** — paradigm transcendence: shed human cognitive defaults, dissolve the frame, transplant structures from other domains, and surface what's beyond conventional analysis.

First: if an AGENTS.md file exists, read it for project context.

## Pick the mode

If the trigger already implies a direction, go straight there — critique / stress-test / devil's-advocate / find-flaws → **Genius**; transcend / go-deeper / alien / escape-local-optima → **Alien**. If it's ambiguous ("explore this idea", "go deep on this"), ask:

```
AskUserQuestion:
  question: "Which direction for this idea?"
  header: "Mode"
  options:
    - label: "Genius — critique & sharpen"
      description: "Forensic first-principles review: stress-test assumptions, find the fatal flaw, reconstruct a tighter version."
    - label: "Alien — transcend & expand"
      description: "Break the paradigm: dissolve the frame, transplant structures from other domains, find what's beyond conventional analysis."
  multiSelect: false
```

Then **load and follow the chosen mode's reference in full**:

- Genius → read `references/genius.md`
- Alien → read `references/alien.md`

Run the two as a two-stage pipeline when warranted: Genius first (perfect within the paradigm), then Alien (transcend it).

## When to Use

- Before committing to a major architectural or strategic decision
- When evaluating frameworks, strategies, or concepts
- When something "feels right" but hasn't been stress-tested
- As a devil's advocate for your own ideas
- When conventional analysis feels complete but insufficient, or you suspect the real leverage lives outside the current frame
