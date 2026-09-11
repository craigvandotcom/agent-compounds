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

### The state line is machine-read — keep the token first

`skills/_tools/plan-approve.sh` check 3 refuses approval while any card stands `needs-human`,
and it reads the state off the LINE. The contract is one rule: **inside `## Decisions`, a
card's state token is the first word on its line** — once a list marker, an optional `state`
label and markdown decoration (backticks, bold) are stripped. Both shapes in use satisfy it:

    - **state** — `needs-human`
    - **state** — `settled: keep the one engine — ADR 0007 § 3`
    `needs-human — already owned by bd-2mik, not re-decided here.`
    `settled: apps/model-gateway/ — its own deployable and image.`

Everything after the token is free prose, so a `settled:` card may discuss escalation by name
without tripping the gate. What DOES trip it is burying the token mid-sentence
(`this one is still needs-human`) — that line reads as prose to the gate and as an open card
to a human, which is the disagreement the gate exists to prevent. Lead with the token.

The gate is scoped to the `## Decisions` section, so the rest of the plan may use the words
freely. It fails closed: an ambiguous line refuses rather than approves.

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
