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
| **Stack** | Markdown skills/agents + bash (`harness-sync.sh` → `deploy.sh`); no app runtime |
| **Type** | Shared engineering tooling registry (skills, agents, prompt library, plans) |
| **Purpose** | Canonical source of the neoMeta engineering skill/agent registry, symlink-deployed into every app |

## Project Commands

| Operation | Command |
|---|---|
| **Sync ALL harness homes (root + apps)** | `./harness-sync.sh --all` (drift check: `--check`) |
| **List deployables** | `./deploy.sh --list` |
| **Selective one-off stamp (non-target project)** | `./deploy.sh <target> --skills a,b --agents x,y` (or `--all`) |
| **Dry run** | `./harness-sync.sh --all -n` / `./deploy.sh <target> --all -n` |
| Dev/test/lint/build | N/A (content repo — no build pipeline) |

## Distribution policy (2026-06-13, Craig-approved)

**Full set everywhere, auto-synced — no per-project exclude list.** Every INTERNAL neoMeta
app gets the entire registry (all skills + all agents) via `deploy.sh --all`. There is no
selective per-app skill list anymore — availability is uniform.

**Consumer requirement (2026-07-08):** every deploy target's `.claude/settings.json` must
carry `"skillListingBudgetFraction": 0.02` — the full registry's model-invocable
descriptions exceed Claude Code's default listing budget, and without the setting an app
degrades to nondeterministic per-app description truncation. New apps inherit it by copying
settings from an existing app (the standard bootstrap). The registry's own gate:
`lint.sh` Check D / `validate-skill.sh --registry` (budget threshold coupled to this value
+ the invocation-graph rule — flags derived from the files, never memory; doctrine:
`skills/skill-builder/references/token-economics.md`).

**Auto-propagation:** `infra-sync.sh` runs `harness-sync.sh --all` daily (06:30): for root +
each app in `infrastructure/ac-deploy-targets.list` it runs `deploy.sh --all` (the `.claude/`
layer) and then projects that layer into every other harness home — `.agents/skills`
(Codex+Pi), `.factory/` (Droid, skills+droids+hooks+MCP), `.codex/` (generated agent TOMLs,
hooks.json, MCP toml). Manifest: `harnesses.json` (+ gitignored `harnesses.local.json`);
hook wiring canon: `hooks/hooks.json`. A newly added registry skill therefore lands in every
app AND every harness on the next sync with **no manual re-stamp** (idempotent:
creates/refreshes symlinks only, never clobbers a real file — so local customizations like
art-still's `design-system` survive; generated files are stamp-gated).

**Public repos (the `public` flag, 2026-07-10):** public OSS repos (e.g. `vitest-affected`)
are synced like everyone else — the concern was never the sync, it was *committing* the
symlinks (dangling for external cloners + internal-structure leak). Such targets carry a
`public` flag in the list and must gitignore their harness layer (`.claude/`, `.agents/`,
`.factory/`, `.codex/`); only AGENTS.md/CLAUDE.md and deliberately tracked project-authored
skills stay published. harness-sync.sh verifies the ignore rules before stamping
(`guard_public`, backed by `deploy.sh --require-ignored`) and skips the target loudly if
they're missing — the invariant is enforced, not conventional. To add/remove a target, edit
`infrastructure/ac-deploy-targets.list` (not deploy.sh).

## Architecture

```
agent-compounds/
├── skills/        # the registry — each dir = one skill (SKILL.md + references/ + workflows/)
│   ├── ac-*       # the compounding-engineering pipeline — 3 loops, one conductor (ac-loop): dev (align→plan→beadify→implement→verify→review→merge→land→publish), triage (ac-triage), audit (audit+ac-hygiene); doctrine = ac-pipeline-builder
│   ├── context-engineering, reflect, dream   # the AI-native-org substrate trio (deploy together)
│   └── …          # ui/web/react/capacitor/supabase/testing/seo + jef-prompts (recipe library)
├── agents/        # subagent definitions (researcher, implementer, validator — the 3 stances — plus tester, code-explorer, browser-tester, browser-agent)
├── deploy.sh      # symlinks (never copies) skills/agents into a target's .claude/
├── templates/     # project-AGENTS.md (new-project L0 template) + ci-build-guards.md
│                  #   (required-NEXT_PUBLIC_* build assert + dep-removed CI gate, copy-paste)
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
