---
name: ac-bead-refine
description: 'Use to REFINE existing beads to convergence — 3 parallel reviewers hunt for gaps, the conductor makes each bead self-contained and agent-ready, then removes the ''unrefined'' label and stamps ''refined''. Triggers: ''refine the beads'', ''bead refine'', ''make beads implementation-ready'', ''refine bead structure''. Requires beads already created (by ac-beadify); to create beads use ac-beadify.'
---

# Bead Refine

**Purpose:** Iterative multi-agent refinement of an existing bead structure — sizing, dependencies, acceptance criteria, self-containment — until convergence. Removes the `unrefined` label and stamps `refined` — the readiness gate is presence of `refined`, not absence of `unrefined` (`skills/_shared/bead-conventions.md`), and this skill's stamp is its exclusive output (alongside `ac-triage`'s narrower, justified path for refined-by-construction defects).

## When to Use

- After `/ac-beadify` has created beads, before `/ac-implement`. Not optional — this is where beads earn the `refined` stamp.
- **NOT** when no beads exist yet → `/ac-beadify`.
- **NOT** when beads are already refined and ready → `/ac-implement`.

## I/O Contract

|            |                                                              |
| ---------- | ------------------------------------------------------------ |
| **Input**  | Open beads in `br` (from `/ac-beadify` or any source)        |
| **Output** | Refined beads ready for `/ac-implement` (`unrefined` removed, `refined` added) |
| **Next**   | `/ac-implement`                                              |

## Procedure

This is a multi-agent conductor workflow. **Load and follow [`references/workflow.md`](references/workflow.md)** — it holds the full phased procedure (reviewer prompts, round structure, fix application, convergence, label removal).
