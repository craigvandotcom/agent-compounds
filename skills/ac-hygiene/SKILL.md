---
name: ac-hygiene
description: 'The single code-quality lane — a 5-lens Opus panel (bug hunter, adversary, failure engineer, promise keeper, test warden), minimum 3 rounds for cross-round consensus, scoped to code a user reaches in production. Audits the TEST SUITE as hard as the code: test-quality checks; mutation probes convict hollow tests and trimming counts as much as fixing. Fixes commit directly to `main` (trunk-direct); deferred findings become an epic of beads. Triggers: ''hygiene'', ''clean up the codebase'', ''iterative review'', ''tidy the code'', ''weekly hygiene run''. NOT for a single-module or single-domain deep dive (the audit checklists now live in `ac-review/references/`), the skill/agent registry (skill-builder's registry-audit workflow), or pipeline/board housekeeping (use ac-align's nightly reconcile).'
---


**You are the conductor.** A panel of reviewers hunts independently, each through a different
lens. You synthesize, fix, and iterate. Codebase-wide — not tied to any feature branch or diff.

Scaling tiers per `ac-pipeline/references/risk-classification.md`.
Capability-starved runs: `ac-pipeline/references/degraded-mode.md`.

The weekly quality pass for a repo (`PANEL=full`, 5 lenses), or a quick between-session sweep
(`PANEL=light`, 3 lenses). Scoped to the product surface — `references/reviewers.md` § THE BAR.

---

## I/O Contract

|                  |                                                                                            |
| ---------------- | ------------------------------------------------------------------------------------------ |
| **Input**        | Full codebase, recent commits, or specific directory (user-selected scope)                 |
| **Output**       | Fixed issues committed, health assessment report                                           |
| **Artifacts**    | Round findings in `$ARTIFACTS_DIR/round-{N}-{role}.md`, consensus registry                 |
| **Verification** | Quality gate (test, lint, type-check, build) all passing                                   |

## The run

1. **Initialize** — scope, trunk-direct confirm, consensus registry, baseline gate, the
   conductor-run lenses (coverage audit, knip, stamp-audit, friction cluster-walk), run ledger.
   Full procedure: `references/run-init.md`.
2. **Review loop (phases 1-4)** — spawn the panel, synthesize, auto-apply, converge. Floor
   `MIN_ROUNDS=3`, ceiling `MAX_ROUNDS=5`. Full procedure: `references/run-loop.md`.
3. **Finalize (phase 5)** — conductor triage, decisions, exhaustive quality gate, close
   ceremony, in-session bead refine, report, cleanup. Full procedure:
   `references/run-finalize.md`.

## Contracts this spine carries

**The 5-lens panel** (`PANEL=full`): bug hunter, adversary, failure engineer, promise keeper,
test warden — all Opus, spawned in one message, each writing
`$ARTIFACTS_DIR/round-{N}-{role}.md`. `PANEL=light` = bug hunter + adversary + test warden.
Prompts: `references/reviewers.md`; § THE BAR scopes every lens to the product surface.

**Auto-apply** a fix on any of: Critical/High severity · same-round consensus (2+ agents) ·
cross-round consensus (recurs from a prior round's registry). Everything else defers to the
registry, except `DESIGN_DECISION` items (UX-affecting or approach-transforming), which defer
to the human regardless of severity. Canon: `ac-pipeline/references/review-consensus.md`.

**Trunk-direct.** There is no hygiene branch and no worktree. Fixes commit straight to `main`
as pathspec commits under full H7 discipline (`ac-implement` Phase 0) — never `git add -A`,
never `git add .`, never `git commit -a`, never `git stash`. Commit = push. The panel IS this
run's pre-push review, so there is no separate review step. Canon:
`ac-pipeline/references/commit-discipline.md`.

**Deferred-findings routing (Exhaust Rule).** Nothing actionable leaves as prose. Out-of-scope
confirmed issues → a bead; worth-chasing uncertainties → `-t investigation`; genuine
taste/product forks in an autonomous run → `-t decision --labels human-gate` with a pre-staged
memo. A bead is something you'd schedule; nits stay in the report. Canon:
`beads-standards/reference/bead-conventions.md`.

**Deletion mandate.** A stale/superseded/duplicate finding is REMOVAL-as-disposition, equal to
fixing: a verbatim duplicate deletes outright, a still-needed extract moves to `references/`,
unique content with no surviving twin routes through `MAINTENANCE.md` before git-delete. Canon:
`skill-builder/references/promotion-ladder.md`.

**Round floor.** `MIN_ROUNDS=3` is ABSOLUTE — cross-round consensus needs two later rounds to
recur. Never finalize before round 3; ceiling `MAX_ROUNDS=5`. Details: `references/run-loop.md`.

**Run ledger.** One task per major section; add a "Round N" task as each round begins.
Sub-skills invoked by the Ship and Refine tasks (`ac-publish`, `ac-polish`) run their OWN
ledgers — this ledger tracks top-level sections only. Contract:
`ac-pipeline/references/run-ledger.md`.

**Stamp-audit + coverage lenses** are weekly-only conductor passes, not panel lenses:
`references/run-init.md`.

## When to use

Weekly quality pass per repo (`PANEL=full`) or a quick between-session sweep (`PANEL=light`).
For feature-specific review before merge, use `/ac-review`. Overrides ("light", "headless",
scope/round overrides), troubleshooting, and the standing-review-of-`main` duty:
`references/run-overrides.md`.

---

_Hygiene: the recurring codebase quality pass. For session closure: `/ac-land`._
