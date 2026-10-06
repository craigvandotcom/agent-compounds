---
status: captured
type: chore
size: M
horizon: next
source: human
dependencies: []
---

# Readiness audit — a user who syncs main and re-polishes every open bead gets a clean run

One-line intent: before anyone else runs the factory, prove the bead canon matches the tools as
shipped, and hand them one short checklist of what to run after syncing.

Deliverable: one short checklist for other users. Origin: step 6 of
`_plans/_done/2026-09-27-handoff-bead-quality.md` (steps 1–4 delivered; retired 2026-10-07).

## Check at least

- [ ] Bead canon (beads-standards, bead-schema, bead-checklist, ac-polish bead workflow) matches the
      shipped tools: stored touchers counts gone, bare-filename derive + shared-basename fix,
      `bead.py` as the one reader, the `device` label.
- [ ] Re-polishing an old bead converges: touchers lines re-derive cleanly, no `→ N` counts, no gate
      false positives (prod-write prose, dot-leading paths like `.husky/pre-push`).
- [ ] Beadify's supersedes close runs through close-gate (it used plain `br close` — lint 35 rule 6
      red), and its filing works when the capture guard blocks a subagent's `br create`.
- [ ] Whole-suite probes stay under flight-check's 120s probe limit; xcodebuild probes vs
      `bead.py`'s 60s per-probe timeout (needs a per-tier budget?).
- [ ] `bead.py check <file>` reads a Consumes blocker from the BOARD even when it is a sibling in the
      same polish artifact, so a Consumes fix cannot go GREEN before writeback.
- [ ] stamp-refined's downgrade leaves `human-gate` + `unrefined` together, which the schema forbids —
      **live 2026-10-07: ac-tv83.15, ac-vlje.20**.
- [ ] Schema says a human-gate card is "never `device`", yet stamp-refined refuses a `DEVICE VERDICT`
      probe without it.
- [ ] No nightly re-stamp sweep: `refined` drifts between stamp and claim (stamp-refined over every
      refined bead in ac-tidy's heartbeat?).
- [ ] A polish receipt is not tied to the body it certified: a hand `br update` after fixpoint keeps
      `refined` — should the receipt carry a body digest that stamp-refined compares?
- [ ] Agent Mail product link across agent-compounds + the apps, plus a rule: a shared-tool refusal
      messages agent-compounds' conductor before escalating to a human.
- [ ] What each user runs after syncing (`engine/sync.sh`, `deploy.sh --agents all`, `machine.json`).
