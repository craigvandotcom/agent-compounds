# Agent Compounds

Agentic tools that compound. Each builds on the last.

The canonical home for portable skills and agents. Deploy any subset into a project's `.claude/` with [`deploy.sh`](./deploy.sh) — everything is symlinked back here, so this repo stays the single source of truth and edits propagate instantly.

## Skills

Symlinked into a project as `.claude/skills/<name>/`.

The registry is seven packages (WS3 generates this map from `packages.json`; until then the
groups are prose). Stage order — stage · owner · trigger · human gate · artifact — lives in
`skills/ac-pipeline/references/stage-table.md`; nothing here restates it.

**factory-core** — the production line. Conductor is `ac-implement`; doctrine is `ac-pipeline`.
| Skill | What it does |
|-------|-------------|
| **ac-pipeline** | The pipeline doctrine — canonical stage order, each stage's contract, cross-cutting invariants, the three-loop model |
| **ac-plan** | Idea → ONE plan file — problem, approach, artifact-named deliverables, assumptions with detection rules, risk + sequence, out-of-scope, and a success criterion the skill refuses unless it can come out false |
| **ac-polish** | One fixpoint engine, four modes (plan · bead · code · seams) — a stateless severity-gated reader per round, sent `references/reader-prompt.md` verbatim, reporting edits + a mandatory DECLINED list; stamped by `skills/_tools/polish-fixpoint.sh` only against a measured empty diff at round ≥ 2; runs until it converges. `seams` (a.k.a. ac-seams) resolves an area to its heaviest object and TRACES it through three lenses per round — object (lifecycle stages), flow (steps with controller/sensor/on-failure), boundary (both sides' assumes/asserts) — converging on the merged maps (`scripts/seams-merge.py`, exact keys per lens) and deriving the seams (holes, competing writers, unasserted edges, unsensed steps, unchecked assumptions; cross-lens first) plus the ac-qa journey into a plan for `ac-plan`; `scripts/aim.sh churn` ranks FILES from git churn + no-import co-change, `aim.sh objects [--area]` ranks data OBJECTS by seam load (touchers × layers × writers ÷ tests) — the bridge from an area or a hot file to the object a trace needs |
| **ac-beadify** | Compile an approved plan into lean beads — the four-section schema (Intent / Acceptance Criteria / Delivers / Consumes), a Consumes↔edge-wired dependency graph, plan retirement; refuses any bead whose ACs name no executable probe (**no probe, no bead**) |
| **ac-implement** | Work an epic's bead queue as a SWARM (default width 3, uncapped, until the qualifying beads are exhausted) — the invoking session coordinates, spawned workers run `references/worker.md`: `flight-check.sh` at claim, RED first, `swarm-commit.sh` at commit, `close-gate.sh` at close; `coordinator.sh` owns the close-out (stale-ledger refusal, orphan sweep, one ledger commit) |
| **ac-review** | Feature-branch review — parallel reviewers, auto-fix + escalation |
| **ac-prove** | The shared tip-valid full-suite proof primitive — freshness probe / dispatch-if-stale / ensure --fix-forward; every ship path calls it instead of re-implementing its own CI-trust logic |
| **ac-publish** | The ship gate — `ac-prove` obtains the proof and this gate asserts its REQUIRED JOBS ACTUALLY EXECUTED, refusing `NOT-GATED` on a job that was absent, skipped or cancelled; then version once, tag the proven SHA (never `HEAD`), promote-not-rebuild on web, CI-built artifacts only on native, hand off to `ac-distribute` |
| **ac-land** | Session closure — retrospective learning + system compounding |
| **[beads-standards](./skills/beads-standards/)** | Machine-wide bead canon (not pipeline-scoped) — agent vs human bead templates, `human-gate` label taxonomy + synonym merge map, refined/unrefined semantics, status/priority/close_reason conventions, dependency-wiring requirements |
| **[agent-mail](./skills/agent-mail/)** | Multi-agent coordination domain — session identity (two-tier contract), file reservations, release/deregister exit, build slots; owner of the session-procedure + agent-identity canons |

**factory-verify** — QA journeys, UI elevation, tests, hygiene.
| Skill | What it does |
|-------|-------------|
| **ac-qa** | QA an app build through journeys — one engine, two workflows: browser (web shell — SPA routing, storage/session, service worker, console, responsive) and device (native shell — real taps, keyboard, safe-area, deep links, push, appearance). Depth levels, findings=beads, conductor/worker evidence protocol shared |
| **ui-elevate** | Raise UI to premium — taste layer over correctness, with `app` (product) and `site` (marketing) modes; anti-slop audit; human-in-the-loop |
| **ui-debug** | CSS / visual bug investigation |
| **testing** | Vitest unit/component/integration test authoring |
| **ac-hygiene** | Iterative codebase cleanup (out-of-band, between waves) |

**factory-ops** — human command center, align, backlog intake, triage, native distribute.
| Skill | What it does |
|-------|-------------|
| **ac-human** | Human command center — renders the full board first (loop side included), then drives only work at a human gate (blockers, plans to approve, hopper); `board` mode stops after the read-only board render |
| **ac-align** | Reconcile the pipeline with current strategy; owns the nightly reconcile (archive done work, repair readiness labels) and the weekly strategy align |
| **ac-backlog** | Capture ideas into grouped backlog files (front of the pipeline); also the single-bead intake — one raw idea/bug/decision typed and filed now |
| **ac-triage** | Pull operational + user signal back in (crashes, errors, beta feedback), cluster it, route real findings by shape |
| **ac-distribute** | Native ship mechanics — signed build to TestFlight / App Store submission (the outbound half; `ac-triage` is the inbound counterpart) |

> `ac-distribute/` also carries `references/_DECISION-distribution-stack.md` — the distribution-stack decision doc (ratified 2026-06-15) that preceded the skill.

**stack-nextjs-supabase** — the Next.js + Supabase + Capacitor stack.
| Skill | What it does |
|-------|-------------|
| **supabase** | Supabase CLI, migrations, RLS, Postgres patterns |
| **capacitor** | TypeScript dev in Capacitor (native wrap) projects |

**substrate** — the AI-native-org memory skills (deploy together)
| Skill | What it does |
|-------|-------------|
| **context-engineering** | Canonical save-routing taxonomy and L0–L4 loading model — where durable knowledge goes and what loads when; how the compounding system runs (lanes, cadence, drains) is its `references/operations.md` |
| **reflect** | Capture session learnings into the memory substrate — facts, decisions, recipes, domain-routed and git-tracked |
| **dream** | The org's self-improvement engine — synthesize cross-session patterns, lint the substrate, emit PR-style proposals |
| **wiki** | Write and garden wiki synthesis pages — concept/entity/topic/contradiction pages that integrate atomic facts and decisions into one cited narrative (a derived view, not fact capture) |

**meta** — authoring and auditing the registry itself.
| Skill | What it does |
|-------|-------------|
| **skill-builder** | Meta-skill for authoring/refactoring skills — spine+references standard, RED-GREEN testing, validate/init scripts; builds orchestrated `/command` workflows (`workflows/build-workflow.md`); runs the registry audit — mechanical lint passes + semantic dedup/drift (`workflows/registry-audit.md`); scores subagent prompts against the research-backed rubric (`references/prompt-rubric.md`) |

**library** — one-shot prompts, methodology, labs, multi-model access, UI critique.
| Skill | What it does |
|-------|-------------|
| **[multi-model](./skills/multi-model/)** | Access 400+ AI models (Claude, GPT, Gemini, Grok, DeepSeek) and get a panel synthesized into one consensus answer on OpenRouter Fusion |
| **jef-prompts** | Curated one-shot prompt library (the "jef" pack) — invoke `/jef-prompts <hint>` |
| **jef-flywheel** | The agentic build methodology — beads + swarms, setup, lessons (Jeffrey-Emanuel) |
| **brainstorming** | Divergent–convergent pre-planning ideation |
| **ac-idea-lab** | Deep analysis of a raw idea — genius (forensic review) + alien (paradigm-breaking) modes |
| **ac-plan-lab** | Deep analysis of a plan — genius (forensic review) + alien (paradigm-breaking) modes |
| **ui-brainstorm** | Multi-model UI critique with consensus ranking |

> **Not promoted (stay per-app):** `CORE`, `brand`, `design-system` (pillar-color-coupled), `writing-guidelines` (brand-voice-coupled), `curate` — these are project/brand-specific and can't have one shared version. `app-store-screenshots`, `screenshot-refresh`, `seo-metadata` — app asset + marketing-SEO concerns, owned by each app (reference copies in body-compass-app).

## Commands → Skills (migration complete)

Anthropic merged custom commands into skills (a `commands/x.md` and a `skills/x/SKILL.md` both create `/x`). The migration is done: the engineering workflow commands became the **factory-core skills above**, and the `jef` prompt pack became the **`jef-prompts`** skill. Everything deploys as a skill via `deploy.sh --skills`; one legacy file remains under `commands/jef/`.

## Prompts

The **[jef-prompts](./skills/jef-prompts/)** skill is a curated library of high-leverage one-shot prompts (debugging, performance, refactor, planning, ideation, review, UI, workflow). Invoke `/jef-prompts <hint>` and it loads the best-matching prompt from `skills/jef-prompts/references/`.

## Agents

Portable agent definitions. Each declares a semantic `tier:` (orchestrator | coordinator | worker — never a concrete model); deploy.sh generates them into `.claude/agents/` with the model stamped per harness from `harnesses.json agent_models`, so the same tier can mean fable/opus/sonnet in Claude Code and glm/deepseek via OpenCode Go.

| Agent | What it does |
|-------|-------------|
| **[orchestrator](./agents/orchestrator.md)** | Fleet-conductor stance — plans, sequences, delegates, holds decisions and batch boundaries; never implements |
| **[coordinator](./agents/coordinator.md)** | Judgment stance — looks, understands, critiques, synthesizes; read-only analysis, no mechanical execution |
| **[researcher](./agents/researcher.md)** | Read-only gather-and-distill stance — investigates the brain, codebase, and web; never writes |
| **[implementer](./agents/implementer.md)** | Production stance — scoped execution of approved plans/specs (code, content, config) |
| **[validator](./agents/validator.md)** | Adversarial verification stance — audits/judges work against rubrics, finds issues, never fixes |

> **Consolidation rule (2026-09-07):** the fleet carries exactly these five stances — stance = who, tier = model strength, domain = a lens prompt from the skill that needs it (QA journeys, browser automation, test writing all ride implementer/validator prompts). The former `tester`, `code-explorer`, `browser-agent`, `browser-tester`, `device-tester`, and `review/*` agent files were folded: spawning a new agent file for a new domain is now the wrong move — write a lens prompt instead. `implementer` and `validator` were formerly named `engineer` and `reviewer` — those aliases are retired.

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
  --skills supabase,testing,jef-prompts --agents engineer,reviewer

# Or take everything
./deploy.sh ../my-project --all

# Preview without writing
./deploy.sh ../my-project --all --dry-run
```

`deploy.sh` computes relative symlinks automatically and **refuses to overwrite a real file** already at the target — so it never clobbers a project's customized skill. Each skill lands as `.claude/skills/<name>/` and is invoked as `/<name>` (e.g. `/ac-plan`, `/jef-prompts`).

Then create the project's context file:

```bash
cp templates/project-AGENTS.md ../my-project/AGENTS.md   # fill in stack + conventions
mkdir -p ../my-project/_backlog ../my-project/_plans ../my-project/_strategy
```

### Skills setup

```bash
export OPENROUTER_API_KEY=sk-or-...  # for multi-model
```

Claude Code discovers each `SKILL.md` automatically. Use e.g. `/multi-model What makes a great API?` — direct query or panel synthesis via OpenRouter Fusion (`skills/multi-model/workflows/fusion.md`).

## Dependencies

| Dependency | What it provides | Install |
|-----------|-----------------|---------|
| **[beads (br)](https://github.com/Dicklesworthstone/beads_rust)** | Artifact-based planning and implementation tracking — plans, beads, pipeline stages | `cargo install --git https://github.com/Dicklesworthstone/beads_rust.git` |
| **[agent-mail (MCP)](https://github.com/Dicklesworthstone/mcp_agent_mail)** | Inter-agent messaging, file reservations, coordination for multi-agent workflows | Add as MCP server in `.claude/settings.json` |
| **openrouter** | OpenRouter CLI for multi-model queries (used by the multi-model skill) | Install the `openrouter` CLI and ensure it's on your `PATH` |
| **[agent-browser](https://www.npmjs.com/package/agent-browser)** | Headless browser automation CLI for UI testing (used by implementer workers on browser journeys, ac-land, ac-review) | `npm install -g agent-browser` |

## Philosophy

- **Compound, don't collect** — each skill should make the next one more valuable
- **SKILL.md is the interface** — human-readable reference that doubles as AI context
- **Standalone by default** — no frameworks, no setup wizards
- **One workflow file per skill** — e.g. `skills/multi-model/workflows/fusion.md`

## License

MIT
