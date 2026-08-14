---
skill: testing
created: 2026-08-14
last_pass: 2026-08-14
entries: 1
---

# testing — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

## empty-swr-success-mocks-miss-realtime-collision
- skills: [testing]
- impact: L
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: 2026-08-14
- last_seen: 2026-08-14
- stage: reproduce
- status: open
- proposed_fix: a remount fixture that empties SWR and lets food-repo mocks succeed is not a stand-in for N concurrent realtime `.on()` subscribers. Widen the fixture to mount the same hook N times against one table+filter (or assert subscribe-throw isolation), matching the production collision — do not treat empty-cache + happy mocks as the nightly Connection Problem.
- narrative: RUN 20260814-213141-15553. ~40 min. Empty-SWR remount + succeeding food mocks stayed GREEN (`body-compass-app/__tests__/components/entries-view-remount.test.tsx`); the nightly layer-1 triathlon Connection Problem is three Entries-tree instances of `useTodaysSignals`' realtime `.on('postgres_changes')` colliding (React 19 reports the effect throw to the nearest ErrorBoundary). Adjacent to `fixture-shape-validity-is-a-test-quality-dimension` (impossible persisted state) but a different direction: this fixture is a possible remount and still measures the WRONG cause. A green remount suite therefore cannot certify the nightly path.
