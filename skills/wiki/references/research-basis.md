# Wiki skill — research basis

**Sources (cite, don't copy — read these directly for full detail):**
- `knowledge/3-references/research/ai-native-org/2026-07-12-2321-wiki-agent-memory-layer.md`
  — the field research report (Karpathy LLM-Wiki pattern, best practices, failure
  modes, ten-tool landscape, multi-model consensus)
- `knowledge/0-inbox/research/2026-07-13-0853-memory-knowledge-system-audit.md`
  — the internal audit that graded our actual substrate against that report's rubric
- `infrastructure/plans/memory-wiki-upgrade.md` — the canonical execution spec these
  two reports were distilled into (decision log, phase closures, standing principles)

This file distills the parts load-bearing for how the `wiki` skill behaves. It does not
restate either report in full — read them for field history, tool survey, or the raw
audit gap table.

---

## Why write-time synthesis beats read-time (pure RAG)

Compaction happens at write time: read → extract → cross-reference → reconcile, done
once at ingest, instead of re-derived from raw chunks on every query. A wiki page is
that compaction persisted as an asset — "compile once, don't re-retrieve every time"
(research report §2, §4). This is additive to our existing hybrid retrieval (qmd), not
a replacement — qmd still does discovery and fallback; the wiki is what discovery finds
once someone has already done the synthesis work.

## Evidence for THE CITATION RULE

GitHub Copilot's production agentic-memory system is the field's one rigorously
A/B-tested implementation found in the research pass: memories written as explicit tool
calls **with code citations**, citations **re-verified at read time** — +3% precision /
+4% recall on review, +7pp PR merge rate, p<0.00001; it survived adversarial
poisoned-memory stress tests by discovering and correcting contradictions (research
report §4, "Governance/quality — the load-bearing part"). This is the single strongest
empirical result in the whole research pass — it is why THE CITATION RULE in SKILL.md
is a hard rule, not a style preference.

## Failure modes (named, so the skill can refuse them)

| Failure mode | What it looks like | Report reference |
|---|---|---|
| **Slop / ingest-everything automation** | Automated pipelines dumping email/Slack archives into the wiki, diluting signal | research report §4 anti-patterns |
| **Near-duplicate pages** | Multiple pages on the same concept because create-vs-update wasn't checked | research report §4, "one concept per page" |
| **Rot / staleness** | Pages outliving the facts that grounded them; agents reason from stale pages with full confidence, unlike humans who discount aged docs | research report §2 "honest limits"; arXiv 2606.09090 |
| **Ouroboros compression** | Repeated dedupe/summarize cycles silently erode nuance | research report §4 anti-patterns |
| **Hallucination laundering** | Reader-writer contamination — the same process reads and writes the KB, so a hallucination can compound into "truth" | research report §2 "honest limits" |
| **Hallucinated wikilinks** | Links to pages that "should" exist but don't | research report §4 anti-patterns |
| **Frontmatter/schema drift** | Silently corrupts the derived index (qmd, lint) | research report §4 anti-patterns |
| **Over-automation fails silently** | Background pipelines failing ~50% of the time undetected; fix was manual in-context capture + deterministic scripts | research report §2, dev.to case study |
| **Building the UI before the substrate is trustworthy** | Browsing surface built before pages are cited/reviewed | research report §4 anti-patterns |

## The one-month-retrospective caution

The field's first empirical retrospective on the Karpathy pattern (~760 pages, one
month in) found **"time maintaining vs. time saved is roughly a wash"** — the wiki does
not self-populate with value, and works best in narrow, well-sourced technical domains
(research report §1). This is why Phase 3 seeds only 5-10 pages in ONE bounded domain
(`neometa/wiki/`) rather than attempting broad coverage, and why `workflows/garden.md`
treats maintenance as a real, budgeted cost rather than assuming the wiki pays for
itself automatically.

## What the audit found we already have (don't rebuild)

The audit confirmed our substrate already implements most of the field's converged best
practices — markdown-as-substrate, hybrid BM25+vector retrieval (qmd), typed atomic
memory, relevance-injection hooks, reflect/dream write-and-lint loops — and named the
actual gap as narrower than "build a wiki": (1) no synthesis layer, (2) hygiene
enforcement was LLM-judged instead of deterministic (fixed separately —
`infrastructure/scripts/health/memory-lint.py`, Phase 1), (3) no human-browsable
surface (audit gap map, items 1-5 of the "Honest gap analysis" section). This skill
exists to close gap (1) only — it is deliberately not a rewrite of retrieval, write
loops, or hygiene, all of which the audit found already ahead of the field.

## Multi-model consensus, condensed

Three independent models (GPT-5.6, Gemini 3.1 Pro, DeepSeek V4 Pro), given our stack,
converged 3/3 on: wiki pages are a derived view (never a new source of truth); Obsidian
pointed at the repo is the browsing surface (no rendered site); deterministic scripts
own mechanical truth, LLMs own semantic proposals only, reviewable and never silently
applied (research report §6). Every enforcement rule in SKILL.md traces directly to
this consensus.
