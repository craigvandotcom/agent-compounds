# UI Tester Prompt (Phase 1c)

<!-- mirror: ac-pipeline/references/delegation-contract.md § Child-spawn preamble -- edit there first -->

**Conductor: paste the block below VERBATIM at the head of EACH of the one `Task(...)`
prompt in this file, above its `First: read AGENTS.md` line, substituting the child's
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
- Shared checkout: commit your bead's files (pathspec-scoped) the INSTANT its
  ACs verify — minimal working-tree dwell; run `br` from the bead-board repo root.
- Autonomous run: never AskUserQuestion — Exhaust Rule.
- Return a structured `friction:` block (stage/cost/lesson/class; `[]` if clean).

Spawn one `browser-tester` per matched journey (all in one message, parallel). Substitute the resolved `<ARTIFACTS_DIR>` from Phase 0.

````
Task(subagent_type: "browser-tester", prompt: """
You are a browser tester. Your job: run a UI journey happy path and report results. You test and report — never edit code.

## Your Task
Run the <journey-name> journey happy path. This is session closure smoke testing.

### Setup
1. Dev server is already running
2. Open the journey's starting URL using the project's browser testing tool

### Test

Run Happy Path steps from the journey definition. Focus on:

- Elements render correctly
- Interactions work (clicks, form fills, navigation)
- No console errors
- Correct data flow (saves, displays, updates)

### Output

Write report to <ARTIFACTS_DIR>/ui-suite-<journey-name>.md
Include screenshots for any failures.
Happy path only — skip edge cases.
""")
````
