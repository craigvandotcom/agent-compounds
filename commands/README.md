# Flywheel Commands

Agentic engineering workflows for Claude Code. Drop into any project's `.claude/commands/` directory.

Inspired by Jeffrey Emanuel's Agentic Coding Flywheel methodology: 80-85% planning, 15-20% implementation.

## Installation

1. Copy `commands/*.md` into your project's `.claude/commands/` (or a subdirectory like `.claude/commands/flywheel/`)
2. Copy `AGENTS.md` template into your project root
3. Fill in `AGENTS.md` with your project's commands, architecture, and conventions
4. Optionally copy `CLAUDE.md` template as a starter

## Commands

### Backlog Management

| Command | Purpose |
| ------- | ------- |
| `backlog-add` | Capture ideas with smart grouping — checks existing files, beads, and plans for duplicates |
| `backlog-tidy` | Pipeline housekeeping — archive completed items, reconcile statuses, flag orphans, suggest merges |
| `backlog-next` | Pipeline dashboard — scan backlog/plans/beads, show funnel status, offer next action |

### Planning

| Command | Purpose |
| ------- | ------- |
| `plan-init` | Create implementation plans — 3 parallel explorers, validation baseline, test specs, user-gated approval |
| `plan-refine-internal` | Multi-agent plan refinement — 3-tier (light/medium/heavy), no external API |
| `plan-refine-external` | Multi-model refinement via OpenRouter — 4 diverse external models |
| `plan-review-genius` | Single-model deep forensic review |
| `plan-transcender-alien` | Paradigm-breaking alternative perspectives |
| `plan-clean` | Final correctness check — 3 Sonnets verify accuracy, structure, and polish with cross-round consensus |

### Beads (Implementation)

| Command | Purpose |
| ------- | ------- |
| `beadify` | Convert refined plan to beads (labels `unrefined`), archive plan to `_done/` |
| `bead-refine` | Refine bead structure — removes `unrefined` label on convergence |
| `bead-work` | Sequential implementation — conductor + engineer sub-agents |
| `bead-land` | Session closure — retrospective learning + system compounding |

### Review & Ship

| Command | Purpose |
| ------- | ------- |
| `work-review` | Feature-branch code review — 4 parallel Sonnet reviewers, severity-based auto-fix, user-escalated decisions |
| `wave-merge` | Merge wave branch to main — PR creation, CI/agent feedback triage, auto-fix, merge |
| `hygiene` | Iterative codebase review — 3 Opus agents, multiple rounds until plateau |

### Meta

| Command | Purpose |
| ------- | ------- |
| `prompt-enhance` | Analyze and enhance subagent prompts — score against pattern rubric, diagnose gaps, rewrite |

### Ideas

| Command | Purpose |
| ------- | ------- |
| `idea-review-genius` | Deep review of specific ideas |
| `idea-transcender-alien` | Alien-perspective idea enhancement |

## Workflow

```
backlog-add → backlog-tidy → backlog-next → plan-init → plan-refine-internal → plan-clean → beadify → bead-refine → bead-work → bead-land → work-review → wave-merge
         ↑                                                                                                                                          |
         └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

## Pipeline Lifecycle

Items flow through the pipeline with tracked status at each stage:

```
Backlog (captured) → Plan (draft → refined → approved) → Beads (unrefined → refined → implemented → closed)
```

| Stage | Status Field | Tracked In |
| ----- | ------------ | ---------- |
| Backlog | `status:` frontmatter (`captured` → `planned` → `complete`) | `_backlog/**/*.md` |
| Plan | `status:` frontmatter (`draft` → `refined` → `approved` → `beadified`) | `.claude/plans/*.md` |
| Bead | `unrefined` label (present → removed by `/bead-refine`) | `br` labels |

**Key rule:** Once beads are created, the plan is archived to `_done/`. Beads are the source of truth — if a bead can't stand alone without the plan, it's not ready.

## Dependencies

### Required (for bead-* commands)

- **beads_rust** (`br`) — bead task management
- **beads_viewer** (`bv`) — TUI viewer + AI-driven work selection

### Optional

- **GitHub CLI** (`gh`) — required for `wave-merge` (PR creation, CI checks, merge)
- **OpenRouter** (`openrouter` CLI) — required only for `plan-refine-external`
- **Browser testing tool** (e.g., `agent-browser`) — optional UI validation in `bead-land`

## Key Files

| File | Purpose |
| ---- | ------- |
| `AGENTS.md` | **Template** — project context for subagents (commands, architecture, skills, rules) |
| `CLAUDE.md` | **Template** — minimal pointer for main orchestrator |

## Philosophy

> "Planning tokens are cheaper than implementation tokens"
> — Jeffrey Emanuel

Each cycle improves the next. `bead-land` extracts learnings and proposes system upgrades, making subsequent sessions faster and higher quality.
