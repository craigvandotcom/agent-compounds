# polish · bead mode

The loop is in `ac-polish/SKILL.md` and is the same in every mode. This file supplies only
what bead mode binds, and it is a MANDATORY load for a bead run.

## Bindings

| knob | bead mode |
| --- | --- |
| **TARGET** | the epic id |
| **ARTIFACT** | the epic's bead set exported to one file by `scripts/bead-artifact.py export` |
| **CHECKLIST** | `references/bead-checklist.md` |
| **VALIDATE** | `skills/_tools/element4-check.sh` over every bead in the artifact |
| **STAMP** | `polish-fixpoint.sh --mode bead` writes the `POLISH-FIXPOINT:` receipt comment |

## Run PER-EPIC, never per-bead

One loop over the epic's whole bead set. Per-bead is a ~20x cost difference for no measured
gain, and cross-bead defects — Consumes↔edge parity, duplicated Delivers, a contradiction
between two siblings — are invisible to a per-bead reader.

## The board is not the artifact

Export once, at the start. The loop edits the ARTIFACT; the board is not touched until the run
ends. A mid-run writeback changes what the next round's reader sees, and the round that follows
measures churn instead of defects.

Land it with `scripts/bead-artifact.py writeback --apply` AFTER the verdict, in one pass.
The script refuses when `br` cannot resolve a board from the CWD, and never writes `refined`
or `unrefined` — those belong to `stamp-refined.sh` alone.

## `refined` is a separate gate, and it is not this loop's to grant

The receipt this loop writes is a PRECONDITION of `refined`, not a grant of it.
`skills/_tools/stamp-refined.sh` is the sole sanctioned writer: it runs `element4-check.sh`,
REFUSES any description carrying no executable `Probe:` line — a stamp that certifies nothing
a gate can execute is a labeling defect — and for an `origin:ac-*` bead additionally
requires a conforming receipt at rounds >= 2. Pre-floor stamps are restamped on sight,
never grandfathered.

Stamp `refined` only on beads that are implementable work. A `decision`-type bead is a human
fork and element 4 exempts it — a receipt records that it was polished; it does not make it
ready to implement. Leave those, and anything held, for the human.

## Hand-off

Report `rounds-to-fixpoint` with the verdict token, then hand the refined set to `ac-implement`
or name what still blocks it.
