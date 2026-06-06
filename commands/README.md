# Flywheel — now Skills

The agentic engineering flywheel (inspired by Jeffrey Emanuel's methodology: 80-85%
planning, 15-20% implementation) **used to live here as slash commands**. It now lives
as **skills** under `agent-compounds/skills/ac-*`, invoked as `/ac-*`.

This `commands/` directory now holds **only the `jef` prompt pack** (see below). The
flywheel command files were removed once their content was fully ported to skills.

## Why skills, not commands

Commands and skills were maintained as parallel copies and drifted. Skills are now the
single source of truth — one copy, deployed via `deploy.sh`, no duplication to keep in sync.

## Old command → new skill

| Old command | New skill (invoke as) |
| ----------- | --------------------- |
| `/backlog-add` | `/ac-backlog` |
| `/backlog-tidy` | `/ac-tidy` |
| `/pipeline-next` | `/ac-next` |
| `/pipeline-align` | `/ac-align` |
| `/plan-init`, `/plan-refine-*`, `/plan-clean`, `/plan-review-genius`, `/plan-transcender-alien` | `/ac-plan` (these are now modes of one skill) |
| `/beadify`, `/bead-refine` | `/ac-beadify` |
| `/bead-work` | `/ac-implement` |
| `/work-review` | `/ac-review` |
| `/wave-merge` | `/ac-merge` |
| `/bead-land` | `/ac-land` |
| `/hygiene` | `/ac-hygiene` |
| `/human-next` | `/ac-human-next` |
| (orchestrator) | `/ac-pipeline` |
| `/prompt-enhance`, `/idea-review-genius`, `/idea-transcender-alien`, `/screenshot-refresh`, `/vm-heavy-prep` | unchanged (same name, now skills) |

## Installation

Deploy skills into a project with `deploy.sh` (symlinks — changes propagate instantly):

```bash
# Flywheel skills + the jef command pack + standard agents
./deploy.sh your-project --all

# Or a curated set
./deploy.sh your-project --skills ac-plan,ac-implement,ac-review,ac-merge --commands

# 2. Copy the AGENTS.md template into your project root and fill it in
cp AGENTS.md your-project/AGENTS.md

# 3. Create the standard project structure
mkdir -p your-project/_backlog your-project/_plans your-project/_strategy
```

`--commands` now symlinks the `jef` pack only (`.claude/commands/jef`).

## Project Structure

The flywheel skills expect this layout at the project root:

| Directory | Purpose |
| --------- | ------- |
| `_backlog/` | Captured ideas and active work items (`_done/` subdirectory for completed) |
| `_plans/` | Implementation plans (`_done/` subdirectory for beadified plans) |
| `_strategy/` | Strategy docs — used by `/ac-align` (optional but recommended) |
| `AGENTS.md` | Project context for subagents (commands, architecture, conventions) |

## Workflow

The canonical pipeline and stage sequence is documented in
[`skills/ac-pipeline/SKILL.md`](../skills/ac-pipeline/SKILL.md):

```
/ac-align → /ac-next → /ac-plan → /ac-beadify → /ac-implement → /ac-review → /ac-merge → /ac-land
```

`/ac-implement` loops until the wave is complete. `/ac-review` is optional — use before
merging when you want explicit review. `/ac-align` is a periodic strategic check, not a
linear step.

## Pipeline Lifecycle

Items flow through the pipeline with tracked status at each stage:

```
Backlog (captured) → Plan (draft → refined → approved) → Beads (unrefined → refined → implemented → closed)
```

| Stage | Status Field | Tracked In |
| ----- | ------------ | ---------- |
| Backlog | `status:` frontmatter (`captured` → `planned` → `complete`) | `_backlog/**/*.md` |
| Plan | `status:` frontmatter (`draft` → `refined` → `approved` → `beadified`) | `_plans/*.md` |
| Bead | `unrefined` label (present → removed by `/ac-beadify` refine mode) | `br` labels |

**Key rule:** Once beads are created, the plan is archived to `_done/`. Beads are the
source of truth — if a bead can't stand alone without the plan, it's not ready.

## Dependencies

### Required (for bead-* skills)

- **beads_rust** (`br`) — bead task management
- **beads_viewer** (`bv`) — TUI viewer + AI-driven work selection

### Optional

- **GitHub CLI** (`gh`) — required for `/ac-merge` (PR creation, CI checks, merge)
- **OpenRouter** (`openrouter` CLI) — required only for `/ac-plan` external-refine mode
- **Browser testing tool** (e.g., `agent-browser`) — optional UI validation in `/ac-land`

## The `jef` command pack

`commands/jef/` is a separate library of standalone prompts (bug hunters, optimizers,
reorganizers, etc.), unrelated to the flywheel pipeline. It is still deployed as slash
commands via `deploy.sh --commands` (→ `.claude/commands/jef`).

## Philosophy

> "Planning tokens are cheaper than implementation tokens"
> — Jeffrey Emanuel

Each cycle improves the next. `/ac-land` extracts learnings and proposes system upgrades,
making subsequent sessions faster and higher quality.
