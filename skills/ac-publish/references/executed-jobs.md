# Executed-jobs evidence — the tier-blindness case and the four live runs

## Why the assertion is two layers (jobs AND steps)

`quality-gate.yml` emits the SAME TWO JOB NAMES for both tiers, so at job level a Tier-1
`batch-close` run is indistinguishable from a Tier-2 full proof:

- **Tier 2 (reason=prove / publish)** — full suite: next build, shadow divergence, db reset,
  real-Postgres integration.
- **Tier 1 (reason=batch-close)** — format/lint/tsc/affected-tests only; the heavy steps skip
  via `inputs.reason != batch-close` on each step.

A Tier-1 run therefore reports the same two job names with `conclusion=success` while never
building, never running the divergence check, and never touching real Postgres. The job-level
assertion alone reads it as GATED-OK.

## The reproducing run (Tier-1 that must be refused)

Run `32980692074` (2026-08-26, workflow_dispatch, run conclusion=success, both required jobs
success), asserted with a step-level check:

```
success  ::  Unit + integration tests (vitest)
skipped  ::  Build check (next build)
success  ::  TypeScript check (tsc --noEmit)
skipped  ::  Shadow divergence check
skipped  ::  Supabase integration tests — real Postgres (workflow_dispatch only)
skipped  ::  Apply migrations — db reset (workflow_dispatch only)
```

Four of six substantive steps SKIPPED while both jobs are green. Confirmed Tier-1 by inference:
the step 'Detect migration changes in batch range (batch-close only)' — gated solely on
`reason==batch-close` — RAN with conclusion success in that run. The step-level layer refuses
this run, naming the skipped steps.

Same class the repo's own infra tooling documents elsewhere (a docker-keepalive header records
the supabase tier "reports SUCCESS over skipped steps ... unnoticed for two consecutive
batches", bd-3bcad).

## The refused red run (job-level)

Run `33369682855` concludes `failure` — the existing job-level layer refuses it by name.

## The green full proof (both layers pass)

Run `34172430677` — all six substantive steps conclude `success`; both layers pass.

## Executed live, all four ways

A gate whose commands nobody ran is a scar list with better formatting. Before shipping, the
assertion is executed against: a green full proof (34172430677), a required job that concluded
`failure` refused by name (33369682855), a Tier-1 run whose heavy steps skipped refused by name
(32980692074), and an empty `REQUIRED` refused.

## The six substantive steps (the REQUIRED_STEPS contract)

- Unit + integration tests (vitest)
- Build check (next build)
- TypeScript check (tsc --noEmit)
- Shadow divergence check
- Supabase integration tests — real Postgres (workflow_dispatch only)
- Apply migrations — db reset (workflow_dispatch only)

Committed in the registry repo at `.github/required-jobs.txt` alongside the job list —
see the ac-publish executed-jobs assertion.