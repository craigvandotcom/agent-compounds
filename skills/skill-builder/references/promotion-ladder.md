# The skill-content promotion ladder (three tiers, two directions)

How a piece of knowledge enters, rises, falls, and leaves a skill — **without ever being lost.**
This is the operable form of the promotion/demotion doctrine the skill-diet plan's WS1 calls for;
it specializes `context-engineering` § PROMOTION & DEMOTION (SKILL.md:243–267) for the skill layer.

## ToC
- The three tiers
- The ladder (asymmetry: up needs proof, down needs disuse)
- What routes through the holding zone (and what skips it)
- Holding-zone mechanics (review-by, churn, exit)
- Reconciliation with delete-outright (git is the archive)
- How we decide movement — metrics & the measurement problem
- Integration with the existing system

## The three tiers

| Tier | What it is | Load cost | Holds |
|---|---|---|---|
| **1 · SKILL.md core** | loaded every invocation | paid every run | enforcement + orchestrator content the model needs *each time* |
| **2 · `references/`** | loaded on demand | free until read | proven-useful detail a stage or sub-agent pulls when relevant |
| **3 · holding zone** (the `MAINTENANCE.md` holding-pen) | never loaded at runtime | ~zero | content **not in active use, pending a decision** — either incubating up or aging out |

The holding zone is one concept serving both directions: content on its way **up** (a speculative
addition that hasn't earned a higher tier) and content on its way **out** (removed from active use,
quarantined before deletion) both sit here. It is a *buffer*, never a permanent store.

## The ladder

```
              INSERTION  (rise needs PROOF)              DELETION  (fall needs only DISUSE)

   ┌─ 1 · SKILL.md core ───────  proof gate:                     no longer needed every run
   │                             N green runs that EXERCISE it           │
   │                             / probe-verified fact                   ▼
   │                             / Craig sign-off (conductor core)       │
   │                                     ▲                               │
   ├─ 2 · references/ ─────────  demonstrated useful ≥N times            no longer pulled at all
   │                                     ▲                               ▼
   ├─ 3 · holding zone ────────  incubating (proposed, unproven)   quarantined (review-by timer)
   │                                     ▲                               │
   └─ (new signal enters here) ──────────┘                              ▼
                                                            git delete  (cut-log entry + SHA)
```

**The references→core rung, spelled out** (the diagram's tier-1 proof gate, stated in prose so it
reads as a rule and not just a picture): promoting content into **SKILL.md core** requires N green
runs that exercise it, or a probe-verified fact — and for **conductor-core** specifically, Craig's
sign-off on top of that evidence. Promotion into `references/` needs the evidence alone; no sign-off
is required below tier 1.

**The load-bearing asymmetry:** *going up requires evidence; going down requires only that the
content stopped being used.* That is what makes the ladder safe — promotion is hard (you must prove
worth), demotion is easy (disuse is enough), and **nothing unique is deleted without first spending
a timed window in the holding zone where it can be caught.** Easy to demote, impossible to vaporize.

## What routes through the holding zone — and what skips it

The holding zone would drown in noise if *every* removal passed through it. Two removals skip it,
because no knowledge is at risk:

- **Extract** (core → references): still needed, just not every run → straight to `references/`,
  leave a pointer. No holding zone.
- **Delete a duplicate** (a verbatim copy whose twin survives elsewhere): hard-delete immediately —
  the knowledge lives on in the twin.

The holding zone is **mandatory only for the "delete *unique* content" path** — a rationale, an
incident, a superseded-but-maybe-useful block with no surviving twin. That is precisely the content
whose loss can't be undone by pointing at a copy, so it earns the timed buffer.

## Holding-zone mechanics

Every holding-zone entry (in the skill's `MAINTENANCE.md` § Holding pen) carries:
- **what** it is + **where it came from** (section, date).
- a **`review-by` date** (default window: **one dream cycle ≈ 1 week**, or 30 days for low-traffic
  skills — tune per skill).
- a **default resolution** (`promote` or `delete`).

**Exit is signal-driven, evaluated by the next hygiene pass or dream cycle that reaches the skill:**
- **Reclaimed / re-added** before `review-by` → it churns back UP (promote to references/core per the
  proof rules); the churn detector notes "this keeps coming back — home it properly."
- **Unclaimed past `review-by`, no churn signal** → **git-delete** with a **cut-log entry** recording
  what/why/SHA. The cut-log entry IS the conservation record (satisfies the plan's WS3.1
  conservation check by construction — every removal maps to a destination, here "deleted @ SHA").

## Reconciliation with delete-outright (git is the archive)

The skill-diet plan ratified **Assumption 4: delete-outright — git history is the archive, no
archive file is created.** The holding zone does **not** violate this, because it is **transient, not
an archive**: delete-outright *fires at the end of the holding period*. git remains the true archive —
nothing is ever truly lost, everything is recoverable by SHA. The holding zone's only job is to make
recently-removed knowledge **discoverable for a window** without git-archaeology. Read the two
together as: *git = never lost; holding zone = easily reclaimable for a window, then git-only.*

## How we decide movement — metrics & the measurement problem

**The honest constraint (confirmed against current industry practice, 2026): there is no
per-line usage telemetry.** A skill's SKILL.md is read into the model's context; nothing exposes
which lines the model actually attended to or relied on. "Loaded" is not "used" — core loads every
run regardless. Interpretability that could trace causal line-level influence (attention
introspection, attribution graphs) is research-only, needs model-specific tooling + GPU, and no agent
harness surfaces it — do NOT try to adopt it. Everything the industry does is a **behavioral proxy**:
does removing the content change the *output* (ablation), does it *activate* when it should (trigger
tests), does it show up in *logs* (file-touch, recurrence). We decide movement the same way.

**For promotion (does this earn a higher tier?) — require EVIDENCE:**
- **Ablation / N green runs that EXERCISE the mechanism** — the **gold standard** (the RED-GREEN test,
  `references/testing-patterns.md`; corroborated as the industry's first-class eval leg). Withhold the
  *section*, run a scenario that should need it; quality drops → it earned its tier; nothing changes →
  it didn't. Caveat: a single-scenario PASS is a false-negative risk — use ≥2 repeat-cycle scenarios.
- **Recurrence count** — `dream` Phase 2 already counts how often a lesson recurs across sessions;
  ≥N recurrences justifies `references/`. This is the **cheapest legitimate substitute** for a usage
  signal and is already built — prefer it before spending on ablation. The recurrence signal itself
  is sourced from per-skill `FRICTIONS.md` sensor logs (`references/friction-capture.md`), whose
  `Σ(impact × frequency × recurrence)` weighting (dream Phase 2 / W4.5) surfaces over-bar clusters as
  skill-improvement beads — friction-capture is the sensor, this ladder is the decision.
- **Probe-verified environment fact** — a claim a script confirms true (a tool's real behavior).

**For demotion (has this fallen out of use?) — DISUSE proxies are enough (no proof needed to fall):**
- **File-touch / uptake (the one real usage signal we have)** — for a **`references/` file**, an
  agent's own tool-trace shows whether a run *opened* it. A reference nothing has opened across recent
  runs is a strong demotion candidate. This is log-derivable and honest (it measures *opened*, not
  *relied-on*, but it's the closest thing to real telemetry). Worth instrumenting **only for
  high-traffic conductor skills** where guessing wrong is expensive — not the long tail. (Does NOT
  apply to tier-1 core, which loads unconditionally — core is judged by ablation, not uptake.)
- **Still-cited check** — grep the registry: zero inbound references + not exercised by recent runs → demote.
- **Recurrence decay** — a lesson whose recurrence count has gone cold.
- **Archetype expectation** — an orchestrator's every-run enforcement stays; a knowledge skill's
  detail no stage pulls demotes freely.
- **Churn** (`git log -S`) — repeatedly added-and-removed = contested; use it to flag *sticky
  sediment* and route it (home it properly, don't re-cut). ⚠️ **Novel, un-validated proxy:** no
  industry source treats git-churn as a content-*value* signal — it is our own heuristic; treat it as
  a flag to investigate, never as sole grounds to promote/delete. Pilot it, don't trust it blind.

**Also eval the description layer (routing), separately from content tiers:** a trigger
**precision/recall list** — a "should-activate" set of natural prompts + a "should-NOT-activate"
exclusion set, run against the description (obra/superpowers pattern, `testing-patterns.md`). Cheap,
prose-only, catches the most common real failure: under/over-triggering. Do this for every skill.

**What to actually run, cheapest-first:** (1) trigger precision/recall list — near-zero cost, every
skill; (2) recurrence-count before promotion — already built; (3) RED-GREEN ablation on a small
golden scenario set before references→core — the proof gate; (4) file-touch uptake — high-traffic
conductors only; (5) generic LLM-judge task-eval harness (promptfoo/DeepEval) — only if you already
run one for other reasons, not worth building for skill governance alone; (6) interpretability — never.

**Rule of thumb:** promotion is gated on *demonstrated* value (ablation/recurrence); demotion runs on
*absence of* value signal (disuse). When you genuinely can't tell, **demote — don't delete**: the
holding zone exists precisely so an uncertain call is reversible.

## Integration with the existing system

- **Tier 3 lives in `MAINTENANCE.md`** (§ Holding pen) — per-skill, co-located, already built
  (`references/maintenance-ledger.md`). No new file.
- **The move-out decision tree** (`structure-standard.md` § The move-out decision) is the demotion
  half of this ladder; this doc adds the *proof-gated promotion* half + the *timed holding zone*.
- **The hygiene-pass** applies the ladder section-by-section; the **cut-log** records deletions;
  the **churn detector** (`git log -S`) supplies the contested/settled signal.
- **The plan's WS1** should cite this file as its promotion-ladder deliverable rather than authoring
  a duplicate; the only genuinely-new rung it adds on top is the conductor-core **Craig sign-off**.
