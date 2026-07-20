# Per-skill friction capture — FRICTIONS.md

The pressure sensor that feeds the promotion ladder. `promotion-ladder.md` already covers
*how we decide movement* (recurrence-counting, the measurement problem, the cheapest-first
metric order) — this file does not restate that; it defines the log those metrics read from.

## ToC
- What FRICTIONS.md is
- The entry schema (+ example)
- The per-skill template
- How it feeds promotion
- Deduplication (W4.2)
- Routing (brief pointer)

## What FRICTIONS.md is

`skills/<name>/FRICTIONS.md` is a per-skill **sensor log** — a debugging/logs file for that
skill, not a knowledge store and not a work-surface. Its only job: capture root frictions
(things that went wrong, cost time, or needed a workaround while the skill was in use) so
promotion/demotion becomes data-driven instead of vibes-driven.

- **Tier-3-adjacent** — never loaded with SKILL.md, never referenced from the spine (same
  discipline as `MAINTENANCE.md`; `validate-skill.sh`'s orphan check should skip it by name too).
- **One per skill, created lazily** on first captured friction — no empty-file sprawl across
  the registry's skills.
- **Sibling, not duplicate, of `MAINTENANCE.md`:** `MAINTENANCE.md` is the *shape*-hygiene
  work-surface a hygiene-pass drains (`references/maintenance-ledger.md`). `FRICTIONS.md` is
  the *friction* sensor log a promotion pass reads — different consumer, different question
  ("is this skill shaped right?" vs "is this skill causing recurring pain?"). Same file-format
  discipline (frontmatter + append-only entries, lazy creation, sidecar, no runtime load).
- **Feeds, does not decide:** raw entries here are input; the actual promotion decision still
  runs through `promotion-ladder.md`'s proof gates. This file only makes the recurrence signal
  that gate already relies on cheap to compute.

## The entry schema

| Field | Meaning |
|---|---|
| `id` | short kebab slug, minted per the dedup rule below (e.g. `bug-lane-claim-race`) |
| `skills` | list of skill names this friction touches — a friction can span >1 skill; it is counted **once per id** regardless of how many skills list it |
| `impact` | size estimate: `S` \| `M` \| `L` |
| `frequency` | est. how often it bites: `rare` \| `occasional` \| `frequent` \| `every-run` |
| `recurrence` | count of times this exact friction has been re-observed — the promotion-weight multiplier |
| `related` | list of related friction ids — the on-insert graph, a byproduct of the dedup judgment |
| `first_seen` / `last_seen` | dates |
| `proposed_fix` | one-line pre-drafted fix, ready to paste into a bead if this cluster gets promoted |
| `stage` | the pipeline stage/skill run that emitted it (e.g. `ac-loop`, `hygiene-pass`, `dream`, `curate`, `reflect`, `manual`) |
| `status` | `open` \| `promoted` \| `resolved` \| `wontfix` |
| `narrative` | prose — what happened, why it's friction |

**Example entry:**

```
## bug-lane-claim-race
- skills: [ac-loop]
- impact: M
- frequency: occasional
- recurrence: 3
- related: []
- first_seen: 2026-06-10
- last_seen: 2026-07-18
- stage: ac-loop
- status: open
- proposed_fix: claim the bead before the ready-scan re-reads, not after — close the read-then-write gap.
- narrative: two concurrent loop instances both selected the same bug-lane bead because the
  claim write landed after the next instance's ready-scan re-read the same snapshot; second
  claim silently overwrote the first, causing duplicate work on the same bead.
```

## The per-skill template

Copy-paste into `skills/<name>/FRICTIONS.md` on first captured friction:

```markdown
---
skill: <name>
created: <YYYY-MM-DD>
last_pass: <YYYY-MM-DD or "never">
entries: <n>
---

# <name> — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see friction-capture.md
     § Deduplication) — do not append a duplicate root friction under a new id. -->

## bug-lane-claim-race
- skills: [<name>]
- impact: M
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: <YYYY-MM-DD>
- last_seen: <YYYY-MM-DD>
- stage: <emitting stage>
- status: open
- proposed_fix: <pre-drafted fix>
- narrative: <what happened, why it's friction>
```

## How it feeds promotion

`dream` Phase 2 (**W4.5, not yet built**) is the consumer: it weights `Σ(impact × frequency ×
recurrence)` per `id` across every `FRICTIONS.md` that lists it (once per id, per the schema),
and a cluster over the bar becomes a `skill-improvement` bead carrying the cluster's
pre-drafted `proposed_fix` as a starting point. This file only supplies the log; the weighting
engine, thresholds, and bead-authoring flow belong to W4.5 — don't build them here.

## Deduplication

Dedup is **ID + agent-judgment, not embeddings.** On capture, the agent reads the target
skill's existing `FRICTIONS.md` entries and judges same-vs-new against them directly:

- **Same root friction** → reuse the existing `id`, bump `recurrence`, update `last_seen` and
  (if sharper) `proposed_fix`.
- **New root friction** → mint a new kebab-slug `id`.

Per-skill sets are small (~5-30 entries), so an agent reading and judging the whole file
directly is cheap and reliable — no index is needed at this scale. `qmd` vector-search is
**demoted to a secondary "candidate-pull" role only**: it may surface maybe-related entries
(e.g. across skills, when the friction might already be logged elsewhere) for the agent to
read and judge — it never decides same-vs-new itself. The `related` field is a free byproduct
of this judgment: whichever ids the agent compared against (whether it judged same or new)
get recorded there, building the graph without extra work.

## Routing (brief pointer)

Frictions route to a skill's `FRICTIONS.md` via ac-land's tier-router (**W4.3, not yet
built**) — full routing logic lives there. The ambiguity defaults it will apply:

- **Uncertain, loop-mechanics-flavored** → default sink is `ac-loop`'s `FRICTIONS.md`.
- **Uncertain, general** → `memory/auto/` (the existing catch-all substrate).
- **Genuinely cross-cutting** → record once in the *primary* skill's `FRICTIONS.md`, with a
  `see <id> in <primary>` pointer entry in each secondary skill's file (never a full copy).
</content>
