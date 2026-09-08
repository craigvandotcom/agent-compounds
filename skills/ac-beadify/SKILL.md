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

Contract compiled TO: `references/bead-schema.md` (mandatory load); canon by pointer:
`skills/ac-pipeline/SKILL.md`, `beads-standards`.

## The refusal that defines this skill

**No probe, no bead.** An AC that names no executable probe is not a smaller AC — the bead
is REFUSED, emitted nowhere, returned to the plan. This is a refusal, not a warning, never a
label: softening it IS the vacuous-AC regression (measured H-impact, recurrence 5, previously
regressed). Mechanically, for every candidate bead:

```sh
# every AC must yield a probe; every probe must be runnable AND RED against current HEAD
grep -o 'Probe: `[^`]*`' "$BEAD" | sed 's/^Probe: `//; s/`$//' \
  | while IFS= read -r p; do
      sh -n -c "$p" || { echo "REFUSED: unrunnable probe: $p"; continue; }
      sh -c "$p" >/dev/null 2>&1 \
        && echo "REFUSED: already green — this probe passes before the work exists: $p"
    done
```

Count the extracted probes against the AC bullets; fewer = REFUSED. A prose fragment
(`wc -l`, "diff the file") is not a probe. **Execution is part of the refusal**: compile runs
every probe against current HEAD — one that exits 0 is already green, asserts nothing, and
REFUSES the bead naming the offending AC (dogfood #2 measured 19; baseline in
`ac-pipeline/FRICTIONS.md`). A probe that cannot run at compile (state-mutating, needs a
device/credentials) goes on an explicit NOT-EXECUTED list with the reason — never a silent
skip; a probe naming an artifact this bead has yet to create keeps the guarded form
`test -x <path> && bash <path>`, honestly RED at compile.

## Procedure

1. **Read the plan and the schema.** Load `references/bead-schema.md`. Confirm the plan
   carries an approval stamp; an ungraded plan is returned, not compiled.
2. **Cut the work into beads.** Sizing is from the bead-checklist, never from taste: one bead
   = one focused worker pass. Two signals govern the cut, both cheaper here than at implement:
   - **Split signal** — heavy in-bead cognition at implement time means it was too big; split it.
   - **Under-specification is a PREMISE-FAILURE class** — a worker must never grind through an
     underdetermined bead improvising decisions the bead should have made; a fork the plan does
     not settle goes back to the plan, or out as a human gate.
3. **Write each bead to the four-section schema, exactly.** `## Intent` · `## Acceptance
   Criteria` · `## Delivers` · `## Consumes` — first header per type: `bug` → `## Steps to
   Reproduce`, `epic` → `## Success Criteria` (`br lint` compiles those in). Nothing else.
   **Line numbers are banned in Intent** — a `file:line` anchor decays before the claim does.
4. **Apply the refusal** (§ above) to every bead before any of them is created. Refuse the
   bead, not the batch — but do not create a partial graph around a refused node.
5. **Wire Delivers/Consumes as the graph.** `## Delivers` names artifacts; a dependent's
   `## Consumes` cites `<blocker-id> -> <artifact>` that the blocker's Delivers promises, or
   `none`; a `<…>` placeholder is REFUSED (it reads as a premise). Then create the edges and
   read them back: direction is `<blocked> depends-on <blocker>`, a reversed `br dep add` is
   SILENT, and an epic reaches its children by parent-child, never `blocks`.
- **Consumes↔edge parity, both directions.** Every Consumes line has an edge; every edge
      has a Consumes line. Verify with `br dep cycles` plus `br show` on both ends.
- **One path per `## Delivers` bullet, and every delivered path that ALREADY EXISTS owes a
      touchers line.** `skills/_tools/touchers.sh derive <path>` prints `<stem> <N> <command>`;
      write it beneath the bullet as ``touchers: `<command>` → <N> · owned by: <sibling bead>``
      — else `out-of-scope: <why>`.
6. **Create the beads** per the schema's Header fields: `br create` REJECTS `-f` alongside a
   title, so bodies go `-d "$(cat <file>)"` and bead text must stay dcg-safe.
7. **Retire the plan** (§ below).

## Plan retirement — the seams chain, and the one case that refuses it

Tenet 7: plan hard, then retire the plan — beads and the constitution are its only survivors.
On a successful compile the plan file is **moved to `_plans/_done/`**, the epic bead gets a
comment naming its new path; the plan is preserved, never deleted.

**A seams plan is never a single file — retire the whole chain.** A plan compiled from
`ac-polish` seams mode carries `seams_source:` naming its seams doc; each seams doc carries
`parent:` / `supersedes:` / `splits[]:` / `seeded_from:` edges to its siblings. Walk those
edges and move EVERY reachable `_plans/` file to `_plans/_done/` (not just `$PLAN_FILE`) —
stamped `status: done` + `beadified: <epic-id>`, RETIREMENT HELD guard (§ below) per file.

**REFUSE to retire while an open bead still needs the plan as its subject** — a dogfood
receipt, a bead whose Delivers or Intent names the plan path. If one exists, leave the file
where it is and say so:

```sh
RUST_LOG=error br list --status open --json \
  | grep -Fq "$(basename "$PLAN_FILE")" && echo "RETIREMENT HELD: an open bead still names $PLAN_FILE"
```

The guard lives HERE — the only place its condition still holds.

## Hand-off

A compiled epic with no grading is a dead end: hand the bead set to `ac-polish` first.
