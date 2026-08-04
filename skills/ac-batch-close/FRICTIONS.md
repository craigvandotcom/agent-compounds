---
skill: ac-batch-close
created: 2026-07-22
last_pass: 2026-08-04
entries: 4
---

# ac-batch-close — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

## per-child-usage-never-reaches-the-ceremony
- skills: [ac-batch-close, ac-loop]
- impact: M
- frequency: every-run
- recurrence: 3
- related: [delegated-close-child-cannot-satisfy-the-identity-and-slot-mandate]
- first_seen: 2026-07-22
- last_seen: 2026-08-04
- stage: ac-batch-close
- status: open
- proposed_fix: the conductor must carry each child's task-completion usage line (model + token counts) into the batch-close delegation prompt, since that is the only place the data exists. Alternatively, drop the cost section from the ceremony report and let a separate harness-level collector own it — but do not leave a mandated report section that is structurally unfillable.
- narrative: the batch-close ceremony report has a cost/usage section, but per-child model and token usage is never forwarded into the batch-close delegation, and a child cannot observe its OWN usage from inside its run. The section is therefore impossible to fill honestly by any agent in the chain — the ceremony either leaves it blank or invents numbers. Observed on all 3 batch-closes of RUN 20260722-085844-39967. This is a pipeline-contract gap, not a child failure.
  **RUN 20260803-113231-34132, +1 — root cause named.** A closing child recorded the Worker-cost line as UNAVAILABLE rather than estimating it (the right call), and in doing so identified WHY the section is unfillable: the skill is written as though batch-close runs AS the conductor, but per-child token usage arrives only in the conductor's task-completion notifications, and this ceremony ran as a delegated child. So the section is not merely un-forwarded data — it is a VANTAGE mismatch baked into the skill's assumed execution position. That reframing picks a winner between the two fixes proposed above: forwarding the usage lines into the delegation prompt works precisely because the conductor is the only agent that ever holds them. Same root as `delegated-close-child-cannot-satisfy-the-identity-and-slot-mandate` — the skill assumes conductor vantage in more than one place.
  **RUN 20260803-221658-19787, +3 (third consecutive run) — recorded verbatim again from the delegated vantage, which is now the DEFAULT rather than an edge case.** The combined ceremony over five batches again could not fill Worker-cost, and again correctly recorded it as unfillable rather than estimating. Three runs is enough to stop treating this as a data-plumbing oversight: the ceremony has run delegated in every recent loop, so a section that is only fillable from the conductor's seat is unfillable in practice, and the skill's mandated report shape has been wrong-by-default for three runs while every closer independently re-derives the same "UNAVAILABLE" conclusion. Impact raised S→M on that basis — the per-run cost is still small, but a mandatory section that no correct execution can satisfy trains closers to treat mandated sections as advisory, which is the expensive part and does not stay local to this field. The fix choice is unchanged and already picked by the previous entry (forward the per-child usage lines into the delegation prompt, since the conductor is the only agent that ever holds them); this run adds only that the alternative — deleting the section — is now equally defensible and cheaper, because three runs of "UNAVAILABLE" is the same information as no section at all.

## delegated-close-child-cannot-satisfy-the-identity-and-slot-mandate
- skills: [ac-batch-close, ac-loop]
- impact: M
- frequency: every-run
- recurrence: 3
- related: [per-child-usage-never-reaches-the-ceremony]
- first_seen: 2026-08-03
- last_seen: 2026-08-03
- stage: ac-loop
- status: open
- proposed_fix: reconcile the skill with the loop's child-preamble on WHO owns identity for a spawned close child — state that when batch-close runs delegated, the Tier-1 identity mint and the advisory build slot are the CONDUCTOR's (already held), the child inherits the handed AGENT_NAME, and the `origin/main == HEAD` assertion is the operative protection. Written as a documented delegated shape, not as a skipped step.
- narrative: three occurrences across two ceremonies in one run, all the same root. ac-batch-close mandates a Tier-1 identity mint plus an advisory build-slot acquisition at Act 0, but a delegated child (a) is handed a fixed AGENT_NAME by the conductor, (b) holds no registration_token, so there is nothing to acquire a slot WITH, and (c) runs under an environment contract that assigns file reservations to the conductor in the first place. Every child therefore SKIPPED the mandate — correctly, and at zero cost, since the skill itself names `origin/main == HEAD` as the real protection. The friction is that a correct execution has to silently no-op a MANDATORY step and hope that reads as expected rather than as a compliance failure: the doctrine and the loop's own child-preamble disagree, and the child is left adjudicating between them mid-ceremony.

## findings-filed-after-the-report-force-a-second-commit
- skills: [ac-batch-close]
- impact: S
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: 2026-08-03
- last_seen: 2026-08-03
- stage: ac-loop
- status: open
- proposed_fix: file every known-actionable finding BEFORE writing the ceremony report — the report cites bead IDs, so any bead minted after it is written cannot be referenced without amending or re-committing it. Ordering, not extra work.
- narrative: a closing child discovered a real defect during Act 1, wrote the ceremony report, and only then filed the bead — so the report needed a SECOND commit purely to cite the ID it had just created. Cost one extra commit. Trivial per occurrence, but it is a pure sequencing defect with a free fix: the finding was already known when the report was being drafted, and nothing about Act 3 requires the report to be written first.

## needs-decision-has-no-deferred-with-reasoning-escape
- skills: [ac-batch-close]
- impact: S
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: 2026-07-31
- last_seen: 2026-07-31
- stage: ac-loop
- status: open
- proposed_fix: introduce a NEEDS_DECISION sub-grade (open-Critical vs deliberate-deferral) so the gate can decide for itself instead of needing a human/conductor override.
- narrative: the skill says NEEDS_DECISION -> STOP unconditionally, with no expressed escape for "deferred-with-reasoning, no open Critical". The conductor had to override it in the delegation prompt to proceed. Cost was zero this run because the conductor overrode in-prompt, but the gate itself cannot make this call without that override.
