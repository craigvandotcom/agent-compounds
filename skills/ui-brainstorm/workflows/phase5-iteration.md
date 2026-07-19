# Phase 5: Iteration Support Workflow

**Goal:** Refine chosen idea or run new brainstorm round

**Input:** User decision from Phase 4 synthesis
**Output:** Refined design, mockup, or new brainstorm

---

## User Decision Points

After reviewing Phase 4 synthesis, user chooses:

**Option A: Accept Winner**
→ Proceed to mockup generation

**Option B: Refine Winner**
→ Run refinement round with constraints

**Option C: Explore Controversial Idea**
→ Deep dive into high-variance option

**Option D: Start Over**
→ New brainstorm with different context/screenshot

**Option E: Reject All**
→ Document learnings, try different approach

---

## Option A: Accept Winner → Mockup Generation

User selected winning idea, ready to visualize.

### Mockup Generation Tools

**Option 1: v0.dev (Vercel)**

- Best for: React/Next.js components
- Input: Text description of winning idea
- Output: Live preview + code

**Usage:**

```bash
# Manual: Copy winning idea description to v0.dev web interface
# Paste screenshot + description
# Iterate on generated preview
```

**Option 2: screenshot-to-code**

- Best for: Existing UI modifications
- Input: Original screenshot + modification instructions
- Output: Updated HTML/CSS

**Usage:**

```bash
# If screenshot-to-code CLI available:
screenshot-to-code [original-screenshot] --prompt "[winning idea description]"
```

**Option 3: Figma AI (Recommended for high-fidelity)**

- Best for: Detailed design handoff
- Input: Winning idea + brand guidelines
- Output: Figma file with components

**Usage:**

- Manual process
- Export description to Figma
- Use Figma AI to generate layouts
- Refine with design tokens

**Option 4: Native Claude Vision (Quick iteration)**

- Best for: Rapid concept validation
- Input: Screenshot + winning idea
- Output: Annotated mockup description

**Usage:**

```markdown
SCREENSHOT: [Attach original]

WINNING IDEA: [Paste winning idea from Phase 4]

TASK: Describe what this interface would look like after implementing this idea.

Focus on:

- Visual changes (layout, colors, typography)
- Interaction changes (hover states, transitions)
- Content changes (copy, icons, imagery)

Create detailed description a designer could implement.
```

---

## Option B: Refine Winner

User likes direction but wants modifications.

### Refinement Prompt

**Execute in Claude Code:**

```markdown
ORIGINAL WINNING IDEA:
[Paste winning idea from Phase 4]

USER CONSTRAINTS:
[What user wants adjusted - e.g., "make it work on mobile", "reduce implementation time", "increase visual impact"]

REFINEMENT TASK:
Generate 3 variations of the winning idea that address constraints.

For each variation:

1. Title (variation on original)
2. What changed from original
3. How it addresses constraint
4. Tradeoffs introduced
5. Updated rubric scores

FORMAT:

## Variation 1: [Title]

**Changes from Original:** [list]
**Constraint Addressed:** [how]
**New Tradeoffs:** [what's sacrificed]
**Updated Rubric:**

- Visual Appeal: [score] - [justification]
- Usability: [score] - [justification]
- Brand Alignment: [score] - [justification]
- Innovation: [score] - [justification]
- Feasibility: [score] - [justification]
  **Total:** [sum]
```

**Output:** 3 variations ready for quick selection

**Time:** ~2 minutes

---

## Option C: Explore Controversial Idea

User intrigued by high-variance idea despite low consensus.

### Deep Dive Analysis

**Execute in Claude Code:**

```markdown
CONTROVERSIAL IDEA:
[Paste high-variance idea from Phase 4]

DISAGREEMENT DATA:

- Claude ranked: [X]
- GPT ranked: [Y]
- Gemini ranked: [Z]
- Variance: [value]

DEEP DIVE TASK:
Analyze why models disagreed and when this idea might be right.

OUTPUT STRUCTURE:

## Disagreement Root Cause

[What fundamental assumption differs across models?]

## Proponent Case (Best Argument For)

[Synthesize strongest rationale from top-ranking model]

## Opponent Case (Best Argument Against)

[Synthesize strongest rationale from bottom-ranking model]

## Conditions for Success

[Specific circumstances where this idea would win]

## De-Risking Strategy

[How to test/validate before full implementation]

## Modified Version

[Compromise that addresses opponent concerns while keeping proponent vision]
```

**Output:** Decision framework for controversial idea

**Time:** ~3 minutes

---

## Option D: Start Over (New Round)

User wants fresh ideas with refined context.

### New Round Setup

**What changed:**

- Updated context (clarify misunderstanding from Round 1)
- New screenshot (different page/state)
- Adjusted rubric weights (emphasize different criteria)
- Exclude certain patterns (eliminate ideas from Round 1)

**Prompt for Round 2:**

```markdown
CONTEXT: Previous brainstorm generated 15 ideas. User wants new direction.

ROUND 1 LEARNINGS:
**Patterns to avoid:** [What didn't work]
**Constraints to emphasize:** [What matters most]
**New context:** [Updated problem description]

UPDATED RUBRIC WEIGHTS:

- Visual Appeal: [X%]
- Usability: [X%]
- Brand Alignment: [X%]
- Innovation: [X%]
- Feasibility: [X%]

TASK: Generate 5 new ideas (different from Round 1) using updated weights.
```

**Return to Phase 1 with refined inputs.**

---

## Option E: Reject All → Document Learnings

No ideas met user needs. Extract learnings for future.

### Post-Mortem Template

**File:** `knowledge/2-areas/software/design-critiques/YYYY-MM-DD-[project]-postmortem.md`

```markdown
# UI Brainstorm Post-Mortem: [Project]

**Date:** [timestamp]
**Outcome:** All ideas rejected

## What Went Wrong

**Misaligned Context:**
[Was the problem poorly defined?]

**Wrong Rubric Weights:**
[Did we optimize for the wrong criteria?]

**Insufficient Constraints:**
[What constraints should have been explicit upfront?]

**Model Limitations:**
[What did models consistently miss?]

## What to Try Next

**Alternative Approach:**
[Different methodology - e.g., start with user research, competitor teardown]

**Refined Context:**
[Rewrite problem description with new insights]

**Updated Rubric:**
[Adjust weights based on what mattered most]

## Learnings for Playbook

**Don't repeat:**

- [Mistakes to avoid]

**Do differently:**

- [Process improvements]

**Update rubric template:**

- [Suggested weight changes]
```

**Save learnings:** via the reflect skill (session-end capture to the memory substrate). **Retrieve past failures:** `qmd query "ui brainstorm failures" --json`

---

## Memory Integration

After any iteration outcome, save learnings.

### What to Save

**Winning Patterns:**

```markdown
Pattern: [What won]
Context: [When it won]
Score: [Consensus strength]
Rubric: [Which criteria dominated]
```

**Model Performance:**

```markdown
Claude: [Tendencies - conservative/innovative/practical]
GPT: [Tendencies]
Gemini: [Tendencies]

Best performer: [Which model's ideas won most]
```

**Rubric Refinements:**

```markdown
Original weights: [list]
What we learned: [Which criteria mattered most in reality]
Suggested weights: [Updated based on outcomes]
```

### Storage Location

**Memory substrate update:**

Invoke the **reflect** skill at session end to capture learnings to the memory
substrate (`infrastructure/memory/auto/` or the app-local equivalent) — typed
fact/rule file + `MEMORY.md` index line, dedupe-over-append via `qmd search` first.

**Manual tracking (optional):**
`knowledge/2-areas/software/design-critiques/_learnings.md`:

```markdown
## Brainstorm Session [N] - [Date]

**Project:** [name]
**Winning Idea:** [title]
**Key Insight:** [What we learned about what works]
**Model MVP:** [Which model contributed winner]
**Rubric Adjustment:** [Any weight changes recommended]
```

---

## Success Metrics (Post-Implementation)

Track implemented ideas to improve future brainstorms.

**File:** `knowledge/2-areas/software/design-critiques/_outcomes.md`

```markdown
## Implemented Ideas Tracker

### Idea: [Title] (Brainstorm YYYY-MM-DD)

**Consensus Score:** 44/45
**Implemented:** [Date]

**Pre-Implementation Baseline:**

- Task completion time: 45s
- User satisfaction: 3.2/5
- Support tickets: 12/week

**Post-Implementation Results:**

- Task completion time: 32s (-29%) ✅ Beat target
- User satisfaction: 3.8/5 (+19%) ✅ Beat target
- Support tickets: 9/week (-25%) ❌ Missed target

**Learnings:**

- High consensus score (44/45) predicted success
- Usability rubric was accurate predictor
- Support ticket reduction lagged (needed onboarding)

**Rubric Adjustment:**

- Increase Usability weight from 30% → 35%
- Add "Onboarding needed" criterion for complex changes
```

**Update after:** 2 weeks, 1 month, 3 months post-launch

---

## Command Shortcuts

Create quick commands for common iterations:

**File:** `.claude/commands/ui-refine.md`

```markdown
---
name: ui-refine
description: Refine a specific idea from last brainstorm
---

# UI Refine Command

USAGE: /ui-refine [idea-number] [constraint]

Load last brainstorm session from:
`knowledge/2-areas/software/design-critiques/[latest].md`

Extract Idea [idea-number].

Run refinement workflow from `ui-brainstorm/workflows/phase5-iteration.md` Option B.

Apply constraint: [constraint]

Generate 3 variations.
```

---

## Quality Checks (End of Iteration)

Before closing brainstorm session:

- [ ] User decision documented (which option chosen)
- [ ] Learnings saved to playbook or manual log
- [ ] Next steps clear (mockup, refinement, new round, reject)
- [ ] Success metrics baseline captured (if implementing)
- [ ] All session files indexed in `_index.md`

---

## Session Closure Template

**File:** Update `knowledge/2-areas/software/design-critiques/YYYY-MM-DD-[project]-final-report.md`

**Add to end:**

```markdown
---

## Session Closure

**Date:** [timestamp]
**Decision:** [Accept/Refine/Explore/StartOver/Reject]
**Next Action:** [Specific next step]

**Files Generated:**

- Generation: [path]
- Rankings: [path]
- Consensus: [path]
- Synthesis: [path]
- [Optional: Refinement/Mockup/PostMortem]

**Learnings Saved:** [Yes/No]
**Playbook Updated:** [Yes/No]

**Session Complete** ✅
```

---

## Time Estimate (Per Iteration Option)

- Option A (Mockup): 5-10 minutes
- Option B (Refinement): 2-3 minutes
- Option C (Deep Dive): 3-5 minutes
- Option D (New Round): ~10 minutes (mini-session)
- Option E (Post-Mortem): 3-5 minutes

---

**End of Workflow** - User has actionable next steps.
