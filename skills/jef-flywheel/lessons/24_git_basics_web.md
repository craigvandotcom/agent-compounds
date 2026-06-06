# Git Essentials

**Source:** github.com/Dicklesworthstone/agentic_coding_flywheel_setup

---

> **Goal:** Master git basics and recognize dangerous operations before they happen.

          **Git** is a version control system that tracks
          changes to your code over time. Think of it like a detailed history
          of every change you've ever made, with the ability to go back to
          any point.

        ",
              description: "Stage a file for commit",
            },

              command: "git add .",
              description: "Stage all changes",
            },

              command: 'git commit -m "message"',
              description: "Create a commit with a message",
            },

              command: "git push",
              description: "Upload commits to remote",
            },

              command: "git pull",
              description: "Download and merge remote changes",
            },

              command: "git log --oneline",
              description: "View commit history",
            },

              command: "git diff",
              description: "See uncommitted changes",
            },
          ]}

          The .gitignore file tells git which files to
          ignore. This is **critical for security** because you
          never want to commit:

> ---

            **Never commit secrets!** If you accidentally commit an
            API key, consider it compromised. Rotate it immediately.

        ",
              description: "Create a new branch",
            },

              command: "git checkout <branch>",
              description: "Switch to a branch",
            },

              command: "git checkout -b <name>",
              description: "Create and switch in one command",
            },

              command: "git merge <branch>",
              description: "Merge branch into current branch",
            },

              command: "git branch -d <name>",
              description: "Delete a merged branch",
            },
          ]}

> ---

            Always create a new branch for features or experiments. Keep{" "}
            main stable.

          <strong >
            AI agents may propose these commands.
          </strong>{" "}
          Know what they do before approving them:

> ---

            **Before approving any git command from an agent:**

            1. Run git status to see current state

            2. Run git stash to save uncommitted work

            3. Only then proceed with destructive commands

          When things go wrong, these commands can help:

        ",
              description: "Discard changes to a specific file",
            },

              command: "git revert <commit>",
              description: "Create new commit that undoes a previous one",
            },
          ]}

```

# Or create a branch at that commit:
$ git branch recovery <hash>
```

```
 temp.txt
$ git stash
$ git stash pop
$ rm temp.txt
```

          showLineNumbers

// =============================================================================
// CONCEPT CARD
// =============================================================================
function ConceptCard({
term,
definition,
example,
}: {
term: string;
definition: string;
example: string;
}) {

#### {term}

{definition}

Example: {example}

// =============================================================================
// IGNORE ITEM
// =============================================================================
function IgnoreItem({
pattern,
reason,
critical,
}: {
pattern: string;
reason: string;
critical?: boolean;
}) {

      <code >
        {pattern}
      </code>
      {reason}
      {critical && (
        Security Risk
      )}

// =============================================================================
// DANGEROUS COMMAND
// =============================================================================
function DangerousCommand({
command,
effect,
alternative,
}: {
command: string;
effect: string;
alternative: string;
}) {

        `{command}`

**Effect:** {effect}

**Alternative:** {alternative}

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
