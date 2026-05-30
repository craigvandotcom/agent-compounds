# Case Study: SLB

**Source:** github.com/Dicklesworthstone/agentic_coding_flywheel_setup

---

> **Goal:** See how a tweet becomes working code in one evening: 76 beads, 268

        commits, from idea to ~70% complete in hours.

          On December 13, 2025, a conversation on X about AI agents
          accidentally deleting Kubernetes nodes sparked an idea: what if
          dangerous commands required{" "}
          **peer review from another agent**?

          The idea was simple: like the "two-person rule" for nuclear
          launch codes, agents should need a second opinion before running
          destructive commands like rm -rf,{" "}
          kubectl delete, or{" "}
          DROP TABLE.

          Instead of just noting the idea for later, the flywheel approach is to{" "}
          **start immediately** while the idea is fresh.

> ---

            The key insight: an initial plan within the first hour, even if
            rough, is worth more than a perfect plan days later. The agents will
            help refine it.

          Once the initial plan existed, it was sent to multiple frontier models
          for review and improvement:

            The feedback was then integrated by Claude Code, with{" "}
            **multiple verification passes** to ensure nothing was
            missed:

```

> ****
            Each verification pass found something. This is why multiple passes
            are critical - they catch problems in the planning phase when
            they're easiest to fix.

          The refined plan was then transformed into structured, trackable
          beads. The prompt was carefully crafted to ensure thoroughness:

```

            Then, just like the plan itself, the beads went through verification
            passes:

```

          The Simultaneous Launch Button implements a{" "}
          **two-person rule** for AI coding agents:

          With beads ready, the agent swarm began implementation. The project
          was smaller than cass-memory, but the workflow was identical:

```

--status in_progress

# ... implement ...

br close <id>

# Commit agent runs every 15-20 min

cc "Commit all changes in logical groupings with
detailed messages. Don't edit code. Push when done."

```

            showLineNumbers

          By dinner time, about two-thirds of the project was complete. The
          agent swarm continued working while the developer ate, pushing commits
          autonomously.

          Compared to the 693-bead cass-memory project, SLB's 76 beads
          allowed for some workflow optimizations:

> ****
            Start with smaller projects to learn the workflow. Once
            you're comfortable with 50-100 beads, scale up to larger
            projects.

          Pick a small tool idea (something that would take you a day or two
          manually) and try this workflow:

```

> ---

            For your first flywheel project, aim for something with 50-100 beads.
            CLI tools, utilities, and small libraries are perfect candidates.

// =============================================================================
// IDEA CARD - The tweet inspiration
// =============================================================================
function IdeaCard() {

#### The WarGames Insight

"You know how in movies like WarGames they show how the two
guys have to turn the keys at the same time to arm the nuclear
warheads? I want to make something like that where for potentially
damaging commands, the agents have to get one other agent to agree
with their reasoning and sign off on the command."

            Two-person rule for AI agents

// =============================================================================
// TIMELINE CARD
// =============================================================================
function TimelineCard() {
const steps = [
{ time: "3:55 PM", event: "Idea sparked from tweet", icon: Lightbulb },
{ time: "~4:30 PM", event: "Initial plan drafted with Claude Code", icon: FileText },
{ time: "5:25 PM", event: "Plan document published", icon: GitBranch },
{ time: "Evening", event: "Multi-model feedback gathered", icon: MessageSquare },
{ time: "Night", event: "Beads created, implementation started", icon: LayoutDashboard },
];

      <h4 >

        December 13, 2025 Timeline
      </h4>

        {steps.map((step, i) => (

              <step.icon  />

                {step.time}

              {step.event}

        ))}

// =============================================================================
// FEEDBACK CARD
// =============================================================================
function FeedbackCard({
model,
focus,
color,
}: {
model: string;
focus: string;
color: string;
}) {

        {model}

{focus}

// =============================================================================
// BEADS RESULT CARD
// =============================================================================
function BeadsResultCard() {

#### Final Beads Structure

          14
          Epics

          62
          Tasks

          76
          Total Beads

Smaller than cass-memory's 693 beads, but still comprehensive
enough to capture the full implementation.

// =============================================================================
// RISK TIER CARD
// =============================================================================
function RiskTierCard() {
const tiers = [

      name: "CRITICAL",
      approvals: "2+",
      examples: "System destruction, database drops",
      color: "from-red-500/20 to-rose-500/20",
      border: "border-red-500/30",
    },

      name: "DANGEROUS",
      approvals: "1",
      examples: "rm -rf, git push --force",
      color: "from-orange-500/20 to-amber-500/20",
      border: "border-orange-500/30",
    },

      name: "CAUTION",
      approvals: "Auto (30s)",
      examples: "Single file delete, branch remove",
      color: "from-yellow-500/20 to-amber-500/20",
      border: "border-yellow-500/30",
    },

      name: "SAFE",
      approvals: "Skip",
      examples: "Temp file cleanup, cache clear",
      color: "from-emerald-500/20 to-teal-500/20",
      border: "border-emerald-500/30",
    },

];

{tiers.map((tier, i) => (

            {tier.name}

              {tier.approvals}{/^\d/.test(tier.approvals) ? (tier.approvals === "1" ? " approval" : " approvals") : ""}

{tier.examples}

      ))}

// =============================================================================
// RESULTS CARD
// =============================================================================
function ResultsCard() {

#### Implementation Results

          268
          Total Commits

          Go 1.21+
          Built In

          ~70%
          Day 1 Complete

// =============================================================================
// COMPARISON CARD
// =============================================================================
function ComparisonCard({
title,
items,
gradient,
}: {
title: string;
items: string[];
gradient: string;
}) {

#### {title}

        {items.map((item, i) => (
          -
            {item}

        ))}
