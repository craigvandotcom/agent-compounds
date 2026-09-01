---
name: ac-pipeline
disable-model-invocation: true
description: 'The pipeline CONSTITUTION + the operating contracts. Constitution: Invariants (hold at any model capability) + Calibrations (each naming the telemetry that retires it) — read before writing, tuning or reviewing any lean-pipeline skill or script. Triggers: "pipeline constitution", "pipeline invariants", "tune the pipeline", "ac-pipeline". Operating contracts: the owner-hosted runtime canons every ceremony consults live in references/ of this same skill (commit-discipline, delegation-contract, run-ledger, run-id, verification-gate, qa-shared, board-scan, risk/consensus/disposition, degraded-mode, shell-guardrails), and the deterministic gates live in scripts/ (beads-closed-gate, validate-qa-run, close-evidence-check, board-truth). NOT for RUNNING anything: one stage (that stage''s own skill), or a gate/script this skill merely hosts (the calling ceremony fires it).'
---

# ac-pipeline — the constitution + the operating contracts

Two sections, and the split IS the mechanism. **Invariants** hold at any model capability. **Calibrations**
are capability/tooling facts, each naming the telemetry that retires it — one that cannot is an Invariant in
disguise or a superstition, and is deleted either way. Every control is L-tagged at birth (L1
capability-compensation, decaying, carrying its retiring measurement · L2 verification · L3 intent); one
naming neither its failure nor its layer is DELETED, not demoted.

**Bounds — the anti-drift mechanism itself.** The constitution core (everything above the contracts note
below) stays ~<=90 lines; tuning is NET-ZERO — every addition swaps out a line. Overflow returns to the
plan's record or retires a Calibration; never a grown core. `references/` and `scripts/` of this skill are
NOT constitution overflow — they are the pre-existing owner-hosted operating contracts (§ below), cited
by the ceremonies that need them and carried outside the core's bound. The family budget is mechanical:
`scripts/ac-budget-check.sh` (lint Check 23) — family <=800 lines of SKILL.md across the lean corpus,
<=1,200 loaded; ac-review hosts the review stage but is a fat retained skill outside that cap arithmetic
(its diet is the no-net-growth ratchet, lint Check 14).

## Invariants

1. **Beads are memory + compiled intent, never a cache of the tree.** (L3) Prevents: perishable
   tree-state — file:line anchors, premises — decaying at a measured 100% base rate.
2. **Verify at the fresh moment: flight check at claim, causal probe at close.** (L2) Prevents:
   verification performed at refine time and already stale when the work starts.
3. **A close goes through a gate that can refuse; silence is never success.** (L2) Prevents:
   NOT-GATED greens. Sustained 0% refusal is an alarm, not a triumph.
4. **Specs get a checklist to fixpoint; code gets independent eyes. Depth by risk.** (L2) Prevents:
   committees reviewing prose while code correctness rests on the author's own self-audit.
5. **One engine per pattern; scripts, not scar prose.** (L3) Prevents: the consensus machine copied
   5x plus a mirror, and scars accumulating where a script belongs.
6. **Exhaust to the board (`discovered-from`) — discovered PRODUCT work only.** (L3) Process observations go to
   the family ledger; every finding writes its `VERDICT:` + catch-stage label even when fixed in-batch — the
   fix may be in-batch, the label never. Then land the plane. Prevents: self-beads (39% of the old board).
7. **Plan hard, then retire the plan — beads and this file are its only survivors.** (L3) Prevents: a
   second doctrine home drifting out of sync with the first.
8. **Every control names the failure it prevents AND its layer, or it is deleted.** (L3) L1 controls carry what
   retires them. Prevents: doctrine growing with no stopping rule (the old ac-pipeline doctrine: 413 lines
   + ~2.5k of canon — retired at the 2026-08-30 merge).
9. **A `refined` stamp is only as valid as the content it was stamped on; a content refusal strips it.** (L2)
   `stamp-refined.sh` is the sole writer AND the sole stripper: a bead whose ACs no longer clear the probe
   floor is downgraded to `unrefined` mechanically, never left looking ready. Prevents: beads stamped under
   a prior dialect reaching the worker pool with zero runnable probes and burning claim cycles (measured
   2026-08-30: three of the first four ready beads; swept 2026-08-31 across two boards).

Convention with no mechanical enforcer, claimed as nothing more: every pipeline commit names its failure.

## Calibrations

- **Model tiers.** (L1) Planning is where 85/15 says spend: ac-plan and every polish reader run OPUS-tier;
  workers sonnet; the post-batch reviewers run a DIFFERENT model from the workers — that different-model
  rule is the L2 core and survives tier convergence. *retires when:* telemetry shows rounds-to-clean
  equalizing across tiers.
- **Line guidance.** (L1) Per-file <=120 lines, target ~80 — guidance, not a lint tier; the family cap binds
  first (7 x 120 = 840 > 800). *retires when:* the loaded-path rollup shows the family cap binding alone.
- **Fresh-context polish mechanics.** (L1) The polish SKILL spawns a stateless severity-gated reader per round;
  polish-fixpoint.sh spawns nothing — it measures the diff and gates the stamp. Fixpoint = zero changes at round
  >=2; bound 5; no clean round = no stamp, findings to the human. Bead-polish runs PER-EPIC (~20x cost), and
  routine bound-exhaustion indicts the CHECKLIST, not the artifact. *retires when:* in-context rounds measure
  equal to fresh-context on rounds-to-fixpoint.
- **Post-compaction re-read.** (L1) After a compaction the worker re-reads worker.md + the current bead before
  continuing. *retires when:* post-compaction resumption measures reliable without it.
- **Receipt formats.** (L2) Every receipt body via `-f <file>` with an explicit `--actor`; `--reason` stays
  ASCII-short (measured silent failures); creation bodies use `-d "$(cat file)"` because `br create` REJECTS
  `-f` alongside a title. Identity: Agent Mail `macro_start_session` where the tools exist, else the
  `AGENT_NAME` env fallback — ONE identity signs `--actor` and the commit. *retires when:* the receipt tools
  take one uniform body flag and stop failing silently.
- **Ledger is harness-agnostic.** (L1) A plain run-scoped append-only progress file — never a harness task surface
  as system of record; UIs may mirror, never carry. *retires when:* a harness task API measures outage-proof.
- **Batch-boundary reads.** (L1) Derive from the committed `.beads/issues.jsonl`, never `br ready` alone
  (measured non-deterministic AND stabilizing on a wrong count). *retires when:* `br ready` returns a stable
  count across repeated calls on a fixed tree.
- **COORDINATOR.** (L1) BUILT — human ruling, Craig 2026-08-29. The pipeline runs as a SWARM by
  default (width 3, uncapped, until the qualifying beads are exhausted); width and cap are the
  human's call, not a telemetry threshold. The invoking session is always the coordinator and
  never a worker, at every width — one procedure, no mode branch. **The ruling OVERRIDES this
  Calibration's original trigger, and the trigger was not met:** the measured runs were dependency-bound (a serial chain that idled a second worker),
  never worker-count-bound. Recorded as an override rather than quietly deleted, so the next reader sees a
  decision and not a measurement. The coordinator owns the batch boundary, the CI and review
  trigger, the ledger and the telemetry rollup; a worker owns nothing but the bead in its hand.
  The throughput layer — spawn/replace, liveness, Agent Mail
  reservations, roster — MUST carry: register + introduce at spawn; reserve before touching
  territory, renew on long beads, release at close and VERIFY by re-listing; roster from Agent Mail registrations, not the spawn plan; mail at bead
  boundaries; live-session identity for reservation-holder comparison, never the static `AGENT_NAME` env (a
  static fallback shadowing session identity rejected the worker's OWN reservation, rec 5); liveness from `br
  coordination status`, never harness notifications, with non-disarming sweeps (a transient 5xx read as death
  disarmed one); release verification via the PLAIN release tool (force-release refuses any recently-active
  holder, guaranteed at sweep time); Agent Mail outage = retry next iteration plus a named terminal
  force-release owner (leak-to-TTL measured); and the SLB two-person rule (second-agent approval, signed
  receipt) for unattended destructive ops, which the human gate covers more strongly today. Canon:
  `skills/agent-mail/`. **Reservations are ADVISORY for code paths** — the server grants a path it simultaneously
  reports as conflicting, so `flock` and the `br` claim are the only real exclusion; reserve to signal siblings,
  never to believe you hold a lock. *retires when:* two tuning sessions measure width 3 returning no throughput
  over width 1, at which point the default width drops to 1 — the procedure is unchanged,
  because there is only one.
- **Task-size floor.** (L1) A trivial single-file change with no dependency structure bypasses the pipeline
  entirely — never ceremony for nits. *retires when:* the ledger shows bypassed nits arriving back as defects.

## The family ledger

`FRICTIONS.md` beside this file is the pipeline family's friction ledger — process observations
exhaust there, never to the board (Invariant 6). lint Check 22
(`scripts/ac-ledger-integrity.sh`) enforces the control <-> friction contract both directions.
The legacy ac-pipeline friction log retired with the old architecture lane at the 2026-08-30
merge; git history preserves it, and its cross-cutting entries' primaries live in
`_archive/skills/ac-loop/FRICTIONS.md`.

## Operating contracts and gates (owner-hosted here)

The pipeline's cross-skill contracts live in `references/` of THIS skill — the pipeline's own
behaviour shapes them, so the pipeline skill owns them. Workflow skills bind with one-liners +
`§` pointers (litmus: `skill-builder/references/structure-standard.md` § The workflow/domain
litmus):

`commit-discipline` (H7d git canon) · `delegation-contract` (child-spawn preamble +
bounded-wait) · `run-ledger` (ceremony resume anchor) · `run-id` (scratch-dir scoping +
prefixes) · `board-scan` (orient scans A–E) · `risk-classification` (panel/gate scaling
tiers) · `review-consensus` (consensus + conductor triage) · `ceremony-batching-pool`
(pool RMW + drain) · `disposition` (findings three-way rule + save-for-later) ·
`degraded-mode` (capability-starved runs) · `shell-guardrails` (dcg-safe write/delete
shapes) · `anti-patterns` (named failure modes) · `design-refs` (target-visual capture +
AC-path gate) · `assurance-declarations` (PROBE/SCHEDULE/MODE/ON-FAILURE contract).

`scripts/` hosts the deterministic gates, each with its own test file:
`beads-closed-gate.sh` · `board-truth.sh` · `validate-qa-run.sh` · `close-evidence-check.sh` ·
`claim-race-harness.sh`, plus gate fixture suites (`ci-gate-health`,
`preamble-anchor-audit`, `run-id-concurrent-dir`, `verification-gate-class`).
