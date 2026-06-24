# agent-compounds — Agent Entry Point

> **This registry _is_ `code-pipe`** — the software factory (the `ac-*` production line
> + code QC + code-domain skills), one half of the agentic-factory pair alongside
> **`content-pipe`** (the publishing house, at `neometa/content/content-pipe/`). Both
> consume one shared substrate (`context-engineering`/`reflect`/`dream`) so they write to
> a single memory ledger. A literal `code-pipe` rename + any monorepo convergence are
> deferred future-state — see `_plans/2026-06-23-factory-split-refactor.md`. Ops skills
> (scheduler, vm-heavy-prep) live in `infrastructure/`, not here.

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

## Distribution policy (2026-06-13, Craig-approved)

**Full set everywhere, auto-synced — no per-project exclude list.** Every INTERNAL neoMeta
app gets the entire registry (all skills + all agents) via `deploy.sh --all`. There is no
selective per-app skill list anymore — availability is uniform.

**Auto-propagation:** `infra-sync.sh` re-runs `deploy.sh --all` against each app in
`infrastructure/ac-deploy-targets.list` on every sync. A newly added registry skill therefore
lands in every internal app on the next sync with **no manual re-stamp** (deploy is idempotent:
creates/refreshes symlinks only, never clobbers a real file — so local customizations like
art-still's `design-system` survive).

**Exclusion (the one exception):** public OSS libraries that are cloned standalone are NOT
stamped — e.g. `vitest-affected`. Symlinks into `../../../agent-compounds` would dangle for
external cloners and leak internal tooling structure. The "no exclude" rule is scoped to
internal neoMeta product apps, not published OSS. To add/remove a target, edit
`infrastructure/ac-deploy-targets.list` (not deploy.sh).

## Architecture

```
agent-compounds/
├── skills/        # the registry — each dir = one skill (SKILL.md + references/ + workflows/)
│   ├── ac-*       # the compounding-engineering pipeline (plan→beadify→implement→review→merge→land)
│   ├── context-engineering, reflect, dream   # the AI-native-org substrate trio (deploy together)
│   └── …          # ui/web/react/capacitor/supabase/testing/seo + jef-prompts (recipe library)
├── agents/        # subagent definitions (researcher, implementer, validator — the 3 stances — plus tester, code-explorer, browser-tester, browser-agent)
├── deploy.sh      # symlinks (never copies) skills/agents into a target's .claude/
├── templates/     # project-AGENTS.md — new-project L0 template (copy to your project root)
└── _plans/        # working plans — local-only, untracked (.gitignored; this repo is public)
```

## Rules

- **Symlink, never copy** — deploy.sh refuses to overwrite real files; canonical lives here.
- **Skills carry domain knowledge; agents carry stance + tool permissions only**
  (constitution: `skills/context-engineering/SKILL.md`).
- **Deploy-together dependency:** `reflect` loads `context-engineering` — always ship both.
- New skills pass the selectability test (description = WHEN, not HOW) and the overlap
  check against this registry before landing.
- Recipes go in `skills/jef-prompts/` — never a parallel prompt library.
- **`./lint.sh` before committing registry changes** (exit 0 = clean): dead refs,
  frontmatter/README/disk conformance, portability greps, consumer symlink health,
  deploy.sh dry-run inertness.
