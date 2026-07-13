# Garden the wiki

**Use when:** a periodic hygiene pass over `<domain>/wiki/` — dedupe, merge, prune,
staleness sweep, contradiction-page creation. Not a one-time task; run it on a cadence
(folds into the weekly review per `distill-weekly.md`, or standalone once the wiki grows
past a handful of pages).

**Principle (context-engineering, applies here too):** deterministic checks own
mechanical truth; this workflow (an LLM pass) owns semantic proposals only — never
silently rewrite a page. Every change below is a reviewable diff, same discipline as
the dream cycle.

## Passes

1. **Orphan/index check.** Every page in `<domain>/wiki/` should be reachable from
   `WIKI.md` (or the domain's wiki index) and registered in the `wiki` qmd collection.
   Missing → add the index line (additive, same discipline as `memory-lint.py`'s
   MEMORY.md reconciliation — never a wholesale rewrite of the index).
2. **Dedupe/merge.** Scan for near-duplicate pages on the same concept (the
   create-vs-update judgment failing silently in `seed-page.md`). Found a duplicate →
   propose a merge (don't apply unilaterally if either page is `status: canonical` —
   that's Craig's call); merging two `draft` pages is fine to do directly.
3. **Citation audit.** Sample pages for THE CITATION RULE compliance — every claim
   still traces to a real `[[wikilink]]` target. A link that no longer resolves (the
   source fact was pruned/renamed) is a dead-link finding, same severity as
   `memory-lint.py`'s wikilink check.
4. **Staleness sweep.** Grep `updated:` dates. A page whose cited sources have since
   been superseded or contradicted, or that hasn't been touched while its topic clearly
   moved (a shipped decision, a retired product) — flag for review, don't silently
   rewrite. Evergreen pages (stable concepts) are exempt from age-based flagging;
   entity/topic pages tracking live things are not.
5. **Contradiction detection.** Two sourced claims (across pages, or a page vs. a fact)
   that disagree → create or update a `type: contradiction` page recording both sides
   with their citations. Never silently pick a winner — the contradiction page IS the
   resolution mechanism (record, don't hide — memory-wiki-upgrade decision log #4).
6. **Regeneration, not preservation.** Where a page's structure has drifted from the
   frontmatter contract or accumulated unsourced prose, prefer regenerating the
   affected section from its cited sources over patching around the drift
   (regenerability mindset, SKILL.md).

## Output

A short report: pages touched, merges proposed (not applied to canonical pages), dead
links found, staleness flags, contradiction pages created/updated. Anything touching a
`canonical` page's substance → Craig review, same gate as seeding.
