# Flywheel Swarm Command

> **DRAFT** -- This command needs a full rewrite to match the conductor pattern. Do not use yet. See `/my-flywheel:bead-work` for the current single-session implementation.

Full beads-based swarm orchestration for complex multi-day features.

**Track B: External Beads (beads_rust)**

For Track A (native Tasks + Teammates), use `/taskify` → `/work` instead.

## Prerequisites

- Beads created via `/flywheel:beadify`
- Beads refined via `/flywheel:bead-refine` (6-8 rounds)
- beads_rust (br) and beads_viewer (bv) installed
- tmux available (for visible agent panes)

## Workflow Overview

```
/flywheel:beadify → /flywheel:bead-refine → [/flywheel:swarm] → /flywheel:land
                                                    ↑
                                               YOU ARE HERE
```

## Phase 1: Initialize Swarm

### Verify Beads Ready

```bash
# Check unblocked beads
br ready --json

# Verify dependency graph is clean
# bd doctor does not exist -- use br list to inspect state
# br doctor  # TODO: does not exist yet

# See total work remaining
br list --json | jq '.[] | select(.status == "open")' | wc -l
```

### Configure Agent Prompts

Create AGENTS.md in project root with initialization prompt:

```markdown
# Agent Instructions

First read ALL of this file and README.md super carefully.

Then register with MCP Agent Mail and introduce yourself to other agents.

When you're not sure what to do next, use `bv --robot-next` to prioritize
the best beads to work on next; pick the next one that you can usefully
work on and get started.

## Bead Workflow

1. Run `bv --robot-next` to select highest-impact unblocked bead
2. Mark bead in progress: `br comment bd-xyz "in progress"` (or claim via `bv --robot-next`)
3. Implement the bead (follow TDD - tests first)
4. Run tests until GREEN (Ralph Loop)
5. Mark bead complete: `br close bd-xyz`
6. Sync state: `br sync --flush-only`
7. Repeat from step 1

## Quality Checks

After completing each bead, run:

- Fresh eyes review of your code
- Cross-file impact check
- Test coverage verification

## Communication

Use Agent Mail for:

- Blocking issues needing help
- Conflicts with other agents
- Questions about bead requirements

## When Done

When no beads remain unblocked:

1. Send completion message to team
2. Wait for shutdown signal
3. Run `/flywheel:land` for session closure
```

## Phase 2: Spawn Agent Swarm

### Launch Agents in tmux

```bash
# Create tmux session
tmux new-session -d -s flywheel

# Spawn agents (adjust count based on parallelizable beads)
for i in 1 2 3 4 5; do
  tmux split-window -t flywheel "claude --agent-mail"
done

# Balance panes
tmux select-layout -t flywheel tiled
```

### Agent Initialization

Each agent:

1. Reads AGENTS.md
2. Registers with Agent Mail
3. Runs `bv --robot-next` to select first bead
4. Begins autonomous execution

## Phase 3: Swarm Execution

### Autonomous Bead Selection

Each agent independently:

```
while br ready shows unblocked beads:
    # AI-driven work selection
    bead = bv --robot-next  # Picks highest-impact unblocked bead

    # Mark in progress
    br comment $bead "in progress"  # or claim via bv --robot-next

    # Implement with TDD
    while ! tests_pass:
        implement_and_test()

    # Mark complete
    br close $bead

    # Sync for other agents
    br sync --flush-only
    git add .beads/ && git commit -m "bead: $bead complete" && git push

    # Check mail for coordination
    check_agent_mail()
```

### Coordination via Agent Mail

Agents communicate for:

- Conflict resolution (same file edits)
- Blocking issues
- Questions about requirements
- Progress updates

### Graph Analytics

`bv --robot-next` uses Jeffrey's algorithms:

- Downstream impact scoring
- Dependency resolution
- Work queue optimization
- Parallel opportunity detection

## Phase 4: Quality Loops

### Post-Bead Review

After each bead, agents run quality check:

```
Great, now I want you to carefully read over all of the new code you just
wrote with "fresh eyes" looking super carefully for any obvious bugs,
errors, problems, issues, confusion, etc. Carefully fix anything you uncover.
```

### Random Exploration

Periodically agents explore other code:

```
Sort of randomly explore the code files in this project, choosing code files
to deeply investigate and understand and trace their functionality through
related code files. Do a super careful, methodical check with "fresh eyes"
to find any obvious bugs, problems, errors, issues, silly mistakes, etc.
```

### Cross-Agent Review

Agents review each other's work:

```
Turn your attention to reviewing the code written by your fellow agents and
checking for any issues, bugs, errors, problems, inefficiencies, security
problems, reliability issues, etc. Don't restrict yourself to the latest
commits, cast a wider net and go super deep!
```

## Phase 5: Completion

### Swarm Shutdown

When all beads complete:

```bash
# Verify all beads closed
br list --json | jq '.[] | select(.status == "open")'
# Should return empty

# Final sync
br sync --flush-only
# NOTE: do not use git add -A (may include secrets or unintended files)
git add .beads/ && git commit -m "chore: all beads complete" && git push
```

### Session Closure

Run `/flywheel:land` to:

- File any remaining issues
- Run final quality gates
- Commit and push everything
- Create session summary

## Configuration

### Environment Variables

```bash
# Agent Mail configuration
export AGENT_MAIL_PROJECT_KEY="/path/to/project"

# Beads configuration
export BEADS_DB_PATH=".beads/beads.db"
```

### Scaling

| Feature Complexity | Recommended Agents |
| ------------------ | ------------------ |
| 10-20 beads        | 2-3 agents         |
| 20-50 beads        | 3-5 agents         |
| 50-100 beads       | 5-8 agents         |
| 100+ beads         | 8-12 agents        |

## Differences from Track A (Tasks + Teammates)

| Aspect          | Track A (Tasks)   | Track B (Beads)         |
| --------------- | ----------------- | ----------------------- |
| Tooling         | Native CC Tasks   | beads_rust              |
| Selection       | TaskList → manual | `bv --robot-next` (AI)  |
| Graph analytics | Basic blockedBy   | Full dependency scoring |
| Refinement      | 0 rounds          | 6-8 rounds              |
| Best for        | <1 day features   | Multi-day features      |

## Reference

- `.claude/skills/CORE/references/kieran-swarm-orchestration-skill.md`
- `knowledge/.../research/jeffrey-emanuel-planning-methodology.md`
- `knowledge/.../research/beads-workflow-comparison.md`
