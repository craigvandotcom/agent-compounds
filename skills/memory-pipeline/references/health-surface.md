# Health surface

How to tell whether the substrate is actually working, and which green signals lie.

- [The five checks](#the-five-checks)
- [What each green actually proves](#what-each-green-actually-proves)
- [Diagnosing "the memory didn't surface"](#diagnosing-the-memory-didnt-surface)
- [Measuring a retrieval change](#measuring-a-retrieval-change)
- [Traps](#traps)

## The five checks

```bash
# 1. Substrate integrity — orphans, dead index links, dead wikilinks, frontmatter
python3 infrastructure/scripts/health/memory-lint.py

# 2. Governance — docket age, staleness of the strategy/now files, hygiene rollup
python3 infrastructure/scripts/health/wiki-metrics.py

# 3. Retrieval quality — the only check that measures RELEVANCE
/usr/bin/python3 infrastructure/retrieval-evals/run-evals.py

# 4. Queue composition — how much of the docket is actually human-gated
/usr/bin/python3 infrastructure/dream-cycle/classify.py --dir infrastructure/dream-cycle/proposals/<date>

# 5. Docket completeness — is any gated proposal missing its bead
/usr/bin/python3 infrastructure/dream-cycle/file-beads.py --dry-run
```

Checks 1, 2 and 5 are read-only. Check 3 writes a dated report and, without
`--accept-baseline`, never mutates the baseline. Check 4 is read-only unless
`--apply-tier0` is passed.

## What each green actually proves

Precision here is the whole point — most substrate incidents are a green signal being
read as a stronger claim than it makes.

| Signal | Proves | Does NOT prove |
|---|---|---|
| memory-lint green | every atom is indexed, linked, and parseable | that any atom is correct, current, or retrievable |
| hook health green | injection ran and returned something | that what it returned was relevant |
| retrieval eval exit 0 | no query that hit at baseline-time now misses | that recall is *good* — only that it did not regress |
| `cass search` returns hits | the archive is queryable | nothing about the memory substrate; different system |
| a proposal marked `applied` | the frontmatter was flipped | that the edit landed — verify the target |
| lint.sh green | the registry's structural rules hold | that skill *content* is true |

The load-bearing distinction: **liveness vs relevance.** memory-lint and hook-health are
liveness. Only the retrieval eval measures relevance, and it is the one that costs a
nightly run — which is exactly why it is the one that gets ignored when it goes red.

## Diagnosing "the memory didn't surface"

Work in this order; each step separates a different failure.

1. **Does the doc exist and is it indexed?** `qmd search "<terms>" -c memory`. No hit →
   the atom is missing or unindexed; this is a capture problem, not retrieval.
2. **Does the CLI find it with the full question?** `qmd query "<the actual prompt>"`.
   Found here but not injected → the hook's retrieval is at fault, not the index.
3. **Does the hook find it?** Import `retrieve()` from `.claude/hooks/memory-retrieval.py`
   and call it with the same text. It is side-effect-free and safe to call directly.
4. **Compare the candidate pool against the top-5.** If the target is in the pool but
   ranked out, it is a ranking problem. If it is absent from the pool, it is a
   candidate-selection problem — the search window, the term budget, or the filter.

The distinction in step 4 decides the fix, and they are not interchangeable: widening a
window recovers atoms the ranker never saw, while re-ranking only reorders what it did.

## Measuring a retrieval change

Never adopt a retrieval change on a single run, and never on one query.

- **A/B side-effect-free.** Copy the hook, patch the copy, and score both by importing
  `run-evals.py`'s `active_entries` / `parse_qrels` / `run_retrieval` /
  `score_correctness`. This writes no report and touches no baseline.
- **Three runs minimum, per variant.** The eval has real run-to-run jitter; a change under
  roughly two points is not a signal.
- **Report the trade honestly.** Count queries fixed AND queries broken, not just the net.
  A change that fixes many and breaks a few is usually right, but the few must be named
  and filed, never absorbed into an average.
- **Check latency.** The hook runs on every prompt. Measure median and p90, and re-measure
  with the variant order swapped — the first measurement in a contended shell routinely
  reads twice as slow as the truth.
- **Re-ratify the baseline only after the fix lands**, never before. Accepting a baseline
  over a known regression writes that regression in as the new normal.

## Traps

- **The self-contradictory recommendation.** A health tool can tell you to wait for a
  condition that already holds. Check the condition yourself before following the advice.
- **A probe timeout is not a fault.** A check that cannot complete within its budget on a
  large corpus reports "unverified", and folding that into a risk level makes the tool
  permanently red — which trains everyone to ignore it. Verify independently before
  believing either the red or the green.
- **A count in a proposal decays.** "5 files" becomes 11 while the proposal waits. Re-derive
  before applying, and treat the original number as a claim about a past day.
- **Warning-to-violation promotions are corpus-wide.** Before tightening any check, count
  how many existing files would fail it. The right order is always: clean the corpus, then
  tighten, in separate commits.
- **Docket age beats docket size.** Twenty fresh proposals are healthy; three 30-day-old
  ones mean the drain is broken. Age is the signal that a lane has stopped draining.
