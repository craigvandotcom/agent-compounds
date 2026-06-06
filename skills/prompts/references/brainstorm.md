---
description: Pre-planning exploration when uncertain about approach - diverge wide, then converge
---

## Workflow Position

**Use when:**

- Not sure how to approach something
- Multiple valid solutions exist
- Need to explore possibilities
- Want fresh perspective before committing

**This is pre-planning exploration.** Use before creating implementation plans, committing to strategies, or making major decisions.

---

## Phase 0: Initialize

**MANDATORY FIRST STEP: Create task list with TaskCreate BEFORE starting.**

### Branch Safety Check

**Brainstorms are documentation and can be committed to any branch, but verify where you are:**

```bash
# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"
```

If on a feature branch, brainstorm outputs will be committed there. If on main, they go to main. Either is acceptable.

### Extract Topic

**From user input or ask:**

```
TOPIC: [What are we brainstorming?]
CONTEXT: [Why is this uncertain? What's the challenge?]
DOMAIN: [Software/Architecture/Business/Content/Life/Other]
```

### Determine Output Location

**Ask user or infer:**

- If project has `_plans/research/` → Use that
- If project has `docs/brainstorms/` → Use that
- Otherwise → Ask user: "Where should I save brainstorm artifacts?"

**Store location for rest of workflow:**

```
OUTPUT_DIR: [determined directory]
```

### Create Workflow Tasks

```
TaskCreate(subject: "Phase 1: DISCOVER - Divergent exploration", description: "Spawn 3 parallel explorers: codebase/context patterns, problem space, solution space", activeForm: "Discovering possibilities...")

TaskCreate(subject: "Phase 2: DEFINE - Convergent filtering", description: "Filter 50+ ideas to top 10, score using Jeffrey's criteria, identify top 3", activeForm: "Defining top approaches...")

TaskCreate(subject: "Phase 3: CHALLENGE - Escalation + Six Hats", description: "Challenge top 3 with MUCH BETTER prompt, stress test with Black/Yellow/Green hats", activeForm: "Challenging assumptions...")

TaskCreate(subject: "Phase 4: SYNTHESIZE - Decision brief", description: "Create brainstorm brief with recommendation, alternatives, and key decisions", activeForm: "Synthesizing findings...")
```

**Update task status with TaskUpdate as you progress through phases.**

---

## Phase 1: DISCOVER (Divergent Exploration)

**TaskUpdate(subject: "Phase 1: DISCOVER", status: "in_progress")**

### Spawn 3 Parallel Explorers (Single Message, 3 Task Calls)

```markdown
Task(code-explorer, model: haiku, "CONTEXT PATTERNS EXPLORER

**Topic:** [TOPIC]
**Challenge:** [CONTEXT]
**Domain:** [DOMAIN]

Your job: Find existing patterns, constraints, and prior art related to this topic.

For software projects:

- Search codebase for similar implementations
- Identify relevant patterns and utilities
- Find database/API patterns
- Locate any prior approaches to similar problems

For non-software projects:

- Search documentation for related decisions
- Identify constraints in project files
- Find prior approaches or related work
- Check for existing frameworks or structures

If project has CLAUDE.md or skill files, read relevant context.

Output to: [OUTPUT_DIR]/YYYY-MM-DD-HHMM-brainstorm-patterns-[topic].md

Format:

## Relevant Patterns Found

- [Pattern 1]: [location] - [how it relates]
- [Pattern 2]: [location] - [how it relates]

## Constraints Discovered

- [Constraint 1]
- [Constraint 2]

## Prior Art

- [Any previous attempts or related implementations]
  ")

Task(code-explorer, model: haiku, "PROBLEM SPACE EXPLORER

**Topic:** [TOPIC]
**Challenge:** [CONTEXT]
**Domain:** [DOMAIN]

Your job: Deeply understand the problem we're trying to solve. Don't jump to solutions—explore the problem itself.

Investigate:

1. What is the user/stakeholder actually trying to accomplish?
2. What pain points exist currently?
3. What are the edge cases and variations?
4. Who else has this problem? How do they solve it?
5. What assumptions are we making?

Generate 15-20 problem-focused questions or observations.

Output to: [OUTPUT_DIR]/YYYY-MM-DD-HHMM-brainstorm-problem-[topic].md

Format:

## Problem Understanding

[2-3 sentence articulation of the real problem]

## Key Questions

1. [Question about the problem]
2. [Question about users/stakeholders]
   ...

## Assumptions to Validate

- [Assumption 1]
- [Assumption 2]

## Related Problems

- [Similar problems in this domain]
  ")

Task(code-explorer, model: haiku, "SOLUTION SPACE EXPLORER

**Topic:** [TOPIC]
**Challenge:** [CONTEXT]
**Domain:** [DOMAIN]

Your job: Generate as many potential approaches as possible. Quantity over quality—we'll filter later.

Use SCAMPER technique:

- **S**ubstitute: What could we replace?
- **C**ombine: What could we merge?
- **A**dapt: What can we borrow from elsewhere?
- **M**odify: What can we change?
- **P**ut to other use: Other applications?
- **E**liminate: What can we remove?
- **R**everse: What if we did the opposite?

Generate 30+ raw solution ideas. Include:

- Obvious approaches
- Unconventional approaches
- Simple approaches
- Complex approaches
- 'Crazy' approaches

Output to: [OUTPUT_DIR]/YYYY-MM-DD-HHMM-brainstorm-solutions-[topic].md

Format:

## Raw Solution Ideas (30+)

1. [Idea] - [one sentence]
2. [Idea] - [one sentence]
   ...30+

## Categorized Summary

### Simple/Fast

- [Ideas]

### Standard/Expected

- [Ideas]

### Innovative/Unconventional

- [Ideas]

### Complex/Ambitious

- [Ideas]
  ")
```

**Wait for all 3 agents to complete.**

**Synthesize DISCOVER output:**

Read the 3 exploration files and compile:

- Total raw ideas generated
- Key constraints identified
- Problem understanding refined

**TaskUpdate(subject: "Phase 1: DISCOVER", status: "completed")**

---

## Phase 2: DEFINE (Convergent Filtering)

**TaskUpdate(subject: "Phase 2: DEFINE", status: "in_progress")**

### Spawn Sonnet Agent (Fresh Context)

```markdown
Task(sonnet, "100→10 FILTER AND SCORING

**Topic:** [TOPIC]
**Challenge:** [CONTEXT]
**Domain:** [DOMAIN]

**Discovery Context:**
[Paste synthesized output from Phase 1 - patterns, problem understanding, raw ideas]

---

Your job: Filter the 50+ raw ideas down to the top 10 using Jeffrey Emanuel's criteria.

## Step 1: Quick Filter

Go through each idea and mark:

- ✅ VIABLE: Could work, worth evaluating
- ❌ REJECT: Doesn't fit constraints, infeasible, or low value

Target: ~20 viable ideas

## Step 2: Score Viable Ideas (0-1000)

For each viable idea, score on:

1. **Concept Quality** (0-250): Is it fundamentally sound?
2. **Human Utility** (0-250): Does it solve real problems?
3. **Implementation Feasibility** (0-250): Can we build it correctly?
4. **Complexity/Debt Ratio** (0-250): Is the juice worth the squeeze?

**Total = Sum of 4 scores**

## Step 3: Top 10 Deep Dive

For each of the top 10 by score:

### [Rank]. [Idea Title] - Score: [X]/1000

**What it is:** [Concrete description]
**Why it scores well:** [Key strengths]
**Concerns:** [Weaknesses or risks]
**Implementation sketch:** [High-level approach]

## Step 4: Identify Top 3 Recommendations

Select the 3 ideas that best balance value and feasibility.

**#1 Recommended:** [Title]

- Score: [X]
- Why primary: [Rationale]

**#2 Alternative:** [Title]

- Score: [X]
- When to choose: [Criteria]

**#3 Alternative:** [Title]

- Score: [X]
- When to choose: [Criteria]

Output to: [OUTPUT_DIR]/YYYY-MM-DD-HHMM-brainstorm-filtered-[topic].md
")
```

**Wait for agent completion.**

**TaskUpdate(subject: "Phase 2: DEFINE", status: "completed")**

---

## Phase 3: CHALLENGE (Escalation + Six Hats)

**TaskUpdate(subject: "Phase 3: CHALLENGE", status: "in_progress")**

### Spawn Opus Agent (Extended Thinking, Fresh Context)

```markdown
Task(opus, "CHALLENGE AND STRESS TEST

**Topic:** [TOPIC]
**Challenge:** [CONTEXT]
**Domain:** [DOMAIN]

**Top 3 Approaches from Phase 2:**
[Paste the top 3 recommendations with scores and rationale]

---

## Part 1: 'MUCH MUCH MUCH Better' Challenge

For each of the top 3 approaches, I know you can make them MUCH MUCH MUCH better. Challenge each one:

### Approach 1: [Title]

**What's weak about this?**
[Identify specific weaknesses]

**What's missing?**
[Gaps in the thinking]

**Enhanced version:**
[How could this be dramatically improved?]

**Or entirely new angle:**
[If this approach is fundamentally flawed, what's a better direction?]

[Repeat for Approaches 2 and 3]

---

## Part 2: Six Hats Stress Test

Apply three critical thinking hats to the top approaches:

### Black Hat (Caution/Risks)

_What could go wrong? What are the risks?_

- For Approach 1: [Risks]
- For Approach 2: [Risks]
- For Approach 3: [Risks]
- **Overall:** [Biggest risk across all approaches]

### Yellow Hat (Benefits/Upside)

_What's the upside we might be missing?_

- For Approach 1: [Hidden benefits]
- For Approach 2: [Hidden benefits]
- For Approach 3: [Hidden benefits]
- **Overall:** [Biggest opportunity we might be underweighting]

### Green Hat (Creativity/Innovation)

_What unconventional angle haven't we tried?_

- Completely different framing: [New perspective]
- Combination approach: [Hybrid idea]
- 'What if' scenario: [Bold alternative]
- **Breakthrough idea:** [If there's one innovative idea that emerged, what is it?]

---

## Part 3: Refined Recommendations

After challenging, what are your refined top 3?

### Refined #1: [Title]

- Original or new: [Which]
- Score adjustment: [X → Y]
- Key insight from challenge: [What changed]
- Confidence: [0-100%]

### Refined #2: [Title]

- Original or new: [Which]
- Score adjustment: [X → Y]
- Key insight from challenge: [What changed]
- Confidence: [0-100%]

### Refined #3: [Title]

- Original or new: [Which]
- Score adjustment: [X → Y]
- Key insight from challenge: [What changed]
- Confidence: [0-100%]

### Potential Breakthrough (if any)

[If the challenge phase surfaced something genuinely new and better, describe it here]

Output to: [OUTPUT_DIR]/YYYY-MM-DD-HHMM-brainstorm-challenged-[topic].md
")
```

**Wait for agent completion.**

**TaskUpdate(subject: "Phase 3: CHALLENGE", status: "completed")**

---

## Phase 4: SYNTHESIZE (Decision Brief)

**TaskUpdate(subject: "Phase 4: SYNTHESIZE", status: "in_progress")**

### Read All Phase Outputs

- `[OUTPUT_DIR]/*-brainstorm-patterns-*.md`
- `[OUTPUT_DIR]/*-brainstorm-problem-*.md`
- `[OUTPUT_DIR]/*-brainstorm-solutions-*.md`
- `[OUTPUT_DIR]/*-brainstorm-filtered-*.md`
- `[OUTPUT_DIR]/*-brainstorm-challenged-*.md`

### Create Brainstorm Brief

**File:** `[OUTPUT_DIR]/YYYY-MM-DD-HHMM-brainstorm-[topic].md`

```markdown
# Brainstorm: [Topic]

**Date:** YYYY-MM-DD
**Status:** Ready for Planning
**Domain:** [DOMAIN]
**Phases Completed:** 4 (Discover → Define → Challenge → Synthesize)

---

## Problem Statement

[Clear articulation from problem explorer + refinements]

---

## Discovery Context

**Patterns/Constraints Found:**

- [Relevant pattern/constraint 1]
- [Relevant pattern/constraint 2]

**Prior Art:**

- [Any existing approaches]

---

## Ideas Explored (Top 10)

| Rank | Idea    | Score | Pros    | Cons    |
| ---- | ------- | ----- | ------- | ------- |
| 1    | [Title] | [X]   | [Brief] | [Brief] |
| 2    | ...     | ...   | ...     | ...     |
| ...  | ...     | ...   | ...     | ...     |
| 10   | ...     | ...   | ...     | ...     |

---

## Recommended Approach

**Primary: [Title]**

**Rationale:** [Why this approach, incorporating challenge insights]

**Key elements:**

- [Element 1]
- [Element 2]
- [Element 3]

**Confidence:** [X]%

---

### Alternatives Considered

**Option B: [Title]**

- Score: [X]
- When to choose: [Criteria]
- Tradeoffs: [Brief]

**Option C: [Title]**

- Score: [X]
- When to choose: [Criteria]
- Tradeoffs: [Brief]

---

## Six Hats Stress Test Summary

| Hat                    | Key Finding              |
| ---------------------- | ------------------------ |
| **Black** (Risks)      | [Top risk to watch]      |
| **Yellow** (Upside)    | [Opportunity to capture] |
| **Green** (Innovation) | [Unconventional angle]   |

---

## Key Decisions for Planning

These need to be decided before/during implementation planning:

- [ ] **Decision 1:** [Options A vs B - what it affects]
- [ ] **Decision 2:** [Options X vs Y - what it affects]

---

## Next Steps

**Proceed with:** [recommended approach]

**Alternative:** If [condition], consider [Option B/C] instead.

---

## Research Artifacts

- `*-brainstorm-patterns-*.md` - Context exploration
- `*-brainstorm-problem-*.md` - Problem space exploration
- `*-brainstorm-solutions-*.md` - Raw solution ideas
- `*-brainstorm-filtered-*.md` - Scored and filtered ideas
- `*-brainstorm-challenged-*.md` - Challenge phase output
```

### Safety Check & Commit

```bash
git status --short
```

**Review output:**

- **If ANY deletions (D):** STOP and ask user "You're about to delete X files. Is this intentional?"
- Wait for confirmation before proceeding if deletions present

### Commit Brainstorm Artifacts

```bash
git add [OUTPUT_DIR]/*-brainstorm-*.md

git commit -m "$(cat <<'EOF'
docs(brainstorm): [topic] - exploration complete

Phases: Discover → Define → Challenge → Synthesize
Ideas explored: [X] raw → [Y] filtered → 3 refined
Recommended: [approach name]
Confidence: [X]%

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Present to User

```markdown
## Brainstorm Complete: [Topic]

**Brief:** `[OUTPUT_DIR]/YYYY-MM-DD-HHMM-brainstorm-[topic].md`
**Research:** 5 supporting files in `[OUTPUT_DIR]/`
**Committed:** ✅

---

### Summary

**Problem:** [One sentence]

**Recommended Approach:** [Title]

- Confidence: [X]%
- [2-3 sentence summary]

**Alternatives:**

- Option B: [Title] - when [criteria]
- Option C: [Title] - when [criteria]

---

### Key Findings

**From Challenge Phase:**

- Risk to watch: [Black hat finding]
- Opportunity: [Yellow hat finding]
- Innovation angle: [Green hat finding]

---

### Ready for Planning?

**Options:**

1. **Proceed** → Create implementation plan using [recommended approach]
2. **Choose alternative** → Use [Option B or C] instead
3. **More exploration** → Specify what to dig into
4. **Adjust** → Tell me what to reconsider

**Which direction?**
```

**CRITICAL: WAIT for user's explicit choice before proceeding.**

**TaskUpdate(subject: "Phase 4: SYNTHESIZE", status: "completed")**

---

## Flexibility & Overrides

### User Can Adjust Process

**"Quick brainstorm"**
→ Skip Phase 3 (Challenge), go directly from Define to Synthesize

**"Just explore options"**
→ Run only Phase 1 (Discover), present raw ideas without filtering

**"Focus on [specific angle]"**
→ Adjust explorer prompts to emphasize that angle (e.g., "focus on performance" or "focus on UX")

**"Skip context search"**
→ For greenfield or conceptual brainstorms, skip context-explorer in Phase 1

**"Use Sonnet for challenge"**
→ Use Sonnet instead of Opus in Phase 3 (cheaper, faster, but less deep)

**Trust user's judgment on when to follow/skip steps.**

---

## Token Usage

**Expected:**

- Phase 1: ~15k tokens (3 Haiku agents)
- Phase 2: ~10k tokens (1 Sonnet agent)
- Phase 3: ~15k tokens (1 Opus agent)
- Phase 4: ~5k tokens (synthesis)
- **Total: ~45k tokens**

**Quick mode (skip Phase 3): ~30k tokens**

---

## Domain Flexibility

**This prompt works across domains:**

**Software/Architecture:**

- Feature design
- System architecture
- Technical approach selection

**Business/Strategy:**

- Product direction
- Market positioning
- Business model options

**Content:**

- Editorial strategy
- Content format exploration
- Campaign approaches

**Life Planning:**

- Career decisions
- Life transitions
- Personal projects

**Adapt explorer prompts to domain context while keeping methodology intact.**

---

## Integration with Other Workflows

**Works well with:**

- `plan-review-genius.md` - Run after brainstorm to stress-test selected approach
- `plan-transcender-alien.md` - Run after brainstorm to find paradigm-breaking alternatives
- `idea-review-genius.md` - Run on top 3 approaches for deeper forensic review
- `hundred-to-ten-filter.md` - Alternative to Phase 1+2 for rapid ideation

**The brainstorm provides direction; planning provides specifics.**

---

## Remember

**Brainstorming is divergent thinking before convergent planning.**

✅ Generate many ideas before filtering
✅ Score objectively using criteria
✅ Challenge assumptions aggressively
✅ Produce actionable brief for decision-making
✅ Fresh agent context per phase
✅ Commit artifacts before ending session

❌ Jump to implementation
❌ Filter too early
❌ Skip the challenge phase for important decisions
❌ Proceed without user direction choice
❌ Leave research uncommitted
