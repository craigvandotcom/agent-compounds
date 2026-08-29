---
name: ac-bead-capture
description: 'Use to CAPTURE a raw idea, bug, observation, or decision fork from the user as a properly typed bead — on the go, minimal ceremony. Triggers: ''bead this'', ''file this as a bead'', ''new bead'', ''log a bug'', ''track this item'', ''remember to do X''. The agent classifies, routes to the right repo''s db, and dedupes; for parking an idea in the grouped backlog pool use ac-backlog, for decomposing a whole plan use ac2-beadify, for refining existing beads use ac2-polish (bead mode).'
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
description; refinement is ac2-polish's job (bead mode), not capture's.

**Route before you file — not every capture is a bead.** Decide KIND first, then shape:

| What it is | Goes to | Why |
|-------|---------|-----|
| A defect or want a **user** can reach — one deliverable, one surface | **a bead** (stay in this skill) | Already an execution unit |
| A defect in the **factory** — pipeline · skill text · lint · bead schema · CI wrapper · harness · tool flag · local stack | the owning skill's **`FRICTIONS.md`** (`beads-standards` § label table) | On the board it is a filing defect, not a category |
| A durable **fact, rule, decision or recipe** | the memory substrate (**`context-engineering`**) | Knowledge, not work |
| **Big or fuzzy** — multi-concern, no single deliverable, needs design thinking | **`ac-backlog`** | Needs a plan first, not a force-fit bead |

Route by what it IS, not by who raised it or how fast they typed. Any row but the first:
say which home and why, hand off, STOP — not a bead capture.

## Phase 2 — Route (which db?)

Beads live with the work (see `beads-standards` § Where beads live). Infer from the
subject first, current repo second: app feature/bug → that app's db · skill/
pipeline/registry → agent-compounds (`ac` prefix) · org/infra/memory → root
repo (`org` prefix). No `.beads/` where it belongs → say so and file in the
nearest parent that has one, noting the intended home.

Visual references per `ac-pipeline/references/design-refs.md` (save immediately, cite the path, never prose-only).

## Phase 3 — Classify & create

1. **Dedupe** per the canon’s anchor-dedupe rule
   (`beads-standards/reference/bead-conventions.md` § Anti-inflation): search the target
   db — hit → enrich the existing bead (`br comments add`) instead of creating; tell the user.
2. **Type** per `beads-standards/reference/bead-conventions.md` § Type admission — each
   type admits on a test, never a title prefix; `decision` → label `human-gate` +
   pre-stage the memo: context, options, trade-offs, recommendation. For a `human-gate`/DECISION shape,
   **resolve parentage AT capture** — set `--parent <spawning-epic-id>` (Arm 0:
   human-gate beads bypass `ac-bead-refine`'s adopt-a-parent step and `ac-tidy`'s
   parentage flag, so their parent must be wired here at capture, not deferred; the
   template alone would leave zero-ceremony capture as a bypass). A standalone fork
   with no spawning epic records its origin in the memo `context:` instead.
3. **Labels:** `unrefined` — capture never stamps `refined`, exclusively
   `/ac2-polish`'s output on convergence, no exceptions; a decision fork
   gets `human-gate` instead. Provenance labels only where true.
4. **Create:** `br create "<imperative title>" -t <type> --labels "origin:ac-bead-capture,<labels>"
   --description "<context: what/why/where, user's words preserved>"` — set
   `--priority` only if the user signaled urgency; default is fine. Body carries
   the typed headers from conventions §Body template (`## Steps to Reproduce`
   for bugs, `## Acceptance Criteria`, …) — emit them at creation. Grep any
   file, symbol, commit or bead-id before naming it in a binding header;
   unverified detail is advisory (conventions §Binding vs advisory). For a
   `human-gate`/DECISION shape, add `--parent <spawning-epic-id>` (step 2). An
   optional `origin:` hint may be added to the description for any ad-hoc capture —
   a lightweight provenance breadcrumb (`origin: <slack thread / conversation /
   bead-id>`), never required. A plain non-human-gate capture stays zero-ceremony:
   no epic selection, no origin required.
5. **Public-db rule:** agent-compounds beads publish — neutral title,
   pointer-only for anything sensitive (conventions §Public-repo rule).
6. **Commit** `.beads/` in the target repo (own repo, own commit; discipline:
   `ac-pipeline/references/commit-discipline.md` — pathspec-only, never a wildcard add).

## Phase 4 — Confirm (one line)

`<id> filed in <repo> as <type>[ +labels] — refine with /ac2-polish when
scheduling.` Nothing more; the user is mid-thought.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Interrogating the user (3+ questions) | One round max; `unrefined` exists for a reason |
| Decomposing the idea into an epic + children | That's ac2-beadify, on an approved plan — capture files ONE bead |
| Filing a hunch as `bug` | `bug` = confirmed; suspicion = `investigation` |
| Naming a file, symbol or blocker you have not opened | Grep first; unverified detail is advisory, never binding |
| Skipping dedupe | `br search` first — enrich beats duplicate |
| Strategy/secrets in an agent-compounds bead | That db is PUBLIC — neutral title + private pointer |
| Forgetting the `.beads/` commit | The jsonl is the sync surface — uncommitted = invisible cross-machine |
| Stamping `refined` at capture | Never — exclusively `/ac2-polish`, no exceptions |

