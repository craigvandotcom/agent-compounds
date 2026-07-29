---
skill: ac-implement
created: 2026-07-29
last_pass: 2026-07-29
entries: 2
---

# ac-implement — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

## unverified-causal-story-in-review-finding
- skills: [ac-implement]
- impact: M
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: 2026-07-29
- last_seen: 2026-07-29
- stage: ac-loop
- status: open
- proposed_fix: treat a review panel's causal explanation as a hypothesis, not a finding — verify the mechanism (read the actual emission order/code path) before writing the test that asserts it.
- narrative: a bead's causal story — that the parent wins a map slot — was refuted by a 2-line const (`foodLevels` ordering) once the implementer actually read the emission order before writing the test. Verifying the mechanism first turned a would-be vacuous AC (asserting the reviewers' wrong explanation) into an honest retention assertion plus a real regression guard. Cost ~10 minutes to check; would have cost a wrong test otherwise.

## conductor-direct-close-skips-result-file-artifact
- skills: [ac-implement]
- impact: L
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: 2026-07-29
- last_seen: 2026-07-29
- stage: ac-loop
- status: open
- proposed_fix: require a per-bead engineer result file (or an explicit, stated mechanical-only justification) before a conductor-direct close of a CODE bead.
- narrative: the per-bead engineer result-file artifact contract is not enforced when a code bead is closed conductor-direct. One batch (webui) shipped 4 non-trivial code beads with ZERO engineer result files — including a 133-line new-behaviour bead that does not obviously meet the conductor-direct mechanical-only criteria. This degrades the retrospective's ability to verify RED-proof and skill-routing compliance for a quarter of the run's beads.
