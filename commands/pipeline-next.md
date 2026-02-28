---
description: Pipeline dashboard — scan all stages, reason about sequence, offer what to advance next toward implementation-ready
---

**You are a pipeline advancement scanner.** Read-only. Scan all three data stores, show the funnel, reason briefly about sequencing, then ask what to move forward. Your job is advancing items *toward* implementation-ready — not deciding what to build. Ready beads go to `/bead-work`.

---

## I/O Contract

|                  |                                                                      |
| ---------------- | -------------------------------------------------------------------- |
| **Input**        | None (reads project state directly)                                  |
| **Output**       | Funnel dashboard + sequencing note + action selection                |
| **Artifacts**    | None (stateless — no writes)                                         |
| **Verification** | N/A (read-only)                                                      |

## Prerequisites

- `br` installed — verify with `which br`
- `_backlog/` directory (optional — skipped if missing)
- `_plans/` directory (optional — skipped if missing)

---

## Phase 0: Initialize

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

Read `AGENTS.md` for project context.

---

## Phase 1: Scan (parallel)

Run all three scans simultaneously.

### Scan A: Beads

```bash
br list --json
br ready --json
```

Categorize every bead:

| Category | Criteria |
|----------|----------|
| **Ready (refined)** | In `br ready` AND does NOT have `unrefined` label |
| **Unrefined** | Has `unrefined` label — needs `/bead-refine` |
| **Blocked** | status=open, NOT in ready list |
| **In Progress** | status=in_progress |
| **Closed** | status=closed/done |

For epics (dependent_count > 3 or "epic" in title): count total/ready/blocked/closed children.

### Scan B: Plans

```bash
ls "$PROJECT_ROOT/_plans/"*.md 2>/dev/null
```

For each plan, read frontmatter and first 50 lines:

1. **Status** from frontmatter: `draft | refined | approved | beadified`
2. **Refinement depth** — `refinement_rounds` frontmatter field if present. Fallback: count `### Round N` headings inside the `## Refinement Log` section (headings only — NOT inline references like "R1 fixes"). Extract tier from first mention of `Light | Medium | Heavy` in the log header. Extract final trajectory from the last `Trajectory:` line in the log. (0 rounds = untouched, no log present)
3. **Recency** — file modification time (prefer recently worked plans at same level)
4. **Fallback** (no frontmatter): check for `## Refinement Log` (→ refined), `Status: Approved` text (→ approved). Flag for `/backlog-tidy`.

Skip: `README.md`, files in `_done/`, `research/`, `templates/`, `checkpoints/`.

### Scan C: Backlog

```bash
find "$PROJECT_ROOT/_backlog" -name "*.md" \
  -not -name "_*" -not -name "ROADMAP.md" -not -name "BUSINESS-STRATEGY.md" \
  -not -path "*/_done/*" -not -path "*/_shipped/*" -not -path "*/complete/*" \
  -not -path "*/assets/*" -not -path "*/audits/*" \
  2>/dev/null
```

For each file: extract `status` (captured/planned/complete), unchecked task count, version milestone. Skip `status: complete` and items with zero unchecked tasks.

---

## Phase 2: Prioritize

Order by closeness to implementation-ready (nearest first):

| Priority | Stage | Action |
|----------|-------|--------|
| **1** | Unrefined beads | `/bead-refine` — one step from ready |
| **2** | Plans: approved | `/beadify {path}` — one step from beads |
| **3** | Plans: refined | `/beadify {path}` (or `/plan-clean` if final polish needed) |
| **4** | Plans: draft | `/plan-refine-internal {path}` |
| **5** | Backlog: captured | `/plan-init` (reference the backlog item) |

Within each level, sort by:
1. Refinement depth (desc) — more work invested = do it first (continuity of context)
2. Modification time (desc) — recently touched = active thread, continue it
3. Explicit priority field (desc)

**Ready beads (refined, no `unrefined` label):** surfaced in the summary header only. They are NOT offered as action options — use `/bead-work` for those.

---

## Phase 3: Report

```
## Pipeline Status

Ready to build: {N} beads — run /bead-work when you're ready to implement.

### Needs Bead Refinement ({N} unrefined)
  {id}  {title}  [{priority}]
  ...  (top 5, then "{N} more...")

### Plans: Ready to Beadify ({N})
  {filename}  [approved | refined, {N}r {Tier} → {final_trajectory}]
  ...

### Plans: Needs Refinement ({N} draft)
  {filename}  [{size}, {N}r {Tier}, last touched {date}]
  ...

### Backlog: Needs Planning ({N} items, {file_count} files)
  {version}/{filename}  [{task_count} tasks]
  ...

### In Progress ({N} beads)
  {id}  {title}  [in_progress]

### Blocked ({N} beads across {epic_count} epics)
  {epic_id}  {epic_title}  ({ready}/{total} children ready)

Pipeline: {ready_refined} ready | {unrefined} unrefined | {to_beadify} to beadify | {draft_plans} draft plans | {backlog} backlog
```

Omit sections with zero items.

---

## Phase 4: Sequence Reasoning

Look at the top 2–3 candidates from the highest non-empty priority level. Ask:

- **Dependencies**: does item A require item B to be done first?
- **Shared foundations**: do multiple items share a component, schema, or API that should be defined once?
- **Investment continuity**: within same level, is the naturally sorted order (by refinement depth + recency) correct, or is there a case to swap?
- **Technical debt risk**: would advancing A before B force rework in B later?

**Output:** One brief note if reordering is warranted — `⚡ Sequence note: Consider [X] before [Y] — [reason in one clause].` Omit entirely if the natural order is fine. No analysis theater.

---

## Phase 5: Offer Next Action

Generate up to 4 options from the priority list — one per non-empty level, in order:

```
AskUserQuestion(
  questions: [{
    question: "What do you want to advance?",
    header: "Pipeline Next",
    multiSelect: false,
    options: [
      { label: "Refine beads: {epic_or_count}", description: "/bead-refine" },
      { label: "Beadify: {plan_filename}", description: "/beadify _plans/{filename}" },
      { label: "Refine plan: {plan_filename}", description: "/plan-refine-internal _plans/{filename}" },
      { label: "Plan: {backlog_item}", description: "/plan-init (reference _backlog/{filename})" },
      { label: "Just browsing", description: "No action — I wanted the status report" }
    ]
  }]
)
```

After selection, print the exact command to run with arguments. Do NOT run it — this command is read-only.

---

## Remember

- **Nearest to ready goes first** — unrefined beads before plans before backlog
- **Ready beads are not options here** — they go to `/bead-work`, show count only
- **Within a level, prefer the most invested item** — continuity of context beats fresh starts
- **Sequence note only when warranted** — silence is correct when order is fine
- **Read-only, stateless** — no writes, no mutations, no git ops
- **Omit empty sections** — only show what exists
- **"Just browsing" always available**

---

_Advance the pipeline. For implementation: `/bead-work`. For strategic alignment: `/pipeline-align`._
