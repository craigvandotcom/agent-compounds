---
name: ac-backlog
description: 'Capture ideas into the backlog pool — cohesive grouping (one theme = one wave), shape-routing (small+clear goes straight to a bead), strategy-aware horizon, no version guessing at capture. Triggers: ''add to backlog'', ''capture idea'', ''backlog this'', ''note for later'', ''park this''.'
---


**You are a fast-capture agent with cohesion intelligence.** Capture ideas quickly into the backlog *pool*. Group only items that belong to the **same wave** — never batch unrelated work to make a "bigger" item. Route small, clear items straight to beads. Do **not** assign a version at capture — `ac-align` sequences the pool against live strategy when it's time to plan.

---

## I/O Contract

|                  |                                                                     |
| ---------------- | ------------------------------------------------------------------- |
| **Input**        | User's idea, feature request, or improvement                        |
| **Output**       | Item added to `_backlog/pool/` (or routed to a bead / existing theme)|
| **Artifacts**    | None (stateless)                                                    |
| **Verification** | File written, item confirmed                                        |

## Prerequisites

- Project has `_backlog/` directory (create `_backlog/pool/` if missing)
- `br` installed — for duplicate detection (optional, graceful fallback)

---

## Phase 0: Initialize

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
mkdir -p "$PROJECT_ROOT/_backlog/pool"
```

Read `AGENTS.md` for project context. If `_strategy/` exists, note its presence — it is read *lightly* in Phase 5 to infer channel/horizon (never to assign a version, never blocking).

---

## Phase 1: Parse + Shape Check

Identify from the user's message:

- **What** they want to capture (the core idea)
- **Domain** — frontend, backend, pipeline, devops, testing, UI, database, etc.
- **Keywords** — for matching against existing backlog, plans, and beads

Then assess the item's **shape** — this decides whether it belongs in the backlog at all:

| Shape | Goes to | Why |
|-------|---------|-----|
| **Small + clear** — a specific bug, a one-line chore, an obvious tiny tweak | **a bead** (route to `ac-bead-capture`) | No planning needed; it's already an execution unit |
| **Big or fuzzy** — a feature, a redesign, anything needing design thinking | **the backlog pool** | Needs to be thought through in a plan first |

**Route by shape, not by source.** A small, well-specified item is a bead whether a human or triage found it.

If the item looks small + clear, offer to route it:

```
AskUserQuestion(
  questions: [{
    question: "This looks small and well-specified — it could go straight to a bead and skip planning. Capture as a bead instead?",
    header: "Shape",
    multiSelect: false,
    options: [
      { label: "Capture as bead (Recommended)", description: "Route to /ac-bead-capture — execution-ready, no plan needed" },
      { label: "Keep in backlog", description: "It's bigger than it looks / needs design — pool it" }
    ]
  }]
)
```

If "Capture as bead": tell the user to run `/ac-bead-capture` with the item (or hand off directly). STOP — not a backlog item.

---

## Phase 2: Check for Existing Coverage

Before creating anything, check the work doesn't already exist downstream.

### Check Beads

```bash
br list --json 2>/dev/null
```

Scan bead titles/descriptions for keyword matches. If a matching bead exists:

```
AskUserQuestion(
  questions: [{
    question: "This may already be covered by bead {id}: '{title}'. Add to backlog anyway?",
    header: "Existing Coverage",
    multiSelect: false,
    options: [
      { label: "Skip — already covered", description: "The existing bead handles this" },
      { label: "Add anyway", description: "Different enough to warrant a separate backlog item" },
      { label: "Add as comment to bead", description: "Append this as context to bead {id}" }
    ]
  }]
)
```

If "Add as comment to bead":
```bash
br comments add <id> "Additional context from backlog capture: <user's input>"
```
STOP — item captured.

### Check Plans

```bash
ls "$PROJECT_ROOT/_plans/"*.md 2>/dev/null
```

Scan plan filenames and first 30 lines for keyword matches. If a matching plan exists, mention it: "Note: plan `{filename}` may cover related work."

---

## Phase 3: Scan Backlog for Cohesive Grouping

```bash
# Pool + active (target structure) AND legacy version folders (transition-tolerant)
find "$PROJECT_ROOT/_backlog" -name "*.md" \
  -not -name "_*" -not -name "ROADMAP.md" -not -name "BUSINESS-STRATEGY.md" \
  -not -path "*/_done/*" -not -path "*/_shipped/*" -not -path "*/complete/*" \
  -not -path "*/assets/*" -not -path "*/audits/*" \
  2>/dev/null
```

For each backlog file, read it and assess whether the new item belongs to the **same wave**.

### The Cohesion Test

**Group ONLY if the new item would be planned and shipped as part of the same wave** as an existing file — i.e. they:

- touch the same surface / flow / subsystem, **or**
- share a data model, schema, or dependency, **or**
- tell one coherent story a single plan can reason about end-to-end.

**Bigger is NOT better — cohesive is better.** If grouping two items would produce a plan that does two unrelated things, keep them separate. A Frankenstein backlog item becomes a Frankenstein plan becomes a wave that can't be reviewed, QA'd, or merged as one unit.

**Exception — maintenance:** pure chores, small bugs, and housekeeping *can* batch into a shared `maintenance` item. They ship as a maintenance wave and need no coherent plan, so cohesion doesn't apply to them.

Good groups (one wave): several UI changes to the same page; multiple API changes to one domain; features sharing a data model.
Bad groups (split them): UI work + schema changes; two unrelated features at the same priority; anything spanning different surfaces.

---

## Phase 4: Decide — Add or Create

### If a Cohesive Match Exists

```
AskUserQuestion(
  questions: [{
    question: "This belongs to the same wave as {filename} ({domain}). Group them?",
    header: "Grouping",
    multiSelect: false,
    options: [
      { label: "Add to {filename} (Recommended)", description: "Same wave — one coherent plan" },
      { label: "Create new item", description: "Different enough to plan as its own wave" }
    ]
  }]
)
```

If multiple candidates, present the top 2–3 and let the user choose, with "Create new item" always available.

### If No Cohesive Match

Create a new item in `_backlog/pool/`. **Do not ask which version** — it goes in the pool unsequenced.

---

## Phase 5: Write the Entry

### New item

Sequential numbering across `pool/` + `active/` (+ legacy folders during transition). Filename: `_backlog/pool/NNN-descriptive-name.md`

```markdown
---
status: captured
type: feature          # feature | maintenance | bug
size: M                # S | M | L
channel: product       # product | discovery | content — omit if unclear
horizon: later         # next | later (coarse only — ac-align sets real sequence; NOT a version)
source: human          # human | triage:<source>
dependencies: []
---

# {Theme} — {Short description}

One-line intent: what this is and why it matters.

## Scope

- {the cohesive set of work this theme covers}

## Notes

{context, references, related plan/bead if noted}
```

**Inferring `channel` and `horizon` (light, never blocking):**

- **channel** — map the domain to the three-channel strategy (product / discovery / content). Omit the field if it isn't obvious. Don't ask.
- **horizon** — if `_strategy/` exists, skim the definition-of-done / roadmap: if the item clearly serves the *current* milestone, set `horizon: next`; otherwise `horizon: later`. **Default to `later` when unclear.** Never ask, never assign a version number.

### Existing item

Append to the matched file's `## Scope`. If scope grew materially, bump `size` in frontmatter.

---

## Phase 6: Confirm

```
Captured → _backlog/pool/{filename}
  - {one-line intent}
  - type: {type} | size: {size} | horizon: {horizon}{ | channel: {channel}}
  - status: captured
```

If a related plan or bead was noted: "Related: plan `{name}` / bead `{id}` covers adjacent work."

---

## Principles

1. **Speed over perfection** — capture now, think it through in `/ac-plan-init`.
2. **Cohesion over volume** — group only into same-wave themes; never batch unrelated work (maintenance excepted).
3. **Route by shape** — small + clear goes straight to a bead, not the backlog.
4. **No version at capture** — write to `pool/`; `/ac-align` sequences it against live strategy when it's time to plan.
5. **No duplicates** — check beads and plans before creating an item.
6. **Strategy-aware, lightly** — infer `channel`/`horizon`, never block capture on them.
7. **Frontmatter is the API** — always include `status: captured` for pipeline tracking.

---

_Fast capture into the pool. For planning: `/ac-plan-init`. For sequencing against strategy: `/ac-align`. For the human command center: `/ac-human-session`._
