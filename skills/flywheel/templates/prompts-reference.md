# Flywheel Prompts Reference

Every prompt needed at each stage of the flywheel, in execution order.

---

## Stage 1: Planning

### 1.1 Initial Plan Creation

```
I want to build [DESCRIPTION]. Create a comprehensive implementation
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

### 1.2 Plan Refinement (run 3-5 times)

```
Carefully review this entire plan for me and come up with your best
revisions in terms of better architecture, new features, changed
features, etc. to make it better, more robust/reliable, more performant,
more compelling/useful, etc. For each proposed change, give me your
detailed analysis and rationale/justification for why it would make the
project better along with the git-diff style changes relative to the
original markdown plan shown below:

<PASTE COMPLETE PLAN>
```

### 1.3 Claude Integration + Critique

```
OK, now integrate these revisions to the markdown plan in-place; use
ultrathink and be meticulous. At the end, you can tell me which changes
you wholeheartedly agree with, which you somewhat agree with, and which
you disagree with:

<PASTE GPT PRO'S SUGGESTIONS>
```

### 1.4 Multi-Model Blending

```
I asked 3 competing LLMs to do the exact same thing and they came up
with pretty different plans which you can read below. I want you to
REALLY carefully analyze their plans with an open mind and be
intellectually honest about what they did that's better than your plan.
Then I want you to come up with the best possible revisions to your plan
that artfully and skillfully blends the "best of all worlds" to create
a true, ultimate, superior hybrid version of the plan:

<PASTE COMPETING PLANS>
```

---

## Stage 2: Beadification

### 2.1 Plan to Beads Conversion

```
OK so please take ALL of that and elaborate on it more and then create
a comprehensive and granular set of beads for all this with tasks,
subtasks, and dependency structure overlaid, with detailed comments so
that the whole thing is totally self-contained and self-documenting
(including relevant background, reasoning/justification, considerations,
etc.-- anything we'd want our "future self" to know about the goals and
intentions and thought process and how it serves the over-arching goals
of the project.). Use only the `br` tool to create and modify the beads
and add the dependencies. Use ultrathink.
```

### 2.2 Bead Refinement (run 6-8 times)

```
Reread AGENTS.md so it's still fresh in your mind. Check over each bead
super carefully-- are you sure it makes sense? Is it optimal? Could we
change anything to make the system work better for users? If so, revise
the beads. It's a lot easier and faster to operate in "plan space"
before we start implementing these things! DO NOT OVERSIMPLIFY THINGS!
DO NOT LOSE ANY FEATURES OR FUNCTIONALITY! Also make sure that as part
of the beads we include comprehensive unit tests and e2e test scripts
with great, detailed logging so we can be sure that everything is
working perfectly after implementation. Use ultrathink.
```

---

## Stage 3: Execution

### 3.1 Agent Initialization (Single Agent)

```
First read ALL of the AGENTS.md file super carefully and understand ALL
of it! Then use your code investigation abilities to fully understand
the codebase and technical architecture. Then use bv --robot-next to
find the highest-impact bead to work on. Implement it fully, run tests,
mark it done, and move to the next bead. Use ultrathink.
```

### 3.2 Agent Initialization (Swarm)

```
First read ALL of the AGENTS.md file and README.md file super carefully
and understand ALL of both! Then use your code investigation agent mode
to fully understand the code, and technical architecture and purpose of
the project. Then register with MCP Agent Mail and introduce yourself
to the other agents.

Be sure to check your agent mail and to promptly respond if needed to
any messages; then proceed meticulously with your next assigned beads,
working on the tasks systematically and tracking your progress via beads
and agent mail messages.

Don't get stuck in "communication purgatory" where nothing is getting
done; be proactive about starting tasks that need to be done, but inform
your fellow agents via messages when you do so and mark beads
appropriately.

When you're not sure what to do next, use the bv tool mentioned in
AGENTS.md to prioritize the best beads to work on next; pick the next
one that you can usefully work on and get started. Use ultrathink.
```

### 3.3 Context Refresh (after compaction)

```
Reread AGENTS.md so it's still fresh in your mind. Use ultrathink.
```

### 3.4 Next Bead Selection

```
Reread AGENTS.md so it's still fresh in your mind. Use ultrathink. Use
bv with the robot flags (see AGENTS.md for info on this) to find the
most impactful bead(s) to work on next and then start on it. Remember
to mark the beads appropriately and communicate with your fellow agents.
Pick the next bead you can actually do usefully now and start coding on
it immediately.
```

---

## Stage 4: Quality

### 4.1 Post-Implementation Self-Review

```
Great, now I want you to carefully read over all of the new code you
just wrote and other existing code you just modified with "fresh eyes"
looking super carefully for any obvious bugs, errors, problems, issues,
confusion, etc. Carefully fix anything you uncover. Use ultrathink.
```

### 4.2 Cross-Agent Code Review

```
Ok can you now turn your attention to reviewing the code written by your
fellow agents and checking for any issues, bugs, errors, problems,
inefficiencies, security problems, reliability issues, etc. and
carefully diagnose their underlying root causes using first-principle
analysis and then fix or revise them if necessary? Don't restrict
yourself to the latest commits, cast a wider net and go super deep!
Use ultrathink.
```

### 4.3 Random Deep Exploration

```
I want you to sort of randomly explore the code files in this project,
choosing code files to deeply investigate and understand and trace their
functionality and execution flows through the related code files which
they import or which they are imported by. Once you understand the
purpose of the code in the larger context of the workflows, I want you
to do a super careful, methodical, and critical check with "fresh eyes"
to find any obvious bugs, problems, errors, issues, silly mistakes, etc.
and then systematically and meticulously and intelligently correct them.
Use ultrathink.
```

### 4.4 Testing Coverage

```
Do we have full unit test coverage without using mocks/fake stuff? What
about complete e2e integration test scripts with great, detailed logging?
If not, then create a comprehensive and granular set of beads for all
this with tasks, subtasks, and dependency structure overlaid with
detailed comments.
```

### 4.5 UI/UX Polish

```
I want you to super carefully scrutinize every aspect of the application
workflow and implementation and look for things that just seem
sub-optimal or even wrong/mistaken to you, things that could very
obviously be improved from a user-friendliness and intuitiveness
standpoint, places where our UI/UX could be improved and polished to be
slicker, more visually appealing, and more premium feeling and just
ultra high quality, like Stripe-level apps. Use ultrathink.
```

### 4.6 Escalation (when quality isn't good enough)

```
Ok, that's an amazing start but I know you can make this MUCH MUCH MUCH
better across every dimension we discussed:

- [Specific improvement area 1]
- [Specific improvement area 2]
- [Specific improvement area 3]

You need to think super hard about how to improve DRAMATICALLY in all
of those categories. Use ultrathink.
```

---

## Stage 5: Commit

### 5.1 Structured Commit

```
Now, based on your knowledge of the project, commit all changed files
now in a series of logically connected groupings with super detailed
commit messages for each and then push. Take your time to do it right.
Don't edit the code at all. Don't commit obviously ephemeral files.
Use ultrathink.
```

---

## Stage 6: Ideation (Mid-Project)

### 6.1 Competitive Brainstorming

```
Ok, now I want you to be super creative and come up with your very best
10 ideas for what would make this project even more useful and compelling
and handy and powerful and versatile for both human users AND AI agents
like yourself.

Before proposing your best 10 ideas, I want you to carefully think of
and model out, project forward, evaluate, a minimum of 100 potential
creative ideas, so be prepared to think for a super long time about all
this before responding!!!
```

### 6.2 Multi-Model Idea Evaluation

```
I asked a competing coding agent ([MODEL]) about this project and here
are its best ideas below; I want you to very carefully consider and
evaluate each of them and then give me your candid evaluation and score
them from 0 (worst) to 1000 (best) as an overall score that reflects:

- How good and smart the idea is
- How useful in practical, real-life scenarios
- How practical to implement correctly
- Whether utility justifies increased complexity and tech debt

Use ultrathink.
```

### 6.3 Ideas to Beads

```
OK, let's actually take your top [N] ideas by score and plan to do them
all; take the exact proposals for all [N], study them carefully in terms
of how we would actually need to go about implementing them cleverly and
effectively; then take ALL of that and elaborate on it more and then
create a comprehensive and granular set of beads for all this with tasks,
subtasks, and dependency structure overlaid, with detailed comments so
that the whole thing is totally self-contained and self-documenting.
Use ultrathink.
```
