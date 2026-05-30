# Jeffrey's Skills, Subagents & Prompt Architecture

## How Prompts Are Included in System Setup

**Infrastructure and prompts are SEPARATE installs:**

1. **ACFS Install** (infrastructure only):

   ```bash
   curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/agentic_coding_flywheel_setup/main/install.sh?$(date +%s)" | bash -s -- --yes --mode vibe
   ```

   Installs: shell, runtimes, AI agents, NTM, Agent Mail, CASS, CM, etc.

2. **Skills Install** (prompts + methodology):

   ```bash
   curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/agent_flywheel_clawdbot_skills_and_integrations/main/install.sh?v=$(date +%s)" | bash
   ```

   Installs: 25+ skills (tool-specific + workflow methodology)

3. **Project Setup** (per-project):
   ```bash
   acfs newproj myproject
   ```
   Generates: git repo, AGENTS.md template, optional Beads setup

## Skills System Architecture

Skills are **YAML frontmatter + Markdown** files:

```markdown
---
name: skill-name
description: 'Brief description'
emoji: 🎯
requires:
  bins: ['cli-tool']
  env: ['ENV_VAR']
  config: ['config-key']
install: |
  # Shell commands for setup
---

# Skill Title

## Overview / Usage / Workflow
```

### Two Types of Skills

**Tool-specific** (require CLI installation):

- `ntm` - Named Tmux Manager for multi-agent orchestration
- `agent-mail` - MCP Agent Mail coordination
- `bv` - Beads Viewer (graph-theory task triage)
- `cass` - Cross-Agent Session Search
- `cm` - CASS Memory
- Cloud CLIs: `gcloud`, `wrangler`, `vercel`, `supabase`

**Workflow methodology** (pure prompts, no CLI):

- `planning-workflow` - 80% planning philosophy with exact prompt templates
- `beads-workflow` - Task management with dependencies
- `agent-swarm-workflow` - Coordinating multiple agents
- `de-slopify` - Removing AI writing artifacts
- `ui-ux-polish` - Interface refinement patterns

## How Subagents Work

**Jeffrey uses NTM (Named Tmux Manager), NOT Claude Code's built-in subagent system.**

| Aspect       | Jeffrey's NTM                        | Claude Code Subagents                   |
| ------------ | ------------------------------------ | --------------------------------------- |
| Architecture | Separate CLI instances in tmux panes | Single session spawning ephemeral tasks |
| Models       | Mix: 8 Claude + 6 Codex + 3 Gemini   | All Claude-based                        |
| Coordination | MCP Agent Mail                       | Built-in task isolation                 |
| Session Mgmt | tmux with visual dashboards          | Internal agent spawning                 |
| Use Case     | 7-17 agents simultaneously           | Workers within single project           |

**NTM Commands:**

```bash
ntm spawn myproject --cc=4 --cod=4 --gmi=2  # Create 10 agents + user pane
ntm send myproject --cc "task description"   # Broadcast to all Claude agents
```

**Why NTM over subagents:**

- Multi-model diversity (Claude + OpenAI + Google)
- Cross-project coordination
- Persistent agent identities across sessions
- Visual management through tmux TUI

## Comparison: Jeffrey's Setup vs Ours

| Aspect         | Jeffrey                   | Us                                  |
| -------------- | ------------------------- | ----------------------------------- |
| Prompts        | Separate skills repo      | Built into `.claude/skills/`        |
| Subagents      | NTM (tmux multi-instance) | Claude Code native subagents        |
| Skills format  | YAML + Markdown SKILL.md  | YAML + Markdown SKILL.md (similar!) |
| Installation   | Two-step (ACFS + skills)  | Single `.claude/` structure         |
| Coordination   | MCP Agent Mail            | MCP servers + subagents             |
| Project config | AGENTS.md (downloaded)    | CLAUDE.md (checked in)              |
| Memory         | CASS + CM (cross-session) | Session logs in `.claude/memory/`   |

## Key Insight

Our `.claude/skills/` structure is already very similar to Jeffrey's skills format. The main difference is his skills are installed system-wide while ours are per-project. When we set up the flywheel VM, we can use his skills install for the VM and keep our project-specific skills in `.claude/skills/`.
