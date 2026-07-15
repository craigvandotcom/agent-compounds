# Human-gate template — full copy-paste + worked example

The decision-card shape is the whole point: it makes the bead a *sufficient
statistic* for the decision — everything Craig needs to decide in 15 seconds is on
the card, nothing requires opening a chat log or a plan doc to reconstruct.

## Creation

```bash
br create -t decision --labels human-gate \
  --title "DECISION: <the fork, in one line>" \
  -d "$(cat <<'EOF'
decision: <one-sentence question>

options:
  a) <option A> — <one-line tradeoff>
  b) <option B> — <one-line tradeoff>
  c) <option C, if there is one> — <one-line tradeoff>

context: <why this fork exists now — background the reader needs, kept to a
paragraph or two; link a plan/audit doc for anything longer>
EOF
)"
```

`br create -t decision` matches the type table in `_shared/bead-conventions.md`
(`decision` = a fork only the human can resolve — taste, product, money, risk).
`HUMAN:` is the alternative prefix for a gate that isn't shaped as a decision fork
(an approval, a credential handoff, a "go/no-go") — same fields, same wiring rule.

## Mandatory dependency wiring

Every bead this decision is currently stalling gets a `blocks` edge back to the
decision **at creation time**, not deferred to a later triage pass:

```bash
br dep add <downstream-bead-id> <decision-bead-id>
# repeat for each bead the decision gates
```

If the decision spawns new downstream work later (a common Exhaust-Rule shape — an
autonomous run hits a genuine fork, stages the memo, and keeps moving on other
threads), wire the edge the moment the downstream bead is created, not retroactively
in a batch sweep. An un-wired human-gate bead is invisible to:

- `br ready` — can't exclude the gated subtree, so agents may pick up blocked work
- `bv --robot-next` — can't route around an undecided fork
- the cockpit's leverage metric — reads the gate as stalling nothing, when it may be
  stalling several beads (this was the actual state of 30/31 open human-gate beads
  before this rule: cockpit-mission-panel audit, 2026-07-15)

## Worked example

```bash
br create -t decision --labels human-gate \
  --title "DECISION: push notification provider for Move Free" \
  -d "$(cat <<'EOF'
decision: Which push-notification provider do we standardize on for Move Free's
reminder system?

options:
  a) OneSignal — free tier covers current scale, fastest to wire, but adds a
     third-party SDK to every native build
  b) Native APNs/FCM direct — no SDK dependency, more code to own, matches the
     "own your stack" preference from body-compass
  c) Defer entirely — ship Move Free v1 without push, revisit post-launch

context: Reminder system (bd-abc12) is blocked on this. body-compass shipped (b)
in 2026-03; Move Free's timeline is tighter so (a) may be the pragmatic call this
once. No cost data yet at Move Free's projected user count.
EOF
)"
# -> prints e.g. bd-mf9k1

br dep add bd-abc12 bd-mf9k1   # reminder-system bead now blocked on the decision
```

## Closing a human-gate bead

Agents may comment/enrich (add evidence, refine the options, flag urgency) but never
close. Closure requires a recorded human decision, then the agent executes the
consequences and closes:

```bash
br comments add bd-mf9k1 -m "DECISION (Craig): option (a), OneSignal. Free tier is
fine at this scale, revisit if we outgrow it."
# ... agent implements the consequence, then:
br close bd-mf9k1 -r "shipped: OneSignal wired per Craig's decision (see comments)"
```
