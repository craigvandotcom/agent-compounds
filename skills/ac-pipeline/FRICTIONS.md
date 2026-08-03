---
skill: ac-pipeline
created: 2026-08-03
last_pass: 2026-08-03
entries: 1
---

# ac-pipeline — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

## dcg-blocks-the-skills-own-canonical-artifact-redirects
- skills: [ac-pipeline]
- impact: M
- frequency: every-run
- recurrence: see primary
- related: [dcg-blocks-the-skills-own-canonical-artifact-redirects]
- first_seen: 2026-08-03
- last_seen: 2026-08-03
- stage: ac-loop
- status: open
- proposed_fix: see primary — resolve-then-paste literal paths, or route artifact writes through the Write tool.
- narrative: POINTER ENTRY, not a copy — see `dcg-blocks-the-skills-own-canonical-artifact-redirects` in `skills/ac-loop/FRICTIONS.md`, which is the PRIMARY and the only place occurrences are counted (per friction-capture.md § Routing: cross-cutting frictions are recorded once, with pointers in the secondary skills). Recorded here because RUN 20260803-113231-34132 established that ac-pipeline owns shared substrate inside the blast radius, not merely a downstream skill affected by it: `references/board-scan.md`'s Scan D/E blocks are guard-blocked verbatim, and the artifact-write shapes handed to every child through the delegation preamble are the same construct. A fix applied only to the individual phase skills leaves the shared substrate emitting the blocked shape to every child of every run.
