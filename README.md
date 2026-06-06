# Agent Compounds

Agentic tools that compound. Each builds on the last.

The canonical home for portable skills and agents. Deploy any subset into a project's `.claude/` with [`deploy.sh`](./deploy.sh) — everything is symlinked back here, so this repo stays the single source of truth and edits propagate instantly.

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
| **[ac-pipeline](./skills/ac-pipeline/)** | Orchestrator — chains the stages below with gates (`ac-align → ac-next → ac-plan-init → ac-beadify → ac-implement → ac-review → ac-merge → ac-land`) |
| **ac-backlog** | Capture ideas into grouped backlog files (front of the pipeline) |
| **ac-align** | Reconcile the pipeline with current strategy |
| **ac-next** | Pipeline dashboard — what to advance toward implementation-ready |
| **ac-plan-init** | Create a first-draft implementation plan |
| **ac-plan-clean** / **ac-plan-refine-internal** / **ac-plan-refine-external** | Verify / deepen a plan (correctness pass · multi-agent · multi-model) |
| **ac-plan-review-genius** / **ac-plan-transcender-alien** | Forensic / paradigm-breaking review of a plan |
| **ac-beadify** | Convert a refined plan into a beads task structure (create) |
| **ac-bead-refine** | Refine beads to convergence — self-contained, agent-ready |
| **ac-implement** | Sequential bead implementation — conductor + engineer sub-agents |
| **ac-review** | Feature-branch review — parallel reviewers, auto-fix + escalation |
| **ac-merge** | Merge a wave to main — PR, CI triage, version bump |
| **ac-land** | Session closure — retrospective learning + system compounding |
| **ac-tidy** | Pipeline housekeeping — archive done items, reconcile backlog/plans/beads (out-of-band) |
| **ac-hygiene** | Iterative codebase cleanup (out-of-band, between waves) |
| **ac-human-next** | Human action dashboard — what needs your decision/attention |

**Engineering** (promoted from body-compass-app, the canonical donor)
| Skill | What it does |
|-------|-------------|
| **supabase** | Supabase CLI, migrations, RLS, Postgres patterns |
| **testing** | Vitest unit/component/integration test authoring |
| **react-best-practices** | React + Next.js performance and patterns |
| **capacitor** | TypeScript dev in Capacitor (native wrap) projects |
| **planning** | Plan creation + iterative refinement (scope oscillation) |
| **brainstorming** | Divergent–convergent pre-planning ideation |
| **jef-flywheel** | The agentic build methodology — beads + swarms, setup, lessons (Jeffrey-Emanuel) |
| **jef-prompts** | Curated one-shot prompt library (the "jef" pack) — invoke `/jef-prompts <hint>` |
| **ac-idea-review-genius** / **ac-idea-transcender-alien** | Forensic / paradigm-breaking review of a raw idea |
| **audit** | Systematic code-quality verification framework |
| **skill-builder** | Meta-skill for authoring/refactoring skills — spine+references standard, RED-GREEN testing, validate/init scripts |
| **browser-testing** | UI/login/flow validation via agent-browser |
| **ui-brainstorm** | Multi-model UI critique with consensus ranking |
| **ui-debug** | CSS / visual bug investigation |
| **web-design-guidelines** | Accessibility, forms, animation, typography UX |
| **app-store-screenshots** | Generate iOS App Store screenshots from real screens |

> **Not promoted (stay per-app):** `CORE`, `brand`, `design-system` (pillar-color-coupled), `writing-guidelines` (brand-voice-coupled), `curate` — these are project/brand-specific and can't have one shared version.

## Commands → Skills (migration complete)

Anthropic merged custom commands into skills (a `commands/x.md` and a `skills/x/SKILL.md` both create `/x`). The migration is now done: the engineering workflow commands became the **Pipeline skills above**, and the `jef` prompt pack became the **`jef-prompts`** skill. There is no longer a `commands/` directory — everything deploys as a skill via `deploy.sh --skills`.

## Prompts

The **[jef-prompts](./skills/jef-prompts/)** skill is a curated library of high-leverage one-shot prompts (debugging, performance, refactor, planning, ideation, review, UI, workflow). Invoke `/jef-prompts <hint>` and it loads the best-matching prompt from `skills/jef-prompts/references/`.

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

## Quick Start

### Deploy with `deploy.sh` (recommended)

```bash
# See everything available
./deploy.sh --list

# Stamp a project with a chosen subset (symlinks, never copies)
./deploy.sh ../my-project \
  --skills supabase,testing,planning,jef-prompts --agents engineer,reviewer

# Or take everything
./deploy.sh ../my-project --all

# Preview without writing
./deploy.sh ../my-project --all --dry-run
```

`deploy.sh` computes relative symlinks automatically and **refuses to overwrite a real file** already at the target — so it never clobbers a project's customized skill. Each skill lands as `.claude/skills/<name>/` and is invoked as `/<name>` (e.g. `/ac-plan-init`, `/jef-prompts`).

Then create the project's context file:

```bash
cp AGENTS.md ../my-project/AGENTS.md   # fill in stack + conventions
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
| **[agent-browser](https://www.npmjs.com/package/agent-browser)** | Headless browser automation CLI for UI testing (used by browser-tester sub-agent, ac-land, ac-review) | `npm install -g agent-browser` |

## Philosophy

- **Compound, don't collect** — each skill should make the next one more valuable
- **SKILL.md is the interface** — human-readable reference that doubles as AI context
- **Standalone by default** — no frameworks, no setup wizards
- **One config file** — `expert-panel.json` has everything

## License

MIT
