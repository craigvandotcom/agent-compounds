---
name: ac-plan-clean
description: 'Use to verify an EXISTING plan draft''s correctness, structure, internal consistency, and beadify-readiness — a 4-reviewer hygiene pass that applies targeted fixes, not a rewrite. Run as the final polish before beadifying. Triggers: ''clean the plan'', ''check the plan'', ''correctness pass on the plan'', ''plan clean''. Requires an existing plan file; to create a plan use ac-plan-init; to hunt substantive gaps or ask what the plan is missing, use ac-plan-lab.'
---

# Plan Clean

**Purpose:** Final correctness/hygiene pass on an approved plan — four Sonnet reviewers check accuracy, structure, hygiene, and bead-fit (will it convert cleanly at `/ac-beadify`?) independently; the conductor tracks consensus and applies targeted fixes in place.

## When to Use

- Strategy and architecture are already settled; you want the *document* accurate and clean before `/ac-beadify`.
- **NOT** when the plan needs deeper rethinking → use `/ac-plan-refine-internal` or `/ac-plan-refine-external`.
- **NOT** when there is no plan yet → `/ac-plan-init`.

## I/O Contract

|            |                                                              |
| ---------- | ------------------------------------------------------------ |
| **Input**  | Approved plan file (`_plans/*.md` or user-specified), frontmatter `status: approved`/`refined` (or `loop-ready` for a re-clean) |
| **Output** | Same plan file, corrected in-place, stamped `status: loop-ready` + `plan_clean_rounds`, committed |
| **Next**   | `/ac-beadify` (its status gate accepts `approved`/`loop-ready`/`refined`)     |

## Procedure

This is a multi-agent conductor workflow. **Load and follow [`references/workflow.md`](references/workflow.md)** — it holds the full phased procedure (reviewer prompts, consensus registry, fix application, convergence).
