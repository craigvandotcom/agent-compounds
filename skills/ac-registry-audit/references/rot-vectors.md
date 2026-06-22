# Registry rot vectors — what accumulates across many skill iterations

The registry is a *prompt corpus*, not code. Its decay modes are different from a
codebase's, and most are invisible to a normal code review. These are the four
that accumulate as skills are added, renamed, split, and merged over time.

| Vector | What it is | Caught by `lint.sh`? | Symptom |
|---|---|---|---|
| **Trigger collision** | Two+ skills whose frontmatter trigger surfaces overlap, so an agent routing by description alone picks ambiguously | No | "review the code" could fire `audit`, `ac-review`, or `ac-hygiene` |
| **Divergent duplicate** | Two skills/docs that both claim canonical authority over one domain and have drifted apart | No | `planning` vs the live `ac-plan-*` chain — different methods, same trigger |
| **Dangling cross-ref** | A skill routes to another skill/command/file that no longer exists | Partial — only `/ac-*` tokens, one-directional | `react-best-practices` was a routing target in 8 files after it was deleted |
| **Doc↔disk drift** | README / AGENTS.md / CORE claims that no longer match the files on disk | Partial — disk→README only (misses README→disk ghosts) | README listing a removed skill, or missing a new one, or using a skill's old name |

## What `lint.sh` covers vs what it misses

`lint.sh` mechanizes the **checkable invariants** — dead-pattern greps, `/ac-*`
cross-ref resolution, frontmatter `name`==dirname, disk→README presence, consumer
symlink health. Run it first; it is fast, deterministic, and tells you the
mechanical surface area before any token is spent.

It cannot catch the **semantic** rot — collisions, divergent duplicates, and the
*reverse* drift directions (a README row for a skill that doesn't exist; a
dangling ref to a non-`ac-*` skill). That is what the `dedup-drift-audit.js`
workflow is for: it reads every skill, reasons about overlap, and adversarially
verifies each finding so intentional cross-references (good design) aren't
flagged as collisions.

## False positives to expect (the verify pass kills most)

- **Deliberately-paired skills** that cross-reference each other with a clear
  "use X for A, Y for B" boundary are *good design*, not collisions (e.g.
  `ac-review` feature-scoped vs `ac-hygiene` codebase-wide).
- **Intentionally per-app skills** referenced but not in the shared registry
  (`design-system`, `writing-guidelines`, `curate`, `brand-system`, `CORE`) are
  not dangling — they legitimately live per-app.
- **Historical notes** ("was ui-elevate", "formerly ac-next") are intentional,
  not drift.

## The fix discipline

- **Mechanical fixes** (trigger-surface tightening, dead-ref repair, README
  reconciliation, frontmatter alignment) → apply directly; they don't change what
  any skill *does*, only how it routes. Keep `lint.sh` green at the end.
- **Judgment calls** (restore a deleted skill vs re-route its refs; demote a
  duplicate vs keep it as a scoped alternative) → never auto-decide; surface to
  the human with options.
- **Commit per logical pass** so the diff is reviewable.
