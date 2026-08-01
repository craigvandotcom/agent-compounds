---
name: ac-bead-capture
description: 'Use to CAPTURE a raw idea, bug, observation, or decision fork from the user as a properly typed bead — on the go, minimal ceremony. Triggers: ''bead this'', ''file this as a bead'', ''new bead'', ''log a bug'', ''track this item'', ''remember to do X''. The agent classifies, routes to the right repo''s db, and dedupes; for parking an idea in the grouped backlog pool use ac-backlog, for decomposing a whole plan use ac-beadify, for refining existing beads use ac-bead-refine.'
---

# Capture → Bead

Turn one raw utterance into one well-filed bead (occasionally a small cluster).
**Speed is the point** — the user is capturing on the go; every second of
ceremony costs future captures. Conventions authority:
`../beads-standards/reference/bead-conventions.md` (types, labels, lifecycle, public-db rule).

## I/O Contract

|                  |                                                                       |
| ---------------- | --------------------------------------------------------------------- |
| **Input**        | A raw idea / bug report / observation / decision fork (one line or fuzzy) |
| **Output**       | Bead id(s) + one-line confirmation of where it landed and as what     |
| **Artifacts**    | The bead(s); `.beads/` committed in the target repo                   |
| **Verification** | `br show <id>` renders with all template sections                     |

**No run-ledger by design** — this is a quick-capture skill; the org's one-task-per-section
ledger standard is deliberately waived here because ceremony defeats the skill's purpose
(speed).

## Phase 1 — Clarify (at most ONE round, often zero)

Capture beats interrogation. Ask only if you cannot determine **what done looks
like** OR **which repo it belongs to** — one `AskUserQuestion`, max 2 questions,
then commit to an interpretation. Still fuzzy after that → file it anyway as
`investigation` + `unrefined` with the raw words preserved verbatim in the
description; refinement is ac-bead-refine's job, not capture's.

**Reverse shape-check (the mirror of ac-backlog's routing):** `ac-backlog` routes
small+clear items straight to a bead; this phase does the opposite check — if what's
being captured is actually **big or fuzzy** (multi-concern, spans more than one
surface, no single deliverable a bead can express — a feature, a redesign, anything
needing design thinking), it doesn't belong here as one bead. Route it to
`ac-backlog` instead of force-fitting it into a bead or an epic-shaped description:

| Shape | Goes to | Why |
|-------|---------|-----|
| Small + clear — one deliverable, one surface | **a bead** (stay in this skill) | Already an execution unit |
| Big or fuzzy — multi-concern, no single deliverable, needs design thinking | **`ac-backlog`** | Needs to be thought through in a plan first, not force-fit into one bead |

Route by shape, not by source — a fuzzy multi-concern capture is a fuzzy multi-concern
capture whether the user typed it fast or slow. Say so and hand off: "This spans more
than one bead's worth of work — routing to `ac-backlog` instead of filing it here."
STOP — not a bead capture.

## Phase 2 — Route (which db?)

Beads live with the work (see conventions §Where beads live). Infer from the
subject first, current repo second: app feature/bug → that app's db · skill/
pipeline/registry → agent-compounds (`ac` prefix) · org/infra/memory → root
repo (`org` prefix). No `.beads/` where it belongs → say so and file in the
nearest parent that has one, noting the intended home.

## Phase 3 — Classify & create

1. **Dedupe** per the canon’s anchor-dedupe rule <!-- net-growth-ok: ac-gzb P2 — canon citation replaces weaker local rule -->
   (`beads-standards/reference/bead-conventions.md` § Anti-inflation): search the target
   db — hit → enrich the existing bead (`br comments add`) instead of creating; tell the user.
2. **Type** per conventions: `task` (work) · `feature` (capability) · `bug`
   (CONFIRMED defect — repro/cause in hand, else `investigation`) ·
   `investigation` (open question an agent can resolve) · `decision` (fork only
   the human can resolve → label `human-gate` + pre-stage the memo: context,
   options, trade-offs, recommendation). For a `human-gate`/DECISION shape,
   **resolve parentage AT capture** — set `--parent <spawning-epic-id>` (Arm 0:
   human-gate beads bypass `ac-bead-refine`'s adopt-a-parent step and `ac-tidy`'s
   parentage flag, so their parent must be wired here at capture, not deferred; the
   template alone would leave zero-ceremony capture as a bypass). A standalone fork
   with no spawning epic records its origin in the memo `context:` instead.
3. **Labels:** `unrefined` — capture never stamps `refined`, exclusively
   `/ac-bead-refine`'s output on convergence, no exceptions; a decision fork
   gets `human-gate` instead. Provenance labels only where true.
4. **Create:** `br create "<imperative title>" -t <type> --labels "<labels>"
   --description "<context: what/why/where, user's words preserved>"` — set
   `--priority` only if the user signaled urgency; default is fine. Body carries
   the typed headers from conventions §Body template (`## Steps to Reproduce`
   for bugs, `## Acceptance Criteria`, …) — emit them at creation. For a
   `human-gate`/DECISION shape, add `--parent <spawning-epic-id>` (step 2). An
   optional `origin:` hint may be added to the description for any ad-hoc capture —
   a lightweight provenance breadcrumb (`origin: <slack thread / conversation /
   bead-id>`), never required. A plain non-human-gate capture stays zero-ceremony:
   no epic selection, no origin required.
5. **Public-db rule:** agent-compounds beads publish — neutral title,
   pointer-only for anything sensitive (conventions §Public-repo rule).
6. **Commit** `.beads/` in the target repo (own repo, own commit).

## Phase 4 — Confirm (one line)

`<id> filed in <repo> as <type>[ +labels] — refine with /ac-bead-refine when
scheduling.` Nothing more; the user is mid-thought.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Interrogating the user (3+ questions) | One round max; `unrefined` exists for a reason |
| Decomposing the idea into an epic + children | That's ac-beadify, on an approved plan — capture files ONE bead |
| Filing a hunch as `bug` | `bug` = confirmed; suspicion = `investigation` |
| Skipping dedupe | `br search` first — enrich beats duplicate |
| Strategy/secrets in an agent-compounds bead | That db is PUBLIC — neutral title + private pointer |
| Forgetting the `.beads/` commit | The jsonl is the sync surface — uncommitted = invisible cross-machine |
| Stamping `refined` at capture | Never — exclusively `/ac-bead-refine`, no exceptions |

