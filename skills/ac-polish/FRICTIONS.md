---
skill: ac-polish
created: 2026-09-02
last_pass: 2026-09-02
entries: 1
---

# ac-polish — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     near-duplicate; bump recurrence and last_seen on the existing entry instead. -->

## seams-fixpoint-never-stamps-on-accumulator
- skills: [ac-polish]
- impact: L
- frequency: every-run
- perceptibility: misleading
- recurrence: 1
- related: []
- first_seen: 2026-09-02
- last_seen: 2026-09-02
- stage: manual
- status: promoted
- proposed_fix: discovery ends after two consecutive rounds with no new candidate; consensus by
  given-the-row verifiers, not blind rediscovery; Declined in a sidecar outside the digest;
  artifact in an rg-ignored state dir; one final blind round decides the stamp; unstamped
  hand-off is the normal exit. Landed in workflows/seams.md and references/seams-checklist.md.
- narrative: a 9-round seams run on one target never stamped. The artifact is an accumulator
  (append-only Declined, never-dropped Seen once), so "empty diff" required three
  self-scoped readers to append nothing at all. Rounds 1–3 found 11 seams; rounds 4–9 found
  2 and spent their budget re-finding earlier singletons for consensus. Half the readers'
  repo-wide `rg` surfaced the plan under `_plans/`, weakening every later "independent" hit.
  Checklist question 3 licensed an open-ended class of consistent-today shapes that readers
  flipped between Declined and Seen once every round.
