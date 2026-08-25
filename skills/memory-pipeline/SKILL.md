---
name: memory-pipeline
description: Use when asking how the compounding system RUNS rather than where a fact goes — "how does memory actually work here", "what drains the dream queue", "why didn't that memory surface", "is the substrate healthy", "which lane does this belong in", "what earns a wiki page", "the nightly eval is red", "the docket is backed up". Covers the three compounding lanes (L3 memory, skill frictions, wiki synthesis), their executors, cadence, drains, and health surface. NOT the save-routing taxonomy or what loads when (that is context-engineering).
---

# memory-pipeline — how the compounding system runs

The operational architecture of the org's memory: three lanes that each turn raw
experience into something a future session can retrieve, and the machinery that keeps
them draining.

## The boundary (read this before adding anything here)

`context-engineering` is the **constitution** — where a durable item goes (`{type} ×
{domain}`), what loads when (L0–L4), which layer an instruction belongs in. This skill is
the **operations manual** — who runs, on what cadence, what drains what, and how to tell
whether it is working. Doctrine questions go there; "is it running" questions come here.

Never restate the taxonomy, the L0–L4 table, or the placement ladder in this skill. Cite
them. One source, per `context-engineering` § Common Mistakes.

| Skill | Owns | This skill defers to it for |
|---|---|---|
| `context-engineering` | the constitution | taxonomy · homes · L0–L4 · placement · altitude · promotion doctrine |
| `reflect` | session-end capture | how a single session's lessons are extracted and routed |
| `dream` | synthesis · lint · judge · propose | the cycle's phases, the auto/gated split, REVIEW |
| `wiki` | synthesis pages | page types · frontmatter · citation rule · gardening |
| `skill-builder` | the skill corpus | friction capture · maintenance ledger · hygiene-pass |

## The three lanes

Every lane has the same four beats — **capture → refine → drain → enforce**. A lane is
healthy when all four run; it fails silently when the drain stops while capture keeps
going.

| Lane | Atom | Capture | Refine | Drain | Enforce |
|---|---|---|---|---|---|
| **L3 memory** | a fact/rule/decision in `memory/auto/` | `reflect` at session end; nightly context-mining | `dream` Phase 2 synthesis | `dream` REVIEW + the daily queue job | `memory-lint.py` |
| **Skill frictions** | a `FRICTIONS.md` entry in a skill | the skill's own run, via `reflect` | weighting by impact × frequency × recurrence | `skill-builder` hygiene-pass; promotion to skill text | `lint.sh` |
| **Wiki synthesis** | a cited page in `wiki/` | promotion from clustered facts | monthly garden pass | hallucination audit | `memory-lint.py` (wiki kind) |

**The lanes are not parallel copies — they differ by what the atom is FOR.** An L3 fact
answers a question a future session will ask. A friction entry records that a *procedure*
misbehaved, so it is evidence for changing the procedure, not knowledge to retrieve. A
wiki page integrates many facts into one narrative a human reads. Routing an atom into
the wrong lane is the commonest structural error: see `references/lane-contracts.md` §
Choosing a lane.

## When to Use

- Diagnosing the substrate: recall got worse, the nightly is red, the docket is stale.
- Deciding which lane an atom belongs in, or what earns a wiki page.
- Wiring or changing a job that feeds or drains a lane.
- Onboarding to how the compounding system fits together.

**When NOT to use:**
- Where does this fact go? → `context-engineering`
- Capture this session's lessons → `reflect`
- Run the cycle / review proposals → `dream`
- Write or garden a page → `wiki`
- Fix a skill's own text → `skill-builder`

## Supporting files (load on demand)

| File | When to read |
|---|---|
| `references/lane-contracts.md` | routing an atom · what earns a wiki page · what each lane guarantees |
| `references/cadence-and-jobs.md` | which job runs when · what it drains · run markers |
| `references/health-surface.md` | the substrate looks wrong · a gate is red · before trusting a green signal |

## Health surface

Five commands answer "is it working". Run them before believing any narrative about the
substrate — including this skill's.

```bash
python3 infrastructure/scripts/health/memory-lint.py        # substrate integrity
python3 infrastructure/scripts/health/wiki-metrics.py       # governance metrics, docket age
/usr/bin/python3 infrastructure/retrieval-evals/run-evals.py # can the hook still FIND things
/usr/bin/python3 infrastructure/dream-cycle/classify.py --dir <proposals-dir>
/usr/bin/python3 infrastructure/dream-cycle/file-beads.py --dry-run  # is anything undocketed
```

Interpretation, thresholds, and the traps each one hides: `references/health-surface.md`.

## Failure modes

- **A green canary does not mean the right thing arrived.** Injection health proves the
  pipe carries something; it says nothing about relevance. Only the retrieval eval
  measures whether the *correct* memory surfaces. Recall can rot for weeks behind a green
  dot.
- **Capture outruns drain.** Writing more memory is the easy half. When the drain stalls,
  the queue silently becomes a backlog of decisions nobody is making — and every new
  proposal makes the next review more expensive.
- **Never enforce against a corpus you have not cleaned.** Promoting a lint warning to a
  violation, or ratifying a baseline, freezes the current state in as correct. Clean
  first, then tighten — in that order, in separate commits.
- **A proposal decays while it waits.** Line numbers drift, counts grow, and the premise
  can go false. Re-derive a queued proposal's claims from disk before applying it; the
  judge's verdict was true on the day it was written.
- **Retrieval is the ceiling on everything else.** No capture, synthesis, or gardening
  improves a session that never sees the result. When recall and hygiene compete for
  attention, recall wins.
