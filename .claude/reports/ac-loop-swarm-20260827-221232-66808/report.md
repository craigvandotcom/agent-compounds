# ac-loop-swarm — RUN 20260827-221232-66808

- **Width** 2 · **Cap** none (human ruling) · **Orchestrator** RedBay
- **Started** 2026-08-27T20:12:32Z · **Pool at spawn** 4 pickable
- **Base** `f0b0faf` → **Head** `8c2ebe9` (+ ledger/friction commit)

## Outcome

| | |
|---|---|
| **closed** | 15 |
| **blocked** | 0 |
| **gated** | 0 |
| **premise-failed** | 0 |
| **orphaned** | 0 |
| **unpushed-reconciled** | 0 (workers pushed everything; nothing to rebase) |
| **unverified tiers** | none declared by worker 1; worker 2 returned prose, not the exit JSON |

### Closed

**Worker 1 (GentleCave)** — 8, stop_reason `queue-dry`
`ac-39kx` · `ac-4y92` · `ac-on0y.3` · `ac-cfn4` · `ac-kdxa` · `ac-gv70` · `ac-s6fe` · `ac-vuer`

**Worker 2 (CopperBay)** — 7, stop_reason `queue-dry`
`ac-g2v4` · `ac-qn7h` · `ac-fjgl` · `ac-d12o` · `ac-se4u` · `ac-v1vo` · `ac-7f8s`

Four ac2 skills now exist: `ac2-pipeline` · `ac2-beadify` · `ac2-polish` · `ac2-plan`.
Phases 2–3 (`ac2-implement`, `ac2-review`, `ac2-publish`) were compiled into epic
`ac-k25c` (8 children) and deliberately left unimplemented — worker 2 declined to build a
spec it had authored minutes earlier at the tail of a long session. That is the correct
call and is recorded here as a judgement, not a shortfall.

## Verification (clean HEAD, independent agent)

```
LINT:      426 checks, 7 failures
HARNESSES: discovered 23 · passed 22 · failed 0 · quarantined 1
```

- **NEW/REGRESSION: none.** 6 failures pre-existed this batch (Check 2 `/ac-loop`,
  Check 6 `canonical_ingredients` ×2, Check 15, Check 19 — the Check 19 site was verified
  byte-identical between `e66e995~16` and HEAD).
- **EXPECTED-TRANSIENT:** Check 13 registry-description budget, **31,128 / 30,000**. This
  is the anticipated overlap under the archive-before-use ruling and clears at ~28,243 when
  the 12 absorbed legacy skills are archived. It now fails on its own **named** budget line
  rather than hiding behind Check 13's standing invocation-graph failure — the breach became
  *visible* in this run, which is an improvement in the sensor, not a new defect.
- **All 7 new harnesses pass individually**: `ac2-budget-check`, `ac2-ledger-integrity`,
  `lint-net-growth` (12/0), `polish-fixpoint` (17/0), `element4-check`,
  `stamp-refined-fixpoint`, `friction-rollup` (15/15).
- `cross-repo-gate.test.sh` remains quarantined citing `ac-1227`, still red as designed.
- **CI ("Registry Lint") is red end-to-end** on the identical 7 checks — same signature
  local and remote. Nothing in this run made it worse or better.

**NOT-GATED, stated plainly:** the verifier did not diff each harness's assertions against
its pre-batch version, so "22 passed" does not by itself exclude a harness that was weakened
rather than broken. No evidence suggests one was; the check simply was not run.

## The `ac-on0y.3` / `ac-cfn4` collision — resolved, verified

Both landed with the same worker, and the pre-run risk was that it closed two competing
ledger parsers. It did not. There is exactly **one** parser —
`skills/skill-builder/scripts/friction-rollup.py` (`ac-on0y.3`) — emitting both consumer
views from a single parse. `ac-cfn4` delivered ledger *content* plus a Check-22 integrity
script, not a parser. Verified against close reasons and the tree, not taken on trust.

## Pre-flight catch

`ac-kqpw` sat in the ready pool as a **finished epic** (all 7 children closed), typed
`issue_type: epic` but carrying no `epic` **label**. The worker seed's exclusion list is
label-based, so nothing would have dropped it and a worker would have claimed it. Labelled
before spawning; filed as friction `seed-epic-exclusion-keys-on-label-not-issue-type`.
**Its close remains a human ruling, not a worker's.**

## Friction routed → `skills/ac-loop-swarm/FRICTIONS.md`

- `ubs-summary-counter-and-language-coverage-both-misreport` — **recurrence 3 → 4**, and
  escalated from *misreporting* to **NOT-GATED**: in this repo shell and markdown are the
  dominant languages, so the mandated step-6 quality gate covered nothing on **6 of 8**
  beads. Only two Python files were ever scanned. The fix's load-bearing half (explicit
  NOT-CHECKED verdict, non-zero exit when no scanner matched) is unshipped after four
  observations.
- `seed-epic-exclusion-keys-on-label-not-issue-type` — new.
- `br-ready-has-no-pick-order-flag-so-every-caller-reimplements-it` — new. The canonical
  pick order is prose in beads-standards that every worker re-implements in jq; a rule with
  no enforcement loop.
- `reservation-guard-is-advisory-only-for-code-paths` — new. The step-4 ceremony costs a
  round trip per bead and enforces nothing on this checkout; `flock` and the `br` claim are
  the only real mutexes. The run was safe because the beads touched disjoint files.
- Header bookkeeping: `entries:` read **35** while the file held **47**. Corrected to 50. A
  count field with no loop, drifting unnoticed — noted in the new `friction-corpus` bead.

### Failed control → `skills/ac-bead-refine/FRICTIONS.md`

`tr-shadowed-by-tmux-alias-in-interactive-zsh` was marked **resolved (ac-e5a3, 2026-08-03)**
and bit a worker live 24 days later. **Reopened**, with the record corrected: `ac-e5a3` did
what it claimed — patched 8 named invocations in 4 files — but the root cause is a fleet-wide
interactive-zsh alias shadowing a POSIX binary, which is unbounded. Site coverage was
recorded and read as root coverage, and the ledger had no way to tell them apart. A
promotion pass would have counted this as a control that WORKED.

The generalisable defect: **`status: resolved` must distinguish root-fixed from
sites-patched**, or a site-scoped fix silently degrades into a false all-clear the moment
anyone writes new code.

## Discoveries filed as beads

| bead | P | what |
|---|---|---|
| `ac-polish-fixpoint-digest-only-bnyx` | 1 | fixpoint proven from artifact digest alone; would have STAMPED over 3 unfixed defects. Worker 2 refused the stamp by hand and filed against the engine it had built an hour earlier. **An empty artifact diff is not an empty finding set.** |
| `ac-beadify-execute-probes-at-compile-bq6d` | 1 | execute each probe at compile time, refuse any that exits 0 before the work exists. Dogfood #2 measured 19 defects over 5 reader rounds, dominated by already-green ACs. |
| `ac-friction-corpus-unscorable-ipig` | 2 | 36/167 entries unscorable; `quiet` used outside the perceptibility vocabulary; header counts unchecked. ~21% of the sensor corpus silently skipped. |
| `ac-ac2-plan-cross-family-citation-3q5e` | 3 | `ac2-plan` cites a checklist as own-dir that lives in `ac2-polish`; Check 23 was widened to accept it rather than the citation corrected. |

## What the dogfood runs actually bought

Both receipts **falsified their own pre-registered predictions**, which is the whole point.
Dogfood #1 pre-registered "ZERO CHANGES" against a plan that had already survived 11
fresh-context polish rounds and a three-lens tribunal; round 2 found **3 real defects** —
including that the Phase-4 cutover slate archives `stamp-refined.sh`, the plan's own
declared sole writer of `refined`, while ac2 still requires it. The ledger went 6 → 10.

Two of dogfood #2's 19 defects were **introduced by the previous round's own fix** and
caught only by the next fresh reader.

## Open for the human

1. **`ac-kqpw`** — finished epic, needs a close ruling.
2. **Registry budget at 31,128/30,000** — red until the 12 absorbed skills are archived.
   Every run until cutover will see it.
3. **`ac-k25c`** (8 beads, Phase 2–3) is unrefined; it wants a refine pass before a swarm
   takes it, and `ac-beadify-execute-probes-at-compile-bq6d` should land first if the
   already-green AC class is to be caught mechanically rather than by five reader rounds.
4. **`ac-1227`** (cross-repo doctrine restore-vs-rehome) and decision beads
   `ac-on0y.5` / `ac-on0y.6` remain open.
