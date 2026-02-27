# Agent Compounds

Agentic tools that compound. Each builds on the last.

Symlink into any project's `.claude/commands/ac/` for instant access across all your projects.

## Skills

| Skill | What it does |
|-------|-------------|
| **[openrouter](./skills/openrouter/)** | Access 400+ AI models. Discover, select, and query the right model for any task |
| **[expert-consensus](./skills/expert-consensus/)** | Fan out one prompt to multiple AI models, synthesize into consensus |

## Commands

Agentic engineering workflows. See [`commands/README.md`](./commands/README.md) for full docs.

| Command | What it does |
|---------|-------------|
| **[pipeline-next](./commands/pipeline-next.md)** | Pipeline dashboard — scan all stages, sequence-reason, offer what to advance toward implementation-ready |
| **[pipeline-align](./commands/pipeline-align.md)** | Align pipeline against current strategy — audit for fit, sequence, and gaps |
| **[plan-init](./commands/plan-init.md)** | Create implementation plans — 3 parallel explorers, validation baseline |
| **[bead-work](./commands/bead-work.md)** | Sequential implementation — conductor + engineer sub-agents (loops until wave done) |
| **[work-review](./commands/work-review.md)** | Feature-branch code review — 4 parallel reviewers, auto-fix + escalation |
| **[hygiene](./commands/hygiene.md)** | Iterative codebase review — 3 agents, multiple rounds |
| + 15 more | Backlog capture, planning refinement, beadification, session landing, idea review |

## Prompts

_Coming soon._

## Sub-Agents

_Coming soon._

## Quick Start

### Commands (recommended: symlink)

```bash
# Symlink commands — changes to agent-compounds propagate instantly
ln -s /path/to/agent-compounds/commands your-project/.claude/commands/ac

# Create standard project structure
mkdir -p your-project/_backlog your-project/_plans your-project/_strategy

# Copy and fill in the AGENTS.md template
cp AGENTS.md your-project/AGENTS.md
```

Commands are then available as `/ac/pipeline-next`, `/ac/plan-init`, `/ac/bead-work`, etc.

### Skills

```bash
export OPENROUTER_API_KEY=sk-or-...  # get one at https://openrouter.ai/keys
pip install orcli                     # for openrouter skill
```

```bash
cp -r skills/expert-consensus your-project/.claude/skills/
```

Use in Claude Code: `/expert-consensus What makes a great API?`

Claude Code discovers `SKILL.md` automatically. Toggle models in `expert-panel.json`.

## Philosophy

- **Compound, don't collect** — each skill should make the next one more valuable
- **SKILL.md is the interface** — human-readable reference that doubles as AI context
- **Standalone by default** — no frameworks, no setup wizards
- **One config file** — `expert-panel.json` has everything

## License

MIT
