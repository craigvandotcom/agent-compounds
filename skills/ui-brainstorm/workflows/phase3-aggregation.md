# Phase 3: Consensus Aggregation Workflow

**Goal:** Calculate consensus scores using Borda count + detect controversial ideas

**Input:** 3 ranking matrices from Phase 2
**Output:** Ranked list with consensus scores and variance metrics

---

## Borda Count Method

**Scoring system:**

- 1st place = 15 points
- 2nd place = 14 points
- 3rd place = 13 points
- ...
- 15th place = 1 point

**For each idea:**

1. Find its rank in each model's list
2. Convert rank to points
3. Sum points across all 3 models
4. **Max possible score: 45 points** (1st + 1st + 1st)

---

## Manual Calculation Template

**Create aggregation spreadsheet (or markdown table):**

```markdown
# Borda Count Aggregation

| Idea | Claude Rank | Claude Pts | GPT Rank | GPT Pts | Gemini Rank | Gemini Pts | Total | Variance |
| ---- | ----------- | ---------- | -------- | ------- | ----------- | ---------- | ----- | -------- |
| 1    | 5           | 11         | 3        | 13      | 7           | 9          | 33    | 4.0      |
| 2    | 1           | 15         | 1        | 15      | 2           | 14         | 44    | 1.0      |
| 3    | 12          | 4          | 15       | 1       | 10          | 6          | 11    | 20.7     |
| ...  |             |            |          |         |             |            |       |          |

**Legend:**

- Rank: Position in that model's ranking (1 = best)
- Pts: Borda points (16 - rank)
- Total: Sum of all 3 models' points
- Variance: Statistical variance across 3 ranks
```

---

## Calculation Steps

### Step 1: Extract Rankings

From Phase 2 doc, create lookup table:

**Claude's ranks:**

- Idea 5 = Rank 1
- Idea 12 = Rank 2
- Idea 3 = Rank 3
- ...

**GPT's ranks:**

- Idea 2 = Rank 1
- Idea 5 = Rank 2
- ...

**Gemini's ranks:**

- Idea 2 = Rank 1
- Idea 8 = Rank 2
- ...

---

### Step 2: Convert to Points

For each idea, calculate Borda points:

**Points = 16 - Rank**

**Example: Idea 5**

- Claude rank: 1 → Points: 15
- GPT rank: 2 → Points: 14
- Gemini rank: 7 → Points: 9
- **Total: 38 points**

---

### Step 3: Calculate Variance

Variance measures disagreement across models.

**Formula:**

```
Mean = (Rank1 + Rank2 + Rank3) / 3
Variance = [(Rank1 - Mean)² + (Rank2 - Mean)² + (Rank3 - Mean)²] / 3
```

**Example: Idea 5**

- Ranks: 1, 2, 7
- Mean: (1 + 2 + 7) / 3 = 3.33
- Variance: [(1-3.33)² + (2-3.33)² + (7-3.33)²] / 3
- Variance: [5.44 + 1.78 + 13.44] / 3 = 6.89

**Interpretation:**

- Low variance (<5): Strong consensus
- Medium variance (5-10): Mixed opinions
- High variance (>10): Controversial (investigate dissent)

---

### Step 4: Sort by Total Score

Rank all 15 ideas by total Borda points (descending).

**Example output:**

```markdown
## Consensus Rankings

1. **Idea 2** - 44 points (variance: 1.0) - Strong consensus winner
2. **Idea 5** - 38 points (variance: 6.9) - High score, moderate disagreement
3. **Idea 8** - 35 points (variance: 3.2) - Solid consensus
4. **Idea 12** - 33 points (variance: 4.5) - Good consensus
5. **Idea 1** - 33 points (variance: 11.2) - CONTROVERSIAL (high variance)
   ...
6. **Idea 3** - 11 points (variance: 20.7) - HIGHLY CONTROVERSIAL (ranked 1st by one model, 15th by another)
```

---

## Automated Calculation (Python)

For faster processing, use Python script:

```python
#!/usr/bin/env python3
"""
Borda Count Calculator for UI Brainstorm
"""

# Rankings from each model (idea_id: rank)
claude_ranks = {
    1: 5, 2: 1, 3: 12, 4: 8, 5: 1, 6: 10, 7: 3, 8: 4, 9: 14, 10: 6,
    11: 7, 12: 2, 13: 15, 14: 9, 15: 11
}

gpt_ranks = {
    1: 3, 2: 1, 3: 15, 4: 5, 5: 2, 6: 12, 7: 8, 8: 4, 9: 11, 10: 7,
    11: 6, 12: 9, 13: 14, 14: 10, 15: 13
}

gemini_ranks = {
    1: 7, 2: 2, 3: 10, 4: 6, 5: 7, 6: 11, 7: 5, 8: 1, 9: 13, 10: 8,
    11: 4, 12: 3, 13: 15, 14: 12, 15: 9
}

# Calculate Borda points
def borda_points(rank):
    return 16 - rank

# Calculate variance
def variance(ranks):
    mean = sum(ranks) / len(ranks)
    return sum((r - mean) ** 2 for r in ranks) / len(ranks)

# Aggregate scores
results = []
for idea_id in range(1, 16):
    c_rank = claude_ranks[idea_id]
    g_rank = gpt_ranks[idea_id]
    m_rank = gemini_ranks[idea_id]

    total = borda_points(c_rank) + borda_points(g_rank) + borda_points(m_rank)
    var = variance([c_rank, g_rank, m_rank])

    results.append({
        'idea': idea_id,
        'total': total,
        'variance': var,
        'ranks': [c_rank, g_rank, m_rank]
    })

# Sort by total score
results.sort(key=lambda x: x['total'], reverse=True)

# Print results
print("# Consensus Rankings\n")
for i, r in enumerate(results, 1):
    controversy = ""
    if r['variance'] > 10:
        controversy = " - **HIGHLY CONTROVERSIAL**"
    elif r['variance'] > 5:
        controversy = " - *Moderate disagreement*"

    print(f"{i}. **Idea {r['idea']}** - {r['total']} points (variance: {r['variance']:.1f}){controversy}")
    print(f"   Ranks: Claude={r['ranks'][0]}, GPT={r['ranks'][1]}, Gemini={r['ranks'][2]}")
    print()
```

**Usage:**

```bash
python3 /tmp/borda-calculator.py > /tmp/consensus-rankings.md
```

---

## Output Document

**File:** `knowledge/2-areas/software/design-critiques/YYYY-MM-DD-[project]-consensus.md`

**Structure:**

```markdown
# UI Brainstorm: [Project] - Consensus Aggregation

**Date:** [timestamp]

## Methodology

- Scoring: Borda count (1st=15pts, 15th=1pt)
- Models: Claude, GPT-4, Gemini
- Max possible: 45 points

## Top 5 Consensus Ideas

### 1. Idea [N] - [Title] (44 points, variance: 1.0)

**Ranks:** Claude=1, GPT=1, Gemini=2
**Consensus:** Strong agreement - all models ranked in top 2
**Description:** [paste from Phase 1]

### 2. Idea [N] - [Title] (38 points, variance: 6.9)

**Ranks:** Claude=1, GPT=2, Gemini=7
**Consensus:** High score with moderate disagreement on Gemini
**Description:** [paste from Phase 1]

[Continue for top 5]

## Controversial Ideas (Variance >10)

### Idea [N] - [Title] (28 points, variance: 12.3)

**Ranks:** Claude=2, GPT=14, Gemini=5
**Disagreement Analysis:**

- GPT strongly deprioritized (rank 14) due to feasibility concerns
- Claude/Gemini saw innovation value despite implementation complexity
  **Minority View Worth Considering:** [Extract GPT's rationale]

## Bottom 3 (Low Consensus)

### 15. Idea [N] - [Title] (11 points, variance: 20.7)

**Ranks:** Claude=15, GPT=15, Gemini=10
**Why low:** [Common concerns from all models]

---

**Next Phase:** Synthesis report (phase4-synthesis.md)
```

---

## Quality Checks

Before proceeding to Phase 4:

- [ ] All 15 ideas have Borda scores calculated
- [ ] Scores sum correctly (each model contributed 120 total points: 1+2+...+15)
- [ ] Variance calculated for controversial ideas
- [ ] Top 3-5 ideas clearly identified
- [ ] High-variance ideas flagged with dissent analysis
- [ ] Descriptions from Phase 1 ready to paste into synthesis

---

## Interpretation Guide

**High score + low variance:**
→ Clear winner, proceed with confidence

**High score + high variance:**
→ Popular but polarizing, investigate disagreement before committing

**Medium score + low variance:**
→ Safe choice, consensus on "good enough"

**Medium score + high variance:**
→ Some see potential others miss, worth discussion

**Low score + low variance:**
→ Clear loser, eliminate

**Low score + high variance:**
→ One model loved it, others hated it, investigate outlier

---

## Common Issues

| Problem                            | Solution                                               |
| ---------------------------------- | ------------------------------------------------------ |
| Scores don't match expected winner | Variance matters - high variance reduces confidence    |
| Multiple ideas with same score     | Use variance as tiebreaker (lower = better)            |
| Top idea has high variance         | Flag for human review before implementation            |
| Calculation errors                 | Verify each model contributed exactly 120 total points |

---

## Time Estimate

- Manual calculation (spreadsheet): 5 minutes
- Python script: 2 minutes
- Analysis and documentation: 3 minutes

**Total: ~5-10 minutes**

---

**Next:** `phase4-synthesis.md` for final report generation
