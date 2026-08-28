# polish · plan mode

The loop is in `ac2-polish/SKILL.md` and is the same in every mode. This file supplies only
what plan mode binds, and it is a MANDATORY load for a plan run.

## Bindings

| knob | plan mode |
| --- | --- |
| **TARGET** | the plan's path |
| **ARTIFACT** | the plan file itself — the loop edits it in place |
| **CHECKLIST** | `references/plan-checklist.md` |
| **VALIDATE** | none — a plan has no executable form. Every round records. |
| **STAMP** | `polish-fixpoint.sh --mode plan` rewrites the plan's YAML frontmatter |

## The stamp is written by the script, never by hand

`polish_rounds`, `polish_fixpoint_sha256` and `polish_stamped_at` have exactly one writer.
Hand-editing any of the three forges a fixpoint that was never measured. Re-stamping replaces
the keys rather than appending, so a re-run cannot leave two contradictory records.

## The plan must be FROZEN for the whole run

The artifact is the deliverable and a human can open it mid-run. An edit from outside the loop
ENDS the run — restart on a frozen plan rather than extending over a moving one.

## Hand-off — a stamped plan with no beads is a dead end

END a STAMPED plan run by invoking `ac2-beadify` on the stamped plan, or by queueing that
hand-off explicitly with the human. Do not finish by reporting success and stopping.
