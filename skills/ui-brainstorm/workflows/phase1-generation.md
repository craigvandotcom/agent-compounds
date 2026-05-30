# Phase 1: Idea Generation Workflow

**Goal:** Generate 15 unique UI/UX improvement ideas from 3 cutting-edge vision models

**Input:** Screenshot + context description
**Output:** 15 structured ideas with rubric scores

**Key Change:** All models receive the actual screenshot directly (no text bridges).

---

## Model 1: Claude Opus 4.6 (Native Vision)

**Execute directly in Claude Code conversation:**

```markdown
CONTEXT: [User's context about what needs improvement]

SCREENSHOT: [Attach screenshot]

TASK: Generate 5 UI/UX improvement ideas for this interface.

For each idea:

1. Title (3-5 words)
2. Description (2-3 sentences explaining the change)
3. Score against design rubric:
   - Visual Appeal (1-5): Does it look professional and engaging?
   - Usability (1-5): Is it intuitive and accessible?
   - Brand Alignment (1-5): Does it match brand identity?
   - Innovation (1-5): Does it differentiate from competitors?
   - Feasibility (1-5): Can it be implemented reasonably?

Format each idea as:

## Idea [N]: [Title]

**Description:** [explanation]
**Rubric Scores:**

- Visual Appeal: [score] - [justification]
- Usability: [score] - [justification]
- Brand Alignment: [score] - [justification]
- Innovation: [score] - [justification]
- Feasibility: [score] - [justification]
  **Total:** [sum]

CONSTRAINTS:

- Each idea must be distinct (no variations of same concept)
- Focus on user impact, not technical implementation
- Justify each rubric score with specific reasoning
```

**Capture Claude's 5 ideas to working doc.**

---

## Model 2: Gemini 3.1 Pro (Vision via OpenRouter)

**Model:** `google/gemini-3.1-pro-preview`

**CLI Method:**

**Step 1: Create prompt file**

```bash
cat > /tmp/gemini-prompt.txt << 'EOF'
CONTEXT: [User's context]

TASK: Generate 5 UI/UX improvement ideas for this interface.

For each idea:
1. Title (3-5 words)
2. Description (2-3 sentences)
3. Score against design rubric:
   - Visual Appeal (1-5): Professional and engaging?
   - Usability (1-5): Intuitive and accessible?
   - Brand Alignment (1-5): Matches brand identity?
   - Innovation (1-5): Differentiates from competitors?
   - Feasibility (1-5): Can be implemented reasonably?

Format:
## Idea [N]: [Title]
**Description:** [explanation]
**Rubric Scores:**
- Visual Appeal: [score] - [justification]
- Usability: [score] - [justification]
- Brand Alignment: [score] - [justification]
- Innovation: [score] - [justification]
- Feasibility: [score] - [justification]
**Total:** [sum]

CONSTRAINTS:
- Each idea must be distinct
- Focus on user impact
- Justify each score
EOF
```

**Step 2: Run with vision**

```bash
openrouter --file /tmp/gemini-prompt.txt --image [screenshot-path] -m gemini --max-tokens 2000 --raw -o /tmp/gemini-ideas.md
```

**Capture Gemini's 5 ideas to working doc.**

---

## Model 3: Grok 4.20 (via OpenRouter)

**Model:** `x-ai/grok-4.20-beta`

**CLI Method:**

**Step 1: Create prompt file**

```bash
cat > /tmp/grok-prompt.txt << 'EOF'
CONTEXT: [User's context]

TASK: Generate 5 UI/UX improvement ideas for this interface.

For each idea:
1. Title (3-5 words)
2. Description (2-3 sentences)
3. Score against design rubric:
   - Visual Appeal (1-5): Professional and engaging?
   - Usability (1-5): Intuitive and accessible?
   - Brand Alignment (1-5): Matches brand identity?
   - Innovation (1-5): Differentiates from competitors?
   - Feasibility (1-5): Can be implemented reasonably?

FORMAT:
## Idea [N]: [Title]
**Description:** [explanation]
**Rubric Scores:**
- Visual Appeal: [score] - [justification]
- Usability: [score] - [justification]
- Brand Alignment: [score] - [justification]
- Innovation: [score] - [justification]
- Feasibility: [score] - [justification]
**Total:** [sum]

CONSTRAINTS:
- Each idea must be distinct
- Focus on user impact
- Justify each score
EOF
```

**Step 2: Run with vision**

```bash
openrouter --file /tmp/grok-prompt.txt --image [screenshot-path] -m grok --max-tokens 2000 --raw -o /tmp/grok-ideas.md
```

**Capture Grok's 5 ideas to working doc.**

---

## Consolidation

**Create master doc with all 15 ideas:**

**File:** `knowledge/2-areas/software/design-critiques/YYYY-MM-DD-[project]-generation.md`

**Structure:**

```markdown
# UI Brainstorm: [Project] - Idea Generation

**Date:** [timestamp]
**Screenshot:** [path]
**Context:** [user's problem description]

## Claude Opus 4.6 Ideas (1-5)

[Paste Claude's 5 ideas]

## Gemini 3.1 Pro Ideas (6-10)

[Paste Gemini's 5 ideas, renumbered 6-10]

## Grok 4.20 Ideas (11-15)

[Paste Grok's 5 ideas, renumbered 11-15]

---

**Next Phase:** Cross-pollination ranking (phase2-ranking.md)
```

---

## Quality Checks

Before proceeding to Phase 2:

- [ ] All 15 ideas present and numbered
- [ ] Each idea has all 5 rubric scores
- [ ] Scores are justified (not just numbers)
- [ ] No obvious duplicates across models
- [ ] Ideas are UI/UX focused (not technical implementation)
- [ ] Context/screenshot clearly documented

---

## Common Issues

| Problem                          | Solution                                                 |
| -------------------------------- | -------------------------------------------------------- |
| Model generated only 3-4 ideas   | Re-run with explicit "Generate exactly 5 distinct ideas" |
| Duplicate concepts across models | Proceed anyway - ranking will surface best version       |
| Missing rubric scores            | Request model to score all 5 criteria                    |
| Vague descriptions               | Ask for specific user-facing changes                     |
| No justifications                | Require reasoning for each score                         |

---

## Time Estimate

- Screenshot analysis: 30 seconds
- Claude generation: 60 seconds
- GPT generation: 60 seconds (+ manual copy if using web)
- Gemini generation: 60 seconds (+ manual copy if using web)
- Consolidation: 60 seconds

**Total: ~5 minutes**

---

**Next:** `phase2-ranking.md` for cross-pollination ranking
