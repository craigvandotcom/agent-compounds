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

**Arm 1 rubric (prevention at the front door — see `references/workflow.md` § Method).** Two
checks the stamp gate now enforces: (1) **dependency edges are bead-level only — NO epic
endpoints** (I2, `beads-standards` § Sequencing & parentage); an edge with an epic on either
end is a finding. (2) **finding beads carry `discovered-from:`** (an honest `unknown` passes).
PLUS a convention that **NEVER blocks `refined`**: refine **adopts** an unparented bead into
an epic when §3 routing makes the parent obvious — idempotent (adopt only a parentless bead,
re-check `br show` immediately before `br dep add`, verify single-parenthood after), never
mutex-guarded. (Light-path refine criteria are **decided ACCEPT** — bd-9bvr2 closed
`decided:ACCEPT` 2026-07-18 — and **implemented** below as the formal `refine-light`
branch; do not re-open a human-gate on those criteria.)

**UI beads derived from a visual reference** must carry the reference-image path
(`docs/design-refs/<surface>-<source>-reference.<ext>`, per `ac-plan-init`'s capture rule)
in their `## Acceptance Criteria` — the Completeness Reviewer (see `references/workflow.md`)
checks for this and for AC drift against the source research doc's geometry, not just
internal bead coherence.

## Light-path refine branch (`refine-light`) — formal criteria (bd-chd5p.6 / Item 4)

**Decision D1 (2026-07-18):** ACCEPT plan criteria as written. **bd-9bvr2 closed
`decided:ACCEPT`** — this section **implements** those criteria; do not re-open a
human-gate.

Evidence: ≥5 clean light-paths + 1 costly failure (bd-hfdst). bd-hfdst **passed** a
"mechanism traced at a named line" test with detailed but **WRONG** file:lines —
excluding clauses are the **async/persist hard gate (#1)** plus **independent
concurrence (#4)**, not self-attested mechanism-traced alone.

### HARD GATE first (criterion #1) — fail → full `MIN_ROUNDS` / `refine-full`

Light path is **forbidden** if the fix touches **any** of:

- a **RISK-TOUCH** path under `_shared/risk-classification.md` **binding #5**
  (file-set of the bead under refine — same files the refine stamp will cite),
  especially persistence/write/RPC surfaces; **OR**
- any **async / multi-writer / SSE / poll / create** surface.

*This* hard gate would have excluded bd-hfdst. Classify the bead's file set against
risk-classification before considering criteria 2–4.

### Criteria #2–#4 (ALL four required; any fail → full MIN_ROUNDS)

| # | Criterion |
| - | --------- |
| **1** | **HARD GATE** above (RISK-TOUCH persistence / async-multi-writer) |
| **2** | **Single-file scope** required |
| **3** | Evidence from the **same run**, **< 24h old measured against `RUN_ID` start** (QA repro or review finding); paste **artifact path + ISO timestamp** into the stamp |
| **4** | Mechanism traced to concrete `file:line`, **AND** that trace **confirmed by a single spawned adversarial subagent DISTINCT from the trace's author** (never conductor self-concurring). Output is one-line **PASS** naming the `file:line` independently confirmed |

### Stamp content (`refine-light`)

When all four hold, stamp `refine-light` (not only `refined`) and record in a bead
comment:

- `file:line` of the mechanism
- evidence artifact path + ISO timestamp (< 24h vs RUN_ID start)
- independent concurrence one-liner (PASS + file:line)

Grep can confirm all three fields are **present**; it cannot confirm trace correctness —
independent concurrence is the guard.

Failing any criterion → run full `MIN_ROUNDS` and stamp `refine-full`. Procedure detail:
`references/workflow.md` § Light-path / refine-light.

## Procedure

This is a multi-agent conductor workflow. **Load and follow [`references/workflow.md`](references/workflow.md)** — it holds the full phased procedure (reviewer prompts, round structure, fix application, convergence, label removal), including the formal light-path branch.
