---
name: ac-bead-refine
description: 'Use to REFINE existing beads to convergence — 3 parallel reviewers hunt for gaps, the conductor makes each bead self-contained and agent-ready, then removes the ''unrefined'' label and stamps ''refined''. Triggers: ''refine the beads'', ''bead refine'', ''make beads implementation-ready'', ''refine bead structure''. Input is open beads from ac-beadify OR any other source (hygiene, triage, review''s Exhaust Rule, conductor follow-ups); creating plan-decomposition beads is ac-beadify''s job.'
---

# Bead Refine

**Purpose:** Iterative multi-agent refinement of an existing bead structure — sizing, dependencies, acceptance criteria, self-containment — until convergence. Removes the `unrefined` label and stamps `refined` — the readiness gate is presence of `refined`, not absence of `unrefined` (`skills/_shared/bead-conventions.md`), and this skill's stamp is its **sole** output, exclusively — no other skill, and no conductor, ever applies it.

## When to Use

- After beads exist and need to earn the `refined` stamp, before `/ac-implement`. Beads
  arrive from any source — `/ac-beadify` (plan decomposition), `ac-hygiene` (deferred
  findings epic), `ac-triage` (finding-beads epic), `ac-review`'s Exhaust Rule, or a
  conductor's own follow-up beads. Not optional — this is where beads earn the stamp,
  regardless of who created them.
- **NOT** when no beads exist yet and you need PLAN decomposition → `/ac-beadify` (creating
  the epic/task structure from a plan is its job, not this skill's).
- **NOT** when beads are already refined and ready → `/ac-implement`.

## I/O Contract

|            |                                                              |
| ---------- | ------------------------------------------------------------ |
| **Input**  | Open beads in `br` (from `/ac-beadify` or any other source)        |
| **Output** | Refined beads ready for `/ac-implement` (`unrefined` removed, `refined` added) |
| **Next**   | `/ac-implement`                                              |

## Epic-Scoped Invocation

Callers may invoke this skill "scoped to an epic" (e.g. `ac-hygiene`'s or `ac-triage`'s
per-run epic, or `ac-loop` refining a beadified epic). In that mode the reviewed bead set
is **the epic + every child linked to it by a `parent-child` dependency** — derive the
child set with `br dep list <epic-id> --direction up -t parent-child --json` (each entry's
`issue_id` is a child) and combine with the epic id itself; `br list --json` has no
dependency-edge field, so filter via `dep list`, not by trying to slice `list --json`
directly. See `references/workflow.md` § Gather Bead Snapshot for the exact commands.

Reviewers receive the epic (title/description) as shared context alongside its children,
and the Structure Optimizer (Agent 3) treats **the epic's children as the sequencing
universe** — its dependency/ordering/granularity checks apply within that set, not the
whole board. Convergence and the `refined` stamp (below) apply to the epic + its children
only.

Non-epic calls (a single bead, or "refine everything open") behave exactly as today: the
bead set is whatever `br list --json` returns for that scope.

**UI beads derived from a visual reference** must carry the reference-image path
(`docs/design-refs/<surface>-<source>-reference.<ext>`, per `ac-plan-init`'s capture rule)
in their `## Acceptance Criteria` — the Completeness Reviewer (see `references/workflow.md`)
checks for this and for AC drift against the source research doc's geometry, not just
internal bead coherence.

## Procedure

This is a multi-agent conductor workflow. **Load and follow [`references/workflow.md`](references/workflow.md)** — it holds the full phased procedure (reviewer prompts, round structure, fix application, convergence, label removal).
