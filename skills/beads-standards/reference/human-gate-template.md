# Human-gate template — full copy-paste + worked example

The decision-card shape is the whole point: it makes the bead a *sufficient
statistic* for the decision — everything Craig needs to decide in 15 seconds is on
the card, nothing requires opening a chat log or a plan doc to reconstruct.

## ToC
- Creation
- Parentage at creation (Arm 0)
- Mandatory dependency wiring
- Worked example
- ACTION cards (do-in-the-world tasks)
- Closing a human-gate bead

## Creation

```bash
br create -t decision --labels human-gate \
  --parent <spawning-epic-id> \
  --title "DECISION: <the fork, in one line>" \
  -d "$(cat <<'EOF'
decision: <one-sentence question>
Gate-reason: fork — <why this is a genuine fork only Craig can resolve>

options:
  a) <option A> — <one-line tradeoff>
  b) <option B> — <one-line tradeoff>
  c) <option C, if there is one> — <one-line tradeoff>

context: <why this fork exists now — background the reader needs, kept to a
paragraph or two; link a plan/audit doc for anything longer>
EOF
)"
```

`br create -t decision` matches the type table in `beads-standards/reference/bead-conventions.md`
(`decision` = a fork only the human can resolve — taste, product, money, risk).
`HUMAN:` is the alternative prefix for a gate that isn't shaped as a decision fork
(an approval, a credential handoff, a "go/no-go") — same fields, same wiring rule.

## Parentage at creation (Arm 0)

A human-gate bead sets its **parent = the epic whose work spawned the fork**, at creation
time — the `--parent <spawning-epic-id>` above. This is Arm 0, the ONE place parentage is
ENFORCED rather than conventional: human-gate/DECISION beads bypass both `ac-bead-refine`'s
adopt-a-parent step and `ac-tidy`'s parentage flag (agents may enrich but never process a
human-gate bead), so parentage that is conventional everywhere else must be wired here, at
the one moment an agent creates the bead. This sits ALONGSIDE the mandatory `blocks`-edge
wiring below — both, not either. A fork with no spawning epic (a genuinely standalone
decision) simply records its origin in the card's `context:` field — no disposition
grammar, no synthetic parent.

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
  --parent <move-free-reminders-epic-id> \
  --title "DECISION: push notification provider for Move Free" \
  -d "$(cat <<'EOF'
decision: Which push-notification provider do we standardize on for Move Free's
reminder system?
Gate-reason: fork — provider choice is a product/risk fork only Craig can resolve

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

## ACTION cards (do-in-the-world tasks)

Some human beads aren't forks — they're a task only Craig can perform (a console
toggle, a store submission, a credential handoff). Same `human-gate` label (still the
sole gate label — no new `-gate` variant), different **title prefix** (`ACTION:`) and a
checklist body instead of options. No options block: an action card is a *do-this*, not
a *choose-between*.

```bash
br create -t task --labels human-gate \
  --title "ACTION: <the action, one line>" \
  -d "$(cat <<'EOF'
Gate-reason: authorization — <why this needs Craig's authorization>
what:            <the action, one line>
where:           <the exact surface — console / app / URL / menu path>
checklist:
  - <ordered step 1>
  - <ordered step 2>
estimated-time:  <rough wall-clock — "2 min", "15 min">
best-done-when:  <ridealong hint — e.g. "on the next ASC version submission">
EOF
)"
```

`-t task` (not `-t decision`) — an action has no fork to record; its closure is "done",
not "decided". The `best-done-when` field is the ridealong hint that lets a sit-down
session batch the action against the moment it naturally belongs to.

### Capture that needs a PLAN is an ACTION card

Work too large or too consequential to implement directly — a model rework, an
architecture change, anything where inventing the design inside a ticket is the wrong
shape — files as an `ACTION:` card, never an agent bead.

The action is *kick off the planning chain*: `ac-plan-init` → refine → approve →
`ac-beadify`. Put the analysis already done in the body as the brief. Close the card when
the plan is beadified.

Do not file it as a task bead and do not start planning unprompted. The "this needs a
plan" judgement belongs in the human session, not buried in a backlog nobody can pick up.

### Worked example (modelled on BCA bd-l6khg.13)

```bash
br create -t task --labels human-gate \
  --title "ACTION: configure the ASC intro-offer for Body Compass" \
  -d "$(cat <<'EOF'
Gate-reason: authorization — ASC console toggle only Craig can perform
what: Set up the introductory offer (7-day free trial) on the Body Compass
subscription in App Store Connect so it ships with the next version.

where: App Store Connect → Body Compass → Subscriptions → <group> → the monthly
product → Introductory Offers.

checklist:
  - Create a new introductory offer on the monthly subscription
  - Type: Free trial, duration 1 week, all territories
  - Attach it to the version currently in "Prepare for Submission"
  - Confirm the offer shows as "Ready to Submit" alongside the build

estimated-time: 10 min
best-done-when: on the next ASC version submission (the offer must ride a version —
it cannot ship standalone).
EOF
)"
# -> prints e.g. bd-l6khg.13

br dep add bd-l6khg.13 <version-submission-bead-id>   # wire it to the ride it depends on
```

The action rides the version-submission bead: `best-done-when` records the timing
constraint in prose, and the `blocks` edge makes it mechanical — the docket surfaces the
action beside the submission it must accompany.

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
