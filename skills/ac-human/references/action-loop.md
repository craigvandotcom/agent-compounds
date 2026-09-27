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
  On tap (either path) → record + execute + close + **confirm the ripple**, then auto-advance.
  - **Ruling that changes a refined bead's scope — same step, never a separate pass:** when
    the recorded ruling changes the scope of a bead that holds `refined` (the ruled bead
    itself, or a bead it gates), in the SAME step rewrite that bead's title and ACs to the
    ruled option and strip `refined` (remove `refined`, add `unrefined`) so a polish pass
    re-grades the rewritten text before any claim. Stripping alone is enough when there is
    no time to rewrite. Never leave `refined` on a bead whose text the ruling contradicts.
    `skills/_tools/stamp-refined.sh`'s ruling-staleness leg backstops a ruling recorded ON
    the refined bead itself — refusing and downgrading when the ruling is newer than the
    last polish receipt — but a ruling recorded on a separate DECISION card leaves no
    comment on the beads it gates, so for those this rewrite-or-strip step is the only guard.
  `<human>` is copied VERBATIM from the closing board's own `.beads/config.yaml` `humans:`
  key (`beads-standards/reference/bead-conventions.md` § Decision beads is the sole
  restatement) — never a role name, never typed from memory:
  ```bash
  br comments add <id> "DECISION (<human>): <choice> — <why>"
  # ...carry out consequences...
  # Resolve close-gate.sh consumer-first: `.claude/skills/...` is where deploy.sh symlinks
  # it into every app; `skills/...` (this registry and one other app that carries it
  # natively) is the fallback.
  CLOSE_GATE=".claude/skills/ac-implement/scripts/close-gate.sh"
  [ -f "$CLOSE_GATE" ] || CLOSE_GATE="skills/ac-implement/scripts/close-gate.sh"
  "$CLOSE_GATE" <id> --reason "<what was decided/done>"
  br sync --flush-only && git add .beads/issues.jsonl \
    && git commit -m "chore(beads): human ruling on <id> [no-bead]" && git push
  ```
  **Commit the ledger on the same tap that records the ruling** — an uncommitted ledger is not a durable decision, and a later job reading `origin/main` will overwrite it (`beads-standards` § Working cadence). Push failure is not a stall: the local commit is durable, report it and carry on.
  Report: `✓ closed bd-<id> — unblocked bd-<x>, bd-<y>`.
  **Upstream is the real fix:** decision beads should *arrive* pre-staged. If a filer keeps shipping bare decisions, fix the filer, not just the symptom here.
- **🔴 Proposal (`pipeline-proposal` / `dream-proposal`):** Apply → invoke the owning skill's INTERACTIVE flow; its own gate re-confirms the moves against the *current* board — intended, never bypass it — then set the proposal `status: applied` and close with the idiom above. Discard → `status: rejected` and close, no skill. A memo is an argument, not a finding.
- **🔴 Declared lane card — batch the unanimous:** `AskUserQuestion(question: "{lane}: {N} queued — {u} unanimous, {s} split", options: ["Accept all {u} unanimous (Recommended)", "Walk each one", "Skip"])`. Accept → for each `✓` member in order: record `DECISION (<human>): accept — <its recommendation> (unanimous batch)`, close through `close-gate.sh`; **stop at the first failure** and report it. Commit the ledger once after the batch, then walk the split members one tap each.
- **🔴 Lane, ELEVATED — auto-advance INTO the sitting:** a first-class item right after its own itemized P0/P1s: `AskUserQuestion(question: "{lane}: {N} queued (oldest {age}). Work it now?", options: ["Work it now (Recommended)", "Work the top {n} only", "Skip"])`.
- **🧰 Friction** (one per entry, after 🔴): show the entry and its `fix:`, then `AskUserQuestion`: Promote / Won't fix / Later. Promote → file one `skill-improvement` bead carrying the proposed fix (`/ac-backlog` single-bead intake), then set the entry `status: promoted` in its ledger. Won't fix → `status: wontfix`. Later → no write. Ledgers are local-only; never commit them.
- **🧠 Memory** (one per row, after 🧰): draft the concrete edit — merged note, archive move, corrected path — and show the diff, then `AskUserQuestion`: Apply / Keep / Later. Apply → write it through `context-engineering`'s conventions and commit in the owning repo. Keep → stamp `verified_against: <owning repo's HEAD sha>` (memory-lint reads a git sha, never a date) so it stops resurfacing. Later → no write.
- **🔴 PRs — batch the trivial:** dependabot/grouped bumps → ONE prompt ("Merge the N green dependabot PRs?"), not N. Substantive PRs → one each.
- **🔴 CI / prod:** summarize the failure in a line, then `AskUserQuestion`: "Investigate now / File a bead / Skip."
- **🟡 Plan** (`status: draft` · `status: refined` · an `approved` plan a regate check refused): `AskUserQuestion`: "Continue planning? `/ac-plan {path}`." Continue → run `/ac-plan {path}` in this session; it resumes at the right step by the plan's own keys — a `refined` plan (ac-beadify's needs-human refusal) resumes at final approval the same way (Decision 4: one approval path). Skip → leave it queued. Approval and readying live inside ac-plan's own procedure now — this tap only ever offers to continue it.
- **🟢 Hopper** (only once 🔴/🟡 are clear, or the human jumps here): `AskUserQuestion` to pick which `active/` item to plan (→ `/ac-plan`), approve/discard a triage candidate, or promote the pool (→ `/ac-align`).

## Session mechanics

**Approve-then-diff capture:** when a decision or plan approval follows the human first editing/correcting the deliverable, diff drafted vs kept *before* closing and hand it to `reflect` as a lesson candidate — the cheapest high-signal capture in the session.

**Auto-advance:** after each action, confirm the result + ripple + `{N} remaining`, then immediately present the next most-urgent item — never re-render the whole dashboard mid-flow, never offer a subset picker. Stop only when the human picks "Done" or every tier is empty.

**Migration duty:** any human-pending item found in a legacy file scan (e.g. `_backlog-manual/`, plan `needs-approval`) that is NOT yet a bead → convert to a `human-gate` bead (`-t decision` for choices, `-t task` for manual actions) so the docket stays the system of record. File scans are a safety net, not the source of truth.
