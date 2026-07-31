---
skill: ac-batch-close
created: 2026-07-22
last_pass: 2026-07-31
entries: 2
---

# ac-batch-close — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

## per-child-usage-never-reaches-the-ceremony
- skills: [ac-batch-close, ac-loop]
- impact: S
- frequency: every-run
- recurrence: 1
- related: []
- first_seen: 2026-07-22
- last_seen: 2026-07-22
- stage: ac-batch-close
- status: open
- proposed_fix: the conductor must carry each child's task-completion usage line (model + token counts) into the batch-close delegation prompt, since that is the only place the data exists. Alternatively, drop the cost section from the ceremony report and let a separate harness-level collector own it — but do not leave a mandated report section that is structurally unfillable.
- narrative: the batch-close ceremony report has a cost/usage section, but per-child model and token usage is never forwarded into the batch-close delegation, and a child cannot observe its OWN usage from inside its run. The section is therefore impossible to fill honestly by any agent in the chain — the ceremony either leaves it blank or invents numbers. Observed on all 3 batch-closes of RUN 20260722-085844-39967. This is a pipeline-contract gap, not a child failure.

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
