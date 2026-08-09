# Phase 3 mechanics — attribution, fix-forward, mutation probes

The conductor drives this phase directly (it is one serial pass over a quiescent tree) and
delegates only the repair workers. SKILL.md § Phase 3 holds the enforcement spine; this
file holds the mechanics.

## 1. The global pass

Run all three, tree-wide, in this order — cheapest signal first, so a type error is not
diagnosed as forty test failures:

```bash
PHASE_BASE=<sha of main at the Phase-2 barrier open>   # the conductor recorded this
PHASE_TIP=$(git rev-parse HEAD)

pnpm typecheck                       # or the repo's equivalent
VITEST_AFFECTED_REF="$PHASE_BASE" pnpm test    # affected-vs-phase-base, not per bead
pnpm lint
```

Output is **the failure set** — a list of `(check, failing unit)` pairs. It is not a
verdict, and no fix starts until the whole set is enumerated. A partial set produces
overlapping repair workers.

**Format/lint first-pass rule:** a formatter's own output is applied and committed as ONE
bookkeeping commit before attribution starts, so formatting noise never lands in a bisect
range. Never blind-commit formatter output on markdown. Record that commit's sha: a
failure that later bisects to IT is formatting-caused — repair it as its own cluster,
attributed to no bead and excluded from `repair%`.

## 2. Mechanical attribution by bisect

One bead = one commit is what makes this work. For each failing test:

```bash
git bisect start "$PHASE_TIP" "$PHASE_BASE"
# exit 125 = SKIP, not bad. Most Phase-3 failures are tests ADDED this phase: at commits
# before the test file existed, a bare vitest run exits non-zero, bisect reads "bad", and
# the walk converges on the base — misfiling the new test's failure as pre-existing debt.
git bisect run sh -c 'test -f <path/to/failing.test.ts> || exit 125; pnpm vitest run <path/to/failing.test.ts> -t "<test name>"'
git bisect reset
```

- The first-bad commit's trailer names the bead. That is the attribution — **no diff
  reading, no judgment call.**
- A failure that bisects to `$PHASE_BASE` itself pre-dates the phase: file it as an
  `unrefined` bead, exclude it from `repair%`, and move on. It is not this cycle's debt.
  This verdict is trustworthy ONLY under the exit-125 guard above.
- A commit touching `package.json`/`pnpm-lock.yaml` inside the range makes mid-range
  checkouts run against a mismatched `node_modules` — spurious bads. When the range
  contains one, add `pnpm install --frozen-lockfile >/dev/null 2>&1 || exit 125` to the
  bisect script, after the test-file guard.
- A failure that does not reproduce deterministically is a **flake**: re-run that ONE file
  in isolation before spending a bisect on it (a bisect over a flake returns a random
  commit and slanders a bead).
- Bisect is cheap per failure and embarrassingly parallel across failures only if each run
  gets its own checkout — on ONE shared tree, run them **serially**. The tree is quiescent;
  serial bisects are still faster than arguing about attribution.

## 3. Failure clusters → repair workers

Group the attributed failures into **clusters**, one repair worker each:

- Same first-bad commit → one cluster (one bead broke several tests).
- Different commits, overlapping territory manifests → one cluster (the repairs would
  collide; a shared cluster serialises them inside one worker).
- Otherwise → separate clusters, dispatched in parallel.

Repair workers **DO run per-fix checks** — the tree is quiescent, so a gate here costs
nothing and catches everything. Each repair commits with a pathspec, under the commit mutex,
citing BOTH the repair and the bead it repairs.

A repair that cannot be made safe **reverts its bead's commit** (its own revert commit) and
reopens the bead with the failure pasted in. Reverting is a normal outcome, not an
escalation — the bypass lane exists for what genuinely cannot wait.

## 4. Loop to green

Re-run the global pass after every repair round. **Cap: 2 repair rounds.** A third means the
phase cannot converge → **C2 hard stop**: do not close, file a P0 bead, Slack the finding.

Two rounds is deliberate. Round 1 fixes what Phase 2 broke; round 2 fixes what round 1
broke. A round 3 is evidence that the failures are not independent — which is a Phase-1
specification failure, not something more repair will resolve.

## 5. Sampled mutation probes

The probe answers one question: **did the tests written this phase actually catch anything?**

**Sampling rule.** Sample **~20%** of the phase's fixes, stratified **across lanes** — take
at least one from every lane that produced a fix, then fill the remainder by highest risk
flag (`hot-tier` first). Never sample the cheapest fixes; a probe set chosen for convenience
measures convenience.

Excluded from the sample and from the `hollow%` denominator: beads whose contract declared
`RED: n/a` (pure refactor, config, docs).

**Per sampled bead:** one bead = one commit means the TEST and the fix live in the SAME
commit — a bare revert deletes the test it is about to run. Restore the test files from
the bead commit before running, or every probe degenerates to a missing-file error.

```bash
git revert --no-commit <bead-commit>                  # stages the full revert — fix AND test now gone
git show <bead-commit>:<test-path> > <test-path>      # per test file: put the TEST back
                                                      # probe state = test present, fix absent
pnpm vitest run <test-path> -t "<the declared test name>"
git reset --hard HEAD                                 # the ONLY restore that works — `git checkout -- .`
                                                      # cannot undo a staged revert (pathspec matches
                                                      # nothing known to git) and leaves the tree
                                                      # reverted, poisoning every later probe
```

- **PASS (healthy):** the test FAILS, and its failure resembles the declared RED
  expectation. Restore and move on.
- **HOLLOW:** the test still passes with the fix reverted. **Reopen the bead** with the
  probe output pasted in, labelled `unrefined`, and count it in `hollow%`.
- **MISMATCH:** the test fails, but with a failure unlike the declared RED. Not hollow —
  the test does catch something — but the contract's element 4 was wrong. Comment on the
  bead; count it in neither numerator.

Run probes **serially** on the shared tree, and restore after each one. A probe left
un-restored poisons every subsequent probe.

## 6. The two metrics

```
repair%  = (repair items this phase) / (beads this phase)        healthy ≤ 10%
hollow%  = (hollow beads) / (beads sampled, RED:n/a excluded)    healthy ≤  5%
```

Both go in the phase report, the Slack notify, and the run carrier — **always, including a
clean run.** They are guidance, not gates: they steer the NEXT cycle's spec pressure.

| Breach | Reading | Response |
|---|---|---|
| `repair%` > 10% | Phase 1's contracts are not carrying their weight | Tighten elements 1–3 and 6; add an adversarial round |
| `hollow%` > 5% | Tests are being written to pass, not to catch | Tighten element 4; raise the sample above 20% next cycle |
| Sustained breach of either | The gate-free build phase is not paying for itself in this territory | Fall back to the **per-landing-check variant** for `hot-tier` beads only — gates return inside Phase 2 for the hot tier, the cold tier stays gate-free |

The fallback is documented, scoped and reversible. It is not a rollback of ac-loop-2 — it is
the dial the two metrics exist to move.
