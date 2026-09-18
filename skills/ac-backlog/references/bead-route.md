# Bead route — the single-bead intake

A small, well-specified item is an execution unit, not a backlog item. Capture it as ONE
typed bead, minimal ceremony. Authority for types, labels and lifecycle:
`beads-standards/reference/bead-conventions.md`.

**Route by KIND before you file — not every capture is a bead.** Decide kind first:

| What it is | Goes to | Why |
|-------|---------|-----|
| A defect or want a **user** can reach — one deliverable, one surface | **a bead** (stay in this route) | Already an execution unit |
| A defect in the **factory** — pipeline · skill text · lint · bead schema · CI wrapper · harness · tool flag · local stack | the owning skill's **`FRICTIONS.md`** (`beads-standards` § label table) | On the board it is a filing defect, not a category |
| A durable **fact, rule, decision or recipe** | the memory substrate (**`context-engineering`**) | Knowledge, not work |
| **Big or fuzzy** — multi-concern, no single deliverable, needs design thinking | **the backlog pool** (`SKILL.md` Phase 2 onward) | Needs a plan first, not a force-fit bead |

Route by what it IS, not by who raised it or how fast they typed. Any row but the first:
say which home and why, hand off, STOP — not a bead capture.

1. **Route to the right db.** Beads live with the work (see `beads-standards` § Where beads
   live): app feature/bug → that app's db · skill/pipeline/registry → agent-compounds
   (`ac` prefix) · org/infra/memory → root (`org` prefix). No `.beads/` where it belongs →
   file in the nearest parent that has one, noting the intended home.
2. **Dedupe.** Search the target db per the canon's anchor-dedupe rule
   (`bead-conventions.md` § Anti-inflation) — a hit → enrich the existing bead
   (`br comments add`) instead of creating; tell the user.
3. **Type.** Per `bead-conventions.md` § Type admission — each type admits on a test, never a
   title prefix. A `decision` → label `human-gate` + pre-stage the memo (context, options,
   trade-offs, recommendation) and wire `--parent <spawning-epic-id>` AT capture; a
   standalone fork with no spawning epic records its origin in the memo `context:` instead.
4. **Labels.** `origin:ac-backlog` FIRST, then `unrefined` — capture never stamps `refined`
   (exclusively ac-polish's output on convergence); a decision fork gets `human-gate`
   instead. Provenance labels only where true. An implementable bead
   (`bug`/`task`/`feature`) is BORN PROBE-BEARING (create contract § Probe): its
   `## Acceptance Criteria` carries a ``Probe: `<command>` — tier:`` bullet; no probe →
   file `investigation`.
5. **Create.** `br create "<imperative title>" -t <type> --labels "origin:ac-backlog,<labels>" --description "<context: what/why/where, the user's words preserved>"`.
   Set `--priority` only if the user signaled urgency; default is fine. Body carries the
   typed headers from conventions § Body template (`## Steps to Reproduce`,
   `## Acceptance Criteria`, …) — emit them at creation. Grep any file, symbol, commit or
   bead-id before naming it in a binding header; unverified detail is advisory
   (conventions § Binding vs advisory).
6. **Commit** `.beads/` in the target repo (own repo, own commit; discipline:
   `ac-pipeline/references/commit-discipline.md` — pathspec-only, never a wildcard add).
   The jsonl is the cross-machine sync surface — uncommitted = invisible.

**Clarify at most once.** Capture beats interrogation. Ask only if you cannot determine what
done looks like OR which repo it belongs to — one `AskUserQuestion`, max 2 questions, then
commit to an interpretation. Still fuzzy → file it anyway as `investigation` + `unrefined`
with the raw words preserved verbatim; refinement is ac-polish's job (bead mode), not capture's.

**Confirm in one line:** `<id> filed in <repo> as <type>[ +labels] — refine with ac-polish
when scheduling.` Nothing more; the user is mid-thought.
