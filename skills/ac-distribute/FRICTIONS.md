---
skill: ac-distribute
created: 2026-08-21
last_pass: 2026-09-06
entries: 3
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

## ship-lane-consumes-local-generated-state-without-asserting-it-matches-the-manifest
- skills: [ac-distribute, capacitor]
- impact: H
- frequency: occasional
- perceptibility: silent
- recurrence: 1
- related: [fastlane-release-lane-never-proven-end-to-end]
- first_seen: 2026-08-24
- last_seen: 2026-08-24
- stage: distribute
- status: open
- proposed_fix: assert in the ship lane that `CapApp-SPM/Package.swift` and `Package.resolved` stay clean across `cap sync`, and clear `.next/dev` before the type-check. Both are preconditions, not diagnostics.
- narrative: the lane builds from whatever the workstation happens to hold, and never checks
  that against the committed source of truth. TWO FACES, opposite perceptibility, same root.
  SILENT: `node_modules` held a purchases SDK two minor versions behind the lockfile because
  nobody re-installed after a dependabot bump. `cap sync` regenerates the SPM manifests FROM
  `node_modules`, so every local build silently rewrote the native pins backwards and produced
  an archive that did not match the branch it claimed to be. A native smoke run PASSED against
  that archive before anyone noticed. LOUD: a leftover dev-server types cache, included via
  `tsconfig`, failed the capacitor build with sixty module-not-found errors pointing at healthy
  source files, because the build moves those pages aside for static export. The lesson is the
  pairing: the same missing precondition yields a wrong binary that certifies clean, or a
  correct tree that fails incomprehensibly, and only luck decides which. CI never sees either —
  it installs frozen and checks out clean — so the entire class is invisible until a human
  ships from a workstation, which is the least-supervised moment in the pipeline.

## distribution-doc-drifts-and-nothing-reconciles-it
- skills: [ac-distribute]
- impact: S
- frequency: occasional
- perceptibility: misleading
- recurrence: 1
- related: []
- first_seen: 2026-08-24
- last_seen: 2026-08-24
- stage: distribute
- status: open
- proposed_fix: reconcile the app-facts doc against the lane it describes on each release; a claim about what the lane CANNOT do is the one to re-probe, not to trust.
- narrative: the app-facts doc the skill routes to first told a reader two false things. It
  claimed agent shells cannot codesign — the signing probe passed cleanly twice in the same
  session, `Authority=Apple Distribution`, keychain set no-timeout. And its version table sat
  twelve builds behind what had shipped. The version staleness is cosmetic; the capability
  claim is not, because a doc that says a lane needs a human at the keyboard will stop an agent
  that could have run it, and the failure mode is silent deferral rather than a visible error.
  A negative capability claim ages worst of all: nothing exercises it, so nothing disproves it.

## the-documented-reliable-ship-path-has-no-quality-gate
- skills: [ac-distribute, ac-publish]
- impact: L
- frequency: frequent
- perceptibility: quiet
- recurrence: 1
- related: [a-gate-must-fail-when-it-verified-nothing]
- first_seen: 2026-08-26
- last_seen: 2026-08-26
- stage: ac-distribute
- status: open
- proposed_fix: make `scripts/ship-testflight.sh` refuse to upload unless the target commit carries a passing required check-run set, reusing `scripts/ci/testflight-gate-check.sh`. Give it a loud, named override for the deliberate hotfix case. Reconcile the two contradictory comments in ios-release.yml.
- narrative: `scripts/ship-testflight.sh` has ZERO quality-gate patterns -- `grep -cE "Quality Gate|check-run|check_runs|gh api"` returns 0. Its only gate is a SIGNING preflight inside the fastlane release lane, which checks credentials, not code health. Meanwhile `.github/workflows/ios-release.yml` contradicts itself in two lines: `:32` calls `pnpm ship:testflight` "the reliable ship path", `:74` says "This is the ONLY TestFlight path". Both cannot be true, and `:74` is what makes the gap invisible -- a reader auditing release safety reads it, concludes the gated workflow is the only way out, and stops looking. Per the workflow's own header, builds 33-34 shipped through the ungated script. bd-r0434 hardened the LESS-USED lane; fixing only that leaves the actually-used path open while making the safety story read as resolved -- the worst combination.
