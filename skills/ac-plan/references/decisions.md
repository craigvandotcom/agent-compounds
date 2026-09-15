# decisions.md — the card shape ac-plan's `## Decisions` section uses

The spine (`skills/ac-plan/SKILL.md`'s Procedure) points here. This file holds the shape; the
canon it defers to stays where it lives.

## The card

Every fork the plan turns on, one card per fork:

- **question** — the fork, in one line.
- **options** — each with its one-line tradeoff.
- **recommendation** — one line; a card with no recommendation is an unfinished analysis.
- **what settles it** — the query, measurement or test that distinguishes the options.
- **vision** — `vision: "<quoted line>"`, the `## Vision` line this card rests on. A settled
  card that cannot quote one is not a decision — it is an assumption about intent, and an
  assumption about intent is always a question: append it as a fresh `needs-human` card
  instead of settling it silently ("no vision line, no agent decision").
- **state** — `settled: <choice> — <why>` or `needs-human`.

Before writing a card, run the escalation test
(`beads-standards/reference/human-gate-template.md` § The escalation test) — a fork a query
settles is research done now, not a card.

**The plan-time bar.** A fork that shapes architecture, a new object, schema, interface or
dependency, or that changes the ask, is asked even when the agent already has a
recommendation — the escalation test's ordinary bar (would a competent human want to weigh
in) is not enough at plan time, because these are exactly the forks a later `regate` would
otherwise reopen after beads are already cut.

## The question shape

Every `needs-human` card reaches the human as one numbered item in the batched round, each
carrying its recommended answer — a card with options but no recommendation is not ready to
ask. Facts get looked up, never asked: if a query settles it, it is research done now, not a
question. Two defaults, and they are not the same default:

- a **design** question default-accepts on "go" — silence takes the recommendation.
- a **vision** question has no default — silence leaves it `needs-human`, because filling a
  gap in intent silently is the one thing an agent may never do.

## Improvements — opt-in, capped, never silent

The agent may offer up to two "beyond the ask" improvements alongside the plan — each one
line, each explicitly opt-in, surfaced in the same approval round as the Decisions cards
(`references/approval-brief.md`). An improvement is never folded into the plan's Deliverables
on the agent's own judgement; it is accepted only when the human opts in on the tap.

## The live-human ask

When a human is present, batch every `needs-human` card into ONE AskUserQuestion round and
record each answer as `DECISION (<human>): <choice> — <why>`. An unattended run leaves them
`needs-human` for the docket — never invent an answer.

## The `Human gates:` line

The Risk + sequence section carries a `Human gates:` line naming every authorization gate
(store submit, PROD migration) so `ac-beadify` compiles them knowingly with `human-gate`,
`Gate-reason: authorization`, and the lifecycle note that their probes are a checklist for
the closer.
