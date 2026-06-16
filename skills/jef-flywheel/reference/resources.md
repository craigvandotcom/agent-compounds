# Flywheel Resources & Sources

All resources used in building this knowledge base.

---

## Jeffrey's Repositories (GitHub: Dicklesworthstone)

| Repo                                                | Purpose                                    | URL                                                                                            |
| --------------------------------------------------- | ------------------------------------------ | ---------------------------------------------------------------------------------------------- |
| **agentic_coding_flywheel_setup**                   | Main installer + lessons + onboarding      | [GitHub](https://github.com/Dicklesworthstone/agentic_coding_flywheel_setup)                   |
| **agent_flywheel_clawdbot_skills_and_integrations** | Skills repo (prompts + methodology)        | [GitHub](https://github.com/Dicklesworthstone/agent_flywheel_clawdbot_skills_and_integrations) |
| **mcp_agent_mail**                                  | Agent coordination server (HTTP + SQLite)  | [GitHub](https://github.com/Dicklesworthstone/mcp_agent_mail)                                  |
| **beads_rust**                                      | Task tracker CLI (br)                      | [GitHub](https://github.com/Dicklesworthstone/beads_rust)                                      |
| **beads_viewer**                                    | Graph-theory TUI + robot-mode API (bv)     | [GitHub](https://github.com/Dicklesworthstone/beads_viewer)                                    |
| **automated_plan_reviser_pro**                      | APR - iterative plan refinement via Oracle | [GitHub](https://github.com/Dicklesworthstone/automated_plan_reviser_pro)                      |
| **named_tmux_manager**                              | NTM - agent orchestration                  | [GitHub](https://github.com/Dicklesworthstone/named_tmux_manager)                              |
| **claude_agent_session_store**                      | CASS - session search                      | [GitHub](https://github.com/Dicklesworthstone/claude_agent_session_store)                      |
| **repo_updater**                                    | RU - multi-repo sync tool                  | [GitHub](https://github.com/Dicklesworthstone/repo_updater)                                    |

## Websites

| Resource                                | URL                                                |
| --------------------------------------- | -------------------------------------------------- |
| Agent Flywheel (setup wizard + lessons) | [agent-flywheel.com](https://agent-flywheel.com)   |
| Jeffrey's Prompts (curated library)     | [jeffreysprompts.com](https://jeffreysprompts.com) |
| Jeffrey's personal site                 | [jeffreyemanuel.com](https://jeffreyemanuel.com)   |

## Key X/Twitter Threads & Tweets

### Core Workflow Thread (Nov 28, 2025)

- [Thread](https://x.com/doodlestein/status/1994526015587266875) | [ThreadReader](https://threadreaderapp.com/thread/1994526015587266875.html)
- Content: Full flywheel workflow walkthrough, 5,500-line plan → 347 beads, multi-model agent swarm, prompts for each stage

### Plan Refinement with ChatGPT 5.2 Pro (Jan 2026)

- [Tweet](https://x.com/doodlestein/status/2007588870662107197)
- Content: Paste markdown plan into ChatGPT 5.2 Pro with extended reasoning. Repeat 4-5 rounds until steady-state. Key insight: planning tokens are cheaper than implementation tokens.

### Agent Personalities & Model Roles (Oct 2025)

- [Tweet](https://x.com/doodlestein/status/1983299213233385822)
- Content: Sonnet 4.5 is eager but makes sloppy mistakes. Codex with high reasoning effort is slower but more careful. Each model develops a distinct "personality" in agent context.

### Unix Tool Philosophy (Dec 2025)

- [Tweet](https://x.com/doodlestein/status/2000271365816131942)
- Content: Focused, composable tools > monolithic systems. One tool per function: mail, tasks, viewer, orchestration.

### MCP Tool Overload (Sep 2025)

- [Tweet](https://x.com/doodlestein/status/1940527120746484142)
- Content: Too many MCP tools = paradox of choice + context window bloat. Need "tool search meta-tool" approach — keep only core tools globally, add others on demand.

### Cross-Pollinating Agent Instructions (Feb 2026)

- [Tweet](https://x.com/doodlestein/status/2014807563183992890)
- Content: Life hack — give detailed instructions to Claude Code Opus, then template the same task for Codex/GPT with "I just asked another agent to do the following..."

### Agent Mail Reminder Fix (Jan 2026)

- [Tweet](https://x.com/doodlestein/status/2005311608961040826)
- Content: Common complaint that agents forget to check mail. Solution: automated hooks now trigger mail checks. Works for Claude Code, expected for Codex/Gemini.

### Beads Rust Introduction (Feb 2026)

- [Tweet](https://x.com/doodlestein/status/2012972038332260744)
- Content: br (beads_rust) replaces original Go-based bd. Full JSONL + SQLite hybrid storage.

### 347 Beads from 5,500-line Plan (Dec 2025)

- [Tweet](https://x.com/doodlestein/status/1997797659310956688)
- Content: Claude turned 5,500-line plan into 347 beads with dependency structure. Shows bv analysis output.

### Sonnet 4.5 Day-One Impressions

- [Tweet](https://x.com/doodlestein/status/1972824197245391200)
- Content: Sonnet 4.5 usage volume is much higher than Opus 4.1. Impressed but notes need for code review loops to catch sloppy mistakes.

### Agent Mail Demo Project

- [Tweet](https://x.com/doodlestein/status/1986267787572953329)
- Content: Working on shareable agent mailbox demo for real projects. Commercial version under development.

### Repo Updater (RU) Introduction

- [Tweet](https://x.com/doodlestein/status/2009758450171924729)
- Content: ru (repo_updater) for multi-repo sync. Made out of necessity — "wasting far too much time" manually syncing repos.

### Original Workflow Post (Sep 2025)

- [Tweet](https://x.com/doodlestein/status/1938439318533513714)
- Content: Initial workflow description using Claude Code for web applications. The foundation everything else built on.

## Our PKM Research Files

| File                                                                                      | Date     | Content                                     |
| ----------------------------------------------------------------------------------------- | -------- | ------------------------------------------- |
| `knowledge/2-areas/agentic-engineering/advanced/05-jeffrey-emmanuel-agentic-flywheel.md` | Jan 2026 | Full flywheel overview with 7 tools         |
| `knowledge/2-areas/agentic-engineering/research/jeffrey-emanuel-planning-methodology.md` | Jan 2026 | Detailed planning methodology from X thread |
| `knowledge/2-areas/agentic-engineering/research/jeffrey-emanuel-ideation-methodology.md` | Jan 2026 | Competitive brainstorming + idea scoring    |
| `knowledge/2-areas/agentic-engineering/research/beads-workflow-comparison.md`            | Jan 2026 | Beads vs Jira/Linear comparison             |
| `knowledge/2-areas/agentic-engineering/advanced/jeffrey-emmanuel-workflow.md`            | Dec 2025 | Earlier workflow notes                      |

## External Analysis

| Resource                                 | URL                                                                                                                                                                    |
| ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Agent Mail + Beads coordination analysis | [bryanwhiting.com](https://www.bryanwhiting.com/ai/agent-mail-beads-coordinated-ai-coding-agents-how/)                                                                 |
| Agent Flywheel overview (Vibe Sparking)  | [vibesparking.com](https://www.vibesparking.com/en/blog/ai/2026-01-06-agent-flywheel-agentic-coding-setup/)                                                            |
| DCG safety philosophy analysis           | [reading.torqsoftware.com](https://reading.torqsoftware.com/notes/software/ai-ml/safety/2026-01-26-dcg-destructive-command-guard-safety-philosophy-design-principles/) |

## Third-Party References

| Person        | Context                                             |
| ------------- | --------------------------------------------------- |
| Steve Yegge   | Beads naming origin, "gastown" / vibe coding essays |
| Mckay Wrigley | Opus 4.5 agent unlock analysis                      |
| Dan Shipper   | Agent-native principles, Every.co                   |
| IndyDevDan    | Agent management patterns                           |

---

_Last updated: 2026-02-14_
