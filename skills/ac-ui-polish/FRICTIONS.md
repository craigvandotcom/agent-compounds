---
skill: ac-ui-polish
created: 2026-07-31
last_pass: 2026-09-06
entries: 1
---

# ac-ui-polish — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

## serve-prod-dirty-gate-blocks-pre-commit-verify
- skills: [ac-ui-polish]
- impact: S
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: 2026-07-31
- last_seen: 2026-07-31
- stage: ac-loop
- status: open
- proposed_fix: document the correct order explicitly — ubs -> commit -> rebuild -> verify -> push. A fix cannot be browser-verified before it is committed, because `scripts/qa/serve-prod.sh` refuses a dirty working tree.
- narrative: `scripts/qa/serve-prod.sh` has a dirty-input gate, so a fix cannot be browser-verified BEFORE commit. Cost ~8 minutes working out the correct sequencing by trial and error.
