---
name: wiki
description: Use when writing, updating, or gardening wiki synthesis pages — concept, entity, topic, or contradiction pages that integrate multiple atomic facts and decisions into one coherent, cited narrative. Triggers on "wiki page", "synthesis page", "seed a wiki page", "garden the wiki", "concept page", "entity page", "contradiction page", "write X up as a wiki page", "dedupe the wiki", "WIKI.md front door", "weekly distillation", "STRATEGY.md decisions log". NOT for saving one fact/rule/decision (context-engineering routes those) or session-end capture (reflect) — a wiki page is a DERIVED view over facts already saved there.
---

> **Shared skill (agent-compounds).** Symlinked into projects via `deploy.sh` — this is
> the single source of truth; edit here, not in a consumer copy. Method-only and
> portable (no project facts).

# wiki — the synthesis layer

**Purpose:** write, update, and garden the org's synthesis pages — the "wiki" in the
Karpathy-pattern sense: prose that integrates many atomic facts/decisions into one
coherent, navigable narrative. Not a new source of truth; a **derived, regenerable
cache** over the substrate that already exists.
**Constitution:** `../context-engineering/SKILL.md` (load it first — WRITE taxonomy,
homes, PLACEMENT/ALTITUDE all come from there; this skill is the `synthesis` type's
method).
**Evidence base:** `references/research-basis.md` — distills the field research + our
internal audit; read before seeding pages or designing a garden pass.
**Status:** MVP (schema layer only — Phase 3 item 0 of
`infrastructure/plans/memory-wiki-upgrade.md`; the pages themselves are item 1, not yet
seeded)

---

## When to Use This Skill

**Intent Triggers:**
- Drafting a new synthesis/concept/entity/topic/contradiction page
- Updating an existing wiki page with new source material
- Running a dedupe/merge/prune/staleness pass over `wiki/`
- The weekly distillation cadence (STRATEGY.md decisions log, NOW.md refresh)
- Deciding whether new material becomes a new page or an update to an existing one

**When NOT to Use:**
- Saving a single fact, rule, decision, or recipe → `context-engineering` routes it
- End-of-session capture → `reflect`
- Reading/browsing pages (no skill needed — `qmd query` or open the file)

---

## Page types

| Type | It is… | Example |
|---|---|---|
| **concept** | an idea/pattern that recurs across facts/decisions | "the flywheel", "low time preference" |
| **entity** | a named thing with a lifecycle (product, agent, system) | "Body Compass product thesis", "the agent org" |
| **topic** | a bounded subject area integrating several concepts/entities | "the content engine", "health protocol stack" |
| **contradiction** | two or more sourced claims that disagree, recorded not hidden | "unsit-app branch doctrine vs BCA doctrine" |

One canonical page per concept — kebab-case filename, `<domain>/wiki/<slug>.md`
(`neometa/wiki/` is the first and only live domain; other domains get one only when
they earn it, per context-engineering's "no slot → flag a taxonomy bug, never invent a
folder" rule).

## Frontmatter contract

```markdown
---
title: <human-readable title>
type: concept | entity | topic | contradiction
sources: [<fact/decision/doc slugs this page distills>]
related: [<other wiki page slugs>]
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
confidence: high | medium | low
trigger: <when should an agent load this page — the retrieval-trigger description>
status: draft | canonical
---
```

`trigger:` is not decorative — it's Devin's structural idea (see
`references/research-basis.md`): author *when this should surface* explicitly, don't
make the agent infer relevance post hoc. Write it the way you'd write a skill's
`description:` trigger clause.

## THE CITATION RULE

**Every claim in a wiki page carries a `[[wikilink]]` to the fact, decision, or source
it comes from.** Pages are DERIVED views, never a source of truth — the atomic facts in
`<domain>/memory/auto/`, the decisions in `alignment/decisions/`, and the raw sources in
`references/`/`knowledge/` remain canonical. A sentence with no citation trail is not
synthesis, it's a claim with nowhere to verify it — cut it or find its source first.

This is the single most validated mechanism in the field evidence (GitHub Copilot's
production A/B test: citation-verified memory beat uncited memory on every measured
metric, p<0.00001 — see `references/research-basis.md`). It is also the guard against
hallucination laundering: an agent re-reading its own uncited synthesis with full
confidence is how a wiki quietly becomes fiction.

## Create-vs-update judgment

**Dedupe-over-append at the page level, same as facts.** Before drafting a new page:
`qmd search`/`grep` the `wiki/` dir for an existing page on the same concept. Found one
→ update it (new sources, revised claims, `updated:` bump) — never create a
near-duplicate "v2" page. Genuinely new concept, no existing page covers it → create.
**One canonical page per concept** is the invariant a garden pass exists to restore
when this judgment call was missed.

## The authority chain

```
raw sources (references/, knowledge/, research reports)
        │ never edited by agents — read, cited, immutable
        ▼
canonical facts + decisions (memory/auto/, alignment/decisions/)
        │ append-only claims — the ground truth
        ▼
synthesis pages (wiki/)
        │ derived narrative — regenerable, never precious
```

Agents may only write/edit the bottom layer. A wiki page claiming something not
traceable up this chain is a schema violation, not a stylistic nitpick.

## Regenerability mindset

A wiki page is a **rebuildable cache**, not an asset to protect. If a page drifts,
duplicates, or goes stale, the fix is to regenerate it from its cited sources — never to
patch around a page's accumulated cruft to preserve its prose. The structure (the
taxonomy, the citation discipline) is the asset; any individual page is disposable.
Treat a "this page took effort to write, don't rewrite it" instinct as the anti-pattern
it is (`references/research-basis.md`: ouroboros compression, ingest-everything
automation).

## Craig reviews before canonical

New pages and material edits land `status: draft`. A page only becomes `status:
canonical` after Craig reviews it — flip the frontmatter field, nothing else changes.
Draft pages are still linkable and citable (a page in progress is still useful), but a
draft's claims carry lower trust than a canonical one until reviewed. Never self-flip
`canonical` — that's the self-certification anti-pattern
(`[[no-self-certifying-remedy]]`).

## Anti-patterns to refuse

| Anti-pattern | Why it's refused |
|---|---|
| Mirroring operational state (status, logs, beads, health reports) | Pages point at live state, never copy it — copies go stale immediately (memory-wiki-upgrade decision log #4) |
| An uncited claim | Breaks THE CITATION RULE — find the source or cut the sentence |
| A near-duplicate page for the same concept | Update the existing page instead (create-vs-update judgment) |
| Scope creep ("all of my knowledge" pages) | Most-cited death in the field research — bounded ontology, one domain at a time |
| Precious/protected pages resistant to regeneration | Violates the regenerability mindset — pages are cache |
| Self-flipping `status: canonical` | Craig reviews every page before it's canonical |
| Building a browsing UI before the substrate is trustworthy | Obsidian is the browsing surface; no rendered site (not-build list) |

---

## Workflows

| Workflow | Use when |
|---|---|
| `workflows/seed-page.md` | Drafting a brand-new synthesis page from cited sources |
| `workflows/garden.md` | Periodic dedupe/merge/prune + contradiction-page creation + staleness sweep |
| `workflows/distill-weekly.md` | Weekly review's distillation cadence — STRATEGY.md decisions log + NOW.md refresh |

## Reference Documentation

| File | Contents |
|---|---|
| `references/research-basis.md` | Distilled field research + internal audit evidence — read before seeding pages or designing a garden pass |

---

## Common Mistakes

| Mistake | Fix |
|---|---|
| Writing a wiki page as if it were a new source of truth | It's a derived view — every claim traces up the authority chain |
| Skipping `qmd search` before drafting | Dedupe-over-append — update the existing page |
| Omitting `trigger:` | Write the retrieval-trigger clause, same discipline as a skill description |
| Flipping `status: canonical` yourself | Craig reviews first |
| Mirroring a beads/status dashboard into a page | Point at it, never copy it |
| Treating a stale page as precious | Regenerate from cited sources; pages are cache |
