# Executed-jobs evidence — the tier-blindness case and the four live runs

## Why the assertion is two layers (jobs AND steps)

**THE TIER IT GUARDED AGAINST IS RETIRED** (bd-fugib.7's slim proof deleted the
`batch-close`/Tier-1 leg and its dispatcher; a workflow_dispatch run is now always the full
leg). The step-level layer stays: it is the layer that REFUSED the runs below, and the
failure mode it guards — a green conclusion over skipped/never-scheduled steps — is exactly
what any future step rename, step deletion, or `if:` re-gating would silently create. The
history stands because it is what the layer was built from, and what a future editor must
repeat against before touching `.github/required-jobs.txt`.

- **Tier 2 (reason=prove / publish)** — full suite: next build, vitest full suite, db reset,
  real-Postgres integration. The ONLY leg remaining. Its quality-gate job name carries
  the ` — Tier 2 full suite` suffix on every dispatch.
- **Tier 1 (reason=batch-close)** — deleted 2026-10-02 (slim proof). It lived to show why
  job names alone cannot gate a proof:

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

## The adjudicated contract (the REQUIRED_STEPS names, as of the slim proof)

bd-fugib.8 rewrote the contract to the slim proof's surviving names (bd-fugib.7 renamed the
vitest step, deleted the TypeScript and Shadow-divergence steps, and retired the tier suffix
condition — a prove dispatch now ALWAYS carries it):

- Unit + integration tests (vitest, full suite)
- Build check (next build)
- Supabase integration tests — real Postgres (workflow_dispatch only)
- Apply migrations — db reset (workflow_dispatch only)

Job level (two required jobs, exact names incl. the suffix the workflow appends):

- Quality Gate (format · lint · types · build · tests · prompt-drift) — Tier 2 full suite
- Supabase integration tests (real Postgres · workflow_dispatch only)

Committed in the registry repo at `.github/required-jobs.txt` alongside the job list —
see the ac-publish executed-jobs assertion.