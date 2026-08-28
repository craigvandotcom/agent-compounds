---
skill: ac-publish
created: 2026-08-21
last_pass: 2026-08-21
entries: 1
---

# ac-publish — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     near-duplicate; bump recurrence and last_seen on the existing entry instead. -->

## db-deploy-hardening-is-deferred-until-the-secrets-are-wired
- skills: [ac-publish]
- impact: M
- frequency: once
- recurrence: 1
- related: [a-dormant-pipeline-reports-success]
- first_seen: 2026-07-16
- last_seen: 2026-08-21
- stage: deploy
- status: open
- proposed_fix: Attach these three items to the ACT OF WIRING the secrets, not to a standalone
  bead — the work is dormant until `SUPABASE_ACCESS_TOKEN` / `SUPABASE_DB_PASSWORD` and the
  `production-db` environment exist, and a bead with no trigger simply ages. Gate the wiring
  on: (1) SEC-1 — stop passing the DB password as a `--password` CLI arg on link /
  migration-list / db-push, where it is visible via `ps aux` on the self-hosted runner, which
  is Craig's own dev machine; check whether the installed Supabase CLI supports
  `--password-stdin` or reads `SUPABASE_DB_PASSWORD` from env and use whichever exists.
  (2) SEC-2 — `db-deploy-push.sh:44` captures `supabase migration list ... 2>&1` into LIST and
  echoes it; the CLI does not echo the password but auth-failure stderr could surface
  sensitive detail in Actions logs, so drop or filter the unconditional echo. (3) SEC-6 is a
  DESIGN FORK needing a human: `deploy-additive` gates on `vars.DB_DEPLOY_GATE_ALL != 'true'`,
  so additive migrations auto-push UNLESS the var is set — a forgotten or deleted var silently
  ENABLES auto-push, which cuts against fail-safe. Decide between keeping the documented
  graduated default and flipping to gate-by-default (explicit opt-in to auto-push), and
  consider binding the var at the `production-db` environment level rather than repo level so
  it inherits that environment's access controls.
- narrative: `.github/workflows/db-deploy.yml` plus `scripts/ci/db-deploy-push.sh` are DORMANT
  — the activation guard `exit 0`s without pushing when the prod secrets are absent
  (db-deploy.yml:~102). Every item above is therefore non-blocking TODAY and becomes live-risk
  at the exact moment prod secrets are wired, which is why it has sat for over a month with
  nothing forcing it. This is a specific instance of the wider `a-dormant-pipeline-reports-
  success` class: a check over an empty target returns green and reads as proof. Two related
  fixes DID land in the originating review — the classifier regex now catches TRUNCATE /
  RENAME / ALTER COLUMN TYPE / SET NOT NULL, and drift-abort now fails closed on an unexpected
  `migration list` format. Source bead: bd-8araw.
