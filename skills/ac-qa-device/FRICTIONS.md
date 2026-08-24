---
skill: ac-qa-device
created: 2026-08-24
last_pass: 2026-08-24
entries: 1
---

# ac-qa-device — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     near-duplicate; bump recurrence and last_seen on the existing entry instead. -->

## a-pass-stamp-names-the-claim-not-the-artifact-it-measured
- skills: [ac-qa-device, ac-distribute]
- impact: H
- frequency: occasional
- perceptibility: silent
- recurrence: 1
- related: [ship-lane-consumes-local-generated-state-without-asserting-it-matches-the-manifest]
- first_seen: 2026-08-24
- last_seen: 2026-08-24
- stage: qa-device
- status: open
- proposed_fix: a PASS stamp records the identity of the artifact it drove — resolved dependency versions, commit, build number — and the run asserts that identity against the branch before it asserts anything about behaviour.
- narrative: a device-QA note recorded that its purpose was to discharge the runtime risk of a
  dependency bump, and in the same breath recorded the resolved pins it observed — which were
  the OLD version's pins. The run measured the pre-bump artifact and certified the post-bump
  one. Nothing in the stamp format made that contradiction visible, because the stamp carries
  the INTENT ("prove the bump") next to the MEASUREMENT, and a reader takes the intent as the
  subject. The bump then stood as proven for four days on evidence that disproved it.
  The failure is structural, not careless: QA drives whatever binary the lane hands it, so a
  stale build input silently changes the subject of every assertion in the run, and a stamp
  that names only the claim cannot detect that the subject moved. Both times this fired, the
  run itself was competently executed and its assertions were true — of the wrong artifact.
  A PASS is meaningless until the artifact under test is identified as strictly as the
  behaviour under test.
