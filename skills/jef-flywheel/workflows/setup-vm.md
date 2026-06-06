# Setup Jeffrey Emanuel's Agentic Coding Flywheel

**Status:** Ready for tomorrow
**Date:** 2026-02-13
**Goal:** Get the full flywheel running on a cloud VM with a clear workflow from idea to commit

---

## What We Already Have

- [x] CASS memory system (installed locally)
- [x] CM context manager (installed locally)
- [x] Agent Mail MCP (configured)
- [x] Flywheel prompts (agent-swarm-launcher, robot-mode-maker, etc.)
- [x] Comprehensive research notes in PKM (5 files)
- [x] All genius/alien prompts with severity-tiered output
- [x] This plan folder with workflow guide, prompts, and templates

## Pre-Setup Checklist

### Before Tomorrow (Do on MacBook Tonight)

- [ ] **Enable Codex Device Auth:** ChatGPT Settings → Security → Enable "Device code login" (required for headless VPS auth)
- [ ] **API Keys Ready:**
  - Anthropic API key (Claude Code, already have)
  - OpenAI ChatGPT Pro/Plus account (Codex uses OAuth, NOT API keys)
  - Google account (Gemini CLI, free)
- [ ] **VPS Provider Account:**
  - Hetzner recommended for value (CX32: 16GB RAM, 4 vCPU, ~€13/mo)
  - Alternatives: OVH, Contabo, DigitalOcean
- [ ] **SSH Key Generated:**
  - `ssh-keygen -t ed25519 -C "your_email@example.com"`
  - Add public key to VPS provider dashboard
  - Add to `~/.ssh/config`: `ServerAliveInterval 60` and `ServerAliveCountMax 3`
- [ ] **Real Project Chosen:**
  - Pick existing project with tests for first flywheel run
  - Something small enough to complete in 2-3 hours
- [ ] **GitHub Access from VM:**
  - SSH key or personal access token for repo cloning
- [ ] **Setup Mode Decision:**
  - **Hybrid:** Claude Code on MacBook, Codex + Gemini on VM, Agent Mail coordinates
  - **All-VM:** SSH into VM, run everything there (simpler, more latency)
- [ ] **Path Convention Decision:**
  - ACFS defaults to `/data/projects/`. Our structure uses `~/Repos/`
  - Options: (a) `acfs newproj myproject ~/Repos/software/` (b) symlink `/data/projects` → `~/Repos/software`

## What We Need to Do Tomorrow

### Phase 1: VM Setup (~30 min)

1. Spin up Ubuntu VPS (Hetzner CX32 or equivalent: 16GB RAM, 4 vCPU)
2. Run ACFS installer:
   ```bash
   curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/agentic_coding_flywheel_setup/main/install.sh?$(date +%s)" | bash -s -- --yes --mode vibe
   ```
3. Install skills repo (separate step!):
   ```bash
   curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/agent_flywheel_clawdbot_skills_and_integrations/main/install.sh?v=$(date +%s)" | bash
   ```
4. **Verify install:** `acfs doctor`
5. **Note:** ACFS changes tmux prefix from `Ctrl+b` to `Ctrl+a`

### Phase 2: Agent Auth & Safety (~15 min)

1. **Authenticate agents (VPS-specific):**
   ```bash
   claude auth login                    # Follow browser link
   codex login --device-auth            # Headless-friendly (enable in ChatGPT Settings first!)
   gemini                               # Follow prompts
   ```
2. **Backup credentials immediately:**
   ```bash
   caam backup claude my-main-account
   caam backup codex my-main-account
   caam backup gemini my-main-account
   ```
3. **Install safety tools:**
   ```bash
   dcg install                          # Destructive Command Guard (Claude Code hook)
   ```
4. **Verify SRPS** (auto-deprioritizes builds/tests to keep VM responsive):
   ```bash
   systemctl status ananicy-cpp
   ```
5. **Run tutorial:** `onboard 0` to orient yourself

### Phase 3: First Project Setup (~15 min)

1. Create project:
   ```bash
   acfs newproj my-first-project --interactive
   # Or with custom path: acfs newproj my-first-project ~/Repos/software/
   ```
   This creates: git repo, `.beads/`, `AGENTS.md`, `.claude/` settings, `.gitignore`
2. Install pre-commit guard for file reservations:
   ```bash
   mcp-agent-mail install-precommit-guard
   ```
3. Start Agent Mail server: `am`
4. Test tools: `bv --robot-help`, `br list`, `cass --json search "test"`

### Phase 4: First Flywheel Run (~2-3 hours)

1. Follow workflow guide (see `workflow-walkthrough.md`)
2. Start with a real project/feature
3. Walk through: Idea → Plan (try `apr refine plan.md`) → Beads → Execute → Review → Commit
4. Single agent first, scale to swarm once comfortable
5. Consider a **commit agent pattern**: one agent commits every 15-20 min while others implement

## Files in This Folder

| File                      | Purpose                                                                  |
| ------------------------- | ------------------------------------------------------------------------ |
| `README.md`               | This master plan                                                         |
| `workflow-walkthrough.md` | Step-by-step journey from idea to commit                                 |
| `prompts-reference.md`    | All prompts needed at each stage                                         |
| `agents-template.md`      | AGENTS.md template for new projects                                      |
| `tool-reference.md`       | Quick reference for br, bv, ntm commands                                 |
| `skills-and-subagents.md` | Jeffrey's skills architecture and integration patterns                   |
| `workflow-cadence.md`     | Waves vs continuous analysis (both work with beads)                      |
| `vps-options.md`          | VM specs and provider comparison                                         |
| `multi-device-setup.md`   | MacBook + VM + phone setup patterns                                      |
| `lessons/`                | All 36 flywheel learning hub lessons (local reference)                   |
| `resources.md`            | Complete list of all sources: repos, tweets, articles, PKM files         |
| `tweet-insights.md`       | Practical insights extracted from Jeffrey's tweets (Oct 2025 - Feb 2026) |

## Tool Priority (For Craig's 3-Agent Scale)

| Priority | Tool                 | Why                                                                     |
| -------- | -------------------- | ----------------------------------------------------------------------- |
| 1        | **DCG**              | Safety net — agents run in vibe mode, one bad `rm -rf` ends everything  |
| 2        | **CAAM**             | Credential backup immediately after auth                                |
| 3        | **acfs doctor**      | Verify install works before proceeding                                  |
| 4        | **SRPS**             | Keeps VM responsive when agents spawn builds/tests                      |
| 5        | **Pre-commit guard** | Prevents file conflict damage between agents                            |
| 6        | **APR**              | Automates plan refinement (15-20 AI rounds). Biggest ROI at small scale |
| 7        | **PT**               | Zombie process cleanup (`pt --top`)                                     |
| 8        | **NTM + BV + BR**    | Core flywheel tools                                                     |
| 9        | **JFP**              | Browse/install prompts from Jeffrey's library                           |
| 10       | **S2P**              | Context assembly for web LLM sessions                                   |

**Skip for now:** SLB (overkill at 3 agents), WA (needs WezTerm), Brenner Bot, XF, RCH, GIIL

## Cost (Craig's Actual Scale)

**Starting with 3 agents, not 10+:**

- **Agent 1:** Claude Code (Max plan) - $200/month
- **Agent 2:** Codex CLI (OpenAI $20/mo tier) - $20/month
- **Agent 3:** Gemini CLI (free tier) - $0/month
- **VPS:** Hetzner CX32 (16GB RAM, 4 vCPU) - ~$10-15/month

**Total: ~$225-235/month**

**Notes:**

- No ChatGPT Pro needed initially (can add later if needed for planning)
- 16GB RAM is generous for 3 agents (~2GB per agent = 6GB + 4GB OS overhead)
- Tokens are the bottleneck, not CPU/RAM
- This scale validates the workflow before expanding

## Scale Notes

**Why 16GB RAM is enough:**

- Each agent process: ~2GB RAM peak
- 3 agents = ~6GB used
- OS + services: ~4GB
- Headroom: ~6GB for file buffers and temp processes

**Scaling path:**

- 3-5 agents: 16GB (CX32, ~€13/mo)
- 6-10 agents: 32GB (CX42, ~€24/mo)
- 10+ agents: 64GB (CX52, ~€48/mo)

**Both wave and continuous workflows work with beads:**

- Tool doesn't care how beads arrive (batch or stream)
- Cadence is a workflow choice, not a technical limitation
- See `workflow-cadence.md` for pattern comparison

## Key Resources

- [Agent Flywheel Setup Repo](https://github.com/Dicklesworthstone/agentic_coding_flywheel_setup)
- [Agent Flywheel Website](https://agent-flywheel.com)
- [Beads Rust](https://github.com/Dicklesworthstone/beads_rust)
- [Beads Viewer](https://github.com/Dicklesworthstone/beads_viewer)
- [Jeffrey's Skills Repo](https://github.com/Dicklesworthstone/agent_flywheel_clawdbot_skills_and_integrations)
- [Jeffrey's Prompts](https://jeffreysprompts.com)

## Ongoing Maintenance

```bash
acfs-update --stack              # Weekly update (all tools + Dicklesworthstone stack)
acfs-update --agents-only        # Quick agent-only update
acfs-update --dry-run             # Preview what would change
```

Optional cron for automated weekly updates:

```bash
0 3 * * 0 $HOME/.local/bin/acfs-update --yes --quiet >> $HOME/.acfs/logs/cron-update.log 2>&1
```

## Key Operational Notes (From Lessons)

- **UBS scoping:** `ubs file.ts` runs in <1 second. `ubs .` can take 30+ seconds. Always scope to changed files when possible
- **CASS warning:** Never run bare `cass` — it launches a TUI that blocks the session. Always use `cass --robot` or `cass --json`
- **`br` syntax:** Bead IDs use `bd-` prefix. Full flags: `--title`, `--priority`, `--label`, `--blocks`, `--blocked-by`, `--status`, `--reason`
- **Agent Mail server:** Start with `am` command (not `python server.py`)
- **Commit agent pattern:** Case studies show a dedicated agent committing every 15-20 min during swarm work — not just at the end
- **APR usage:** `apr refine plan.md` automates 15-20 rounds of plan refinement. Use before beadifying to avoid wasting tokens on bad plans

## Our Existing Research

- `knowledge/1-active/agentic-engineering/advanced/05-jeffrey-emmanuel-agentic-flywheel.md`
- `knowledge/1-active/agentic-engineering/research/jeffrey-emanuel-planning-methodology.md`
- `knowledge/1-active/agentic-engineering/research/jeffrey-emanuel-ideation-methodology.md`
- `knowledge/1-active/agentic-engineering/research/beads-workflow-comparison.md`
