# polish · code mode

The loop is in `ac2-polish/SKILL.md` and is the same in every mode. This file supplies only
what code mode binds, and it is a MANDATORY load for a code run.

Code mode differs from plan and bead in one way that governs everything else: **the artifact
is the thing that ships.** A bad edit to a plan is inert. A bad edit here is a defect.

## Bindings

| knob | code mode |
| --- | --- |
| **TARGET** | the bead that owns the scope — code carries no receipt of its own |
| **ARTIFACT** | `scripts/code-manifest.py <scope>` — one `sha  path` line per in-scope file |
| **CHECKLIST** | `references/code-checklist.md` |
| **VALIDATE** | tests green · build green · `ubs <changed-files>` clean |
| **STAMP** | `polish-fixpoint.sh --mode code --target <bead-id>` writes the receipt to that bead |

## The manifest is the artifact — never a concatenation of the source

The loop edits real files in place. The gate measures a MANIFEST of their digests, so fixpoint
means "no file in scope changed this round". Round-tripping source through an exported blob
corrupts it; do not build one.

## VALIDATE gates the round, not the stamp

Apply the round's findings, then run the suite, the build, and `ubs` over the changed files.
A round that leaves any of them red is NOT recorded: revert it or fix it, then record. Without
this a run reaches "fixpoint" on a tree that does not compile.

`ubs` exit 0 counts only when `Files scanned` equals the number of files passed — it silently
drops file types it does not cover, and a shortfall is NOT-GATED, not a pass.

## Own the scope for the whole run

Reserve the scope's paths before round 1 and hold them to the verdict. The frozen-input guard
fires on any edit from outside the loop, and in a live tree that includes you, another session,
and a rebase.

## COMMIT ONLY ON CONVERGENCE

Checkpoint each round on a scratch branch so a dead session loses nothing. Squash to ONE commit
at the verdict, and merge only then. Every round left the tree green, so the commit is green by
construction. A run that ends in cycling, exhaustion or an out-of-band amendment merges
NOTHING — the branch is abandoned and the findings go to the human.

## Hand-off

Hand the converged branch to `ac-merge`. Report `rounds-to-fixpoint` with the verdict token,
and name any finding the checklist could not settle with an oracle — that is a bead, not a
polish round.
