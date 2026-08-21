---
skill: ac-distribute
created: 2026-08-21
last_pass: 2026-08-21
entries: 1
---

# ac-distribute — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     near-duplicate; bump recurrence and last_seen on the existing entry instead. -->

## fastlane-release-lane-never-proven-end-to-end
- skills: [ac-distribute, ac-publish]
- impact: M
- frequency: per-release
- recurrence: 1
- related: []
- first_seen: 2026-08-12
- last_seen: 2026-08-21
- stage: distribute
- status: open
- proposed_fix: Prove the lane on the next real release rather than as a standalone exercise.
  Every local half is already proven, so what remains is only the upload leg and the dSYM
  gate — both of which a real submission exercises for free. Fold the proof into the next
  ac-publish run and record the result there. Do NOT re-file this as a standalone task: it
  has aged on the human docket since 2026-08-12 precisely because a dry-run-only proof has
  no natural trigger.
- narrative: The 2026-08-12 signing-capability restoration (bd-hk339) proved everything that
  can be proved WITHOUT uploading: `xcodebuild archive` (Release, manual signing, match
  AppStore profiles) succeeded; `-exportArchive` with `method: app-store-connect` and
  `signingStyle: manual` produced a 19.5 MB signed `App.ipa`; app plus
  BodyCompassWidgetExtension both signed `Apple Distribution: Craig Van Heerden (DYNQVB8R49)`
  with embedded profile `match AppStore com.craigvan.bodycompass` carrying
  `aps-environment: production`; `codesign --verify --deep --strict` passed. What was never
  exercised is the upload leg and the dSYM gate. A premise correction found during refine
  matters for whoever picks this up: the original AC required `gh workflow run
  ios-release.yml`, and THAT LANE IS RETIRED — an AC naming a retired lane is unsatisfiable
  as written and will send the next reader hunting for a workflow that no longer exists.
  Source bead: bd-yb6mp.
