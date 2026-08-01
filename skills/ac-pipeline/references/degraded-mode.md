# Degraded single-conductor mode (bd-nreuv)

**Read this only when the probe has already tripped** — the healthy path pays nothing but the
one-clause probe in each spine's own SKILL.md. Owners: `ac-bead-refine`, `ac-review`,
`ac-qa-browser` (and any phase skill whose workflow mandates a panel or a conductor/worker
fan-out). One probe, one stamp grammar, three skills — defined once here so they can't drift.

**The purpose is honesty, not permission.** A capability-starved run should produce a *reduced
but truthfully labelled* result instead of either nothing or a full-rigor claim it didn't earn.
The thing that must never happen is the one that did: 15+ children across three stages silently
ran their lenses sequentially in-context, improvised a prose disclosure each time, and emitted
artifacts (`refine-full` stamps, review VERDICTs) that were **indistinguishable from a real
panel pass**. A degraded run that isn't machine-detectably marked as degraded is worse than a
failed one, because a failed one doesn't lie.

## ToC
- 1. The capability probe (at skill entry, before any fan-out)
- 2. The sequential-lens path — what it does and does not buy
- 3. Stamp grammar (machine-readable, additive, one form for all three skills)
- 4. refine-light-solo — what the light path means with no distinct subagent

## 1. The capability probe (at skill entry, before any fan-out)

Two independent triggers. Either one puts you in degraded mode:

- **Structural — no `Task` tool.** If `Task` is not in your available tool list, you were loaded
  *inside* a subagent and cannot spawn anything. This is the common case: the panel was never
  going to happen, so don't attempt it and don't discover it halfway. Check at entry.
- **Runtime exhaustion — spawns keep failing.** API `529 Overloaded`, rate-limit, or timeout on
  the spawn itself. Bounded ladder, in order, stopping at the first that succeeds:
  **full panel → smaller panel (drop the diff-conditional lenses first, never the core ones) →
  solo.** At most **2 retries per rung**, with backoff. Do not loop a rung indefinitely and do
  not skip a rung. Five consecutive 529s once took out a 7-dimension panel, its smaller-panel
  retry, a lean solo validator *and* the next child, leaving a batch's convergence ratio
  permanently unmeasured — an unbounded retry converts starvation into a lost measurement.

**A caller that knowingly delegates a conductor skill into a child SHOULD pass `DEGRADED=1`**;
its absence is never evidence of capability. The probe is yours to run, always.

**Fail-safe:** if you only discover mid-run that you cannot spawn, you were degraded from the
start. Stamp accordingly and say so — never retro-narrate a solo run as a panel run.

## 2. The sequential-lens path — what it does and does not buy

Run the same lenses, in the same order, **sequentially in your own context**. Then state plainly:

- **Retained: lens CONTENT.** The questions each reviewer would ask still get asked, and that is
  where most of the value lives. This path is worth running.
- **LOST: adversarial independence.** Every finding and every severity now rests on one context's
  judgement. A solo reviewer cannot catch its own blind spot, and it cannot disagree with itself.
  This is not a formality: bd-hfdst **passed** a self-attested "mechanism traced at a named line"
  check with detailed but **WRONG** `file:line`s. Independence is what would have caught it.
- **AT RISK: coverage.** Sequential lenses run out of context long before a panel runs out of
  workers. A degraded `ac-qa-browser` pass once reported "exhaustive" while leaving 10–14
  registry journeys undriven (bd-0cfn8). So a degraded run MUST enumerate what it actually
  covered — see the `lenses`/`journeys` fields below. "Exhaustive" is a claim you have forfeited.

## 3. Stamp grammar (machine-readable, additive, one form for all three skills)

**Beads → add the `degraded-solo` label, ALONGSIDE the normal path label, never instead of it.**
So a degraded full refine is `refine-full` **+** `degraded-solo`.

- *Why additive rather than a `refine-full-solo` rename:* a renamed stamp silently breaks the
  `refine-full`/`refine-light` frequency series that LABEL-FREEZE exists to protect
  (`beads-standards` § LABEL-FREEZE explicitly permits *adding* a load-bearing label, and
  forbids repurposing one). Additive keeps every existing series intact, makes
  `path-label ∧ degraded-solo` a one-grep query, and needs exactly one new token for all three
  skills instead of a parallel vocabulary per skill.
- Named `degraded-solo`, not bare `solo`, to stay clear of `risk-solo`
  (`ac-pipeline/references/risk-classification.md`), which is unrelated.

**Non-bead artifacts → a REQUIRED field, present in both states** (an always-present field makes
its absence a detectable defect; an only-when-degraded field is indistinguishable from a writer
that forgot):

```
Degraded: no
Degraded: solo (trigger=no-task-tool|spawn-529|spawn-timeout; lenses=correctness,security,perf; journeys=7/21)
```

- `ac-review` report → in the header block, next to `**Range:**`.
- `ac-qa-browser` / `ac-qa-device` manifest + `QA_VALIDATION` report → top-level key.
- **Leave the `VERDICT:` token itself alone** — `APPROVED`/`NEEDS_DECISION` are parsed by
  `ac-loop` step 5 and by the verification gate; suffixing them would break those readers. The
  `Degraded:` field is the carrier, and a downstream consumer must read it before treating a
  `VERDICT: APPROVED` as a panel verdict.

## 4. `refine-light-solo` — what the light path means with no distinct subagent

**The problem.** `ac-bead-refine`'s light-path criterion #4 requires the mechanism trace to be
"confirmed by a single spawned adversarial subagent DISTINCT from the trace's author (never
conductor self-concurring)". With no `Task` tool that is **structurally unreachable**, and the
observed consequence was the worst of the three options: children stamped `refine-full` — the
*stronger* claim — because the light path was closed to them. The stamp misreported rigor upward.

**Rejected: let the conductor self-concur.** That deletes the only guard criterion #4 exists to
provide, on the exact failure it was written for (bd-hfdst's confidently wrong `file:line`).

**Ruling — substitute an EXECUTED witness for the human-shaped one.** What criterion #4 actually
buys is a check on the trace that is *independent of the author's belief*. A second agent is one
source of that; **execution is another, and a solo context has it.** So:

> **`refine-light-solo`** = criteria **#1–#3 unchanged** (hard gate, single-file scope,
> same-run <24h evidence), with **#4 replaced by an executed confirmation of the traced
> `file:line`**: a command whose output *differs* depending on whether that line is the
> mechanism — a failing assertion that flips on the fix, a probe, an instrumented log, a
> reverted-hunk re-run. Paste the command, its **verbatim** output, and its **exit code** into
> the stamp comment. A description of what the command would show does not count; an unexecuted
> claim is exactly the self-attestation being replaced.

- **Cannot produce such a check → the light path is CLOSED.** Run full `MIN_ROUNDS` and stamp
  `refine-full` + `degraded-solo`. The light path is never reached by having fewer options.
- Stamp = `refine-light` **+** `degraded-solo`, and the comment carries the #1–#3 fields plus the
  executed-witness block in place of the concurrence one-liner.
- **Why this is a real substitution and not a loophole:** it is strictly *harder* to fake than
  criterion #4. A second agent can be argued into agreement; a command that must actually run and
  produce differing output cannot. Independence is genuinely weaker — one context still chose the
  check — so the `degraded-solo` label stays mandatory and the result is never called a panel pass.
