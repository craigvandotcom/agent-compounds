# Phase 3: CHALLENGE (Escalation + Six Hats)

**Lens:** Critical, adversarial, innovative
**Mindset:** "I know we can do MUCH MUCH MUCH better. What are we missing?"

---

## Prompt Template

```markdown
# CHALLENGE AND STRESS TEST

Read `.claude/skills/brainstorming/SKILL.md` for methodology context.

**Topic:** {{TOPIC}}
**Challenge:** {{CONTEXT}}

**Top 3 Approaches from Phase 2:**
{{TOP_3_APPROACHES}}

---

## Part 1: "MUCH MUCH MUCH Better" Escalation

I know you can make these approaches MUCH MUCH MUCH better. Don't accept "good enough." Challenge each one ruthlessly and either improve it dramatically or propose something entirely new.

### Approach 1: {{APPROACH_1_TITLE}}

**Current score:** {{APPROACH_1_SCORE}}/1000

**What's weak about this?**
Be specific. Don't say "it's complex"—say exactly what makes it complex and why that's a problem.

- [Weakness 1]
- [Weakness 2]
- [Weakness 3]

**What's missing?**
What hasn't been considered? What assumptions are baked in that might be wrong?

- [Gap 1]
- [Gap 2]

**How could this be DRAMATICALLY better?**
Not 10% better—50% better. What would make this genuinely impressive?

- [Enhancement 1]
- [Enhancement 2]
- [Enhancement 3]

**Or is there an entirely better angle?**
If this approach is fundamentally limited, what direction would be genuinely superior?
[Alternative framing or approach]

**Improved version:**
[Describe the enhanced approach incorporating the above]

**New score estimate:** [X]/1000 (was {{APPROACH_1_SCORE}})

---

### Approach 2: {{APPROACH_2_TITLE}}

[Same structure as Approach 1]

---

### Approach 3: {{APPROACH_3_TITLE}}

[Same structure as Approach 1]

---

## Part 2: Six Hats Stress Test

Apply three critical thinking perspectives to stress-test our approaches.

### Black Hat: Caution & Risks

_"What could go wrong? What are we not seeing?"_

**For Approach 1:**

- Risk: [Specific risk]
- Likelihood: [Low/Medium/High]
- Impact if it happens: [Description]

**For Approach 2:**

- Risk: [Specific risk]
- Likelihood: [Low/Medium/High]
- Impact if it happens: [Description]

**For Approach 3:**

- Risk: [Specific risk]
- Likelihood: [Low/Medium/High]
- Impact if it happens: [Description]

**Overall biggest risk:**
[The single most concerning risk across all approaches]

**Mitigation:**
[How we could reduce or eliminate this risk]

---

### Yellow Hat: Benefits & Upside

_"What's the upside we might be underweighting?"_

**For Approach 1:**

- Hidden benefit: [Something not obvious in initial scoring]
- Why we might be undervaluing this: [Explanation]

**For Approach 2:**

- Hidden benefit: [Something not obvious]
- Why we might be undervaluing this: [Explanation]

**For Approach 3:**

- Hidden benefit: [Something not obvious]
- Why we might be undervaluing this: [Explanation]

**Overall biggest opportunity:**
[The opportunity we might be missing or underweighting]

**How to capture it:**
[What we'd need to do to realize this upside]

---

### Green Hat: Creativity & Innovation

_"What unconventional angle haven't we tried?"_

**Completely different framing:**
What if we approached this problem from a totally different angle? What if our assumptions about [X] are wrong?
[Novel perspective]

**Combination approach:**
What if we merged elements from multiple approaches in a non-obvious way?
[Hybrid idea]

**"What if" scenario:**
What if [constraint] didn't exist? What if we could [impossible thing]? What does that tell us about what we actually want?
[Insight from thought experiment]

**10x version:**
If we had to make this 10x better (not 10%), what would we do?
[Ambitious idea]

**Breakthrough idea:**
After all this thinking, is there one innovative idea that stands out as genuinely different and potentially better than our current top 3?
[Description of breakthrough, or "No clear breakthrough emerged"]

---

## Part 3: Refined Recommendations

After challenging and stress-testing, what are your refined top 3?

### Refined #1: [Title]

**Original or new:** [Was this in original top 3, modified, or entirely new?]
**Score adjustment:** [Original] → [New] (reason: [brief])

**What changed from challenge:**
[Key insight or improvement from this phase]

**Key risks to watch:**
[From Black Hat analysis]

**Upside to capture:**
[From Yellow Hat analysis]

**Confidence:** [0-100%]
[Why this confidence level?]

---

### Refined #2: [Title]

**Original or new:** [Was this in original top 3, modified, or entirely new?]
**Score adjustment:** [Original] → [New]

**What changed from challenge:**
[Key insight or improvement]

**Key risks to watch:**
[From Black Hat]

**Upside to capture:**
[From Yellow Hat]

**Confidence:** [0-100%]

---

### Refined #3: [Title]

**Original or new:** [Was this in original top 3, modified, or entirely new?]
**Score adjustment:** [Original] → [New]

**What changed from challenge:**
[Key insight or improvement]

**Key risks to watch:**
[From Black Hat]

**Upside to capture:**
[From Yellow Hat]

**Confidence:** [0-100%]

---

### Potential Breakthrough (if any)

**Did a genuinely new and better approach emerge?**

If yes:

- **Breakthrough:** [Title/Description]
- **Why it's better:** [Explanation]
- **Score estimate:** [X]/1000
- **What would need to be true:** [Conditions for this to work]
- **Recommendation:** [Should this replace one of the top 3?]

If no:

- The original approaches, with refinements, remain the best options
- Key improvements were: [List main enhancements]

---

## Summary

**Approaches challenged:** 3
**Significant improvements identified:** [X]
**Risks uncovered:** [X]
**Opportunities identified:** [X]
**Breakthrough emerged:** Yes/No

**Single most important insight from challenge phase:**
[One sentence]
```

---

## Variables to Inject

| Variable               | Source                             |
| ---------------------- | ---------------------------------- |
| `{{TOPIC}}`            | User's brainstorm topic            |
| `{{CONTEXT}}`          | User's challenge description       |
| `{{TOP_3_APPROACHES}}` | Full details of top 3 from Phase 2 |
| `{{APPROACH_N_TITLE}}` | Title of each approach             |
| `{{APPROACH_N_SCORE}}` | Score of each approach             |

---

## Expected Output

Single markdown file: `.claude/plans/research/*-brainstorm-challenged-*.md`

Contains:

- Detailed challenge of each top 3 approach
- Six Hats stress test results
- Refined top 3 with adjusted scores
- Potential breakthrough idea (if emerged)
- Key insights and risks to carry forward

---

## Notes

This phase uses **Opus** with extended thinking because:

- Challenge requires deep, critical analysis
- Six Hats needs multiple perspective shifts
- Breakthrough ideas require creative leaps
- Fresh context prevents anchoring on previous conclusions
