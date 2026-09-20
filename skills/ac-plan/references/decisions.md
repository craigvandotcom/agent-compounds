# decisions.md — the card shape ac-plan's `## Decisions` section uses

The spine (`skills/ac-plan/SKILL.md`'s Procedure) points here. This file holds the shape; the
canon it defers to stays where it lives.

## The card

Every fork the plan turns on, one card per fork. One card is a top-level bullet
plus its sub-bullets; `settled: <choice> — <why>` reads plain or bold;
`vision: "<quoted ## Vision line>"` sits anywhere in the card; `needs-human` is
the open token.

- **question** — the fork, in one line.
- **options** — each with its one-line tradeoff.
- **recommendation** — one line; a card with no recommendation is an unfinished analysis.
- **what settles it** — the query, measurement or test that distinguishes the options.
- **vision** — `vision: "<quoted ## Vision line>"` anywhere in the card, the `## Vision` line this card rests on. A settled
  card that cannot quote one is not a decision — it is an assumption about intent, and an
  assumption about intent is always a question: append it as a fresh `needs-human` card
  instead of settling it silently ("no vision line, no agent decision").
- **state** — `settled: <choice> — <why>`, plain or bold, or `needs-human`.

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

The agent may offer up to two opt-in lines alongside the plan — an improvement beyond the ask,
or a diet-pass trade short of it (a cut that loses something the agent still backs) — each one
line, each explicitly opt-in, surfaced in the same approval round as the Decisions cards
(`references/approval-brief.md`). An improvement is never folded into the plan's Deliverables
on the agent's own judgement; it is accepted only when the human opts in on the tap.
An accepted improvement appends one sentence to `## Vision`, so its card has a line to quote;
an accepted trade rewrites or removes the `## Vision` sentence it narrows.

## The live-human ask

When a human is present, batch every `needs-human` card into ONE AskUserQuestion round and
record each answer by rewriting the card's state line to `settled: <choice> — <why>`. An unattended run leaves them
`needs-human` for the docket — never invent an answer.

## The `Human gates:` line

The Risk + sequence section carries a `Human gates:` line naming every authorization gate
(store submit, PROD migration) so `ac-beadify` compiles them knowingly with `human-gate`,
`Gate-reason: authorization`, and the lifecycle note that their probes are a checklist for
the closer.
