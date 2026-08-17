# Filing bar — what the loop may put on the board

The loop's output is shipped code plus a SHORT list of things worth tracking. A run that
files forty items has moved triage onto the human, not off them.

## Two channels, never mixed

| Channel | Carries | Consumer |
|---|---|---|
| `friction:` block | **Machinery only** — pipeline, skill text, lint ratchets, bead schema, CI wrappers, test-harness ergonomics, tool-flag quirks, local-stack problems | conductor → run carrier → session report → skill/tooling fix |
| Product-findings list | **Product findings below the auto-file bar** (priority `2`-`4`) | conductor → session report → human promotes to a bead |
| The board | **Product `0`/`1` with a verified reproduction**, plus failed gates | `ac-bead-refine` → next wave |

A product finding NEVER goes in `friction:`. Frictions are for the machinery that builds the
product, not the product.

## The auto-file bar

The loop auto-files a bead only for:

1. A product defect at priority `0` or `1` (criteria: `beads-standards` § Status & priority canon).
2. A **gate that failed to catch product defects** — a silent gate makes every later green
   unreliable, so it is filed regardless of priority and tagged `gate-failure`.

Everything else is reported, not filed. Admin-surface defects are priority `2` by definition
and are therefore reported, never auto-filed.

## Three admission tests — all three, before any `br create`

**1. Reproduction.** Cite `file:line` re-read at the CURRENT HEAD, or a driven journey step
with its observed output. Banned in a filed claim: *may*, *likely*, *appears*, *probably*,
*seems*. A finding you cannot state as a fact is a finding you have not finished.

**2. Duplicate.** Grep the board for the subject first. If a sibling exists, enrich it and
name it — do not file alongside it. Two beads on one seam is one bead and one distraction.

**3. No-op.** Ask whether the bead could close with an empty diff. If it could, it describes a
state, not a defect.

## Reporting threshold

Past **10** auto-filed beads in a run, rank the remainder and report them instead of filing.
Hitting the threshold is a signal to triage at the source, not a quota to spend.

## Why this exists

One run filed 51 beads: 31% were machinery, 72% of the product ones landed at priority `2`
because no level had an admission test, and an adversarial audit found roughly a quarter were
duplicates, splits, or claims false at HEAD. The three tests above would have caught the false
and duplicate ones at the filing site for free.
