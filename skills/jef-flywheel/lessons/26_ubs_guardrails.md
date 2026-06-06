# UBS: Code Quality Guardrails

**Source:** github.com/Dicklesworthstone/agentic_coding_flywheel_setup

---

> **Goal:** Learn to catch bugs before they reach production with UBS.

          **UBS (Ultimate Bug Scanner)** is your safety net
          before every commit. It scans your code for common bugs, security
          issues, and anti-patterns that might slip through during development.

          Think of it as a code review bot that catches issues in seconds, not
          hours.

Run `ubs` before every
commit.

Exit 0 = safe to commit. Exit >0 = fix issues first.

> ---

            Always scope to changed files when possible.{" "}
            `ubs file.ts` runs in under 1 second, while{" "}
            `ubs .` may take 30+ seconds.

UBS output follows a consistent format:

```

            examples={[
              "Null safety violations",
              "XSS/Injection vulnerabilities",
              "Async/await issues",
              "Memory leaks",
            ]}

            examples={[
              "Type narrowing issues",
              "Division by zero risks",
              "Resource leaks",
              "Missing error handling",
            ]}

            examples={[
              "TODO/FIXME comments",
              "Console.log statements",
              "Unused variables",
              "Magic numbers",
            ]}

          For maximum safety, add UBS to your pre-commit workflow:

```

> ---

            ACFS agents are trained to run `ubs` automatically
            before committing. You get this protection by default!

```

// =============================================================================
// OUTPUT EXPLAINER
// =============================================================================
function OutputExplainer({
  pattern,
  meaning,
  color,
}: {
  pattern: string;
  meaning: string;
  color: string;
}) {

      `{pattern}`
      →
      {meaning}

// =============================================================================
// SEVERITY CARD
// =============================================================================
function SeverityCard({
  level,
  icon,
  color,
  border,
  examples,
  action,
}: {
  level: string;
  icon: React.ReactNode;
  color: string;
  border: string;
  examples: string[];
  action: string;
}) {

          {icon}

#### {level}

            {examples.map((ex, i) => (
              -
                {ex}

            ))}

            {action}

// =============================================================================
// FIX WORKFLOW
// =============================================================================
function FixWorkflow() {
  const steps = [
    { title: "Read finding", desc: "Understand the category and fix suggestion" },
    { title: "Navigate to location", desc: "Go to file:line:col" },
    { title: "Verify it's real", desc: "Not all findings are bugs—some are false positives" },
    { title: "Fix root cause", desc: "Don't just mask the symptom" },
    { title: "Re-run UBS", desc: "Confirm the fix worked (exit 0)" },
    { title: "Commit", desc: "Now you're safe to commit!" },
  ];

        {steps.map((step, i) => (

              {i + 1}

#### {step.title}

{step.desc}

        ))}
```
