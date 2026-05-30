# Insights from Jeffrey's Tweets (Oct 2025 - Feb 2026)

Practical knowledge extracted from @doodlestein's X/Twitter that goes beyond the lessons and GitHub docs.

---

## Model Selection & Roles

**Plan with Opus, execute with Sonnet:**

- Opus 4.5 for complex planning, architecture decisions, and agent coordination
- Sonnet 4.5 for high-volume implementation (much more usage per dollar)
- Sonnet is "eager to jump in" but makes sloppy mistakes — mitigate with code review loops
- Codex with high reasoning effort is slower but fewer mistakes

**Gemini for review duty:**

- Assign Gemini agents primarily to code review, not core implementation
- Different model = different perspective = catches blind spots

**Cross-pollination hack:**

- Give detailed instructions to Claude Code Opus, then re-use those instructions as a template for Codex/Gemini: "I just asked another agent (Claude Code Opus 4.5) to do the following: [paste]. Now you do the same thing."
- Gets multi-model diversity without re-writing prompts from scratch

## Planning Methodology (Extended)

**ChatGPT 5.2 Pro for plan refinement:**

- Paste entire markdown plan into ChatGPT 5.2 Pro web app with extended reasoning enabled
- Ask for detailed revisions with rationale and git-diff style changes
- Start fresh conversations each time (avoid context contamination)
- After 4-5 rounds, suggestions become incremental = steady state = done
- "Planning tokens are cheaper than implementation tokens"

**Don't prematurely automate:**

> "Don't prematurely automate until you have an intimate, intuitive feel for your 'core value-add loop.' Otherwise you'll have a fully automated system quickly that efficiently and automatically does a stupid or otherwise sub-optimal thing."

**Plan documents can be massive:**

- Jeffrey's plans routinely hit 5,000-6,000 lines
- "Not slop — the result of countless iterations and blending of ideas from many models"
- A 6,000-line plan is still shorter than the code it produces

## Agent Coordination Insights

**Agent Mail reminder problem:**

- Common complaint: agents forget to check their mail
- Solution: automated hooks that trigger mail checks (now works for Claude Code)
- Manual reminder also works: "Check your agent mail and promptly respond if needed"
- Jeffrey says "the benefit more than makes up for the annoyance"

**Communication purgatory:**

- Real danger: agents spend all their time messaging each other and nothing gets built
- Solution: explicit anti-stalling directive in AGENTS.md
- "Don't get stuck in 'communication purgatory' — be proactive about starting tasks"

**Agent personalities emerge:**

- Each model develops a distinct working style when given agent identity
- Speed, confidence, and cognitive power are intertwined
- Some agents are "bold" (start immediately), others are "cautious" (over-plan)
- This is a feature, not a bug — diversity of approaches catches more issues

## Tool Philosophy

**Unix approach > monolithic systems:**

> "The Unix tool approach of having a bunch of focused, composable functional units that can be used in isolation or as part of a larger pipeline is also the best approach for tooling for coding agents."

- One tool per function: mail, tasks, viewer, orchestration
- Problem with monolithic: "people have their own workflows and it's too hard to make one-size-fits-all"
- Each tool should work standalone AND compose with others

**MCP tool overload is real:**

> "Too many tools at once give the models 'paradox of choice' analysis paralysis and blows so much of the context window that it's like knocking them on the head with a lead pipe."

- Solution: "tool search meta-tool" — keep core tools globally, add others on demand
- At Craig's 3-agent scale: less of an issue, but still worth keeping MCP configs minimal
- Only include the tools agents actually need for the current task

## The Flywheel Effect

**Self-reinforcing tooling:**

> "My agentic coding workflow has gotten so meta and self-referential lately. I can feel the flywheel spinning faster and faster."

- Tools improve each other: NTM orchestrates agents that improve NTM
- Better tools → more capable agents → more code shipped → better understanding of needed tools → better tools
- "All the real value-add is happening 'by agents, for agents'"

**Agent-first design:**

> "You should make all your tooling agent-first because the agents are just better at this stuff."

- Tools should have `--robot` and `--json` flags for machine consumption
- TUI modes for humans, robot modes for agents
- "Offloads cognition from its brain onto its tooling, just like how a person can lean on spellcheck"

## Practical Tips

**Code review loops after implementation:**

- Sonnet/Codex make mistakes. Always run 2-3 rounds of:
  1. Self-review ("fresh eyes" prompt)
  2. Cross-agent review (other agents check your code)
  3. Random deep exploration (trace execution flows)

**Beads conversion takes coaxing:**

- "Claude took some coaxing and cajoling, but finally finished turning the 5,500 line plan into 347 beads"
- Large plans → large bead sets. Be patient. Use `ultrathink`.

**Structured commits:**

- Agents should commit in "logically connected groupings with super detailed commit messages"
- Don't edit code during commit phase
- Don't commit ephemeral files

**Skill organization:**

- Skills are "perfectly structured and organized directories filled with good information, insights, workflows"
- Optimized for AI consumption with "perfect progressive disclosure" and "token density"
- Our `.claude/skills/` format is already compatible with this philosophy

---

## Key Quotes Worth Remembering

> "It's a lot easier and faster to operate in 'plan space' before we start implementing these things!"

> "If you simply use these tools, workflows, and prompts in the way I just described, you can create really incredible software in just a couple days, sometimes in just one day."

> "The bottleneck in software isn't writing code — it's coordination."

> "Every tool you add makes every agent more productive, and the compounding never stops."

---

_Compiled: 2026-02-14_
_Sources: X/Twitter @doodlestein, ThreadReaderApp, WebSearch_
