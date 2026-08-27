---
name: ac2-pipeline
description: 'The ac2 lean-pipeline CONSTITUTION — Invariants (hold at any model capability) + Calibrations (each naming the telemetry that retires it). Read before writing, tuning or reviewing any ac2-* skill or script. Triggers: "ac2 constitution", "ac2 invariants", "tune ac2", "ac2-pipeline". Not the legacy ac-* pipeline (that is ac-pipeline).'
---

# ac2-pipeline — the constitution

Two sections, and the split IS the mechanism. **Invariants** hold at any model capability. **Calibrations**
are capability/tooling facts, each naming the telemetry that retires it — one that cannot is an Invariant in
disguise or a superstition, and is deleted either way. Every control is L-tagged at birth (L1
capability-compensation, decaying, carrying its retiring measurement · L2 verification · L3 intent); one
naming neither its failure nor its layer is DELETED, not demoted.

**Bounds — the anti-drift mechanism itself.** <=80 lines. NEVER a `references/` or `scripts/` dir
(relocation-instead-of-reduction is the measured evasion: per-file caps "held" while references/ grew ~11x).
Tuning is NET-ZERO — every addition swaps out a line. Overflow returns to the plan's record or retires a
Calibration; never a subdirectory, never a raised bound. Family: <=800 lines of ac2-*/SKILL.md, <=1,200 loaded.

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
   retires them. Prevents: doctrine growing with no stopping rule (ac-pipeline: 413 lines + ~2.5k of canon).

Convention with no mechanical enforcer, claimed as nothing more: every ac2 commit names its failure.

## Calibrations

- **Model tiers.** (L1) Planning is where 85/15 says spend: ac2-plan and every polish reader run OPUS-tier;
  workers sonnet; ac2-review a DIFFERENT model from the workers — that different-model rule is the L2 core and
  survives tier convergence. *retires when:* telemetry shows rounds-to-clean equalizing across tiers.
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
- **DEFERRED COORDINATOR.** (L1) ac2 ships at N=1: the invoking session runs the worker prompt and owns batch
  boundary, CI + review trigger, the ledger and the telemetry rollup. The throughput layer — spawn/replace,
  liveness, Agent Mail reservations, roster — is BUILT ONLY when telemetry shows a measured throughput ceiling
  (a batch whose wall time is worker-count-bound, not gate-bound), never on anticipation. Its spec, when built,
  MUST carry: register + introduce at spawn; reserve before touching territory, renew on long beads, release at
  close and VERIFY by re-listing; roster from Agent Mail registrations, not the spawn plan; mail at bead
  boundaries; live-session identity for reservation-holder comparison, never the static `AGENT_NAME` env (a
  static fallback shadowing session identity rejected the worker's OWN reservation, rec 5); liveness from `br
  coordination status`, never harness notifications, with non-disarming sweeps (a transient 5xx read as death
  disarmed one); release verification via the PLAIN release tool (force-release refuses any recently-active
  holder, guaranteed at sweep time); Agent Mail outage = retry next iteration plus a named terminal
  force-release owner (leak-to-TTL measured); and the SLB two-person rule (second-agent approval, signed
  receipt) for unattended destructive ops, which the human gate covers more strongly today. Canon:
  `skills/agent-mail/`. *retires when:* the coordinator is built, or two tuning sessions measure no ceiling.
- **Task-size floor.** (L1) A trivial single-file change with no dependency structure bypasses ac2 entirely — never
  ceremony for nits. *retires when:* the ledger shows bypassed nits arriving back as defects.
