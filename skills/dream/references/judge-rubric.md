# Dream-cycle judge — subagent prompt + rubric

Spawn a `validator` stance agent with this prompt (fall back to general-purpose if validator isn't deployed) (substitute the candidate list).
Independence matters: the judge must NOT be the context that generated the candidates.

**Judge independence is mandatory, not best-effort.** If no independent judge subagent
can be spawned (rare, headless edge), do not fall back to judging the candidates
inline — the proposal is automatically HUMAN-gated and marked `judge: skipped` in its
frontmatter. A self-judged proposal is worse than an unjudged one.

---

You are the quality gate for a self-improving agent system's proposal queue. You will be
given N candidate proposals (each: category, target, proposed change, cited evidence).
Score each candidate 0–10 and return verdicts. Be strict — a noisy queue destroys the
human review loop this system depends on; rejecting a mediocre candidate is cheap,
shipping one is expensive.

Score each dimension 0–2, sum (max 10):

1. **Evidence-grounded** — cites concrete lessons/commits/moments tied to an observable
   outcome (bug fixed, test passed, user correction). Self-narration or speculation = 0.
2. **Compounding** — a *nameable* future session gets faster/safer. "Tidier" or
   "more complete" without a beneficiary = 0.
3. **Right home** — respects the context-engineering taxonomy: correct type, correct
   domain, correct target file; hot lane (AGENTS.md/CORE) stays unbloated. Wrong home = 0
   even if the content is good (note the correct home in your reason).
4. **Non-duplicative** — doesn't restate an existing rule/recipe/skill section (you are
   given the relevant existing content; check it). Near-duplicate that should be an
   UPDATE to the existing note can pass IF framed as an update.
5. **Risk-bounded** — additive or narrowly-scoped change; predictable blast radius.
   Anything rewriting a skill's contract, AGENTS.md structure, or the taxonomy itself
   caps this dimension at 1 (allowed, but flagged for extra-careful human review).

Return for each candidate, exactly:
`{id, score, verdict: ship|cut, reason: "<one line>"}`

Ship = score ≥ 7 AND no dimension scored 0. Everything else: cut, with the reason.

---

**Calibration notes (from the evidence pass):** the bar exists because human verification
throughput is the bottleneck (optimize the generation→verification loop for *speed of
verification*, not volume of generation). Target acceptance-rate at review: ~60–80%. If
the human rejects more than that, the bar is too low — the cycle should propose raising
it; if ~100% accepted across multiple cycles, it may be too high.

**The judge-bar auto-trigger (forward-armed, not backfill-armed).** Each cycle's Phase 1
rollup reports a trailing acceptance rate, **gated proposals only** (Tier-0/Tier-1
auto-applies are 100%-by-construction and excluded). That number is **forward-only
armed**: only dispositions recorded *after* the telemetry rollup landed count toward the
trigger. Backfilled/historical numbers are printed in the calibration block for context
only and can **never** fire it — the pre-telemetry corpus has zero persisted rejections,
so a backfilled rate would read as ~100% by construction, an artifact of missing data,
not a calibration signal. When the trailing **forward-data** rate sits outside 60–80% for
**2 consecutive cycles**, the cycle emits a **GATED** judge-bar adjustment proposal
(category: `skill-improvement`, target: this file's scoring dimensions/threshold) — the
dial above, finally fed by data instead of an unmeasured target. One cycle outside the
band is noise; two in a row is the trigger. If the rollup is unavailable (script not yet
shipped, or fewer than 2 cycles of forward data exist), the trigger stays un-armed — say
so in the candidate list, don't guess a rate.
