---
name: ac-beadify
description: 'Compile an APPROVED ac2 plan into lean beads — the four-section ac2 schema, a wired dependency graph, and plan retirement. Refuses any bead whose ACs name no executable probe (no probe, no bead). Triggers: "ac2 beadify", "compile the plan into ac2 beads", "ac2 beads from plan". To grade the result use ac-polish.'
---

# ac-beadify — plan in, lean beads out

## I/O Contract

|                  |                                                                              |
| ---------------- | ---------------------------------------------------------------------------- |
| **Input**        | One APPROVED plan file (`ac-plan`, graded by `ac-polish` plan-checklist)     |
| **Output**       | Beads in `br` on the ac2 schema, with every dependency edge wired both ways    |
| **Artifacts**    | The epic bead; the plan moved to `_plans/_done/` (retirement)                  |
| **Verification** | `br dep cycles` · `br lint` · the probe-extractor below · Consumes↔edge parity |

Contract compiled TO: `references/bead-schema.md` (mandatory load). Doctrine:
`skills/ac-pipeline/SKILL.md`. Canon by pointer, never restated: `beads-standards`.

## The refusal that defines this skill

**No probe, no bead.** An AC that names no executable probe is not a smaller AC — the bead
is REFUSED, emitted nowhere, and returned to the plan for a deliverable that can be checked.
This is a refusal, not a warning, and never a label: softening it to a warning IS the
vacuous-AC regression it exists to stop (measured H-impact, every-run, recurrence 5,
previously regressed). Mechanically, for every candidate bead:

```sh
# every AC must yield a probe, and every probe must be runnable as written
grep -o 'Probe: `[^`]*`' "$BEAD" | sed 's/^Probe: `//; s/`$//' \
  | while IFS= read -r p; do sh -n -c "$p" || echo "REFUSED: unrunnable probe: $p"; done
```

Count the extracted probes against the AC bullets. Fewer probes than ACs = REFUSED. A prose
fragment (`wc -l`, "diff the file", "grep for it") is not a probe. A probe naming an artifact
this bead has yet to create uses the guarded form `test -x <path> && bash <path>` so its
leading word exists today and it is honestly RED until the artifact lands.

## Procedure

1. **Read the plan and the schema.** Load `references/bead-schema.md`. Confirm the plan
   carries an approval stamp; an ungraded plan is returned, not compiled.
2. **Cut the work into beads.** Sizing is from the bead-checklist, never from taste: one bead
   = one focused worker pass (Jef's wave: 5,500 plan lines → 347 beads, ~16 lines/bead).
   Two signals govern the cut, and both are cheaper here than at implement:
   - **Split signal** — heavy in-bead cognition discovered at implement time means the bead
     was too big. Split it now.
   - **Under-specification is a PREMISE-FAILURE class** — a worker must never grind through
     an underdetermined bead improvising decisions the bead should have made. If the plan
     does not settle a fork, the bead does not exist yet; send the fork back to the plan or
     file it as a human gate.
3. **Write each bead to the four-section schema, exactly.** `## Intent` · `## Acceptance
   Criteria` · `## Delivers` · `## Consumes` — first header per type: `bug` → `## Steps to
   Reproduce`, `epic` → `## Success Criteria` (`br lint` compiles those in). Nothing else.
   **Line numbers are banned in Intent** — symbol and file names are welcome as hints, but a
   `file:line` anchor decays before the claim and nothing cheap tells you it has.
4. **Apply the refusal** (§ above) to every bead before any of them is created. Refuse the
   bead, not the batch — but do not create a partial graph around a refused node.
5. **Wire Delivers/Consumes as the graph.** `## Delivers` names artifacts; a dependent's
   `## Consumes` cites `<blocker-id> -> <artifact>` where that blocker's Delivers actually
   promises that string, or the single word `none`. Then create the edges and read them back:
   direction is `<blocked> depends-on <blocker>`, a reversed `br dep add` is SILENT, and an
   epic reaches its children by parent-child, never `blocks`.
   - **Consumes↔edge parity, both directions.** Every Consumes line has an edge; every edge
     has a Consumes line. Verify with `br dep cycles` plus `br show` on both ends of each
     edge — a parity gap is the measured way a "wired" graph turns out not to be.
6. **Create the beads.** `br create` REJECTS `-f` alongside a title: bodies go
   `-d "$(cat <file>)"`, which routes prose through the shell, so bead text must stay
   dcg-safe — no command substitution, no unbalanced quoting. Only comments and receipts
   take `-f <file>`.
7. **Retire the plan** (§ below).

## Bootstrap seam — expires at Phase 3

Until `ac-implement` exists, ac2 beads are worked on the CURRENT path, whose engineer spawn
pastes `## Territory` verbatim with no fallback. So beads compiled for **Phases 0, 1 and 2
carry a transitional `## Territory` list**. It is **dropped from Phase 3 on**, when
ac-implement's flight-check derives the surface at claim time instead. The seam is
transitional by construction: it is never graded by `bead-checklist.md`, and it expires — do
not carry it forward, and do not let it grow a second consumer.

## Plan retirement — and the one case that refuses it

Tenet 7: plan hard, then retire the plan — beads and the constitution are its only survivors.
On a successful compile the plan file is **moved to `_plans/_done/`** and the epic bead gets a
comment naming its new path. If beads still need the plan, they are not self-contained enough;
retirement is what forces that discipline, and the plan is preserved, never deleted.

**REFUSE to retire while an open bead still needs the plan as its subject.** Before moving the
file, look for an open bead whose subject IS this plan — a dogfood receipt, a
pre-registration, a bead whose Delivers or Intent names the plan path. If one exists, leave
the file exactly where it is and say so, naming the bead that holds it:

```sh
RUST_LOG=error br list --status open --json \
  | grep -Fq "$(basename "$PLAN_FILE")" && echo "RETIREMENT HELD: an open bead still names $PLAN_FILE"
```

The guard lives HERE, in the skill that ships retirement, because that is the only place its
condition can still be true. A safeguard on the far side of a dependency is decoration.

## Hand-off

A compiled epic with no grading is a dead end: hand the bead set to `ac-polish`
(bead-checklist) before any of it is claimed.
