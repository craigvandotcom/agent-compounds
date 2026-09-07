# decisions.md — the card shape ac-plan's `## Decisions` section uses

The spine (`skills/ac-plan/SKILL.md` step 3) points here. This file holds the shape; the
canon it defers to stays where it lives.

## The card

Every fork the plan turns on, one card per fork:

- **question** — the fork, in one line.
- **options** — each with its one-line tradeoff.
- **recommendation** — one line; a card with no recommendation is an unfinished analysis.
- **what settles it** — the query, measurement or test that distinguishes the options.
- **state** — `settled: <choice> — <why>` or `needs-human`.

Before writing a card, run the escalation test
(`beads-standards/reference/human-gate-template.md` § The escalation test) — a fork a query
settles is research done now, not a card.

## The live-human ask (step 3b)

When a human is present, batch every `needs-human` card into ONE AskUserQuestion round and
record each answer as `DECISION (<human>): <choice> — <why>`. An unattended run leaves them
`needs-human` for the docket — never invent an answer.

## The `Human gates:` line

The Risk + sequence section carries a `Human gates:` line naming every authorization gate
(store submit, PROD migration) so `ac-beadify` compiles them knowingly with `human-gate`,
`Gate-reason: authorization`, and the lifecycle note that their probes are a checklist for
the closer.
