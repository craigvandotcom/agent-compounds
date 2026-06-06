# Agent Compounds

Agentic tools that compound. Each builds on the last.

The canonical home for portable commands, skills, and agents. Deploy any subset into a project's `.claude/` with [`deploy.sh`](./deploy.sh) — everything is symlinked back here, so this repo stays the single source of truth and edits propagate instantly.

## Skills

Symlinked into a project as `.claude/skills/<name>/`.

**Multi-model**
| Skill | What it does |
|-------|-------------|
| **[openrouter](./skills/openrouter/)** | Access 400+ AI models. Discover, select, and query the right model for any task |
| **[expert-consensus](./skills/expert-consensus/)** | Fan out one prompt to multiple AI models, synthesize into consensus |

**Pipeline** — the engineering workflow, one skill per stage, all `ac-` prefixed (chain them with `ac-pipeline`)
| Skill | What it does |
|-------|-------------|
| **[ac-pipeline](./skills/ac-pipeline/)** | Orchestrator — chains the stages below with gates (`ac-align → ac-next → ac-plan → ac-beadify → ac-implement → ac-review → ac-merge → ac-land`) |
| **ac-align** | Reconcile the pipeline with current strategy |
| **ac-next** | Pipeline dashboard — what to advance toward implementation-ready |
| **ac-plan** | Create + refine implementation plans (refine/clean/review modes in `references/`) |
| **ac-beadify** | Convert a refined plan into a beads task structure |
| **ac-implement** | Sequential bead implementation — conductor + engineer sub-agents |
| **ac-review** | Feature-branch review — parallel reviewers, auto-fix + escalation |
| **ac-merge** | Merge a wave to main — PR, CI triage, version bump |
| **ac-land** | Session closure — retrospective learning + system compounding |
| **ac-hygiene** | Iterative codebase cleanup (out-of-band, between waves) |

**Engineering** (promoted from body-compass-app, the canonical donor)
| Skill | What it does |
|-------|-------------|
| **supabase** | Supabase CLI, migrations, RLS, Postgres patterns |
| **testing** | Vitest unit/component/integration test authoring |
| **react-best-practices** | React + Next.js performance and patterns |
| **capacitor** | TypeScript dev in Capacitor (native wrap) projects |
| **planning** | Plan creation + iterative refinement (scope oscillation) |
| **brainstorming** | Divergent–convergent pre-planning ideation |
| **flywheel** | Agent-driven build loop with beads + swarms |
| **audit** | Systematic code-quality verification framework |
| **worktrees** | Git worktrees for parallel agent development |
| **browser-testing** | UI/login/flow validation via agent-browser |
| **ui-brainstorm** | Multi-model UI critique with consensus ranking |
| **ui-debug** | CSS / visual bug investigation |
| **web-design-guidelines** | Accessibility, forms, animation, typography UX |
| **app-store-screenshots** | Generate iOS App Store screenshots from real screens |

> **Not promoted (stay per-app):** `CORE`, `brand`, `design-system` (pillar-color-coupled), `writing-guidelines` (brand-voice-coupled), `curate` — these are project/brand-specific and can't have one shared version.

## Commands → Skills (migration in progress)

Anthropic merged custom commands into skills (a `commands/x.md` and a `skills/x/SKILL.md` both create `/x`). The engineering workflow commands have been **converted to the Pipeline skills above**; the `jef` prompt pack has become the **`prompts` skill** below. The legacy `commands/` files remain for now (still consumed by existing projects) and will be retired in the packaging phase. See [`commands/README.md`](./commands/README.md) for the legacy docs.

## Prompts

The **[ac-prompts](./skills/ac-prompts/)** skill is a curated library of high-leverage one-shot prompts (debugging, performance, refactor, planning, ideation, review, UI, workflow). Invoke `/ac-prompts <hint>` and it loads the best-matching prompt from `skills/ac-prompts/references/`. Add new ones with the `prompt-add` skill.

## Agents

Portable agent definitions, symlinked into `.claude/agents/`.

| Agent | What it does |
|-------|-------------|
| **[engineer](./agents/engineer.md)** | Implementation sub-agent for bead/wave work |
| **[reviewer](./agents/reviewer.md)** | Code review sub-agent |
| **[tester](./agents/tester.md)** | Test authoring / verification sub-agent |
| **[code-explorer](./agents/code-explorer.md)** | Read-only codebase exploration + mapping |
| **[browser-tester](./agents/browser-tester.md)** | UI smoke testing via agent-browser — PASS/FAIL |
| **[browser-agent](./agents/browser-agent.md)** | Ad-hoc browser automation — screenshots, scraping, forms |
| **[review/](./agents/review/)** | Specialist review panel: architecture, correctness, performance, security |

## Quick Start

### Deploy with `deploy.sh` (recommended)

```bash
# See everything available
./deploy.sh --list

# Stamp a project with a chosen subset (symlinks, never copies)
./deploy.sh ../my-project --commands \
  --skills supabase,testing,planning --agents engineer,reviewer

# Or take everything
./deploy.sh ../my-project --all

# Preview without writing
./deploy.sh ../my-project --all --dry-run
```

`deploy.sh` computes relative symlinks automatically and **refuses to overwrite a real file** already at the target — so it never clobbers a project's customized skill. Commands land as `/ac/pipeline-next`, `/jef/bug-hunter`, etc.

Then create the project's context file:

```bash
cp AGENTS.md ../my-project/AGENTS.md   # fill in stack + commands
mkdir -p ../my-project/_backlog ../my-project/_plans ../my-project/_strategy
```

### Skills setup

```bash
export OPENROUTER_API_KEY=sk-or-...  # for openrouter / expert-consensus
```

Claude Code discovers each `SKILL.md` automatically. Use e.g. `/expert-consensus What makes a great API?` — toggle models in `expert-panel.json`.

## Dependencies

| Dependency | What it provides | Install |
|-----------|-----------------|---------|
| **[beads (br)](https://github.com/Dicklesworthstone/beads_rust)** | Artifact-based planning and implementation tracking — plans, beads, pipeline stages | `cargo install beads` |
| **[agent-mail (MCP)](https://github.com/Dicklesworthstone/mcp_agent_mail)** | Inter-agent messaging, file reservations, coordination for multi-agent workflows | Add as MCP server in `.claude/settings.json` |
| **openrouter** | OpenRouter CLI for multi-model queries (used by expert-consensus and openrouter skills) | Install the `openrouter` CLI and ensure it's on your `PATH` |
| **[agent-browser](https://www.npmjs.com/package/agent-browser)** | Headless browser automation CLI for UI testing (used by browser-tester sub-agent, bead-land, work-review) | `npm install -g agent-browser` |

## Philosophy

- **Compound, don't collect** — each skill should make the next one more valuable
- **SKILL.md is the interface** — human-readable reference that doubles as AI context
- **Standalone by default** — no frameworks, no setup wizards
- **One config file** — `expert-panel.json` has everything

## License

MIT
