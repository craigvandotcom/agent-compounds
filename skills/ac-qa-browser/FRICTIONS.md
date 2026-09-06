---
skill: ac-qa-browser
created: 2026-07-22
last_pass: 2026-09-06
entries: 6
---

# ac-qa-browser — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

## curl-regex-probes-report-false-zero-on-streamed-routes
- skills: [ac-qa-browser]
- impact: M
- frequency: occasional
- recurrence: 2
- related: []
- first_seen: 2026-07-22
- last_seen: 2026-07-22
- stage: ac-qa-browser
- status: open
- proposed_fix: state in the workflow that DOM-based assertion is MANDATORY on streamed routes — a curl-plus-regex probe is not a valid negative signal there, only a valid positive one. Add the companion timing rule: probe AFTER hydration settles (wait for a hydration-complete signal or a known post-hydration element), never immediately on load, or the probe races hydration and returns all-zeros on a perfectly healthy page.
- narrative: `/foods` streams its payload through the Next flight mechanism, so the markup a curl fetch sees does not contain the rendered `<h1>` or the card anchors. A curl-plus-regex probe therefore returned 0 matches — a pure MEASUREMENT ARTIFACT that reads exactly like a product defect ("the page renders nothing"). Hit twice in RUN 20260722-085844-39967. Separately, a DOM probe fired before hydration settled also returned all-zeros and nearly produced a false "blank page" finding. Both failure modes manufacture qa-blockers against innocent batches; both are invisible unless the QA agent knows the route streams. Sibling failure mode with the same false-defect signature: a stuck Suspense fallback caused by a stale chunk manifest (see the `stuck-suspense-fallback-is-usually-a-stale-chunk-manifest` memory fact and bd-y5mza).

## serve-prod-dirty-guard-unusable-in-shared-checkout
- skills: [ac-qa-browser]
- impact: S
- frequency: frequent
- recurrence: 1
- related: []
- first_seen: 2026-07-29
- last_seen: 2026-07-29
- stage: ac-loop
- status: open
- proposed_fix: use the cache-serve path (`.next-builds/<sha>-<hash>/.next` + `next start`) as the working substitute; the any-dirty guard needs a shared-checkout mode that tolerates a live sibling's WIP.
- narrative: `scripts/qa/serve-prod.sh`'s any-dirty guard is UNUSABLE in a shared trunk-direct checkout — it can never pass while a live sibling has uncommitted work in the tree, which is the normal state at width>1. Cost ~2 minutes to work around by switching to the cache-serve path. Related bead: bd-7mey3.

## agent-browser-no-network-throttle-flag
- skills: [ac-qa-browser]
- impact: S
- frequency: rare
- recurrence: 1
- related: []
- first_seen: 2026-07-29
- last_seen: 2026-07-29
- stage: ac-loop
- status: open
- proposed_fix: add a built-in network-throttle flag to agent-browser.
- narrative: agent-browser has no network-throttle flag, so a sub-15ms skeleton window is unobservable without hand-rolling CDP throttling via the page's devtools websocket. Cost ~3 minutes to improvise.

## poll-cap-shorter-than-worker-runtime
- skills: [ac-qa-browser]
- impact: S
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: 2026-07-29
- last_seen: 2026-07-29
- stage: ac-loop
- status: open
- proposed_fix: poll caps must exceed realistic worker runtime, or skip polling altogether and just await the completion notification instead.
- narrative: a bounded 10-minute poll loop capped out while a worker was still running; the completion notification for that same worker arrived shortly after anyway. Cost ~10 minutes of wall time to an avoidable poll-cap mismatch.

## local-prod-serve-missing-site-origin
- skills: [ac-qa-browser]
- impact: M
- frequency: every-run
- recurrence: 1
- related: [serve-prod-dirty-guard-unusable-in-shared-checkout]
- first_seen: 2026-08-15
- last_seen: 2026-08-15
- stage: verify
- status: open
- proposed_fix: inject SITE_ORIGIN (e.g. http://localhost:$PORT) in scripts/qa/serve-prod.sh so the mandated local-prod target can walk password-reset; treat a fail-closed 500 when SITE_ORIGIN is unset as env-gap / qa-infra, not a product qa-blocker.
- narrative: exhaustive browser QA on the prescribed local-prod serve (`scripts/qa/serve-prod.sh` / `next start`) failed auth journey assert 4 — POST /api/auth/reset-password returned 500 and the UI showed a connection error instead of the anti-enumeration success copy. Product fail-closed is intentional (bd-iahbm) when SITE_ORIGIN is unset in production; the gap is that the official QA serve never injects it (absent from .env.local, only in .env.example). Auth is in every smoke+ depth, so the mandated target cannot walk password-reset until the serve supplies SITE_ORIGIN. Filed bd-wqzv7 (not a product regression). evidence: RUN 20260815-001616-13976, class=env-gap.

## fixtures-that-hide-from-the-harness-sweep-become-state-it-cannot-reason-about
- skills: [ac-qa-browser]
- impact: M
- frequency: occasional
- perceptibility: misleading
- recurrence: 1
- related: []
- first_seen: 2026-08-24
- last_seen: 2026-08-24
- stage: qa-browser
- status: open
- proposed_fix: a fixture is owned by the run that needs it — seeded at run start, torn down at run end. Never pinned outside the sweep window to survive; and never on an account other runs share.
- narrative: TWO defects, one root: the seed script buys determinism by opting its fixture OUT
  of the harness's own lifecycle. It hard-codes a fixture timestamp with the comment that a
  fixed date "outside any QA run window protects it from the run-window sweep". That works, and
  the cost is that the harness can no longer reason about the fixture at all — it is state the
  sweep is blind to by construction, so it drifts silently and no run owns it.
  The same shape, wider: the fixtures live on ONE shared QA account, which makes any bead
  depending on them structurally unclosable by a concurrent lane. Reseeding destroys a sibling
  run's in-flight state, so the work cycles through workers indefinitely — it looks
  parallelisable and is actually serial, and nothing in the bead or the skill says so. Whoever
  picks it up pays full read cost before discovering it must be routed to a serialised lane.
  A third symptom, worth recording because it misleads separately: the bead's exit criterion
  was already satisfied by a `last_pass` stamp landed in the same run, so it could close on an
  empty diff while the actual defect stayed untouched. A bead whose exit is a QA stamp rather
  than the fixture's own correctness will close as soon as anyone reruns QA.

## e2e-role-selector-collides-after-a-ui-rename
- skills: [ac-qa-browser, testing]
- impact: S
- frequency: occasional
- perceptibility: loud
- recurrence: 1
- related: []
- first_seen: 2026-08-26
- last_seen: 2026-08-26
- stage: ac-qa-browser
- status: open
- proposed_fix: prefer a test id or an exact-match name over a substring role query; a rename that ADDS a matching control breaks a previously-unique selector without touching the spec.
- narrative: The deferred-capture spec's `getByRole('button', name: 'Food')` stopped resolving uniquely once a second control matching that name appeared. The spec was never edited; the page was. A role+name query is only as stable as the SET of controls that can match it, so its correctness depends on code it does not reference -- the same blind-channel shape as a fixture whose binding guard lives in another file.
