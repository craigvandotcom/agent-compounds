---
skill: ac-qa-browser
created: 2026-07-22
last_pass: 2026-07-29
entries: 4
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
