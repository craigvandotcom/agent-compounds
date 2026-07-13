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

**Pipeline** — the engineering workflow, one skill per stage, all `ac-` prefixed. The runtime
conductor is **`ac-loop`**; the design lives in **`ac-pipeline-builder`**. Three operational
loops feed one execution path (see `ac-pipeline-builder` § *The three operational loops*):
the **dev loop** (human intent → plans → waves → `ac-loop` ships), the **triage loop**
(`ac-triage`, scheduled — production signal → defect beads), and the **audit loop**
(`audit` + `ac-hygiene`, periodic — proactive hardening findings → beads).
| Skill | What it does |
|-------|-------------|
| **ac-pipeline-builder** | The pipeline doctrine — canonical stage order, each stage's contract, cross-cutting invariants, the three-loop model |
| **ac-loop** | The runtime conductor — autonomous bead-shipping loop; drives orphan fixes + plan waves to merge unattended, pauses on genuine decisions via Slack |
| **[ac-pipeline](./skills/ac-pipeline/)** | **DEPRECATED** — superseded by `ac-loop` (runtime conductor) + `ac-pipeline-builder` (doctrine); kept for history, its stage chain is stale |
| **ac-backlog** | Capture ideas into grouped backlog files (front of the pipeline) |
| **ac-triage** | Pull operational + user signal back in (crashes, errors, beta feedback), cluster it, route real findings by shape |
| **ac-align** | Reconcile the pipeline with current strategy |
| **ac-plan-init** | Create a first-draft implementation plan |
| **ac-plan-clean** / **ac-plan-refine-internal** / **ac-plan-refine-external** | Verify / deepen a plan (correctness pass · multi-agent · multi-model) |
| **ac-plan-review-genius** / **ac-plan-transcender-alien** | Forensic / paradigm-breaking review of a plan |
| **ac-bead-capture** | Capture a raw idea/bug/decision on the go as one properly typed, routed bead |
| **ac-beadify** | Convert a refined plan into a beads task structure (create) |
| **ac-bead-refine** | Refine beads to convergence — self-contained, agent-ready |
| **ac-implement** | Sequential bead implementation — conductor + engineer sub-agents |
| **ac-review** | Feature-branch review — parallel reviewers, auto-fix + escalation |
| **ac-merge** | Merge a branch to main via PR (surviving PR path: dependabot, human feature branches) — CI triage, version bump |
| **ac-batch-close** | Trunk-direct batch closing ceremony — Tier 1 CI dispatch, review gate, version bump + tag, deploy checks, review-mark advance |
| **ac-land** | Session closure — retrospective learning + system compounding |
| **ac-publish** | Manual, human-triggered release gate — post-loop "ship to production": SHA-pinned full-CI read + full QA + migration safety, composes `ac-merge` + `ac-distribute` |
| **ac-distribute** | Native ship mechanics — signed build to TestFlight / App Store submission (the outbound half; `ac-triage` is the inbound counterpart) |
| **ac-tidy** | Pipeline housekeeping — archive done items, reconcile backlog/plans/beads (out-of-band) |
| **ac-hygiene** | Iterative codebase cleanup (out-of-band, between waves) |
| **ac-human-session** | Human command center — surfaces only work at a human gate (blockers, plans to approve, hopper), conducts the sit-down |
| **ac-dashboard** | Read-only full-board dashboard — backlog/plans/beads/WIP at a glance, both sides of the loop boundary; renders, never acts |

**Engineering** (promoted from body-compass-app, the canonical donor)
| Skill | What it does |
|-------|-------------|
| **supabase** | Supabase CLI, migrations, RLS, Postgres patterns |
| **testing** | Vitest unit/component/integration test authoring |
| **capacitor** | TypeScript dev in Capacitor (native wrap) projects |
| **planning** | Scope-oscillation methodology reference (the lenses the `ac-plan-*` chain applies — not a direct entry point) |
| **brainstorming** | Divergent–convergent pre-planning ideation |
| **jef-flywheel** | The agentic build methodology — beads + swarms, setup, lessons (Jeffrey-Emanuel) |
| **jef-prompts** | Curated one-shot prompt library (the "jef" pack) — invoke `/jef-prompts <hint>` |
| **ac-idea-review-genius** / **ac-idea-transcender-alien** | Forensic / paradigm-breaking review of a raw idea |
| **audit** | The audit loop's checklist framework — severity-scored security/performance/tests/qa/ui sweeps of APP code, findings → beads (for auditing this registry itself → `ac-registry-audit`) |
| **skill-builder** | Meta-skill for authoring/refactoring skills — spine+references standard, RED-GREEN testing, validate/init scripts |
| **workflow-builder** | Build a new orchestrated multi-step `/command` workflow — 6-phase build process, run-ledger + phase-skeleton + quality-gate standards |
| **ac-registry-audit** | Make the registry itself watertight — audit the prompt corpus for trigger collisions, divergent duplicates, dangling refs, doc↔disk drift; mechanical fixes + gated judgment calls (lint.sh → dedup/drift workflow) |
| **browser-testing** | UI/login/flow validation via agent-browser |
| **device-testing** | Ad-hoc native iOS-simulator driving via agent-device, with screenshot/video capture — the native twin of browser-testing |
| **ui-brainstorm** | Multi-model UI critique with consensus ranking |
| **ui-debug** | CSS / visual bug investigation |
| **ac-ui-polish** | Conform UI to the app's design.md then polish to premium — whole-app crawl or one screen; anti-slop audit (was ui-elevate) |
| **ac-site-polish** | Conform the public marketing site to design.site.md then polish to premium — the public twin of ac-ui-polish |
| **web-design-guidelines** | Accessibility, forms, animation, typography UX |
| **app-store-screenshots** | Generate iOS App Store screenshots from real screens |
| **screenshot-refresh** | Discover, seed, and recapture stale landing page screenshots |
| **seo-metadata** | Add or audit SEO and social-share metadata (OG, Twitter cards, JSON-LD, sitemaps) |
| **prompt-enhance** | Audit and improve subagent prompts in skill/command files against a research-backed rubric |
| **ac-qa-device** | QA the native build on device/simulator — journeys, native shell, appearance matrix, screenshots/video |
| **ac-qa-browser** | QA the web build in a browser (the twin) — journeys, web shell, console, responsive, screenshots |

> `ac-distribute/` also carries `references/_DECISION-distribution-stack.md` — the distribution-stack decision doc (ratified 2026-06-15) that preceded the skill.

> **Not promoted (stay per-app):** `CORE`, `brand`, `design-system` (pillar-color-coupled), `writing-guidelines` (brand-voice-coupled), `curate` — these are project/brand-specific and can't have one shared version.

**Substrate** — the AI-native-org memory trio (deploy together)
| Skill | What it does |
|-------|-------------|
| **context-engineering** | Canonical save-routing taxonomy and L0–L4 loading model — where durable knowledge goes and what loads when |
| **reflect** | Capture session learnings into the memory substrate — facts, decisions, recipes, domain-routed and git-tracked |
| **dream** | The org's self-improvement engine — synthesize cross-session patterns, lint the substrate, emit PR-style proposals |

## Commands → Skills (migration complete)

Anthropic merged custom commands into skills (a `commands/x.md` and a `skills/x/SKILL.md` both create `/x`). The migration is done: the engineering workflow commands became the **Pipeline skills above**, and the `jef` prompt pack became the **`jef-prompts`** skill. Everything deploys as a skill via `deploy.sh --skills`; one legacy file remains under `commands/jef/`.

## Prompts

The **[jef-prompts](./skills/jef-prompts/)** skill is a curated library of high-leverage one-shot prompts (debugging, performance, refactor, planning, ideation, review, UI, workflow). Invoke `/jef-prompts <hint>` and it loads the best-matching prompt from `skills/jef-prompts/references/`.

## Agents

Portable agent definitions, symlinked into `.claude/agents/`.

| Agent | What it does |
|-------|-------------|
| **[researcher](./agents/researcher.md)** | Read-only gather-and-distill stance — investigates the brain, codebase, and web; never writes |
| **[implementer](./agents/implementer.md)** | Production stance — scoped execution of approved plans/specs (code, content, config) |
| **[validator](./agents/validator.md)** | Adversarial verification stance — audits/judges work against rubrics, finds issues, never fixes |
| **[tester](./agents/tester.md)** | Test coverage and validation specialist — verifies test quality and runs automated suites |
| **[code-explorer](./agents/code-explorer.md)** | Read-only codebase exploration + mapping, pattern discovery before building |
| **[browser-tester](./agents/browser-tester.md)** | UI smoke testing via agent-browser — runs user journey story files and reports PASS/FAIL |
| **[browser-agent](./agents/browser-agent.md)** | General-purpose headless browser automation — screenshots, scraping, forms, navigation |
| **[device-tester](./agents/device-tester.md)** | Native UI validation agent — runs journeys in the iOS Simulator via agent-device + simctl, reports PASS/FAIL, never edits code |

> **Note:** `implementer` and `validator` were formerly named `engineer` and `reviewer` — those aliases are retired.

## Quick Start

### Deploy with `deploy.sh` (selective one-offs)

> For the standard full sync — all targets, all harnesses (Claude/Codex/Droid/Pi skills,
> agents, hooks, MCP) — use **`./harness-sync.sh --all`** instead; it drives deploy.sh
> internally and runs daily via infra-sync. deploy.sh alone is for stamping a chosen
> subset into one project's `.claude/`.

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
cp templates/project-AGENTS.md ../my-project/AGENTS.md   # fill in stack + conventions
mkdir -p ../my-project/_backlog ../my-project/_plans ../my-project/_strategy
```

### Skills setup

```bash
export OPENROUTER_API_KEY=sk-or-...  # for openrouter / expert-consensus
```

Claude Code discovers each `SKILL.md` automatically. Use e.g. `/expert-consensus What makes a great API?` — toggle models in `skills/expert-consensus/expert-panel.json`.

## Dependencies

| Dependency | What it provides | Install |
|-----------|-----------------|---------|
| **[beads (br)](https://github.com/Dicklesworthstone/beads_rust)** | Artifact-based planning and implementation tracking — plans, beads, pipeline stages | `cargo install --git https://github.com/Dicklesworthstone/beads_rust.git` |
| **[agent-mail (MCP)](https://github.com/Dicklesworthstone/mcp_agent_mail)** | Inter-agent messaging, file reservations, coordination for multi-agent workflows | Add as MCP server in `.claude/settings.json` |
| **openrouter** | OpenRouter CLI for multi-model queries (used by expert-consensus and openrouter skills) | Install the `openrouter` CLI and ensure it's on your `PATH` |
| **[agent-browser](https://www.npmjs.com/package/agent-browser)** | Headless browser automation CLI for UI testing (used by browser-tester sub-agent, ac-land, ac-review) | `npm install -g agent-browser` |

## Philosophy

- **Compound, don't collect** — each skill should make the next one more valuable
- **SKILL.md is the interface** — human-readable reference that doubles as AI context
- **Standalone by default** — no frameworks, no setup wizards
- **One config file per skill** — e.g. `skills/expert-consensus/expert-panel.json`

## License

MIT
