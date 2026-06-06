# CASS: Learning from History

**Source:** github.com/Dicklesworthstone/agentic_coding_flywheel_setup

---

> **Goal:** Search across all past agent sessions to reuse solved problems.

          **CASS (Coding Agent Session Search)** indexes all
          your past agent conversations—Claude Code, Codex, Gemini, Cursor, and
          more—so you can find solutions to problems you've already solved.

          It's like having a searchable memory of everything your agents
          have ever done across all projects.

          You've likely solved many problems before with agents. Without
          CASS:

> ---

            CASS helps you avoid re-solving the same problems. Your past agent
            sessions are a goldmine of solutions!

          **Important:** Never run bare `cass`—it
          launches a TUI that may block your session. Always use{" "}
          `--robot` or `--json`.

          CASS returns structured results with session info and snippets:

```

> ****
            Use `cass expand` with the source path and line
            number to see the full conversation context!

```

// =============================================================================
// USE CASE CARD
// =============================================================================
function UseCaseCard({
problem,
solution,
}: {
problem: string;
solution: string;
}) {

          ✗

{problem}

          ✓

{solution}

// =============================================================================
// SEARCH PATTERN
// =============================================================================
function SearchPattern({
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
// SEARCH WORKFLOW
// =============================================================================
function SearchWorkflow() {
  const steps = [

      icon: ,
      title: "Search",
      desc: "Find relevant past sessions",
    },

      icon: ,
      title: "Review",
      desc: "Check snippets and scores",
    },

      icon: ,
      title: "Expand",
      desc: "View full context if needed",
    },

      icon: ,
      title: "Apply",
      desc: "Use the solution in your current work",
    },
  ];

        {steps.map((step, i) => (

              {step.icon}

#### {step.title}

{step.desc}

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


```
