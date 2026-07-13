# Seed a wiki page

**Use when:** drafting a brand-new synthesis page — a concept/entity/topic/contradiction
that doesn't have a page yet.

**Precondition:** confirmed via the create-vs-update judgment (SKILL.md) that no
existing page already covers this concept — `qmd search`/`grep <domain>/wiki/` first.

## Steps

1. **Gather sources.** `qmd query`/`grep` the relevant memory homes
   (`<domain>/memory/auto/`), `alignment/decisions/`, and — for conceptual/philosophy
   topics — `references/`. Read every source you intend to cite; don't paraphrase from
   memory of having read it once.
2. **Classify the type.** concept | entity | topic | contradiction (SKILL.md table).
   Nothing fits → that's a schema question for Craig, not a reason to force-fit.
3. **Draft the frontmatter.** Full contract (`title, type, sources, related, created,
   updated, confidence, trigger`) — `status: draft`. Write `trigger:` as the retrieval
   condition (when should an agent load this page), not a summary of its content.
4. **Draft the body.** Prose that integrates the sources into one coherent narrative.
   **Every claim gets a `[[wikilink]]`** to the fact/decision/source it comes from — no
   exceptions (THE CITATION RULE). If a sentence has no traceable source, cut it or go
   find the source before writing it.
5. **Link related pages.** Populate `related:` with any existing wiki pages this one
   connects to; add a reciprocal link on the other page if it doesn't already point back.
6. **Self-check before handing off:**
   - Every `[[link]]` resolves (facts, decisions, or other wiki pages — not a guess)
   - No sentence lacks a citation
   - `status: draft` (never flip to canonical yourself)
7. **Hand off to Craig for review.** Point at the file; don't summarize its content in
   the request — Craig reads the page itself. Craig flips `status: canonical` (or asks
   for changes) — this workflow's job ends at draft.

## Do NOT

- Skip step 1 and draft from context-window memory of "what I generally know" — every
  claim needs a real, checkable source.
- Create a second page for a concept that already has one — that's `garden.md`'s dedupe
  territory, and a create-vs-update miss is exactly what garden exists to catch.
