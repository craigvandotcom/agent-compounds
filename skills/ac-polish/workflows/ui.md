# polish · ui mode

The loop is in `ac-polish/SKILL.md` and is the same in every mode. This file supplies only
what ui mode binds, and it is a MANDATORY load for a ui run.

UI mode is `code` mode's sibling — the artifact is the shipped UI, so a bad edit is a defect,
not an inert edit to a plan. It adds one axis code mode does not have: **every theme**. A fix
that is green in the theme you looked at and invisible in the other is the exact defect class
this mode exists to close (`ui-elevate/references/sensors.md` § Why this file exists).

## Bindings

| knob | ui mode |
| --- | --- |
| **TARGET** | the bead that owns the scope — UI carries no receipt of its own |
| **ARTIFACT** | `<STATE>/ui-artifact.txt` — `scripts/code-manifest.py` over the UI scope, plus one `sensors <sha256> <report>` line per sensor report |
| **CHECKLIST** | `references/ui-checklist.md` — the sensor questions, design.md token conformance, the a11y/compliance set |
| **VALIDATE** | tests green · build green · `ubs <changed-files>` clean · sensors green in EVERY theme |
| **STAMP** | `polish-fixpoint.sh --mode ui --target <bead-id>` writes the receipt to that bead |

## The artifact is a manifest plus the sensor digests

The loop edits real files in place. Build the artifact from the manifest and the sensor
reports, so fixpoint means **no file in scope changed AND no sensor report changed** this
round — a code fix with no sensor re-run is not a converged round:

```sh
scripts/code-manifest.py --out <STATE> --scope '<ui-scope>'
{ cat "<STATE>/manifest.txt"
  for r in <sensor-reports>; do printf 'sensors %s %s\n' "$(shasum -a 256 "$r" | awk '{print $1}')" "$r"; done
} > "<STATE>/ui-artifact.txt"
```

`code-manifest.py` fails closed: a scope that matches nothing writes no manifest, because a
short manifest drops files from every later round.

## SENSORS RUN BEFORE EYES, IN EVERY THEME

The sensors are the audit layer, not a nicety. Re-run all three (`sensors.md` Sensors 1–3) on
the round's routes **once per theme**, plus design.md token conformance, and write their
reports into `<STATE>`. A round whose sensor reports are absent, or cover one theme, is
NOT-GATED — not "clean". `unmeasurable === 0` is part of the contrast pass: a node whose paint
the parser cannot resolve is a loud fail, never a silent zero.

## VALIDATE gates the round, not the stamp

Apply the findings, then run tests, the build, `ubs` over the changed files, and the sensors in
every theme. Red on any leg means the round is NOT recorded: revert or fix it, then record.
`ubs` exit 0 counts only when `Files scanned` equals the number of files passed — a shortfall
is NOT-GATED, not a pass.

## The scope must be UNCLAIMED

A file an open bead owns is not this loop's to touch. Check every in-scope path against open
beads BEFORE round 1, matching on the directory as well as the full path.

## Own the scope for the whole run

Reserve the scope's paths through Agent Mail before round 1 and release them at the verdict.
The frozen-input guard fires on any edit from outside the loop — another session, a rebase,
or you in a second window all count.

## COMMIT ONLY ON CONVERGENCE — on the trunk

Work the scope in place on the trunk. Do NOT branch. Rounds are uncommitted working-tree edits;
commit NOTHING until the verdict, then ONE commit at STAMPED. A run that ends in cycling,
exhaustion or an out-of-band amendment commits NOTHING — restore the scope and hand the
findings to the human.

## Out of scope — on purpose

Taste, hierarchy, rhythm and "this feels premium" are `ui-elevate`'s rubric
(`reference/critique-polish.md`), not this checklist. This mode closes **correctness** findings
a command can name; a question with no oracle is DECLINED here and routed to the rubric or a bead.

## Hand-off

Report `rounds-to-fixpoint` with the verdict token and the per-theme sensor counts. Name any
finding the checklist could not settle with an oracle — that is a bead, not a polish round.
