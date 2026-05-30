# Flywheel Workflow: Idea to Commit

A step-by-step walkthrough of Jeffrey Emanuel's agentic coding flywheel. Follow this sequentially for your first run. With practice, this becomes second nature.

---

## Overview

```
IDEA → PLAN → REFINE → BEADIFY → POLISH BEADS → SWARM → REVIEW → COMMIT
 5%     30%    30%       10%        10%           10%      4%       1%
```

**Time allocation:** 85% planning (steps 1-5), 15% execution (steps 6-8)

---

## Step 1: Idea (5 min)

**Goal:** Capture the raw concept. Don't overthink it.

Write 1-2 paragraphs describing:

- What you're building
- What problem it solves
- Reference implementations (if any)
- Technical constraints (stack, libraries)
- Quality bar ("Stripe-level", "world-class")

**Example:**

```
Build a REST API for tracking daily habits. Users can create habits,
log completions, and view streaks. Use Node.js with Express and SQLite.
Should have clean API contracts and comprehensive error handling.
Similar to the Habitica API but simpler.
```

Save as `PLAN.md` in your project root.

---

## Step 2: Initial Plan (30-60 min)

**Goal:** Create a comprehensive plan document.

**Tool:** ChatGPT Pro with Extended Reasoning (web app) OR Claude Opus

**Prompt:**

```
I want to build [PASTE YOUR IDEA]. Create a comprehensive implementation
plan as a markdown document. Include:

1. Architecture overview
2. Data models and schemas
3. API endpoints / user workflows
4. Technology choices with justification
5. Error handling strategy
6. Testing strategy
7. Implementation sequence (what to build first)
8. Known risks and mitigations

Be detailed. This plan will guide AI coding agents to implement
everything. The more detail here, the better the implementation.
```

**Output:** Save the response as your `PLAN.md` (overwrite the initial idea).

---

## Step 3: Refine Plan (1-3 hours, 3-5 rounds)

**Goal:** Iterate until improvements plateau ("steady state").

### Round Pattern:

**A) Get suggestions from GPT Pro:**

```
Carefully review this entire plan for me and come up with your best
revisions in terms of better architecture, new features, changed features,
etc. to make it better, more robust/reliable, more performant, more
compelling/useful, etc. For each proposed change, give me your detailed
analysis and rationale/justification for why it would make the project
better along with the git-diff style changes relative to the original
markdown plan shown below:

<PASTE COMPLETE PLAN>
```

**B) Have Claude integrate + critique:**

```
OK, now integrate these revisions to the markdown plan in-place; use
ultrathink and be meticulous. At the end, you can tell me which changes
you wholeheartedly agree with, which you somewhat agree with, and which
you disagree with:

<PASTE GPT PRO'S SUGGESTIONS>
```

**C) Repeat 3-5 times until changes are incremental.**

### Optional: Multi-Model Blending

After 3+ rounds, get competing plans from Gemini and Grok, then:

```
I asked 3 competing LLMs to do the exact same thing and they came up
with pretty different plans. I want you to REALLY carefully analyze
their plans with an open mind and be intellectually honest about what
they did that's better than your plan. Then come up with the best
possible revisions that artfully blends the "best of all worlds":

<PASTE COMPETING PLANS>
```

**When to stop:** When each round produces only minor tweaks, not structural changes.

---

## Step 4: Convert Plan to Beads (20-30 min)

**Goal:** Transform the refined plan into granular, dependency-aware tasks.

**Tool:** Claude Code (on VM where beads is installed)

**Prompt:**

```
OK so please take ALL of that and elaborate on it more and then create
a comprehensive and granular set of beads for all this with tasks,
subtasks, and dependency structure overlaid, with detailed comments so
that the whole thing is totally self-contained and self-documenting
(including relevant background, reasoning/justification, considerations,
etc.-- anything we'd want our "future self" to know about the goals and
intentions and thought process). Use only the `br` tool to create and
modify the beads and add the dependencies. Use ultrathink.
```

**Key commands the agent will use:**

```bash
br create "Epic: User Authentication" --label auth
br create "Implement JWT token generation" --parent <epic-id> --label auth
br dep add <child-id> <parent-id>  # child depends on parent
br label add <id> "backend"
```

---

## Step 5: Polish Beads (30-60 min, 6-8 rounds)

**Goal:** Refine beads until they're so detailed agents don't need to make decisions.

**Run this prompt 6-8 times:**

```
Reread AGENTS.md so it's still fresh in your mind. Check over each bead
super carefully-- are you sure it makes sense? Is it optimal? Could we
change anything to make the system work better for users? If so, revise
the beads. It's a lot easier and faster to operate in "plan space"
before we start implementing these things! DO NOT OVERSIMPLIFY THINGS!
DO NOT LOSE ANY FEATURES OR FUNCTIONALITY! Also make sure that as part
of the beads we include comprehensive unit tests and e2e test scripts
with great, detailed logging. Use ultrathink.
```

**When to stop:** When running the prompt produces no meaningful changes.

**Quality check:** Each bead should be:

- Self-contained (no need to reference the original plan)
- Clear on what "done" looks like
- Explicit about dependencies
- Include test criteria
- Rich with context for "future self"

---

## Step 6: Launch Swarm (or Single Agent)

**Goal:** Start implementation.

### Single Agent (recommended for first run):

```
First read ALL of the AGENTS.md file super carefully and understand ALL
of it! Then use your code investigation abilities to fully understand the
codebase. Then use bv --robot-next to find the highest-impact bead to
work on. Implement it fully, run tests, mark it done, and move to the
next bead. Use ultrathink.
```

### Multi-Agent Swarm (after you're comfortable):

**Launch with NTM:**

```bash
ntm spawn myproject --cc=3 --cod=1 --gmi=1  # 3 Claude, 1 Codex, 1 Gemini
```

**Each agent gets marching orders:**

```
First read ALL of the AGENTS.md file and README.md file super carefully.
Then register with MCP Agent Mail and introduce yourself to the other
agents. Use bv --robot-next to pick your first bead. Reserve files via
Agent Mail before editing. Work methodically, update teammates, mark
beads complete. Don't get stuck in "communication purgatory" -- be
proactive about starting work. Use ultrathink.
```

### The Implementation Loop (per bead):

```
1. bv --robot-next          → Pick highest-impact unblocked bead
2. Reserve files             → Agent Mail file reservation
3. Implement                 → Write code per bead specification
4. Test until passing        → Ralph Loop (fix until tests pass)
5. Self-review              → "Fresh eyes" review of own code
6. Mark bead done           → br close <bead-id>
7. Release files            → Release Agent Mail reservations
8. Check mail               → Respond to agent messages
9. Repeat from step 1
```

---

## Step 7: Quality Loops

**Goal:** Catch bugs and improve quality. Run between implementation rounds.

### Post-Implementation Review:

```
Great, now carefully read over all of the new code you just wrote and
other existing code you just modified with "fresh eyes" looking super
carefully for any obvious bugs, errors, problems. Carefully fix anything
you uncover. Use ultrathink.
```

### Cross-Agent Review (multi-agent):

```
Turn your attention to reviewing the code written by your fellow agents
and checking for any issues, bugs, errors, inefficiencies, security
problems. Diagnose underlying root causes using first-principle analysis
and fix them. Cast a wider net and go super deep! Use ultrathink.
```

### Random Deep Exploration:

```
Randomly explore the code files in this project, choosing code files to
deeply investigate and trace their execution flows. Do a super careful
check with "fresh eyes" to find any obvious bugs, problems, errors,
silly mistakes and systematically correct them. Use ultrathink.
```

### Our Review Prompts (with severity tiers):

- `/bug-hunter` — Quick scan with triage
- `/bug-hunter-genius` — Deep systematic forensic debugging
- `/bug-hunter-alien` — Transcendent dimensional bug hunting
- `/work-review` — Multi-agent parallel review with auto-fix

---

## Step 8: Commit

**Goal:** Clean commits with context.

**Prompt:**

```
Based on your knowledge of the project, commit all changed files now in
a series of logically connected groupings with super detailed commit
messages for each and then push. Don't edit the code at all. Don't
commit obviously ephemeral files. Use ultrathink.
```

Or use our `/commit` command which follows the same pattern.

---

## Tips for First Run

1. **Start with a small, real project** — not a toy example
2. **Single agent first** — add swarm later
3. **Don't rush planning** — it feels slow but pays off 10x during implementation
4. **Trust the process** — beads that feel "over-planned" are actually perfectly planned
5. **The "steady state" signal** — when refinement produces only minor tweaks, you're ready
6. **Keep AGENTS.md updated** — it's the single source of truth for agents

---

## Quick Reference

| Phase        | Time      | Tool             | Our Prompts                                      |
| ------------ | --------- | ---------------- | ------------------------------------------------ |
| Idea         | 5 min     | Any editor       | -                                                |
| Initial Plan | 30-60 min | GPT Pro / Claude | -                                                |
| Refine Plan  | 1-3 hours | GPT Pro + Claude | `/plan-review-genius`, `/plan-transcender-alien` |
| Beadify      | 20-30 min | Claude Code + br | (beadification prompt above)                     |
| Polish Beads | 30-60 min | Claude Code      | (bead refinement prompt above)                   |
| Execute      | varies    | Agents + bv      | `/agent-swarm-launcher`                          |
| Review       | ongoing   | Review prompts   | `/bug-hunter-genius`, `/work-review`             |
| Commit       | 5 min     | git              | `/commit`                                        |
