# Case Study: CASS Memory

**Source:** github.com/Dicklesworthstone/agentic_coding_flywheel_setup

---

> **Goal:** Learn the full flywheel workflow through a real project: 693 beads, 282

        commits on day one, 85% complete in hours.

          On December 7, 2025, a new project was conceived:{" "}
          **cass-memory** - a procedural memory system for
          coding agents. The goal? Go from zero to a fully functional CLI tool
          in a single day using the flywheel workflow.

          This lesson walks you through exactly how it was done, so you can
          replicate this workflow on your own projects.

          The first step isn't to start coding. It's to{" "}
          **gather diverse perspectives** on the problem.

            Each model received the same prompt with minimal guidance - just 2-3
            messages to clarify the goal. The key instruction: "Design a
            memory system that works for{" "}
            *all* coding agents, not just Claude."

> ---

            Save each conversation as markdown. The{" "}
            chat_shared_conversation_to_file tool makes
            this easy.

          Now comes the crucial step: have one model synthesize the best ideas
          from all proposals into a single master plan.

```

          The resulting plan was **5,600+ lines** - a comprehensive
          blueprint covering architecture, data models, CLI commands, the
          reflection pipeline, storage, and implementation roadmap.

          The plan is the bedrock of a successful agentic project. Let's
          dissect what makes{" "}
          <a

            the actual 5,600+ line plan

          </a>{" "}
          so effective.

          <h4 >

            Document Structure: 11 Major Sections
          </h4>

          <h4 >

            Patterns That Make Plans Effective
          </h4>

          <h4 >

            Distinctive Innovations in This Plan
          </h4>

> ****
            **What Your Plans Should Include:**

              - • **Executive summary** - Problem + solution in 1 page

              - • **Data models** - TypeScript/Zod schemas for all entities

              - • **CLI/API surface** - Every command with examples

              - • **Architecture diagrams** - ASCII boxes showing data flow

              - • **Error handling** - What can go wrong, how to recover

              - • **Implementation roadmap** - Prioritized phases with dependencies

              - • **Comparison tables** - Why this approach over alternatives

> ****
            The full plan is available at{" "}
            <a

              github.com/Dicklesworthstone/cass_memory_system
            </a>
            . Study it as a template for your own project plans.

          A 5,600-line markdown file is great for humans, but agents need{" "}
          **structured, trackable tasks**. This is where
          beads comes in.

```

> ---

            This transformation took multiple passes to refine. The agents
            reviewed and improved the beads structure several times.

          With 350+ beads ready, it's time to{" "}
          **unleash the swarm**. Multiple agents work in
          parallel, each picking up tasks based on what's ready.

```
 --status in_progress

# 3. Implement
# (agent does the work)

# 4. Close when done
br close <id>

# 5. Repeat
```

            showLineNumbers

            The agents coordinate using **bv** (beads viewer) to
            see what's ready, avoiding conflicts and ensuring the most
            important blockers get cleared first.

          When agents need to share context or coordinate on overlapping work,{" "}
          **Agent Mail** provides the communication layer.

```

> ****
            The full Agent Mail archive from this project was{" "}
            <a

              published as a static site
            </a>{" "}
            so you can see the actual agent-to-agent communication.

          With many agents working simultaneously, commits need careful
          orchestration. A dedicated{" "}
          **commit agent** runs continuously.

```

          This pattern ensures atomic, well-documented commits even when 10+
          agents are making changes simultaneously.

          After one day of flywheel-powered development, the cass-memory project
          achieved:

#### Key Lessons

          Ready to try this workflow on your own project? Here's the
          quickstart:

```

> ****
            Start smaller than the cass-memory example. Try this workflow with a
            project that would normally take you a day or two manually. Build
            your confidence before tackling larger projects.

// =============================================================================
// RESULTS CARD - Day 1 results summary
// =============================================================================
function ResultsCard() {

#### Day 1 Results

            693
            Total Beads

            282
            Day 1 Commits

            25+
            Agents Involved

            ~5hrs
            To 85% Complete

// =============================================================================
// PHASE CARD - Workflow phase container
// =============================================================================
function PhaseCard({
  phase,
  title,
  description,
  children,
}: {
  phase: number;
  title: string;
  description: string;
  children: ReactNode;
}) {

          {phase}

#### {title}

{description}

      {children}

// =============================================================================
// MODEL CARD - Individual AI model proposal
// =============================================================================
function ModelCard({
  name,
  color,
  focus,
}: {
  name: string;
  color: string;
  focus: string;
}) {

        {name}

{focus}

// =============================================================================
// SYNTHESIS RESULT CARD
// =============================================================================
function SynthesisResultCard() {

      <h4 >

        PLAN_FOR_CASS_MEMORY_SYSTEM.md
      </h4>

          5,600+ lines

          11 major
          sections

          Best ideas from
          4 models

          Complete{" "}
          implementation roadmap

// =============================================================================
// BEADS TRANSFORMATION CARD
// =============================================================================
function BeadsTransformationCard() {

#### Beads Structure

          14
          Epics

          350+
          Tasks

          13h
          Avg Lead Time

Tasks linked with dependencies so blockers are visible and agents know
        what to work on next.

// =============================================================================
// SWARM SETUP CARD
// =============================================================================
function SwarmSetupCard() {

#### The Agent Swarm

            Claude Code
            5-6 agents (Opus 4.5)

            Codex CLI
            3 agents (5.1 Max)

            Gemini CLI
            2 agents (review duty)

// =============================================================================
// COMMIT STATS CARD
// =============================================================================
function CommitStatsCard() {

#### Commit Statistics

          282
          Day 1 Commits

          ~12
          Per Hour

          Detailed
          Messages

The commit agent ran every 15-20 minutes, grouping changes logically and
        writing detailed commit messages.

// =============================================================================
// STAT CARD
// =============================================================================
function StatCard({
  value,
  label,
  gradient,
}: {
  value: string;
  label: string;
  gradient: string;
}) {

      {value}
      {label}

// =============================================================================
// PLAN SECTION CARD - Shows a section from the plan document
// =============================================================================
function PlanSectionCard({
  number,
  title,
  description,
  icon,
}: {
  number: number;
  title: string;
  description: string;
  icon: ReactNode;
}) {

          {number}

          {icon}

      <h5 >
        {title}
      </h5>

{description}

// =============================================================================
// PLAN PATTERN CARD - Shows a pattern that makes plans effective
// =============================================================================
function PlanPatternCard({
  title,
  description,
  gradient,
}: {
  title: string;
  description: string;
  gradient: string;
}) {

      <h5 >
        {title}
      </h5>

{description}

// =============================================================================
// INNOVATION CARD - Shows distinctive innovations from the plan
// =============================================================================
function InnovationCard({
  title,
  description,
}: {
  title: string;
  description: string;
}) {

        <h5 >
          {title}
        </h5>

{description}


```
