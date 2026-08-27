---
name: ac2-polish
description: 'Polish an ac2 plan or an epic''s bead set to FIXPOINT — a stateless severity-gated reader per round, bounded, stamped only against a measured empty diff at round >= 2. One engine, two checklists, selected by argument. Triggers: "ac2 polish", "polish the plan", "polish the beads", "refine the ac2 beads", "run polish to fixpoint". For the legacy ac-plan-clean / ac-plan-refine-* / ac-bead-refine ceremony use those skills.'
---

# ac2-polish — one fixpoint engine, two checklists

## I/O Contract

|                  |                                                                                 |
| ---------------- | ------------------------------------------------------------------------------- |
| **Input**        | `plan <path>` or `bead <epic-id>` — the argument selects the checklist            |
| **Output**       | A fixpoint-stamped artifact, or findings to the human and NO stamp                |
| **Artifacts**    | `<state>/round-N.sha` per round · `<state>/receipt.txt` · the stamp itself        |
| **Verification** | `skills/_tools/polish-fixpoint.sh` (the gate) · `polish-fixpoint.test.sh` (its proof) |

Checklists: `references/plan-checklist.md` · `references/bead-checklist.md` (mandatory load,
one of the two per run). Doctrine: `skills/ac2-pipeline/SKILL.md`.

## Division of labour — strict, and the reason this works

**This SKILL spawns the readers. `polish-fixpoint.sh` spawns nothing.** The script measures
the diff and gates the stamp; it never reads the artifact for meaning and never decides what
a finding is. A loop that grades itself always finds itself clean, so the measurement is kept
outside the thing being measured.

**Write paths, and there is exactly one writer each:**
- **plan** → the script stamps the plan's frontmatter. Plan-side SOLE WRITER; do not hand-edit
  `polish_rounds`, `polish_fixpoint_sha256` or `polish_stamped_at`.
- **bead** → the script writes the `POLISH-FIXPOINT:` receipt comment, and the `refined` write
  is gated on that receipt from INSIDE `stamp-refined.sh` (ac-gv70). A check a caller can
  route around is not a gate, so the gate lives in the writer — not in this skill's prose.

## The round procedure — ONE procedure, both modes

The mode selects the checklist and the stamp target. Nothing else differs; there is no second
round path for beads, and adding one would end the property this skill exists for.

```
MODE=plan|bead   TARGET=<plan-path|epic-id>   STATE=<run-scoped dir>   MAX=5
CHECKLIST = references/plan-checklist.md   (plan)
          | references/bead-checklist.md   (bead)
ARTIFACT  = the plan file                  (plan)
          | the epic's bead set, exported to one file   (bead)

for ROUND in 1..MAX:
  PRE = sha256(ARTIFACT)                      # observed BEFORE the reader runs
  spawn a FRESH, STATELESS reader for this round:
      input  = ARTIFACT + CHECKLIST
      output = findings, severity-gated (below)
      it carries NO memory of any earlier round
  apply this round's findings to ARTIFACT
  polish-fixpoint.sh --mode $MODE --target $TARGET --artifact $ARTIFACT \
                     --state $STATE --round $ROUND --pre $PRE --max-rounds $MAX
  case the verdict token:
    STAMPED   -> done; go to Hand-off
    CONTINUE  -> next round
    REFUSED round-1-clean   -> next round (a clean first round proves nothing)
    REFUSED bound-exhausted -> STOP: findings to the human, NO stamp
    ENDED out-of-band-amendment -> STOP: the input moved; restart on a frozen input
    NOT-GATED -> STOP: nothing was measured, so nothing is claimed
```

**FRESH CONTEXT EVERY ROUND.** The reader is stateless and spawned per round. Same-context
polish is rot: this pipeline's own three same-context rounds were superseded by fresh-context
rounds that found 30+ defects, one of them fatal. A reader that has already read the artifact
is not a second opinion.

**SEVERITY GATE — correctness · contradiction · unimplementability.** Not style, not
preference, not wording. A round that reports style is a round that did not read for defects.

**FIXPOINT = ZERO CHANGES AT ROUND >= 2.** A clean round 1 is equally consistent with a clean
artifact and a reader that read nothing, so it never stamps.

**BOUNDED, default 5.** No clean round means NO STAMP and the findings go to the human.
Routine bound-exhaustion indicts the CHECKLIST, not the artifact — take it to the tuning
session rather than raising the bound.

**FROZEN INPUT.** An out-of-band amendment ENDS the loop; it never extends it. That is what
the `--pre` digest detects, and it is why a polish run cannot reach round 12 by chasing a
moving target.

## Bead mode runs PER-EPIC

One loop over the epic's whole bead set, never one loop per bead. Per-bead is a ~20x cost
difference for no measured gain, and cross-bead defects — Consumes↔edge parity, duplicated
Delivers, a contradiction between two siblings — are invisible to a per-bead reader.

## Telemetry

`rounds-to-fixpoint` is a BUDGETED metric: report it into the batch rollup with the mode and
the final verdict token. The trajectory is the signal; a single run's round count is not.

## Hand-off — polish hands off, it never rests

A polished plan with no beads is a measured dead-end in both this system and Jef's. On a
STAMPED plan run, END by invoking `ac2-beadify` on the stamped plan, or queue that hand-off
explicitly with the human. Do not finish a plan run by reporting success and stopping.
