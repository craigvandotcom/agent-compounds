# AGENTS.md

> This file tells AI coding agents everything they need to know about this project.

---

## Project Overview

**Name:** [Project Name]
**Description:** [1-2 sentence description]
**Tech Stack:** [Language, framework, key libraries]
**Repository:** [URL]

---

## Getting Started

```bash
# Clone and setup
git clone [URL]
cd [project]
[install command]  # e.g., bun install, cargo build, pip install -e .

# Run tests
[test command]     # e.g., bun test, cargo test, pytest

# Run dev server (if applicable)
[dev command]      # e.g., bun dev, cargo run
```

---

## Architecture

[Brief description of the architecture, key directories, data flow]

```
src/
  api/        # REST endpoints
  models/     # Data models
  services/   # Business logic
  utils/      # Shared utilities
tests/
  unit/       # Unit tests
  e2e/        # End-to-end tests
```

---

## Coding Standards

- [Language-specific conventions]
- [Naming conventions]
- [Error handling patterns]
- [Testing requirements]

---

## Available Tools

### Beads (Task Management)

```bash
br list                    # List all beads
br ready                   # Show unblocked beads
br show <id>               # View bead details
br close <id>              # Mark bead complete
br comment <id> "message"  # Add progress note
```

### Beads Viewer (Prioritization)

```bash
bv --robot-next            # Get highest-impact ready bead
bv --robot-triage          # Full triage with all context
bv --robot-plan            # Parallel execution tracks
bv --robot-insights        # Graph analytics
```

**IMPORTANT: Never run bare `bv` — it launches interactive TUI. Always use `--robot-*` flags.**

### Agent Mail (Coordination)

- Register when starting work
- Reserve files before editing (exclusive locks with TTL)
- Announce work in threads matching bead IDs (e.g., thread_id = "bd-123")
- Check inbox between beads
- Release file reservations when done

### CASS (Memory)

```bash
cm context "<task>" --workspace . --json  # Get relevant context
cass search "<query>" --days 30          # Search session history
```

---

## Workflow

1. Read this entire file first
2. Use `bv --robot-next` to select your bead
3. Reserve files via Agent Mail
4. Implement the bead fully
5. Run tests: `[test command]`
6. Self-review your code with fresh eyes
7. Mark bead done: `br close <id>`
8. Release file reservations
9. Check Agent Mail inbox
10. Repeat from step 2

---

## Rules

- NEVER use `git push --force`
- NEVER skip pre-commit hooks
- NEVER commit .env or credential files
- ALWAYS run tests before marking a bead done
- ALWAYS reserve files before editing
- ALWAYS check Agent Mail between beads
- When in doubt, READ THIS FILE AGAIN
