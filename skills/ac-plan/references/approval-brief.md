# approval-brief.md — the one-screen brief ac-plan and the ac-human plan tap render

`ac-plan/SKILL.md` step 8 (approval) and `ac-human/references/action-loop.md`'s 🟡 Plan tap
both render THIS shape from the same plan file — one producer, two callers, never two texts
for one decision. OUT: the `AskUserQuestion` wiring itself (a separate bead); this file is
only what the brief contains and where each line comes from.

**If the brief does not fit one screen, the plan is too big — never the brief too short.** A
brief that needs scrolling to show what approval commits to has already lost the human's
attention before the question is asked.

## What approval commits to

The human sees this brief, taps once, and that tap is the whole gate: it commits to the
Silver Bullet and every Done when line shown here, and the plan's beads get cut and
implemented with no further contact — unless a later polish round moves a section the
approval digest covers (`plan-approve.sh ready` then reports `regate <sections>` and the
changed sections come back for a one-tap re-approve). Saying so, in these words, on the brief
itself, is what makes the tap informed rather than a formality.

## The eight lines, and where each is read from

| line | source | rule |
| --- | --- | --- |
| what changes | `## Vision` | two lines, plain prose — never the raw section, which may run long |
| deliverables | `## Deliverables` | as paths, one per line, each with its Done when: line — concrete values, what goes in and what comes out; an artifact, never an intention. A path with no Done when renders "no Done when" |
| silver bullet | `## Success criterion` | the Silver Bullet: the one command and its expected result. The pasted failing output stays in the plan. A missing command renders "no silver bullet" |
| seams + tests | `## Seams` | rows whose disposition is not `no seam`, ordered by toucher count (highest first); a `must update` test row renders beside its object, not in a separate list |
| biggest risk | `## Risk + sequence` | the risk plus the assumption it rests on — one pair, not the whole risk list |
| open cards | `## Decisions` | every card still `needs-human`, question + recommended option + its default tag (`[default: <option>]` or `[no default]`, read from the card — a design question with a default is not a vision question with none); a plan with none renders "none open" |
| improvements | agent-proposed, opt-in | up to two items beyond or short of the ask (`decisions.md` § Improvements), each one line, each declined by default until the human opts in |
| commits-to line | this file, verbatim sense | what approval commits to (above) — the brief always ends here |

A line with nothing to show renders its own absence ("no open cards", "no improvements
offered") — it is never dropped silently, because a dropped line and an empty one read the
same to a human skimming for what is missing.

## Seams rows on the brief

`## Seams` rows carry an object, a finding and a disposition (`→ D<n>` · `→ Out of scope` ·
`→ bead`). The brief drops every row whose disposition is `no seam` — those rows exist so the
seams scan can show its own completeness, not because the human needs to see them — and
orders what remains by toucher count, heaviest object first, so the biggest blast radius is
the first thing read. A test row (`unchanged` · `must update` · `none exists`) renders beside
the object it tests, never pulled into a separate section: "what breaks" and "what proves it
still works" belong on one line.

## Skeleton

```markdown
## Approve <plan-slug>?

**Plan:** <plan-path> — the file, open it any time; the question below never stands in for it.

**What changes:** <two lines from ## Vision>

**Deliverables:**
- <path> — Done when: <what goes in → what comes out, with concrete values>
- <path> — Done when: <what goes in → what comes out, with concrete values>

**Silver Bullet:** `<command>` — expected: <result>

**Seams + tests** (ordered by toucher count, `no seam` rows dropped):
- <object> — <finding> → <disposition> · tests: <unchanged | must update | none exists>

**Biggest risk:** <risk> — rests on: <assumption>

**Open decisions:** <question — recommended: option [default: option] | [no default]> | "none open"

**Opt-in (beyond or short of the ask):**
- <improvement or trade, one line>
- <improvement or trade, one line>
| "none offered"

**Approving commits to:** the Silver Bullet and every Done when line above — then beads cut
and implemented with no further contact, unless a later polish round changes a gated section —
then only the changed sections come back for a re-approve.

**Approve / Change / Park / Show me the plan** — Show me the plan prints the whole plan
file and re-asks; Approve is never taken sight-unseen.
```
