# Safety Tools: SLB & CAAM

**Source:** github.com/Dicklesworthstone/agentic_coding_flywheel_setup

---

> **Goal:** Use DCG, SLB and CAAM for layered safety and account management.

          AI agents are powerful but can cause damage if misused. The
          Dicklesworthstone stack includes three safety tools:

          **SLB** implements a "two-person rule"
          for dangerous commands. Just like nuclear launch codes require two
          keys, SLB requires two approvals before executing risky operations.

> ---

            Never bypass SLB protections. If a command requires two approvals,
            there's a reason. Get a second opinion.

         --session-id <sid>",
              description: "Approve a pending request",
            },

              command: 'slb reject <id> --session-id <sid> --reason "..."',
              description: "Reject a pending request",
            },

              command: "slb status <request-id>",
              description: "Check status of a specific request",
            },
          ]}

          **DCG** blocks dangerous commands before they run.
          It inspects every command from Claude Code and stops destructive
          patterns like hard resets, force pushes, and recursive deletes.

          If a command is safe, it runs normally. If it's risky, DCG blocks
          it and suggests a safer alternative.

> ---

            Treat a DCG block as a safety checkpoint. Read the explanation and
            prefer the safer command whenever possible.

        ' --explain",
              description: "Explain why a command would be blocked",
            },

              command: "dcg packs",
              description: "List available protection packs",
            },

              command: "dcg install",
              description: "Register DCG as a Claude Code hook",
            },

              command: "dcg allow-once <code>",
              description: "Bypass a single approved command",
            },

              command: "dcg doctor",
              description: "Check installation and hook status",
            },
          ]}

          **CAAM** enables sub-100ms account switching for
          subscription-based AI services (Claude Max, Codex CLI, Gemini Ultra).
          Swap OAuth tokens instantly without re-authenticating.

         <email>",
              description: "Save current auth as a named profile",
            },

              command: "caam activate <tool> <email>",
              description: "Activate a saved profile",
            },

              command: "caam status [tool]",
              description: "Show currently active profile",
            },

              command: "caam delete <tool> <email>",
              description: "Remove a saved profile",
            },
          ]}

          DCG, SLB, and CAAM integrate with Claude Code, Codex, and Gemini:

```
 DCG: blocked git reset --hard
> Suggestion: git restore --staged .

# Example: Dangerous command triggers SLB
$ claude "delete all test files"
> SLB: This command requires approval
> Waiting for second approval...
> Run 'slb approve req-123 --session-id <sid>' from another session

# Example: Switch Claude accounts for a project
$ caam activate claude work@company.com
> Activated profile 'work@company.com' for claude
> Symlink updated in 47ms

$ claude "continue the project"
> Using profile: work@company.com
```

            <h4 >

              SLB Best Practices
            </h4>

            <h4 >

              DCG Best Practices
            </h4>

            <h4 >

              CAAM Best Practices
            </h4>

           --reason ...",
              "slb approve <id> --session-id ...",
              "slb status <id>",
            ]}
          ' --explain",
              "dcg packs",
              "dcg allow-once <code>",
              "dcg doctor",
            ]}
           <email>",
              "caam activate <tool> <email>",
              "caam status [tool]",
            ]}

// =============================================================================
// SLB DIAGRAM
// =============================================================================
function SlbDiagram() {

            rm -rf /
            Dangerous Command

          ↓

            Agent 1

          +

            Agent 2

          ↓

            Safe to Execute
            Two approvals received

// =============================================================================
// DANGER CARD
// =============================================================================
function DangerCard({
command,
risk,
slb,
}: {
command: string;
risk: string;
slb: string;
}) {

      `{command}`

        {risk}

        {slb}

// =============================================================================
// CAAM FEATURE
// =============================================================================
function CaamFeature({
icon,
title,
description,
}: {
icon: React.ReactNode;
title: string;
description: string;
}) {

        {icon}

#### {title}

{description}

// =============================================================================
// USE CASE
// =============================================================================
function UseCase({
scenario,
description,
}: {
scenario: string;
description: string;
}) {

        {scenario}
        —
        {description}

// =============================================================================
// BEST PRACTICE
// =============================================================================
function BestPractice({ text }: { text: string }) {

      {text}

// =============================================================================
// QUICK REF CARD
// =============================================================================
function QuickRefCard({
title,
commands,
color,
}: {
title: string;
commands: string[];
color: string;
}) {

#### {title}

        {commands.map((cmd) => (
          <code
            key={cmd}

            $ {cmd}
          </code>
        ))}
