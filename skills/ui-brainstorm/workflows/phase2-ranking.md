# Phase 2: Cross-Pollination Ranking Workflow

**Goal:** Each model ranks ALL 15 ideas (anonymized, unbiased)

**Input:** 15 ideas from Phase 1 (anonymized)
**Output:** 3 ranking matrices (45 total rankings)

---

## Pre-Ranking Preparation

### Step 1: Anonymize Ideas

Remove model attribution to prevent bias.

**From Phase 1 doc, create anonymized version:**

```markdown
# UI Improvement Ideas (Anonymized)

## Idea 1: [Title]

**Description:** [description]
**Self-Assessed Rubric:**

- Visual Appeal: [score] - [justification]
- Usability: [score] - [justification]
- Brand Alignment: [score] - [justification]
- Innovation: [score] - [justification]
- Feasibility: [score] - [justification]

## Idea 2: [Title]

...

[Repeat for all 15 ideas]
```

**Save as:** `/tmp/ui-brainstorm-anonymized.md`

**Randomize order (optional):** Shuffle ideas to prevent position bias

```bash
# Simple shuffle: manually reorder 1-15 randomly
# Or use: shuf command if available
```

---

## Ranking Template

Each model uses this template:

```markdown
TASK: Rank these 15 UI/UX improvement ideas from best (1) to worst (15).

RANKING CRITERIA:
Consider all 5 rubric dimensions:

- Visual Appeal (20%)
- Usability (30%)
- Brand Alignment (15%)
- Innovation (20%)
- Feasibility (15%)

OUTPUT FORMAT:

1. Idea [N] - [Score: X/5] - [Brief rationale for ranking]
2. Idea [N] - [Score: X/5] - [rationale]
   ...
3. Idea [N] - [Score: X/5] - [rationale]

OPTIONAL: New Ideas Inspired
If seeing these ideas sparked new concepts, list them:

- [New idea title]: [brief description]

CONSTRAINTS:

- Use each rank exactly once (no ties)
- Focus on user impact, not implementation complexity
- Consider cross-dimensional balance (a 4/5 in Usability might beat 5/5 in Visual Appeal)
- Justify rankings beyond just repeating scores
```

---

## Model 1: Claude Ranking

**Execute in Claude Code:**

```markdown
[Paste anonymized ideas from /tmp/ui-brainstorm-anonymized.md]

[Paste ranking template]
```

**Capture Claude's ranking to working doc.**

---

## Model 2: Gemini 3.1 Pro Ranking

**Model:** `google/gemini-3.1-pro-preview`

**CLI method:**

**Step 1: Create ranking prompt**

```bash
cat > /tmp/gemini-ranking-prompt.txt << 'EOF'
[Paste anonymized ideas]
[Paste ranking template]
EOF
```

**Step 2: Run ranking**

```bash
openrouter --file /tmp/gemini-ranking-prompt.txt -m gemini --max-tokens 2000 --raw -o /tmp/gemini-rankings.md
```

**Capture Gemini's ranking to working doc.**

---

## Model 3: Grok 4.20 Ranking

**Model:** `x-ai/grok-4.20-beta`

**CLI method:**

**Step 1: Create ranking prompt**

```bash
cat > /tmp/grok-ranking-prompt.txt << 'EOF'
[Paste anonymized ideas]
[Paste ranking template]
EOF
```

**Step 2: Run ranking**

```bash
openrouter --file /tmp/grok-ranking-prompt.txt -m grok --max-tokens 2000 --raw -o /tmp/grok-rankings.md
```

**Capture Grok's ranking to working doc.**

---

## Consolidation

**Create ranking matrix:**

**File:** `knowledge/2-areas/software/design-critiques/YYYY-MM-DD-[project]-rankings.md`

**Structure:**

```markdown
# UI Brainstorm: [Project] - Rankings

**Date:** [timestamp]

## Claude's Rankings

1. Idea [N] - [rationale]
2. Idea [N] - [rationale]
   ...
3. Idea [N] - [rationale]

**New Ideas Inspired:**

- [If any]

---

## Gemini 3.1 Pro's Rankings

1. Idea [N] - [rationale]
2. Idea [N] - [rationale]
   ...
3. Idea [N] - [rationale]

**New Ideas Inspired:**

- [If any]

---

## Grok 4.20's Rankings

1. Idea [N] - [rationale]
2. Idea [N] - [rationale]
   ...
3. Idea [N] - [rationale]

**New Ideas Inspired:**

- [If any]

---

**Next Phase:** Consensus aggregation (phase3-aggregation.md)
```

---

## Quality Checks

Before proceeding to Phase 3:

- [ ] All 3 models provided complete rankings (1-15)
- [ ] No duplicate ranks (each model used 1-15 exactly once)
- [ ] Rationales provided for each rank
- [ ] New inspired ideas captured (if any)
- [ ] Rankings reference idea numbers correctly

---

## Handling New Inspired Ideas

If models generated new ideas during ranking:

**Option 1: Include in Phase 3**

- Number new ideas 16, 17, 18, etc.
- Give them default rank (or skip them for this round)

**Option 2: Save for Round 2**

- Document in "Future Ideas" section
- Run separate brainstorm if compelling

**Recommendation:** Option 2 (keep Phase 3 focused on original 15)

---

## Common Issues

| Problem                                   | Solution                                              |
| ----------------------------------------- | ----------------------------------------------------- |
| Model created ties (two ideas ranked #3)  | Request re-ranking with forced uniqueness             |
| Model only ranked top 10                  | Require all 15 to enable proper Borda count           |
| Rankings don't match rationale            | Accept anyway - synthesis will surface contradictions |
| Model added commentary instead of ranking | Extract rankings manually from narrative              |
| Too brief rationales                      | Acceptable if ranking is clear                        |

---

## Reflection Step (Optional Enhancement)

Before ranking others' ideas, ask each model to critique its own:

```markdown
SELF-CRITIQUE: Review your original 5 ideas.

- Which would you rank highest now? Why?
- Which would you deprioritize? Why?
- What did you miss in initial generation?

[Then proceed to full ranking]
```

**Benefit:** Reduces ego bias, increases objectivity

**Cost:** +1 minute per model

---

## Time Estimate

- Anonymization: 2 minutes
- Claude ranking: 2 minutes
- GPT ranking: 2 minutes (+ manual copy if needed)
- Gemini ranking: 2 minutes (+ manual copy if needed)
- Consolidation: 2 minutes

**Total: ~10 minutes**

---

**Next:** `phase3-aggregation.md` for Borda count calculation
