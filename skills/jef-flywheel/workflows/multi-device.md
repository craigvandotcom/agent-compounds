# Multi-Device Setup: MacBook + VM + Phone

## Reference Architecture

```
Repos/                          ← parent git repo (GitHub)
├── .claude/                    ← agent system, skills, plans
├── knowledge/                  ← PKM vault
├── infrastructure/             ← schedulers, notifications, etc
└── software/
    ├── app-one/                ← separate git repo
    ├── app-two/                ← separate git repo
    ├── some-lib/               ← separate git repo
    └── ...
```

Each software project is a nested git repo with its own GitHub remote.

## The Simple Mental Model

```
GitHub = source of truth (always)

MacBook (desk work):
├── Full Repos/ clone
├── Claude Code (local)
├── Agent Mail client (connects to VM server via HTTP)
└── Push to GitHub when done

VM (mobile/parallel work):
├── Full Repos/ clone
├── Claude Code + Codex + Gemini
├── Agent Mail SERVER (HTTP + SQLite, always on)
└── Push to GitHub when done

Phone:
└── SSH to VM via Termux/Blink → tmux session
```

**Sync discipline:** `git pull` before starting work on either machine.

## What Works Without Thinking

| Component                  | Multi-device? | Notes                                                                                             |
| -------------------------- | ------------- | ------------------------------------------------------------------------------------------------- |
| Git repos                  | Yes           | Push/pull via GitHub                                                                              |
| `.claude/` (skills, plans) | Yes           | Lives in Repos/, syncs via git                                                                    |
| Claude Code                | Yes           | Same config on both machines                                                                      |
| Agent Mail                 | Yes           | Centralized HTTP server on VM. MacBook connects via HTTP. All agents see same messages instantly. |
| CASS/CM                    | Per-machine   | Indexes local `~/.claude/` sessions. Fine.                                                        |
| SSH from phone             | Yes           | Tmux keeps sessions alive                                                                         |
| Beads (`br`, `bv`)         | Yes           | IF `.beads/` is committed to project repo                                                         |
| NTM                        | Per-machine   | Tmux sessions are local. Fine.                                                                    |
| Git worktrees              | Per-machine   | Ephemeral, created/destroyed per agent. Fine.                                                     |

## What Needs Care

### 1. Beads State Must Be Committed

Beads state lives in `.beads/` inside the project. Commit it so both machines see the same beads.

```bash
# In each project repo
git add .beads/
git commit -m "sync beads state"
```

Without this, MacBook and VM have different bead views.

### 2. Agent Mail Server Configuration

**Agent Mail is a centralized HTTP server + SQLite database, NOT a per-machine local process.**

- **Run the server on VM** (always on, stable IP)
- **All agents communicate via HTTP API calls** (real-time, instant delivery)
- **Git audit trail is just logging** (happens server-side automatically)

**MacBook agents:** Connect to `http://<vm-ip>:8765/api/`
**VM agents:** Connect to `http://127.0.0.1:8765/api/` (localhost)

All agents see the same messages instantly. No git sync needed for communication.

**Project keys:** Agent Mail uses project paths for namespacing, but since the server is centralized, path differences between machines don't matter for message delivery. Standardizing paths (`~/Repos/` on both) is still recommended for consistency.

### 3. Hybrid Agents (Both Machines, Same Project)

If running agents on MacBook AND VM targeting the same project simultaneously:

- **Use branches:** MacBook agent on `feature/auth`, VM agent on `feature/api`
- **File reservations:** Agent Mail prevents overlapping file edits
- **Beads assign work:** Different beads to different agents/machines

**Simpler alternative:** Keep all agents on one machine at a time. At 3-agent scale, no need for cross-machine coordination.

### 4. Clone Full Repos/ on VM

Don't just clone individual projects. Clone the full `Repos/` structure so `.claude/` (skills, plans, CLAUDE.md) is available.

```bash
# On VM
git clone git@github.com:<your-username>/Repos.git ~/Repos
cd ~/Repos/software/<your-app>
git clone git@github.com:<your-username>/<your-app>.git .  # or git pull
```

## Recommended Workflows

### Desktop Mode (MacBook only)

- Work normally, same as today
- All agents local
- Push when done

### Mobile Mode (VM only, phone SSH)

- SSH to VM from phone
- Attach to tmux session
- All agents on VM
- Push when done

### Power Mode (MacBook + VM)

- MacBook: Claude Code (interactive, your main agent)
  - Connects to Agent Mail server on VM via HTTP
- VM: Codex + Gemini (background workers)
  - Connect to Agent Mail server locally (127.0.0.1)
- **Real-time coordination via Agent Mail** (no git sync needed for messaging)
- Different branches or different projects
- Both push to GitHub
- Merge when done

### Switching Between Modes

```bash
# Before switching machines:
git add -A && git commit -m "wip: switching devices" && git push

# On the other machine:
git pull --all
```

## What Doesn't Matter

- **VPS location** - irrelevant for git sync (all via GitHub)
- **CASS/CM divergence** - each machine has its own session history, that's fine
- **NTM sessions** - tmux is per-machine, just reattach
- **Worktrees** - ephemeral, per-machine, agents create/destroy as needed

## Agent Mail Server Setup

**Run on VM (always on):**

```bash
# Start Agent Mail server on VM
cd ~/Repos/infrastructure/agent-mail
python server.py  # or via PM2 for persistence
```

- **Server:** `http://<vm-ip>:8765`
- **Web UI:** `http://<vm-ip>:8765/mail` (human oversight, read messages)
- **Auth:** Bearer token (configured during install)

**MacBook MCP config** (`~/.claude.json` or `.mcp.json`):

```json
{
  "mcpServers": {
    "agent-mail": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-agent-mail"],
      "env": {
        "AGENT_MAIL_URL": "http://<vm-ip>:8765/api",
        "AGENT_MAIL_TOKEN": "your-bearer-token"
      }
    }
  }
}
```

**VM agents** connect to `http://127.0.0.1:8765/api` (localhost).

All agents see the same messages instantly. Git audit trail happens server-side automatically.

---

## Bottom Line

The flywheel tools are git-native. Keep git synced and everything works. The only real considerations:

1. **Commit `.beads/` state**
2. **Run Agent Mail server on VM** (MacBook connects via HTTP)
3. **Use same path structure on both machines** (recommended for consistency)
4. Don't run conflicting agents on both machines for the same files

At your 3-agent scale, the simplest approach: one machine at a time, git sync between them. Agent Mail enables real-time cross-machine coordination when you need it.
