---
skill: agent-mail
created: 2026-08-14
last_pass: 2026-08-14
entries: 1
---

# agent-mail — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

## commit-as-reservation-holder
- skills: [agent-mail]
- impact: S
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: 2026-08-14
- last_seen: 2026-08-14
- stage: implement
- status: open
- proposed_fix: never mint a second exclusive reservation under a new name on paths already leased; commit as the identity that holds the exclusive lease (export that AGENT_NAME in the same shell as git commit). A second exclusive reserve makes the guard reject BOTH identities.
- narrative: RUN 20260814-213141-15553. A child took an exclusive reserve, then reserved again under a second name. The pre-commit guard then rejected commits from both identities — the first is no longer the exclusive holder of record once the second reserve lands, and the second cannot prove it holds the first lease. Cost minor. Distinct from the existing same-identity missing-env facts (`agent-mail-reservations-and-the-commit-shell`, `precommit-guard-needs-agent-name-in-shell`): those fail because AGENT_NAME is absent in the commit shell; this fails because the lease and the committer are two different minted names. Sibling: `references/session-procedure.md` § Export.
