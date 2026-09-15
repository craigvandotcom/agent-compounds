# polish · plan mode

The loop is in `ac-polish/SKILL.md` and is the same in every mode. This file supplies only
what plan mode binds, and it is a MANDATORY load for a plan run.

## Bindings

| knob | plan mode |
| --- | --- |
| **TARGET** | the plan's path |
| **ARTIFACT** | the plan file itself — the loop edits it in place |
| **CHECKLIST** | `references/plan-checklist.md` |
| **VALIDATE** | none — a plan has no executable form. Every round records. |
| **READERS** | ONE `coordinator` per round — the reader judges correctness, contradiction and unimplementability and applies its own edits, so it needs judgment tier AND the Edit tool; `references/reader-prompt.md` verbatim |
| **STAMP** | `polish-fixpoint.sh --mode plan` rewrites the plan's YAML frontmatter |
| **GATE** | after STAMPED, `plan-approve.sh ready <plan>` — the hand-off never invokes the next stage itself; see below |

## The stamp is written by the script, never by hand

`polish_rounds`, `polish_fixpoint_sha256` and `polish_stamped_at` have exactly one writer.
Hand-editing any of the three forges a fixpoint that was never measured. Re-stamping replaces
the keys rather than appending, so a re-run cannot leave two contradictory records.

## The plan must be FROZEN for the whole run

The artifact is the deliverable and a human can open it mid-run. An edit from outside the loop
ENDS the run — restart on a frozen plan rather than extending over a moving one.

## Hand-off — run the gate, then stop with a Next line

After STAMPED, run `plan-approve.sh ready <plan>`:

- **READY** — the approved sections did not move. End with `Next: /ac-beadify <path>` and stop.
- **REFUSED regate `<sections>`** — a gated section moved since approval. Attended: show the
  changed sections and offer re-approve (`plan-approve.sh approve <plan> [who]`), then run
  `ready` again. Unattended: stop; the plan stays at `status: approved` and ac-human's docket
  shows it waiting.
- **REFUSED not-approved** — the plan never passed approval. End with
  `Next: /ac-plan <path> (approval step)` and stop.

Never invoke `ac-beadify` directly from this hand-off — the gate decides, and every branch
ends by stopping with its own `Next:` line, not by running the next stage.
