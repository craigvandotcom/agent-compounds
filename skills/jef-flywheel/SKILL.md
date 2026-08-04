---
name: jef-flywheel
description: Use when learning or applying the agentic build methodology end-to-end — beads (br/bv) and agent-swarm (ntm) setup, coordinating multi-agent work, AGENTS.md conventions. The conceptual/setup layer, not the per-stage pipeline skills. Triggers on flywheel, agent swarm, ntm, br/bv setup, agent coordination, multi-agent development. To convert a plan into beads use ac-beadify; to run a stage use the ac-* skills; for live coordination (identity, file reservations) use agent-mail; for bead canon use beads-standards.
---

Git discipline: `ac-pipeline/references/commit-discipline.md` — pathspec-only commits, no wildcard adds / stash, commit=push, deletion check. <!-- net-growth-ok: ac-gcj.7 Pass C canon binding -->

Bead creation per `beads-standards/reference/bead-conventions.md` — types, unrefined-at-creation, anchor-dedupe, body template. <!-- net-growth-ok: ac-gcj.7 Pass C canon binding -->

Identity + reservations per `agent-mail/references/session-procedure.md` (mint · export · reserve · release). <!-- net-growth-ok: ac-gcj.7 Pass C canon binding -->

> **Generic skill — method only, zero app facts.** This skill is symlinked from
> agent-compounds and shared across consuming apps. It contains technique and
> patterns, not project specifics. **App specifics (project refs, schema names,
> domain rules, feature flows, env values) → read this app's
> `.claude/skills/CORE/SKILL.md`** (and the `AGENTS.md` summary it indexes).
> Do not add app-specific facts to this file — they belong in CORE.

# Agentic Coding Flywheel

**Purpose:** Knowledge gateway for Jeffrey Emanuel's agentic coding methodology
**Domain:** Multi-agent software development, task planning, swarm coordination
**Status:** Complete
**Source:** [agent-flywheel.com](https://agent-flywheel.com), Jeffrey's GitHub (@Dicklesworthstone)

---

## The Core Loop (8-Step Flywheel)

```
IDEA --> PLAN --> REFINE --> BEADIFY --> POLISH --> EXECUTE --> REVIEW --> COMMIT
 5%      30%      30%        10%        10%        10%         4%        1%
```

**Time Allocation:** 85% planning (steps 1-5), 15% execution (steps 6-8)

**Key Philosophy:** "Planning tokens are cheaper than implementation tokens. It's easier to operate in 'plan space' before implementing."

---

## Quick Start

New to the flywheel? Follow this sequence:

1. Read `workflows/idea-to-commit.md` -- full step-by-step walkthrough
2. Set up your VM using `workflows/setup-vm.md`
3. Use `templates/prompts-reference.md` for copy-paste prompts at each stage
4. Reference `tools/tool-reference.md` for CLI commands
5. Create `AGENTS.md` for your project using `templates/agents-template.md`

For multi-device work (MacBook + VM + Phone): `workflows/multi-device.md`

---

## Principles

**Plan massively, execute briefly.** Jeffrey's plans routinely hit 5,000-6,000 lines. A 6,000-line plan is still shorter than the code it produces. More detail = better implementation.

**Refine until steady state.** Run 3-5 refinement rounds (or 15-20 with APR). Stop when changes plateau -- only minor tweaks, not structural changes.

**Agent-first tooling.** All tools must have `--robot` and `--json` flags for machine consumption. TUI modes for humans, robot modes for agents.

**Unix composability.** One tool per function: mail, tasks, viewer, orchestration. Each works standalone AND composes with others.

**Don't prematurely automate.** Get an intimate, intuitive feel for your core loop before automating. Otherwise you efficiently and automatically do a sub-optimal thing.

---

## Tool Quick Reference

| Tool           | Purpose                                     | Key Command                                             | Full Docs                 |
| -------------- | ------------------------------------------- | ------------------------------------------------------- | ------------------------- |
| **br**         | Task management (create/update/close beads) | `br create --title "Task" --label backend`              | `tools/tool-reference.md` |
| **bv**         | Prioritization and analytics                | `bv --robot-next` (never bare `bv`!)                    | `tools/tool-reference.md` |
| **ntm**        | Agent swarm orchestration                   | `ntm spawn proj --cc=3 --cod=1`                         | `tools/tool-reference.md` |
| **Agent Mail** | Agent coordination (MCP)                    | `send_message`, `fetch_inbox`, `file_reservation_paths` | `tools/tool-reference.md` |
| **dcg**        | Destructive command guard                   | `dcg install`                                           | `tools/tool-reference.md` |
| **ubs**        | Static analysis                             | `ubs file.ts` (not `ubs .`)                             | `tools/tool-reference.md` |
| **cass/cm**    | Session memory                              | `cass --json search "query"` (never bare `cass`!)       | `tools/tool-reference.md` |
| **apr**        | Automated plan refinement                   | `apr setup` then `apr run 1 --login`                    | `tools/tool-reference.md` |
| **acfs**       | System management                           | `acfs doctor`, `acfs newproj`                           | `tools/tool-reference.md` |

---

## The Workflow Steps (Summary)

### 1. Idea (5 min)

Write 1-2 paragraphs: what, why, references, tech stack, quality bar. Save as `PLAN.md`.

### 2. Initial Plan (30-60 min)

Use ChatGPT Pro / Claude Opus to create comprehensive implementation plan (architecture, models, APIs, testing, risks). See `templates/prompts-reference.md` for exact prompts.

### 3. Refine Plan (1-3 hours, 3-5 rounds)

Bounce between GPT Pro (suggest revisions) and Claude (integrate + critique). Optional: multi-model blending with Gemini/Grok. Or use APR for 15-20 automated rounds.

### 4. Convert Plan to Beads (20-30 min)

On VM with beads installed. Use `br` to create granular tasks with dependencies, labels, and self-documenting comments.

### 5. Polish Beads (30-60 min, 6-8 rounds)

Repeatedly review beads until no meaningful changes occur. Each bead must be self-contained with clear "done" criteria.

### 6. Launch Swarm (or Single Agent)

Single agent first: `bv --robot-next` to pick beads, implement, test, close. Scale to swarm with `ntm spawn` once comfortable.

### 7. Quality Loops

Self-review with "fresh eyes", cross-agent review, random deep exploration. Use severity-tiered prompts: `/bug-hunter`, `/bug-hunter-genius`, `/bug-hunter-alien`.

### 8. Commit

Logical commit groupings with detailed messages. Consider a dedicated commit agent (every 15-20 min during swarm work).

**Full walkthrough:** `workflows/idea-to-commit.md`

---

## Implementation Loop (Per Bead)

```
1. bv --robot-next          Pick highest-impact unblocked bead
2. Reserve files             Agent Mail file reservation
3. Implement                 Write code per bead specification
4. Test until passing        Fix until tests pass
5. Self-review               "Fresh eyes" review of own code
6. Mark bead done            br close <bead-id>
7. Release files             Release Agent Mail reservations
8. Check mail                Respond to agent messages
9. Repeat from step 1
```

---

## Key Operational Notes

- **Bead IDs** use `bd-` prefix (e.g., `bd-1234`). Full flags: `--title`, `--priority`, `--label`, `--blocks`, `--blocked-by`, `--status`, `--reason`
- **Agent Mail** is HTTP + SQLite (not git-based). Start with `am` command. Web UI at `http://<vm-ip>:8765/mail`
- **ACFS tmux** changes prefix from `Ctrl+b` to `Ctrl+a`
- **Wave vs continuous:** Flywheel is wave-optimized (big plan, bulk beads, swarm execute, ship). See `reference/workflow-cadence.md`
- **AGENTS.md** is the single source of truth for AI agents in every project

---

## Jeffrey's Key Insights

- Plans can be 5,000-6,000 lines -- "not slop, the result of countless iterations and blending of ideas from many models"
- MCP tool overload causes "paradox of choice" -- keep core tools globally, add others on demand
- The flywheel effect: tools improve each other. Better tools leads to more capable agents leads to more code shipped leads to better tools
- Agent-first design: build for `--robot` and `--json` flags because agents are better at using tools than humans

---

## Common Mistakes

| Mistake                                                | Fix                                                                        |
| ------------------------------------------------------ | -------------------------------------------------------------------------- |
| Running bare `bv` or `cass` in agent context           | Always use `--robot-*` or `--json` flags                                   |
| Skipping plan refinement ("good enough")               | Run 3-5 refinement rounds until steady state                               |
| Starting swarm before single-agent validation          | Do first flywheel run with single agent                                    |
| Communication purgatory (agents messaging, not coding) | Add anti-stalling directive to AGENTS.md                                   |
| Agents forgetting to check mail                        | Use automated hooks or periodic "check mail" prompts                       |
| Committing only at end of session                      | Use commit agent pattern: commit every 15-20 min                           |
| Over-scoping UBS (scanning entire project)             | `ubs file.ts` not `ubs .`                                                  |
| Running `apr` before plan exists                       | Create initial plan first, then `apr refine`                               |
| Premature automation                                   | Get intuitive feel for core loop before automating                         |
| Plans too thin for agent consumption                   | Jeffrey's plans are 5,000-6,000 lines. More detail = better implementation |

---

## Integration with Other Skills

| Skill             | Connection                                                                      |
| ----------------- | ------------------------------------------------------------------------------- |
| **pai**           | Flywheel tools (br, bv, ntm) are PAI toolchain. Config in pai architecture docs |
| **skill-builder** | Create project-specific skills for flywheel projects                            |
| **researcher**    | Deep research on competitors/technologies during planning phase                 |
| **claude-code**   | Subagent architecture for delegating flywheel execution steps                   |
| **strategist**    | Align flywheel project selection with strategic goals                           |
| **admin**         | Schedule flywheel jobs (weekly updates, automated reviews)                      |

---

## Supporting Documentation

### Workflows (Step-by-Step Guides)

| File                          | When to Read                                          |
| ----------------------------- | ----------------------------------------------------- |
| `workflows/idea-to-commit.md` | First flywheel run or refresher on the full process   |
| `workflows/setup-vm.md`       | Setting up VM, installing ACFS, authenticating agents |
| `workflows/multi-device.md`   | Coordinating MacBook + VM + phone                     |

### Templates

| File                             | When to Read                                   |
| -------------------------------- | ---------------------------------------------- |
| `templates/prompts-reference.md` | Need copy-paste prompts for any flywheel stage |
| `templates/agents-template.md`   | Creating AGENTS.md for a new project           |

### Tools

| File                      | When to Read                                                |
| ------------------------- | ----------------------------------------------------------- |
| `tools/tool-reference.md` | CLI commands for br, bv, ntm, dcg, ubs, cass, cm, apr, acfs |

### Reference

| File                             | When to Read                                    |
| -------------------------------- | ----------------------------------------------- |
| `reference/example-setup.md`     | Worked example: 3-agent scale, VPS specs, cost shape |
| `reference/model-selection.md`   | Which AI model for which role                   |
| `reference/workflow-cadence.md`  | Wave vs continuous workflow patterns            |
| `reference/resources.md`         | Complete source index (repos, tweets, articles) |
| `reference/tweet-insights.md`    | Practical insights from Jeffrey's tweets        |
| `reference/vps-options.md`       | VM specs and provider comparison                |
| `reference/skills-comparison.md` | Jeffrey's skills architecture                   |

### Lessons

| File       | When to Read                                                                  |
| ---------- | ----------------------------------------------------------------------------- |
| `lessons/` | Human onboarding -- all 36 ACFS learning hub lessons. See `lessons/README.md` |

### Key Repositories

- [agentic_coding_flywheel_setup](https://github.com/Dicklesworthstone/agentic_coding_flywheel_setup) -- Main installer + lessons
- [beads_rust](https://github.com/Dicklesworthstone/beads_rust) -- Task tracker CLI (br)
- [beads_viewer](https://github.com/Dicklesworthstone/beads_viewer) -- Graph-theory TUI + robot-mode API (bv)
- [mcp_agent_mail](https://github.com/Dicklesworthstone/mcp_agent_mail) -- Agent coordination server
- [automated_plan_reviser_pro](https://github.com/Dicklesworthstone/automated_plan_reviser_pro) -- APR
- [named_tmux_manager](https://github.com/Dicklesworthstone/named_tmux_manager) -- NTM
- [claude_agent_session_store](https://github.com/Dicklesworthstone/claude_agent_session_store) -- CASS

### Craig's PKM Research

- `knowledge/2-areas/agentic-engineering/advanced/05-jeffrey-emmanuel-agentic-flywheel.md`
- `knowledge/2-areas/agentic-engineering/research/jeffrey-emanuel-planning-methodology.md`
- `knowledge/2-areas/agentic-engineering/research/jeffrey-emanuel-ideation-methodology.md`
- `knowledge/2-areas/agentic-engineering/research/beads-workflow-comparison.md`
