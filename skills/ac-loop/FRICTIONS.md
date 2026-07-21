---
skill: ac-loop
created: 2026-07-21
last_pass: 2026-07-21
entries: 1
---

# ac-loop — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

## doc-only-repo-no-loop-adaptation
- skills: [ac-loop]
- impact: M
- frequency: rare
- recurrence: 1
- related: []
- first_seen: 2026-07-21
- last_seen: 2026-07-21
- stage: ac-loop
- status: open
- proposed_fix: add a short "doc-only / non-app repo" adaptation note to ac-loop — when the target repo has no vitest/app-CI/version/QA (e.g. agent-compounds itself), the verify-gate collapses to `lint.sh` + `validate-skill.sh`, and CI-dispatch / version-bump / browser-device passes are skipped; the operator shouldn't have to hand-translate the whole ceremony.
- narrative: during the W3.2 pilot's live-run acceptance (G2), a fresh conductor ran the Rule-0 bug lane on agent-compounds. The loop's Phase-0 board-scan and the verify→CI-dispatch→ac-publish spine all assume a Next.js app; on a doc-only repo the "gate" is really lint.sh + validate-skill.sh and there is no CI/version/QA. The run succeeded, but only because the operator translated the ceremony by hand — the skill has no documented adaptation for this case.
