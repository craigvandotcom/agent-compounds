# Flywheel Tool Quick Reference

---

## br (Beads Rust) — Task Management

Bead IDs use `bd-` prefix (e.g., `bd-1234`).

```bash
# Create
br init                                          # Initialize beads in project
br create --title "Task title" --priority 1 --label backend  # Create new bead
br create --title "Subtask" --parent <id>        # Create child bead

# Dependencies
br update bd-1234 --blocks bd-1235               # bd-1234 blocks bd-1235
br update bd-1234 --blocked-by bd-1236           # bd-1234 is blocked by bd-1236

# View
br list                                          # List all beads
br list --status open                            # List open beads
br ready                                         # List unblocked beads
br show bd-1234                                  # Show bead details
br show bd-1234 --comments                       # Show with comments

# Update
br update bd-1234 --status in_progress           # Change status
br comments add bd-1234 "Progress note"          # Add comment
br close bd-1234 --reason "Fixed in commit abc"  # Mark complete with reason
br reopen bd-1234                                # Reopen bead
br label add bd-1234 "frontend"                  # Add label/tag

# Export
br export --format jsonl                         # Export as JSONL
br export --format md                            # Export as Markdown
br list --json                                   # Machine-readable output
```

---

## bv (Beads Viewer) — Prioritization & Analytics

**CRITICAL: Never run bare `bv` in agent context — it launches interactive TUI.**

```bash
# Agent-Optimized Commands
bv --robot-next                      # Top pick + claim command (minimal)
bv --robot-triage                    # Complete mega-command (everything)
bv --robot-plan                      # Parallel execution tracks
bv --robot-priority                  # Priority misalignment detection

# Graph Analytics
bv --robot-insights                  # PageRank, betweenness, cycles
bv --robot-label-health              # Per-label health scoring
bv --robot-label-flow                # Cross-label dependency matrix

# Tracking
bv --robot-history                   # Bead-to-commit correlations
bv --robot-burndown <sprint>         # Sprint progress
bv --robot-forecast <id|all>         # ETA predictions
bv --robot-alerts                    # Stale issues, blockers

# Output Formats
bv --robot-triage --format toon      # Token-optimized output
export BV_OUTPUT_FORMAT=toon         # Set globally
```

---

## ntm (Named Tmux Manager) — Agent Orchestration

```bash
# Spawn agents
ntm spawn myproject --cc=3           # 3 Claude Code agents
ntm spawn myproject --cc=2 --cod=1   # 2 Claude + 1 Codex
ntm spawn myproject --cc=3 --gmi=1   # 3 Claude + 1 Gemini

# Manage
ntm list                             # List active sessions
ntm kill myproject                   # Kill all agents for project
ntm attach myproject                 # Attach to tmux session
```

---

## Agent Mail — Coordination

```bash
# Via MCP tools (used by agents, not CLI directly)
# Agents use these through Claude Code's MCP integration:

ensure_project          # Register project
register_agent          # Register as agent
send_message            # Send to other agents
fetch_inbox             # Check messages
file_reservation_paths  # Reserve files
release_file_reservations  # Release files
```

---

## dcg (Destructive Command Guard) — Safety

```bash
dcg install                          # Register as Claude Code hook (do this first!)
dcg test "git reset --hard" --explain  # Test and explain why a command is blocked
dcg allow-once <code>                # One-time bypass for specific command
```

Protection packs configured in `~/.config/dcg/config.toml`:

```toml
[packs]
enabled = ["git", "filesystem", "database.postgresql"]
```

---

## ubs (Ultimate Bug Scanner) — Static Analysis

```bash
ubs file.ts                          # Scan single file (<1 sec) — PREFER THIS
ubs scan .                           # Scan entire project (30+ sec) — avoid in agent context
ubs scan . --language python         # Language-specific scan
ubs scan . --severity critical       # Critical issues only
```

**Tip:** Always scope to changed files when possible.

---

## cass / cm — Memory

**CRITICAL: Never run bare `cass` — it launches a TUI that blocks agent sessions.**

```bash
# Session search (always use --robot or --json)
cass --json search "query" --days 30
cass --robot search "query" --workspace .

# Context retrieval
cm context "task description" --workspace . --json
cm reflect                           # Process sessions into playbook

# CM onboarding workflow
cm onboard status                    # Check status and recommendations
cm onboard sample --fill-gaps        # Sessions filtered by playbook gaps
cm playbook add "rule" --category "cat"  # Add rule to playbook
```

---

## apr (Automated Plan Reviser Pro) — Plan Refinement

```bash
apr setup                            # Interactive workflow creation (once per project)
apr run 1 --login --wait             # First round (needs ChatGPT auth)
apr run 2                            # Background round
apr show 5                           # View round 5 output
apr diff 3 5                         # Compare rounds
apr stats                            # Convergence analytics
apr integrate 15 -c                  # Copy Claude Code-ready prompt to clipboard
apr robot validate 3                 # Pre-flight checks (for agent use)
```

---

## pt (Process Triage) — Zombie Cleanup

```bash
pt                                   # Quick overview
pt --top                             # Find resource hogs
pt search node                       # Find specific processes
pt --port 3000                       # Identify port users
```

---

## caam (Credential Account Alias Manager) — Auth

```bash
caam backup claude my-main-account   # Back up credentials after login
caam activate claude backup-account  # Switch accounts (<100ms via symlink)
caam list                            # List all saved accounts
```

---

## acfs — System Management

```bash
acfs doctor                          # Verify installation health
acfs newproj myproject --interactive  # Create new project with full structure

acfs-update --stack                  # Update all tools + Dicklesworthstone stack
acfs-update --agents-only            # Quick agent-only update
acfs-update --dry-run                # Preview what would change
```
