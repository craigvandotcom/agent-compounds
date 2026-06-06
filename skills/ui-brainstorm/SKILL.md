---
name: ui-brainstorm
description: Multi-model UI design critique using consensus ranking. Use when user mentions UI improvements, design critique, interface redesign, or wants multiple perspectives on visual/UX changes. Triggers on "ui brainstorm", "design critique", "improve this interface", "multiple design ideas".
---

> **Generic skill — method only, zero app facts.** This skill is symlinked from
> agent-compounds and shared across all neoMeta apps. It contains technique and
> patterns, not project specifics. **App specifics (project refs, schema names,
> domain rules, feature flows, env values) → read this app's
> `.claude/skills/CORE/SKILL.md`** (and the `AGENTS.md` summary it indexes).
> Do not add app-specific facts to this file — they belong in CORE.

# UI Brainstorm Skill

**Purpose:** Multi-model AI consensus for UI/UX design ideation and critique using cutting-edge vision models
**Tools:** Claude Opus 4.6 (native), openrouter (Gemini 3.1 Pro, Grok 4.20)
**Domain:** Interface design, UX optimization, visual critique
**Status:** MVP

---

## When to Use This Skill

**Intent Triggers:**

- User wants UI/UX improvement ideas
- User needs design critique with multiple perspectives
- User mentions "design brainstorm" or "multiple ideas"
- User has a screenshot needing evaluation
- User wants consensus on best approach

**Example Phrases:**

- "Help me brainstorm UI improvements for this page"
- "Get multiple design ideas for this interface"
- "What would different AI models suggest for this design?"
- "Run a design critique on this screenshot"

**When NOT to Use:**

- Single design iteration (use direct implementation)
- Already committed to specific design (no brainstorm needed)
- Just checking implementation specs (no ideation)

---

## Core Pattern: Multi-Model Consensus Workflow

**Simple, effective brainstorming with cutting-edge vision models:**

1. **Input** - Screenshot(s) + context
2. **Parallel Brainstorm** - 3 vision models generate improvement ideas
   - Claude Opus 4.6 (native vision)
   - Gemini 3.1 Pro (vision via openrouter)
   - Grok 4.20 (via openrouter)
3. **Cross-Pollinate** - Each model ranks all ideas anonymously
4. **Aggregate** - Borda count consensus + variance analysis
5. **Iterate** - Refine winners or pivot

**Key Principle:** All models see the actual screenshot directly (no text bridges). Preserve dissent - high variance flags valuable controversy.

---

## Simplified Workflow

### 1. Input Phase

**User provides:**

- Screenshot(s) of UI to improve
- Context (what's broken, what needs improvement)

### 2. Parallel Brainstorm (Vision-Native)

**All 3 models receive the actual screenshot:**

- **Claude Opus 4.6:** Native vision in conversation
- **Gemini 3.1 Pro:** `google/gemini-3.1-pro-preview` via openrouter
- **Grok 4.20:** `x-ai/grok-4.20-beta` via openrouter

Each generates 5 improvement ideas scored against design rubric.

**Output:** 15 total ideas (3 models × 5 ideas)

**See:** `workflows/phase1-generation.md`

### 3. Cross-Pollinate Rankings

**Each model ranks all 15 ideas anonymously:**

- Ideas stripped of model attribution
- Each model ranks 1-15 with rationale
- Forces objective evaluation (including own ideas)

**Output:** 3 ranking matrices

**See:** `workflows/phase2-ranking.md`

### 4. Aggregate Consensus

**Calculate Borda count scores:**

- 1st place = 15 points, 2nd = 14, ..., 15th = 1
- Sum across models (max 45 points)
- Calculate variance to flag controversial ideas

**Output:** Ranked list with consensus + dissent

**See:** `workflows/phase3-aggregation.md`

### 5. Iterate/Refine

**User decides next step:**

- Implement winning idea
- Request refinement variations
- Deep-dive controversial high-variance idea
- Run another round

**See:** `workflows/phase4-synthesis.md` and `workflows/phase5-iteration.md`

---

## Quick Reference

### Command Invocation

```
/ui-brainstorm [screenshot-path] [context]
```

### Design Rubric (5 Criteria)

| Criterion       | Weight | Question                                |
| --------------- | ------ | --------------------------------------- |
| Visual Appeal   | 20%    | Does it look professional and engaging? |
| Usability       | 30%    | Is it intuitive and accessible?         |
| Brand Alignment | 15%    | Does it match brand identity?           |
| Innovation      | 20%    | Does it differentiate from competitors? |
| Feasibility     | 15%    | Can it be implemented reasonably?       |

### Borda Count Scoring

- 1st place = 15 points
- 2nd place = 14 points
- ...
- 15th place = 1 point

**Sum across 3 models → Max possible score: 45 points**

### Variance Threshold

- **Low variance (<5):** Strong consensus
- **Medium variance (5-10):** Mixed opinions
- **High variance (>10):** Controversial idea (flag for review)

---

## Cutting-Edge Vision Models

### Model 1: Claude Opus 4.6 (Native)

**Access:** Built into Claude Code conversation
**Vision:** Native - attach screenshot directly
**Capabilities:** Best reasoning, nuanced critique, synthesis
**Usage:** Primary model for meta-analysis and final synthesis

### Model 2: Gemini 3.1 Pro

**Model ID:** `google/gemini-3.1-pro-preview`
**Access:** OpenRouter CLI with `--image` flag
**Vision:** Fully supported via CLI
**Capabilities:** Large context, pattern recognition
**Usage:** Alternative perspective on design patterns

### Model 3: Grok 4.20

**Model ID:** `x-ai/grok-4.20-beta`
**Access:** OpenRouter CLI
**Capabilities:** Strong reasoning, contrarian perspective, good evidence citations
**Usage:** Third perspective for consensus validation

### Model 4 (alternate): GPT-5.4

**Model ID:** `openai/gpt-5.4`
**Access:** OpenRouter CLI
**Capabilities:** Comprehensive analysis, practical proposals
**Usage:** Substitute for any model that times out or returns empty

**CLI Usage:**

```bash
# Text-only (most reliable)
openrouter --file prompt.txt --model google/gemini-3.1-pro-preview --raw -o /tmp/output.md

# With vision (if supported by model)
openrouter --file prompt.txt --image screenshot.png --model google/gemini-3.1-pro-preview --raw -o /tmp/output.md
```

**Retired:** Kimi K2.5 (`moonshotai/kimi-k2.5`) was retired — it was unreliable and frequently returned empty responses.

---

## Supporting Documentation

| File                              | When to Read                    |
| --------------------------------- | ------------------------------- |
| `workflows/phase1-generation.md`  | Running idea generation phase   |
| `workflows/phase2-ranking.md`     | Cross-pollination ranking setup |
| `workflows/phase3-aggregation.md` | Calculating Borda count scores  |
| `workflows/phase4-synthesis.md`   | Creating final report           |
| `workflows/phase5-iteration.md`   | Post-decision refinement        |
| `reference/design-rubric.md`      | Detailed rubric criteria        |
| `reference/borda-count-method.md` | Ranking methodology             |
| `reference/model-prompts.md`      | Exact prompts for each phase    |

---

## Output Format

### Idea Structure (Phase 1)

```markdown
## Idea [N]: [Title]

**Model:** [Claude/GPT/Gemini]

**Description:** [2-3 sentences]

**Rubric Scores:**

- Visual Appeal: [1-5] - [justification]
- Usability: [1-5] - [justification]
- Brand Alignment: [1-5] - [justification]
- Innovation: [1-5] - [justification]
- Feasibility: [1-5] - [justification]

**Total:** [5-25]
```

### Ranking Output (Phase 2)

```markdown
## [Model] Rankings

1. Idea [N] - [Score] - [Brief rationale]
2. Idea [N] - [Score] - [Brief rationale]
   ...
3. Idea [N] - [Score] - [Brief rationale]

**New Ideas Inspired:**

- [Optional: Any new ideas sparked by seeing others]
```

### Final Report (Phase 4)

```markdown
# UI Design Critique Report

**Date:** [timestamp]
**Screenshot:** [path]

## Top 3 Consensus Ideas

### 1. [Idea Title] (Score: 42/45)

**Consensus:** [Why models agreed]
**Tradeoffs:** [Key considerations]
**Implementation:** [Next steps]

### 2. [Idea Title] (Score: 38/45)

...

### 3. [Idea Title] (Score: 35/45)

...

## Controversial Ideas (High Variance)

### [Idea Title] (Score: 28/45, Variance: 12)

**Disagreement:** [Why models split]
**Minority View:** [Dissenting perspective worth considering]

## Next Steps

- [ ] Select winning idea
- [ ] Request mockup generation
- [ ] Run refinement round
```

---

## Persistence Strategy

### Output Location

**Primary:** `knowledge/2-areas/software/design-critiques/YYYY-MM-DD-[project].md`

**Rationale:**

- Centralized design history
- Cross-project learning
- Searchable via Grep/PKM

**Structure:**

```
knowledge/2-areas/software/design-critiques/
├── 2026-01-31-login-flow.md
├── 2026-02-05-newsletter-header.md
└── _index.md (summary of all critiques)
```

### Memory Integration

**Save to playbook:**

- Winning patterns (which criteria matter most)
- Model performance (which model's ideas win most)
- Rubric refinements (adjust weights based on outcomes)

**Command:** `cm context "ui brainstorm" --json` retrieves past design critique learnings

---

## Common Mistakes

| Mistake                             | Fix                                                     |
| ----------------------------------- | ------------------------------------------------------- |
| Skipping screenshot analysis        | Always run image-describe first to understand context   |
| Biasing models with brand too early | Keep brand rubric weight low (15%) to allow innovation  |
| Ignoring high-variance ideas        | Flag for review - dissent often signals valuable debate |
| Over-relying on consensus           | Sometimes minority view is breakthrough                 |
| Skipping iteration phase            | Winner often needs 1-2 refinement rounds                |
| Not saving learnings                | Update playbook with what worked/failed                 |

---

## Integration Notes

**Cross-Skill Usage:**

- `brand` skill loads for brand alignment rubric scoring
- `research` skill can analyze competitor designs pre-brainstorm
- `openrouter` tool provides multi-model access

**Subagent delegation:**

- Can be run by architect subagent for system UI work
- Can be run directly by main agent for project-specific design

**Commands:**

- `/ui-brainstorm` - Start new brainstorm session
- `/ui-refine [idea-number]` - Refine specific idea from last session

---

## Performance Notes

**Timing:**

- Phase 1 (Generation): ~2-3 minutes (3 model calls)
- Phase 2 (Ranking): ~3-4 minutes (3 model calls with longer prompts)
- Phase 3 (Aggregation): ~10 seconds (local calculation)
- Phase 4 (Synthesis): ~1-2 minutes (1 meta-model call)
- **Total: ~10 minutes for full workflow**

**Cost Estimate (per session):**

- Phase 1: ~$0.15 (3 models, vision + generation)
- Phase 2: ~$0.20 (3 models, longer prompts)
- Phase 4: ~$0.10 (1 Opus call)
- **Total: ~$0.45 per brainstorm session**

**Token Usage:**

- Screenshot: ~1000 tokens (vision)
- Generation prompts: ~500 tokens each
- Ranking prompts: ~2000 tokens each (includes all 15 ideas)
- Synthesis: ~3000 tokens (full ranking data)

---

## MVP Limitations & Future Enhancements

**MVP (Current):**

- CLI-automated (all models via openrouter CLI with vision support)
- Manual Borda count calculation
- Markdown-only output
- No mockup generation

**v2 Planned:**

- Auto-calculated rankings with visualization
- Integration with v0.dev or screenshot-to-code for mockups
- A/B test tracking for implemented ideas
- Historical pattern analysis (which ideas actually perform better)
- Parallel execution of all models (currently sequential)

**v3 Vision:**

- Real-time collaborative brainstorm (user + AI panel)
- Custom rubric builder
- Domain-specific rubrics (mobile vs web vs marketing page)
- Multi-round refinement automation

---

**Version:** 1.0 MVP
**Created:** 2026-01-31
**Next Review:** After 5 brainstorm sessions (tune rubric weights)
