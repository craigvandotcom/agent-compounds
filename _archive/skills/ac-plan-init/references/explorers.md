<!-- mirror: ac-pipeline/references/delegation-contract.md § Child-spawn preamble -- edit there first -->

**Conductor: paste the block below VERBATIM at the head of EACH of the three `Task(...)`
prompts in this file, above its `First: read AGENTS.md` line, substituting the child's
minted `AGENT_NAME`.** It is the child-side environment contract and a pointer to it is
explicitly insufficient (canon § Child-spawn preamble) — a preamble that stays in this
header and never enters the constructed prompt has not been delivered to any child.

ENVIRONMENT CONTRACT (non-negotiable):
- WAIT for your own long-running commands in-shell (foreground, generous Bash
  timeout, or a foreground until-loop). Never arm a Monitor on your own command
  and end your turn — if a completion event already fired, read it and CONTINUE.
- Agent Mail: CHECK whether you hold `mcp__mcp-agent-mail__*` tools — assume neither way.
  Usually you do NOT: then don't try to register, and your conductor owns reservations.
  Either way, export the `AGENT_NAME` it gave you in each commit's own shell.
- Touching beads (`br`/`bv`)? The canon is `beads-standards` (+ its
  reference/bead-conventions.md for pipeline contracts) — read before inventing usage.
- After every push: verify origin SHA == local HEAD before proceeding.
- A guard block (dcg / pre-commit) means CHANGE APPROACH, never bypass. To DISCARD
  a change: `git checkout HEAD -- <path>` AND unscoped `git stash` are both blocked —
  use scoped `git stash push -- <paths>`; to read a pristine file, `git show <ref>:<path>`.
  Destructive commands (rm / find -delete) take FULLY-LITERAL paths: resolve
  first (`ls -d`), then paste literals — never `$VAR`, `$( )`, or a loop var.
  /tmp literals + distinctive /tmp globs are allowed; home/repo `rm -rf` never
  is — `git rm` if tracked, else gitignore-and-flag or ask the human.
- Shared checkout: `git commit -- <your files>` the INSTANT its ACs verify —
  pathspec on the COMMIT, because scoping only the `add` still publishes the
  shared index. **Never `git add -A` / `git add .` / `git commit -a`** — they
  sweep a concurrent agent's staged work into your bead's commit, silently.
  Minimal working-tree dwell; run `br` from the bead-board repo root.
- Autonomous run: never AskUserQuestion — Exhaust Rule.
- Return a structured `friction:` block (stage/cost/lesson/class; `[]` if clean).

# Plan Explorers (3 parallel agents)

Spawn all three in a **single message** (parallel). Each writes findings to
`_plans/research/`. Substitute `[feature]` and include a skill-hint line only if
Phase-1 skill routing found a relevant skill. Competitive framing: agents
compete — only evidence-backed findings count.

---

## Explorer 1: Patterns

```
Task(subagent_type: "general-purpose", model: "sonnet", prompt: """
First: read AGENTS.md for project context and conventions.
{If relevant skills identified: "Read the relevant skill file for domain patterns (see AGENTS.md > Available Skills)."}

You are finding existing patterns for [feature] in this codebase. You compete with 2 other explorers — only evidence-backed findings with file paths count.

## Method

1. Search project source directories (see AGENTS.md > Architecture) for similar components and utilities
2. Read neighboring files to understand established patterns
3. Note naming conventions, file structure, import patterns
4. Identify reusable code (hooks, utils, components) that the new feature should use
5. Check for similar features that were implemented before — what patterns did they follow?

## Output

Write findings to _plans/research/YYYY-MM-DD-HHMM-exploration-patterns-[feature].md

For each pattern found:
## Pattern N: Title
**File(s):** path/to/file:line
**What it does:** {description}
**Relevance:** How the new feature should use this pattern
**Evidence:** Code snippet or reference

Limit: top 7 patterns. Under 500 words. Cite files, not guesses.
""")
```

## Explorer 2: Dependencies

```
Task(subagent_type: "general-purpose", model: "sonnet", prompt: """
First: read AGENTS.md for project context and conventions.
{If relevant skills identified: "Read the relevant skill file for domain patterns (see AGENTS.md > Available Skills)."}

You are identifying dependencies and APIs needed for [feature]. You compete with 2 other explorers — only evidence-backed findings count.

## Method

1. Check project dependency manifest for relevant libraries already available
2. Search for imports of key libraries used in this project
3. Identify API routes and server actions that exist or need creation
4. Check database schema or data layer for relevant tables/models
5. Note any environment variables or config needed

## Output

Write findings to _plans/research/YYYY-MM-DD-HHMM-exploration-dependencies-[feature].md

For each dependency:
## Dependency N: Title
**Type:** Library | API Route | DB Table | Config | New Requirement
**Current state:** {exists/needs creation/needs modification}
**File(s):** path/to/file:line
**Details:** What's available and what's needed
**Evidence:** Import paths, function signatures, schema definitions

Limit: top 7 dependencies. Under 500 words. Cite files, not guesses.
""")
```

## Explorer 3: Constraints

```
Task(subagent_type: "general-purpose", model: "sonnet", prompt: """
First: read AGENTS.md for project context and conventions.
{If relevant skills identified: "Read the relevant skill file for domain patterns (see AGENTS.md > Available Skills)."}

You are researching constraints for [feature]. You compete with 2 other explorers — only evidence-backed constraints with file citations count.

## Method

1. Search for validation patterns, error handling, auth checks
2. Check for platform-specific constraints (offline sync, mobile, PWA, etc.)
3. Look at existing test patterns for similar features
4. Check for rate limiting, access policies, security boundaries
5. Identify potential conflicts with existing functionality

## Output

Write findings to _plans/research/YYYY-MM-DD-HHMM-exploration-constraints-[feature].md

For each constraint:
## Constraint N: Title
**Type:** Validation | Auth | Performance | Mobile | Testing | Security
**File(s):** path/to/file:line
**Impact:** How this constrains the implementation
**Evidence:** Code reference showing the constraint

Limit: top 7 constraints. Under 500 words. Cite files, not guesses.
""")
```
</content>
