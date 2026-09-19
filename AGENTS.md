# agent-compounds — Agent Entry Point

> **This registry is a software factory** — the `ac-*` production line + code QC +
> code-domain skills. It is deliberately paired with the **substrate** package
> (`context-engineering`/`reflect`/`dream`) rather than owning memory itself, so a
> parallel factory on another domain (content, ops) can consume the same memory
> ledger instead of forking one. Scheduler/infra-ops skills are out of scope here —
> this registry only ships engineering skills and agents.

## Project Overview

| Field | Value |
|---|---|
| **Name** | agent-compounds |
| **Stack** | Markdown skills/agents + bash (`engine/sync.sh` → `engine/deploy.sh`); no app runtime |
| **Type** | Shared engineering tooling registry (skills, agents, prompt library, plans) |
| **Purpose** | Canonical source of a portable engineering skill/agent registry, symlink-deployed into every consuming project |

## Project Commands

| Operation | Command |
|---|---|
| **Sync ALL harness homes (root + apps)** | `./engine/sync.sh --all` (drift check: `--check`) |
| **List deployables** | `./engine/deploy.sh --list` |
| **Selective one-off stamp (non-target project)** | `./engine/deploy.sh <target> --skills a,b --agents x,y` (or `--all`) |
| **Dry run** | `./engine/sync.sh --all -n` / `./engine/deploy.sh <target> --all -n` |
| Dev/test/lint/build | N/A (content repo — no build pipeline) |

## Distribution policy

**Full set everywhere, auto-synced — no per-project exclude list.** Every private
consumer project gets the entire registry (all skills + all agents) via
`engine/deploy.sh --all`. There is no selective per-app skill list — availability is
uniform.

**Consumer requirement (2026-07-08):** every deploy target's `.claude/settings.json` must
carry `"skillListingBudgetFraction": 0.02` — the full registry's model-invocable
descriptions exceed Claude Code's default listing budget, and without the setting an app
degrades to nondeterministic per-app description truncation. New apps inherit it by copying
settings from an existing app (the standard bootstrap). The registry's own gate:
`lint.sh` Check D / `validate-skill.sh --registry` (budget threshold coupled to this value
+ the invocation-graph rule — flags derived from the files, never memory; doctrine:
`skills/skill-builder/references/token-economics.md`).

**Auto-propagation:** a recurring sync job (yours to schedule — cron, a scheduler skill,
whatever runs jobs on your machine) runs `harness-sync.sh --all`: for root + each project
in your own deploy-targets manifest (a plain list of project paths — this registry does not
ship one; keep it wherever your other scheduled-job config lives) it runs `deploy.sh --all`
(the `.claude/` layer) and then projects that layer into every other harness home —
`.agents/skills` (Codex+Pi), `.factory/` (Droid, skills+droids+hooks+MCP), `.codex/`
(generated agent TOMLs, hooks.json, MCP toml). Manifest: `harnesses.json` (+ gitignored
`harnesses.local.json`); hook wiring canon: `engine/hooks.wiring.json`. A newly added
registry skill therefore lands in every project AND every harness on the next sync with
**no manual re-stamp** (idempotent: creates/refreshes symlinks only, never clobbers a real
file — so a project's local customizations to a skill survive; generated files are
stamp-gated).

**Public repos (the `public` flag):** public OSS targets are synced like everyone else —
the concern was never the sync, it was *committing* the symlinks (dangling for external
cloners + internal-structure leak). Such targets carry a `public` flag in your
deploy-targets manifest and must gitignore their harness layer (`.claude/`, `.agents/`,
`.factory/`, `.codex/`); only AGENTS.md/CLAUDE.md and deliberately tracked project-authored
skills stay published. harness-sync.sh verifies the ignore rules before stamping
(`guard_public`, backed by `deploy.sh --require-ignored`) and skips the target loudly if
they're missing — the invariant is enforced, not conventional. To add/remove a target, edit
your deploy-targets manifest (not deploy.sh).

## Architecture

```
agent-compounds/
├── skills/        # the registry — each dir = one skill (SKILL.md + references/ + workflows/)
├── agents/        # the 5 core stances (orchestrator, coordinator, researcher, implementer, validator — each carries a semantic `tier:`, never a concrete model); domain work = stance + lens prompt from the skill, never a new agent file; each carries a semantic `tier:` (orchestrator|coordinator|worker), never a concrete model
├── engine/        # the machinery: the renderer, the stamper and the wiring manifest.
│                  #   Content stays at the root — 4,201 symlinks resolve through it. Check 37
│                  #   forbids the engine spelling a canon path instead of deriving it.
├── templates/     # project-AGENTS.md (new-project L0 template) + ci-build-guards.md
│                  #   (required-NEXT_PUBLIC_* build assert + dep-removed CI gate, copy-paste)
└── _plans/        # working plans — local-only, untracked (.gitignored; this repo is public)
```

**v2 map** (seven packages; WS3 generates the table from `packages.json` later). Stage order
lives in `skills/ac-pipeline/references/stage-table.md`; nothing here restates it.

- **factory-core** — ac-pipeline, ac-plan, ac-polish, ac-beadify, ac-implement, ac-review, ac-prove, ac-publish, ac-land, beads-standards, agent-mail
- **factory-verify** — ac-qa, ui-elevate, ui-debug, testing, ac-hygiene
- **factory-ops** — ac-human, ac-align, ac-backlog, ac-triage, ac-distribute
- **stack-nextjs-supabase** — supabase, capacitor
- **substrate** — context-engineering, reflect, dream, wiki (deploy together)
- **meta** — skill-builder
- **library** — jef-prompts, jef-flywheel, brainstorming, ac-idea-lab, ac-plan-lab, multi-model, ui-brainstorm

**Not promoted (stay per-app):** `CORE`, `brand`, `design-system` (pillar-color-coupled),
`writing-guidelines` (brand-voice-coupled), `curate` — project/brand-specific. `app-store-screenshots`,
`screenshot-refresh`, `seo-metadata` — app asset + marketing-SEO, owned by each app
(a consuming app may keep a reference copy of these rather than promoting them here).

## Rules

- **Symlink, never copy** — deploy.sh refuses to overwrite real files; canonical lives here.
  Agents are the exception: they are GENERATED (tier → model stamped per harness from
  `harnesses.json agent_models`), because a symlinked file cannot carry a per-harness
  model — tier is the canon, models are projections.
- **Skills carry domain knowledge; agents carry stance + tool permissions only**
  (constitution: `skills/context-engineering/SKILL.md`).
- **Deploy-together dependency:** `reflect` loads `context-engineering` — always ship both.
- New skills pass the selectability test (description = WHEN, not HOW) and the overlap
  check against this registry before landing.
- Recipes go in `skills/jef-prompts/` — never a parallel prompt library.
- This repo IS the canonical skill source — when editing a skill here, remember every
  app + the root `.claude/skills/` consume it live via symlink (no deploy step needed
  for content changes; deploy.sh only manages the links).
- Skill authoring standards: the `skill-builder` skill; placement + overlap rules:
  `skills/context-engineering/SKILL.md`.
