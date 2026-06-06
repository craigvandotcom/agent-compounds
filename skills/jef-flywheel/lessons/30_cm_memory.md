# CM: CASS Memory

**Source:** github.com/Dicklesworthstone/agentic_coding_flywheel_setup

---

> **Goal:** Build procedural memory for agents that improves over time.

          **CM (CASS Memory System)** gives AI agents
          effective memory by extracting lessons from past sessions and making
          them retrievable for future work.

          Think of it like how humans learn: you encounter a problem, solve it,
          and remember the solution. CM does this for your agents automatically.

> ---

            CM builds a "playbook" of rules over time. The more
            sessions you analyze, the smarter your agents become!

          The `cm onboard` command guides you through analyzing past
          sessions and extracting valuable rules:

          Before starting complex tasks, retrieve relevant context from your
          playbook:

```

> ****
            Reference rule IDs in your work. For example: "Following
            b-8f3a2c, using bcrypt with cost 12..."

          " --json before non-trivial work'

```

```

// =============================================================================
// MEMORY DIAGRAM
// =============================================================================
function MemoryDiagram() {

          Past Sessions
          Raw conversations

          →

          →

          CM Analysis
          Extract lessons

          →

          →

          Playbook
          Actionable rules

// =============================================================================
// ONBOARDING STEPS
// =============================================================================
function OnboardingSteps() {
  const steps = [

      cmd: "cm onboard status",
      desc: "Check status and see recommendations",
    },

      cmd: "cm onboard sample --fill-gaps",
      desc: "Get sessions filtered by playbook gaps",
    },

      cmd: "cm onboard read /path/session.jsonl --template",
      desc: "Read session with rich context",
    },

      cmd: 'cm playbook add "rule" --category "category"',
      desc: "Add extracted rules",
    },

      cmd: "cm onboard mark-done /path/session.jsonl",
      desc: "Mark session as processed",
    },
  ];

  {steps.map((step, i) => (

            {i + 1}

            `{step.cmd}`

{step.desc}

      ))}

// =============================================================================
// PROTOCOL STEP
// =============================================================================
function ProtocolStep({
  number,
  title,
  description,
}: {
  number: number;
  title: string;
  description: string;
}) {

        {number}

#### {title}

{description}

// =============================================================================
// CATEGORY CARD
// =============================================================================
function CategoryCard({
  name,
  description,
  color,
}: {
  name: string;
  description: string;
  color: string;
}) {

      `{name}`

{description}

// =============================================================================
// BEST PRACTICE
// =============================================================================
function BestPractice({
  title,
  description,
}: {
  title: string;
  description: string;
}) {

{title}

{description}


```
