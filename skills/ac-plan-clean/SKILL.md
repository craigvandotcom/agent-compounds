---
name: ac-plan-clean
description: 'Use to verify an EXISTING plan draft''s correctness, structure, and completeness — a 3-reviewer hygiene pass that applies targeted fixes, not a rewrite. Run as the final polish before beadifying. Triggers: ''clean the plan'', ''check the plan'', ''correctness pass on the plan'', ''plan clean''. Requires an existing plan file; to create a plan use ac-plan-init.'
---

# Plan Clean

**Purpose:** Final correctness/hygiene pass on an approved plan — three Sonnet reviewers check accuracy, consistency, and completeness independently; the conductor tracks consensus and applies targeted fixes in place.

## When to Use

- Strategy and architecture are already settled; you want the *document* accurate and clean before `/ac-beadify`.
- **NOT** when the plan needs deeper rethinking → use `/ac-plan-refine-internal` or `/ac-plan-refine-external`.
- **NOT** when there is no plan yet → `/ac-plan-init`.

## I/O Contract

|            |                                                              |
| ---------- | ------------------------------------------------------------ |
| **Input**  | Approved plan file (`_plans/*.md` or user-specified)         |
| **Output** | Same plan file, corrected in-place and committed             |
| **Next**   | `/ac-beadify`                                                |

## Procedure

This is a multi-agent conductor workflow. **Load and follow [`references/workflow.md`](references/workflow.md)** — it holds the full phased procedure (reviewer prompts, consensus registry, fix application, convergence).
