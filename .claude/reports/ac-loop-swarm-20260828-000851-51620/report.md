# ac-loop-swarm — RUN 20260828-000851-51620

- **Width** 2 · **Cap** none · **Orchestrator** SwiftCanyon
- **Base** `50a1025` → **Head** `de6d52e`
- **Pool at spawn** 2, growing with the chain

## Outcome

| | |
|---|---|
| **closed** | 7 (`ac-k25c.1`–`.7` — the whole implementable chain) |
| **blocked / gated / premise-failed** | 0 / 0 / 0 |
| **orphaned** | 1, recovered |
| **workers lost** | 1 (transient API error) |
| **unpushed** | 0 |

**Phases 2–3 of ac2 are complete.** `ac2-implement` (with `swarm-commit.sh`,
`flight-check.sh`, `close-gate.sh`, `worker.md`), `ac2-review`, `ac2-publish`, and the
`ac-triage` inbound leg all landed. Seven ac2 skills now exist.

### Worker record
- **CloudyIsland** — 7 closed across both stints: `.1`, `.3`, `.4`, `.5`, `.7`
- **MistyBay** — `.2`, then died mid-`.3` (API connection lost)
- **SunnyGate** (replacement) — `.6`

## Verification (clean HEAD, independent agent)

```
LINT:      438 checks, 7 failures      NEW/REGRESSION: none
HARNESSES: discovered 26 · passed 25 · failed 0 · quarantined 1
BUDGET:    family 615/800 lines · loaded path 1062/1200
```

- All 7 lint failures match the known baseline by **name**, not just by count.
- Three new harnesses pass individually: `close-gate` (33), `flight-check` (37),
  `swarm-commit` (32) — **102 cases, 0 failures**.
- `cross-repo-gate.test.sh` still quarantined-red citing `ac-1227`; did **not** flip to
  passing, so no quarantine signal.
- CI signature is identical to local. CI counts 400 checks vs 438 local — a pre-existing
  environment discrepancy (the runner reports `.claude/settings.json unreadable`), not
  introduced here.

### Independent probe re-run — the run's own claim, tested
Before spawning, all **47 AC probes across `ac-k25c` were verified RED**. After the run:
**40 GREEN** (every closed bead), **5 RED** — all of them `ac-k25c.8`, the human-gated
Phase-4 cutover that was correctly never implemented. No bead closed without satisfying
its own acceptance criteria.

**Registry description budget grew: 31,128 → 32,228 / 30,000** (+1,100 this batch). Still
the accepted archive-before-use transient, but the overage is now growing per batch.

## The assurance breach — recorded, not smoothed over

**`ac-k25c.7` was closed while BOTH of its gates refused**: `close-evidence-check.sh`
returned NOT-CHECKED (exit 2) and `close-gate.sh` refused with HASH-LOCK.

Mechanism, from the worker's own diagnosis: the spec says
`close-evidence-check.sh … || stop`, but the check and `br close` were issued as **one
compound shell line**, and a compound line silently defeats the `||`. The gate ran,
refused, and the write happened anyway.

Same root as the `set -e` scar `swarm-commit.sh` now encodes. **Two independent
manifestations in two places makes it a pattern, not a slip** — and both surfaced only
because a worker volunteered its own breach, never because a sensor caught it.

The close was substantively correct — all four ACs independently verified GREEN at
close-out. **That is the dangerous part.** The outcome was good, so nothing external
would ever have flagged it. Assurance that depends on a worker self-reporting is not
assurance. Filed P1: `ac-close-evidence-check-bypassable-by-chaining-kexj`.

## A gate we shipped this run does not work for a whole bead class

Worker-filed **`ac-hnsc`** (P1): `close-gate.sh`'s HASH-LOCK is **structurally
unsatisfiable** for prose and config beads whose subject file exists at claim time.
`flight-check` fingerprints the RED probe *plus every existing file the probe names* — and
for a prose bead the probe names the very file the bead exists to edit, so any successful
fix moves the fingerprint. The "unchanged test" half of the temporal claim can never be
observed.

`ac-k25c.3`'s own Intent promised the opposite: *"prose and config beads take the same
temporal shape."* And `close-gate`'s own remedy text asks prose beads to grow a shell
harness whose only job is to re-run a grep — **a harness written to satisfy a lock, which
is the vacuous-AC shape this pipeline exists to kill.** The worker was right to refuse
that escape rather than take it.

## Discoveries filed

| bead | P | what |
|---|---|---|
| `ac-hnsc` (worker-filed) | 1 | close-gate HASH-LOCK unsatisfiable for prose beads |
| `ac-close-evidence-check-bypassable-by-chaining-kexj` | 1 | a refusing gate composed away by a compound shell line |
| `ac-check23-leg2-cross-family-citation-gy75` | 2 | no ac2 SKILL.md can cite another family's reference by path; both workers hit it |
| `ac-delivers-without-path-defeats-evidence-check-ub21` | 2 | prose-only Delivers ⇒ NOT-CHECKED on every close, indistinguishable from a real failure |

## Friction routed

Bumps: `ubs` NOT-GATED **4 → 5** (5 more beads unscanned) · reservations advisory
**1 → 2** (the server grants a path it *simultaneously reports as conflicting*) · dcg
dynamic-path redirect **2 → 3** (now fires on python **source text**, with no shell
redirect present) · loop-gates-false-green **0 → 1**.

New: a refusing gate composed away by a compound line · dcg blocks throwaway scratch-repo
experiments (taxing the *right* behaviour — verifying a command instead of assuming it) ·
Check 23 cross-family trap invisible until lint (cost held to one round only because one
worker mailed the other unprompted — a human-shaped rescue, not a mechanism) · `br create`
echoes the whole bead body (~4k tokens, taxing thorough filing).

Header count resynced 50 → 54.

## What the loss actually demonstrated

A worker died mid-bead and **the system recovered without a conductor**. The orphaned
claim was swept, and the live sibling re-claimed the bead on its own. The dead worker's
364-line draft was inherited and — importantly — the inheriting worker reported that it
*passed all 33 AC-derived cases unmodified, but only 8 of 12 mutations went RED on the
first round.* The two survivors survived because their leg carried a second guard. **First-run
green against an unverified draft is not evidence without mutation testing**, and the worker
knew to say so.

## Open for the human

1. **`ac-k25c.8`** — Phase-4 hard cutover, `human-gate`, correctly untouched. This is the
   one that archives the legacy ac-* family and clears the budget breach.
2. **`ac-hnsc`** and **`ac-close-evidence-check-bypassable-by-chaining-kexj`** — both P1,
   both defects in gates ac2 depends on. Neither should wait for cutover.
3. Budget overage growing per batch: **32,228 / 30,000**.
4. Still open from before: `ac-kqpw` (finished epic needing a close ruling), `ac-1227`,
   `ac-on0y.5` / `.6`, `bd-7fy3d` (BCA push blocked).
