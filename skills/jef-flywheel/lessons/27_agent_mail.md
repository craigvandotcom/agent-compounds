# Agent Mail Coordination

**Source:** github.com/Dicklesworthstone/agentic_coding_flywheel_setup

---

> **Goal:** Coordinate multiple agents without conflicts using Agent Mail.

          **MCP Agent Mail** is a coordination system that
          lets multiple AI agents work on the same project without stepping on
          each other's toes.

          Think of it as email + file locking for agents. Agents can send
          messages, claim files they're working on, and stay in sync—all
          persisted in git.

          Without coordination, multiple agents working on the same codebase
          can:

> ---

            Agent Mail is available as an MCP server. Your agents can use it
            automatically when configured!

```

```

```

```

> ---

            If you see `FILE_RESERVATION_CONFLICT`, another agent
            has the file. Wait for expiry, adjust your patterns, or use
            non-exclusive reservations.

            Key Functions

// =============================================================================
// PROBLEM CARD
// =============================================================================
function ProblemCard({
problem,
solution,
}: {
problem: string;
solution: string;
}) {

        ✗

        {problem}

      →

        ✓

        {solution}

// =============================================================================
// CONCEPT CARD
// =============================================================================
function ConceptCard({
icon,
title,
description,
children,
}: {
icon: React.ReactNode;
title: string;
description: string;
children: React.ReactNode;
}) {

          {icon}

#### {title}

{description}

      {children}

// =============================================================================
// PATTERN CARD
// =============================================================================
function PatternCard({
title,
description,
code,
}: {
title: string;
description: string;
code: string;
}) {

#### {title}

{description}

```

// =============================================================================
// COORDINATION FLOW
// =============================================================================
function CoordinationFlow() {
  const steps = [

      icon: ,
      title: "Register",
      desc: "Agent joins the project with a unique name",
      color: "from-blue-500/20 to-indigo-500/20",
      borderColor: "border-blue-500/30",
    },

      icon: ,
      title: "Reserve",
      desc: "Claim files before editing",
      color: "from-amber-500/20 to-orange-500/20",
      borderColor: "border-amber-500/30",
    },

      icon: ,
      title: "Communicate",
      desc: "Send messages to coordinate",
      color: "from-primary/20 to-violet-500/20",
      borderColor: "border-primary/30",
    },

      icon: ,
      title: "Work",
      desc: "Make changes within your reservation",
      color: "from-sky-500/20 to-cyan-500/20",
      borderColor: "border-sky-500/30",
    },

      icon: ,
      title: "Release",
      desc: "Free files for other agents",
      color: "from-emerald-500/20 to-teal-500/20",
      borderColor: "border-emerald-500/30",
    },
  ];

        {steps.map((step, i) => (

                {step.icon}

{step.title}

{step.desc}

            {i < steps.length - 1 && (
              <motion.span}}}

                →
              </motion.span>
            )}

        ))}

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

// =============================================================================
// FUNCTION ROW
// =============================================================================
function FunctionRow({ name, purpose }: { name: string; purpose: string }) {

      <code >
        {name}
      </code>
      {purpose}

```
