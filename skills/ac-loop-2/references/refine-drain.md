# Refine-all — drain semantics, grouping, order

Phase 1's refine step. The spine states the invariant; this file states how to execute it.

## The invariant

**Width bounds CONCURRENCY, never COVERAGE.** Dispatch refine children in successive waves
of `width` until the unrefined non-`human-gate` ready set is EMPTY. Re-query between waves —
children file beads, and more arrive mid-phase.

**The conductor decides ORDER, never MEMBERSHIP.** Never narrow the set by priority, type,
label, age or theme.

An undrained set at the barrier is a **C3 stop naming every remaining id**. Never a silent
selection.

**Priority does not rank value on a mixed board — it ranks who filed the bead.** Human
reports and agent-filed pipeline findings use different default priorities, so any
`priority <= N` cut selects by authorship. Do not cut on it.

## Grouping

Grouping exists ONLY for context locality: a child holding one subsystem's beads shares
anchors, prior decisions and vocabulary, so its contracts come out cheaper and more
consistent.

Territory cannot be the key — the territory manifest is contract element 3, an OUTPUT of
refinement. Group on what is knowable BEFORE refining:

1. **By epic** — a bead with a parent joins its epic's group.
2. **Orphans → by cited file path** — grep the bead body for paths, cluster with
   `ac-pipeline/references/board-scan.md` § File-cluster density applied to those greps
   rather than a formal `## Delivers`, which unrefined beads rarely carry.
3. **Residual** — no epic, no cited path — one group, drained last.

**Grouping PARTITIONS; it never FILTERS.** Every bead lands in exactly one group. Every
group is drained. No group is skipped, sampled or deferred.

## Order

Default **oldest-bead-first**, which prevents starvation. Territory conflicts SEQUENCE a
group, never drop it.

## Barrier assertion

Print at the Phase-1 barrier, every run, zeros included:

```
refine-drain: <N> unrefined at phase open · <R> refined · <H> held (contract gap) · <U> STILL UNREFINED
```

`U > 0` is a reported stop condition, never a default. List every remaining id in the
sitting docket.
