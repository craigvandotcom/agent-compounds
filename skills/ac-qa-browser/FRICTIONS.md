---
skill: ac-qa-browser
created: 2026-07-22
last_pass: 2026-07-22
entries: 1
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
