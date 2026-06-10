# agent-compounds — Agent Entry Point

## Project Overview

| Field | Value |
|---|---|
| **Name** | agent-compounds |
| **Stack** | Markdown skills/agents + bash (`deploy.sh`); no app runtime |
| **Type** | Shared engineering tooling registry (skills, agents, prompt library, plans) |
| **Purpose** | Canonical source of the neoMeta engineering skill/agent registry, symlink-deployed into every app |

## Project Commands

| Operation | Command |
|---|---|
| **List deployables** | `./deploy.sh --list` |
| **Deploy to an app** | `./deploy.sh <target> --skills a,b --agents x,y` (or `--all`) |
| **Dry run** | `./deploy.sh <target> --all -n` |
| Dev/test/lint/build | N/A (content repo — no build pipeline) |

## Architecture

```
agent-compounds/
├── skills/        # the registry — each dir = one skill (SKILL.md + references/ + workflows/)
│   ├── ac-*       # the compounding-engineering pipeline (plan→beadify→implement→review→merge→land)
│   ├── context-engineering, reflect, dream   # the AI-native-org substrate trio (deploy together)
│   └── …          # ui/web/react/capacitor/supabase/testing/seo + jef-prompts (recipe library)
├── agents/        # subagent definitions (engineer, reviewer, browser-agent, browser-tester)
│   └── sub-agents/  # FROZEN legacy OSS snapshot — never symlink from here
├── deploy.sh      # symlinks (never copies) skills/agents into a target's .claude/
├── templates/     # AGENTS.md template for NEW projects (the boilerplate lives there, not here)
└── _plans/        # working plans (context-architecture, …)
```

## Rules

- **Symlink, never copy** — deploy.sh refuses to overwrite real files; canonical lives here.
- **Skills carry domain knowledge; agents carry stance + tool permissions only**
  (constitution: `skills/context-engineering/SKILL.md`).
- **Deploy-together dependency:** `reflect` loads `context-engineering` — always ship both.
- New skills pass the selectability test (description = WHEN, not HOW) and the overlap
  check against this registry before landing.
- Recipes go in `skills/jef-prompts/` — never a parallel prompt library.
