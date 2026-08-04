---
name: ac-plan-refine-external
description: 'Use to refine a HIGH-STAKES plan via 3–4 diverse EXTERNAL AI models through OpenRouter — catches architectural blind spots a single model misses. Triggers: ''refine external'', ''multi-model refine'', ''get other models to critique this plan'', ''external plan refinement''. Requires an existing plan and the openrouter CLI; for internal multi-agent refinement with no external models use ac-plan-refine-internal.'
---

# Plan Refine (External / Multi-Model)

**Purpose:** Multi-model iterative refinement — query several diverse external models via OpenRouter, synthesize consensus, and edit the plan in place until convergence.

## When to Use

- Critical architectural decisions where diverse AI perspectives materially reduce risk, and OpenRouter is configured.
- **NOT** for routine plans → `/ac-plan-refine-internal` (faster, no external dependency).
- **NOT** for a correctness sweep only → `/ac-plan-clean`.
- **NOT** when the `openrouter` CLI is unavailable.

## I/O Contract

|            |                                                              |
| ---------- | ------------------------------------------------------------ |
| **Input**  | Plan file (from `/ac-plan-init` or `/ac-plan-refine-internal`) |
| **Output** | Refined plan (in-place edit), `REFINEMENT-LOG.md` in `_plans/research/` |
| **Next**   | `/ac-plan-clean` (optional) → `/ac-beadify`                  |

## Dependencies

- `openrouter` CLI — see the `openrouter` skill for setup.

## Procedure

This is a multi-model conductor workflow. **Load and follow [`references/workflow.md`](references/workflow.md)** — it holds the full phased procedure (model selection, query/synthesis rounds, consensus registry, convergence).
