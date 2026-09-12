# Action loop — per-item taps, recording, and ripple

Extracted from the spine 2026-09-12 (ac-1p7j.37). The spine carries the
drive rule (one item at a time, top of 🔴 downward, tap-not-type,
auto-advance, Done as escape); this file carries the per-type playbook.

## Per item type — present, then one tap

- **🔴 Decision (human-gate bead) — check the memo first:** a tap-able decision needs a *pre-staged memo* — context · options with trade-offs · a recommendation (the `-t decision` contract in `beads-standards/reference/bead-conventions.md`):
    - **Fork card incomplete — BOUNCE, never present:** a `DECISION:` card lacking any of `evidence:` / `consequence:` / `recommendation:` is refused at the tap — label `gate-incomplete`, comment naming the missing line, `human-gate` kept — and it renders `⚠ gate-incomplete`.
    - **Memo present** → show it in 2–4 lines, then put its **options as buttons**, recommendation first + `(Recommended)`:
      ```
      AskUserQuestion(question: "{decision title}", options: [{option A (Recommended)}, {B}, {C}, {Defer}, {Done}])
      ```
    - **Memo missing/thin** (a bare "HUMAN: decide X" with no options) → it is **not tap-ready; do NOT fake buttons.** Surface it as `⚠ no memo` and offer: `Frame it now` (research + write the memo onto the bead, then present options) / `Decide raw` / `Skip` / `Done`. The dashboard **self-heals** bare beads into tap-ready ones.
  On tap (either path) → record + execute + close + **confirm the ripple**, then auto-advance:
  ```bash
  br comments add <id> "DECISION (<human>): <choice> — <why>"
  # ...carry out consequences...
  br close <id> --reason "<what was decided/done>"
  br sync --flush-only && git add .beads/issues.jsonl \
    && git commit -m "chore(beads): human ruling on <id> [no-bead]" && git push
  ```
  **Commit the ledger on the same tap that records the ruling** — an uncommitted ledger is not a durable decision, and a later job reading `origin/main` will overwrite it (`beads-standards` § Working cadence). Push failure is not a stall: the local commit is durable, report it and carry on.
  Report: `✓ closed bd-<id> — unblocked bd-<x>, bd-<y>`.
  **Upstream is the real fix:** decision beads should *arrive* pre-staged. If a filer keeps shipping bare decisions, fix the filer, not just the symptom here.
- **🔴 Curator lane, ELEVATED — auto-advance INTO the sitting:** once the lane crosses the serving policy (`references/docket-lanes.md`), it is a first-class item, right after its own itemized P0/P1s. One tap: `AskUserQuestion(question: "Curator lane: {N} queued (oldest {age}). Run the supervised sitting?", options: ["Run it now (Recommended)", "Work the top {n} only", "Skip"])`. On tap → drive the supervised batch flow, then resume auto-advance.
- **🔴 PRs — batch the trivial:** dependabot/grouped bumps → ONE prompt ("Merge the N green dependabot PRs?"), not N. Substantive PRs → one each.
- **🔴 CI / prod:** summarize the failure in a line, then `AskUserQuestion`: "Investigate now / File a bead / Skip."
- **🟡 Plan:** show a tight summary (outcome · scope · top risk), then `AskUserQuestion`: "Approve → loop-ready / Send to refine / Skip." Approve writes any answer the human gave in the tap into the plan as `DECISION (<human>): …` before running `skills/_tools/plan-approve.sh <plan-path>` — the ONE writer of approval, never a hand edit of the frontmatter; the plan **leaves this view**. Refine → `/ac-polish {path}`.
- **🟢 Hopper** (only once 🔴/🟡 are clear, or the human jumps here): `AskUserQuestion` to pick which `active/` item to plan (→ `/ac-plan`), approve/discard a triage candidate, or promote the pool (→ `/ac-align`).

## Session mechanics

**Approve-then-diff capture:** when a decision or plan approval follows the human first editing/correcting the deliverable, diff drafted vs kept *before* closing and hand it to `reflect` as a lesson candidate — the cheapest high-signal capture in the session.

**Auto-advance:** after each action, confirm the result + ripple + `{N} remaining`, then immediately present the next most-urgent item — never re-render the whole dashboard mid-flow, never offer a subset picker. Stop only when the human picks "Done" or every tier is empty.

**Migration duty:** any human-pending item found in a legacy file scan (e.g. `_backlog-manual/`, plan `needs-approval`) that is NOT yet a bead → convert to a `human-gate` bead (`-t decision` for choices, `-t task` for manual actions) so the docket stays the system of record. File scans are a safety net, not the source of truth.
