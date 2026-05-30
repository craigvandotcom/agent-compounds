# Borda Count Method Reference

Mathematical foundation for multi-model consensus aggregation.

---

## What is Borda Count?

**Definition:** Voting system where each voter ranks all candidates, points are assigned by position, and the candidate with the most total points wins.

**Why use it:**

- Captures strength of preference (not just first choice)
- Reduces impact of strategic voting
- Identifies consensus choices
- Better than simple plurality when >2 options

**Invented by:** Jean-Charles de Borda, 1770

---

## How It Works (UI Brainstorm Context)

**Setup:**

- 15 ideas to rank
- 3 "voters" (AI models)
- Each voter ranks all 15 ideas from 1st to 15th

**Scoring:**

- 1st place = 15 points
- 2nd place = 14 points
- 3rd place = 13 points
- ...
- 15th place = 1 point

**Formula:** Points = (Total Ideas) - (Rank) + 1

- Points = 15 - Rank + 1
- Points = 16 - Rank

**Total Score:** Sum points across all voters

- Max possible: 45 points (1st + 1st + 1st)
- Min possible: 3 points (15th + 15th + 15th)

---

## Worked Example

**Idea 5 rankings:**

- Claude: Rank 1 → 16 - 1 = **15 points**
- GPT: Rank 2 → 16 - 2 = **14 points**
- Gemini: Rank 7 → 16 - 7 = **9 points**

**Total: 38 points** (out of 45 possible)

**Interpretation:** Strong consensus (2 models ranked very high, 1 moderate)

---

**Idea 12 rankings:**

- Claude: Rank 2 → **14 points**
- GPT: Rank 14 → **2 points**
- Gemini: Rank 5 → **11 points**

**Total: 27 points** (out of 45 possible)

**Interpretation:** Controversial (GPT strongly disagrees with Claude/Gemini)

---

## Why Borda Count Over Alternatives?

### Alternative 1: Plurality Voting (Count First Choices)

**Problem:** Ignores strength of preference

**Example:**

- Idea A: 1 first place, 2 last places
- Idea B: 0 first places, 3 second places

**Plurality winner:** Idea A (1 vote vs 0)
**Borda winner:** Idea B (higher total consensus)

**Why Borda is better:** Idea B has broader support, even without #1 votes

---

### Alternative 2: Average Rank

**Method:** Calculate mean rank per idea

**Example:**

- Idea 5: Ranks (1, 2, 7) → Mean = 3.33
- Idea 12: Ranks (2, 14, 5) → Mean = 7.0

**Problem:** Lower mean rank wins (counter-intuitive)

- Idea 5 mean = 3.33 (better)
- But we want higher scores to win

**Why Borda is better:** Points system is intuitive (higher = better)

---

### Alternative 3: Condorcet Method (Pairwise Comparison)

**Method:** Compare each idea pairwise, winner beats majority

**Example:**

- Idea A vs Idea B: A wins if ranked higher by 2+ models
- Repeat for all pairs

**Problem:** Computationally expensive (105 comparisons for 15 ideas)

**Condorcet Paradox:**

- A beats B
- B beats C
- C beats A
- No clear winner (cycle)

**Why Borda is better:** Always produces a winner, simpler calculation

---

## Variance Analysis (Why It Matters)

Borda count alone doesn't show _agreement strength_.

**Example:**

**Idea A:** Total = 36 points

- Ranks: 3, 3, 3 (perfect consensus)
- Variance: 0

**Idea B:** Total = 36 points

- Ranks: 1, 1, 13 (polarized)
- Variance: 32

**Both have same Borda score, but different confidence levels.**

---

## Calculating Variance

**Formula:**

```
Mean = (Rank₁ + Rank₂ + Rank₃) / 3
Variance = Σ(Rankᵢ - Mean)² / 3
```

**Example: Idea A**

- Ranks: 3, 3, 3
- Mean: (3 + 3 + 3) / 3 = 3
- Variance: [(3-3)² + (3-3)² + (3-3)²] / 3 = 0

**Example: Idea B**

- Ranks: 1, 1, 13
- Mean: (1 + 1 + 13) / 3 = 5
- Variance: [(1-5)² + (1-5)² + (13-5)²] / 3 = [16 + 16 + 64] / 3 = 32

**Interpretation:**

- **Low variance (<5):** Strong consensus
- **Medium variance (5-10):** Moderate disagreement
- **High variance (>10):** Controversial (investigate)

---

## Standard Deviation (More Intuitive)

**Formula:** SD = √Variance

**Example: Idea B**

- Variance: 32
- SD: √32 ≈ 5.66

**Interpretation:** On average, ranks differ from mean by 5.66 positions

**Thresholds:**

- SD < 2.5: Strong consensus
- SD 2.5-4: Moderate disagreement
- SD > 4: High disagreement

---

## Decision Matrix: Score + Variance

| Borda Score    | Variance   | Interpretation             | Action                                |
| -------------- | ---------- | -------------------------- | ------------------------------------- |
| High (>40)     | Low (<5)   | **Clear Winner**           | Implement with confidence             |
| High (>40)     | High (>10) | **Popular but Polarizing** | Investigate dissent before committing |
| Medium (30-40) | Low (<5)   | **Safe Consensus**         | Good choice, not exciting             |
| Medium (30-40) | High (>10) | **Mixed Opinions**         | Review rationales, may hide gem       |
| Low (<30)      | Low (<5)   | **Clear Loser**            | Eliminate                             |
| Low (<30)      | High (>10) | **Outlier Appeal**         | One model saw value others missed     |

---

## Statistical Significance

**Question:** Is the difference between Idea A (score 42) and Idea B (score 40) meaningful?

**Simple check:** Do their rank confidence intervals overlap?

**Confidence Interval (rough estimate):**

```
Mean Rank ± (SD × 1.96)  # 95% confidence for 3 samples
```

**Example:**

- Idea A: Mean rank = 2, SD = 1 → CI: [0.04, 3.96]
- Idea B: Mean rank = 3, SD = 5 → CI: [-6.8, 12.8]

**Overlap:** Yes (large overlap due to Idea B's high variance)
**Conclusion:** Difference may not be statistically significant

**Practical implication:** With only 3 models, variance matters more than raw score difference.

---

## Handling Ties

**Scenario:** Two ideas have identical Borda scores

**Tiebreakers (in order):**

1. **Variance (lower is better)**
   - Idea A: 38 points, variance 4
   - Idea B: 38 points, variance 12
   - **Winner:** Idea A (stronger consensus)

2. **Best Rank (highest single rank)**
   - Idea A: Ranks (2, 3, 5) → Best = 2
   - Idea B: Ranks (1, 6, 7) → Best = 1
   - **Winner:** Idea B (at least one model loved it)

3. **Usability Rubric Score**
   - Usability weighted 30% (highest)
   - Use average usability score as tiebreaker
   - **Winner:** Higher usability score

4. **User Decision**
   - Present both ideas
   - Let user choose based on context

---

## Limitations of Borda Count

**1. Vulnerable to Strategic Voting**

- Model could rank competitors low to boost its own ideas
- **Mitigation:** Anonymize ideas (models don't know which are theirs)

**2. Irrelevant Alternatives**

- Adding weak ideas can change winner
- **Example:** If 5 weak ideas are added, ranks shift
- **Mitigation:** Keep idea count stable (always 15)

**3. Equal Weight Per Voter**

- All 3 models weighted equally
- **Could adjust:** If GPT performs better historically, weight 2x
- **Current approach:** Equal weight (simpler, fairer for MVP)

**4. Ordinal Not Cardinal**

- Distance between ranks not meaningful
- Rank 1→2 gap ≠ Rank 14→15 gap
- Models might feel differently about these gaps
- **Mitigation:** Variance analysis captures this

---

## Advanced: Weighted Borda Count

**Scenario:** GPT has historically better design ideas (60% win rate vs 30% for others)

**Weights:**

- Claude: 1.0×
- GPT: 1.5×
- Gemini: 1.0×

**Calculation:**

```
Idea 5 rankings:
- Claude: Rank 1 → 15 × 1.0 = 15 points
- GPT: Rank 2 → 14 × 1.5 = 21 points
- Gemini: Rank 7 → 9 × 1.0 = 9 points

Total: 45 points (instead of 38 unweighted)
```

**Max possible:** (15 × 1.0) + (15 × 1.5) + (15 × 1.0) = 52.5 points

**Implementation note:** Not in MVP, save for v2 after performance tracking

---

## Quick Reference: Borda Count Formula

**Single idea score:**

```
Score = Σ (16 - Rankᵢ) for i in [Claude, GPT, Gemini]
```

**Variance:**

```
Mean = Σ Rankᵢ / 3
Variance = Σ (Rankᵢ - Mean)² / 3
```

**Standard Deviation:**

```
SD = √Variance
```

**Confidence Check:**

```
High Score + Low Variance = Confident Winner
High Score + High Variance = Investigate Dissent
Low Score + Low Variance = Clear Loser
Low Score + High Variance = Outlier (one model disagrees)
```

---

## Python Implementation Reference

```python
def borda_count(rankings_dict):
    """
    Calculate Borda count scores and variance.

    Args:
        rankings_dict: {idea_id: {'claude': rank, 'gpt': rank, 'gemini': rank}}

    Returns:
        List of {idea_id, score, variance, sd, ranks}
    """
    results = []

    for idea_id, ranks in rankings_dict.items():
        # Extract ranks
        claude_rank = ranks['claude']
        gpt_rank = ranks['gpt']
        gemini_rank = ranks['gemini']
        rank_list = [claude_rank, gpt_rank, gemini_rank]

        # Borda points (16 - rank)
        claude_pts = 16 - claude_rank
        gpt_pts = 16 - gpt_rank
        gemini_pts = 16 - gemini_rank
        total_score = claude_pts + gpt_pts + gemini_pts

        # Variance
        mean_rank = sum(rank_list) / len(rank_list)
        variance = sum((r - mean_rank) ** 2 for r in rank_list) / len(rank_list)
        sd = variance ** 0.5

        results.append({
            'idea_id': idea_id,
            'score': total_score,
            'variance': round(variance, 2),
            'sd': round(sd, 2),
            'ranks': rank_list,
            'mean_rank': round(mean_rank, 2)
        })

    # Sort by score (descending)
    results.sort(key=lambda x: x['score'], reverse=True)

    return results
```

---

## Further Reading

**Academic Papers:**

- Borda, J. C. (1784). "Mémoire sur les élections au scrutin"
- Saari, D. (1995). "Basic Geometry of Voting"

**Applications:**

- Eurovision Song Contest (country voting)
- College football rankings (AP Poll, Coaches Poll)
- Wine competitions
- Olympic figure skating

**Comparison Studies:**

- Arrow's Impossibility Theorem (no perfect voting system)
- Condorcet vs Borda tradeoffs

---

**Version:** 1.0
**Last Updated:** 2026-01-31
