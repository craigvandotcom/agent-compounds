---
name: ac2-polish
description: 'Polish a plan, an epic''s bead set, or a code scope to FIXPOINT — a stateless severity-gated reader per round, stamped only against a measured empty diff at round >= 2. One engine, three modes, selected by argument. Triggers: "ac2 polish", "polish the plan", "polish the beads", "polish this code", "refine the ac2 beads", "run polish to fixpoint". For the legacy ac-plan-clean / ac-plan-refine-* / ac-bead-refine ceremony use those skills.'
---

# ac2-polish — one fixpoint engine, three modes

## I/O Contract

|                  |                                                                                 |
| ---------------- | ------------------------------------------------------------------------------- |
| **Input**        | `plan <path>` · `bead <epic-id>` · `code <scope> --target <bead-id>`              |
| **Output**       | A fixpoint-stamped artifact, or findings to the human and NO stamp                |
| **Artifacts**    | `<state>/round-N.sha` per round · `<state>/receipt.txt` · the stamp               |
| **Verification** | `skills/_tools/polish-fixpoint.sh` (the gate) · `polish-fixpoint.test.sh` (its proof) |

## Mode selects a workflow — load it, then run the loop below

The argument picks ONE workflow file. It is a mandatory load, and it is the ONLY place a mode
differs. Do not infer a mode's bindings from this file.

| mode | workflow (mandatory) | checklist (mandatory) |
| --- | --- | --- |
| `plan` | `workflows/plan.md` | `references/plan-checklist.md` |
| `bead` | `workflows/bead.md` | `references/bead-checklist.md` |
| `code` | `workflows/code.md` | `references/code-checklist.md` |

Each workflow binds exactly five knobs — TARGET, ARTIFACT, CHECKLIST, VALIDATE, STAMP — and
names its hand-off. Nothing else about a mode exists. Doctrine: `skills/ac2-pipeline/SKILL.md`.

## Division of labour — strict, and the reason this works

**This SKILL spawns the readers. `polish-fixpoint.sh` spawns nothing.** The script measures the
diff and gates the stamp; it never reads the artifact for meaning and never decides what a
finding is. A loop that grades itself always finds itself clean, so the measurement is kept
outside the thing being measured.

## The round procedure — ONE procedure, ALL modes

There is no second round path for any mode. Adding one ends the property this skill exists for.

```
MODE=plan|bead|code   TARGET·ARTIFACT·CHECKLIST·VALIDATE·STAMP = from the workflow
STATE=<run-scoped dir>   MAX=25 (0=off)

for ROUND in 1..:
  PRE = sha256(ARTIFACT)                      # observed BEFORE the reader runs
  spawn a FRESH, STATELESS reader for this round:
      input  = ARTIFACT + CHECKLIST
      output = findings, severity-gated by the CHECKLIST
      it carries NO memory of any earlier round
  apply this round's findings to ARTIFACT
  VALIDATE — the mode's validity gate. Red means the round is NOT recorded: revert or fix.
  polish-fixpoint.sh --mode $MODE --target $TARGET --artifact $ARTIFACT \
                     --state $STATE --round $ROUND --pre $PRE --max-rounds $MAX
  case the verdict token:
    STAMPED   -> done; go to the workflow's hand-off
    CONTINUE  -> next round
    REFUSED round-1-clean   -> next round (a clean first round proves nothing)
    REFUSED bound-exhausted -> STOP: findings to the human, NO stamp
    ENDED cycling -> STOP: readers reverting each other; findings to the human, NO stamp
    ENDED out-of-band-amendment -> STOP: the input moved; restart on a frozen input
    NOT-GATED -> STOP: nothing was measured, so nothing is claimed
```

**FRESH CONTEXT EVERY ROUND.** The reader is stateless and spawned per round. A reader that
has already read the artifact is not a second opinion.

**SEVERITY GATE.** The CHECKLIST names its three classes and they are the only reportable
findings. Not style, not preference, not wording. A round that reports style is a round that
did not read for defects.

**FIXPOINT = ZERO CHANGES AT ROUND >= 2.** A clean round 1 is equally consistent with a clean
artifact and a reader that read nothing, so it never stamps.

**RUN UNTIL IT CONVERGES.** Three rounds or ten — the loop ends on a MEASURED verdict, never a
round quota. `--max-rounds` is a runaway guard only (default 25, `0` disables). No clean round
means NO STAMP. Cycling or routine exhaustion indicts the CHECKLIST, not the artifact.

**FROZEN INPUT.** An out-of-band amendment ENDS the loop; it never extends it. That is what
the `--pre` digest detects, and it is why a polish run cannot chase a moving target.

## Telemetry

`rounds-to-fixpoint` is a BUDGETED metric: report it into the batch rollup with the mode and
the final verdict token. The trajectory is the signal; a single run's round count is not.
