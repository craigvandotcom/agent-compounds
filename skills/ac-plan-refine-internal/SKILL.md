---
name: ac-plan-refine-internal
description: Use to DEEPEN an existing plan via multi-agent (internal, no external models) refinement — focused-lens reviewers compete, the conductor synthesizes and edits until convergence. Default tier is Medium (3 Opus agents); say "light" or "heavy" in the prompt to override — no pause to ask. Triggers: 'refine the plan', 'refine internal', 'improve this plan with subagents', 'multi-agent plan refinement'. Requires an existing plan; for external multi-model refinement use ac-plan-refine-external.
---

# Plan Refine (Internal)

**Purpose:** Iterative multi-agent refinement of a plan using internal Claude subagents as focused lenses. Evidence-backed findings only; codebase verification mandatory; repeat until convergence.

## When to Use

- A drafted plan needs to get sharper and deeper, without external models.
- **NOT** for high-stakes decisions warranting diverse external models → `/ac-plan-refine-external`.
- **NOT** for a final correctness sweep only → `/ac-plan-clean`.
- **NOT** when there is no plan yet → `/ac-plan-init`.

## I/O Contract

|            |                                                              |
| ---------- | ------------------------------------------------------------ |
| **Input**  | Approved plan file (from `/ac-plan-init`)                    |
| **Output** | Refined plan (in-place edit), Refinement Log appended        |
| **Next**   | `/ac-plan-clean` (optional) → `/ac-beadify`                  |

## Engineering Skill

**Before refining:** load this project's engineering standard from `CORE/SKILL.md` (§ "Engineering standard"). For all current neoMeta apps: `capacitor` (`capacitor/SKILL.md`). Reviewers must evaluate plan decisions against these engineering constraints — not just correctness and completeness.

## Procedure

This is a multi-agent conductor workflow. **Load and follow [`references/workflow.md`](references/workflow.md)** — it holds the full phased procedure (lens prompts, round structure, consensus registry, convergence).
