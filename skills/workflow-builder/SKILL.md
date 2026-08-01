---
name: workflow-builder
description: Use when building a new orchestrated command workflow — a reusable, multi-step `/command` or scheduled job coordinating agents, gates, and outputs toward a repeatable outcome, for content OR code (newsletters, distribution runs, recurring reports, scaffolders, migration drivers, review pipelines). Triggers on "build a workflow", "create a /command", "turn this SOP into a command", "design a pipeline command", "workflow builder". NOT for authoring a SKILL.md (skill-builder), the engineering-pipeline DESIGN doctrine (ac-pipeline), running the pipeline (ac-loop), or deciding where knowledge lives (context-engineering).
---

> **Shared skill (agent-compounds).** Symlinked into projects via `deploy.sh` — this is the
> single source of truth; edit here, not in a consumer copy. Method-only and portable: the
> doctrine lives here, project-specific instances live in `references/examples/`.

# Workflow Builder

**Purpose:** The general meta-process for building **orchestrated command workflows** — the
"how to author a new workflow" skill.

A *workflow* here is a `/command` (or scheduled job) that an orchestrating agent runs to
coordinate sub-agents, quality gates, and outputs toward a repeatable outcome. The outcome
can be **content** (a newsletter, a thread, a distribution run) or **code** (a scaffolder, a
migration driver, a review pipeline). You are authoring the *recipe*, not cooking one meal.

---

## Where this sits (ownership boundaries)

This skill is the **general** layer. Two adjacent skills are more specific; defer to them and
**reference, never restate**:

| Concern | Owner |
| --- | --- |
| How to author any orchestrated workflow (this) | **workflow-builder** |
| The DESIGN doctrine of one specific workflow — the ac-* engineering factory (stage order, contracts, axioms) | **ac-pipeline** |
| How to author a SKILL.md (structure, progressive disclosure, RED-GREEN) | **skill-builder** |
| Where durable knowledge lives / placement + overlap | **context-engineering** |

**`ac-pipeline` is a *specialization* of this skill's doctrine**, not a peer to
duplicate. When building or evolving the engineering pipeline, its axioms win and this skill
defers to them. The standards below are the *general* form; the engineering factory is one
hardened instance.

### Don't restate the axioms — reference them

Several standards in this skill are already first-principles axioms in `ac-pipeline`.
For **engineering** workflows, cite the axiom; this skill states the *general* version for the
broader content+code case:

| General standard here | Specialized axiom in ac-pipeline |
| --- | --- |
| Orchestrator-not-executor ("conductor not musician") | *Altitude separation: thinking ≠ doing* |
| Ask-don't-assume / approval gates | *Humans own intent; the factory owns execution* |
| Declared progress unit (run ledger) | *The bead is the atom* (beads are the engineering progress atom; a TaskCreate run-ledger is the general one) |
| Verify as a classifier-gate, not a fixed run | *Verification gate* (`ac-pipeline/references/verification-gate.md`) |
| Don't block a run on a decision — defer it | *The Exhaust Rule* (decision beads, not mid-run `AskUserQuestion`) |

---

## Orchestration primitives (current)

Pick the lightest tool that fits — don't reach for deterministic orchestration when a single
delegated agent will do.

- **`TaskCreate` / `TaskUpdate` — the run ledger.** The declared progress unit for a workflow
  run: one task per major run SECTION (phases, sub-steps, and iterations as they occur), not
  work items. This is a *runtime progress-visibility* axis — see the Non-negotiable standards
  §1-2 split below for how it relates to (and is deliberately finer than) the design-time phase
  count. Persists across sessions, prevents early exit, and is the resume anchor after
  compaction. Every non-trivial workflow opens with one. *Live reference instances:* `ac-loop`'s
  Phase 0 run ledger; `ac-hygiene`'s "Create Workflow Tasks" section (fixed sections + one
  dynamic task per round).
- **`Agent` tool — the 3-stance trio.** Model-driven delegation: **researcher** (gather &
  distill, read-only), **implementer** (produce the artifact), **validator** (adversarial
  check against a rubric, read-only). *Fat skills, thin agents* — load domain knowledge via a
  skill, not the agent definition. Never mint a per-workflow agent.
- **`Workflow` tool — deterministic orchestration.** Use when control flow should be code, not
  prose: known-up-front fan-out, N-way parallel gates, loop-until-done, pipelines with
  per-item stages.

> Legacy note: older PAI workflows wrote `Task(agent, …)` against dedicated per-workflow
> agents — that contradicts the current *fat-skills / thin-agents / one shared registry*
> doctrine. Use a stance + a loaded skill instead.

---

## The build flow (6 phases)

Full procedure: `workflows/build-workflow.md`. Summary:

| Phase | Goal | Common miss |
| --- | --- | --- |
| **0 · Discovery** | Read 2-3 existing workflows before inventing | Assuming how the system works |
| **1 · Research** | Delegate deep pattern analysis to a **researcher** | Designing it yourself |
| **2 · Refinement** | Resolve open decisions *with the user* — `references/decision-framework.md` | Assuming purpose/structure |
| **3 · Design** | Full spec: phases, delegation, gates, outputs | Phases too granular (>7) |
| **4 · Implementation** | Write the command file + any new references | Editing a non-canonical copy |
| **5 · Verification** | Full test run; gates actually block; resume works | Declaring done after writing the file |

**Skip the heavy process** for a simple, single-user, reversible workflow: use the Quick
Composability Pattern (define the outcome, list the tools, let the agent compose) — see the
head of `references/decision-framework.md`. Reserve the 6 phases for reusable,
multi-stakeholder, or high-stakes workflows.

---

## Non-negotiable standards (the spine)

Every workflow this skill produces has:

1. **A run ledger, declared first** (`TaskCreate`) — **one task per major run SECTION, not a
   restatement of the phase skeleton below.** This is a different axis from item 2: the ledger
   exists for runtime clarity + accountability (so a glance shows exactly where the run is), and
   is expected to run *finer* than the phase count — a single phase can and should emit several
   ledger tasks (a per-round/per-iteration task, a sub-step worth reporting on individually).
   **~8-12 tasks is the normal, encouraged shape for a non-trivial run** — a 3-4-task ledger for
   a real multi-stage workflow is usually under-decomposed, not admirably lean. Mechanics:
   `pending → in_progress → completed`; dependencies via `addBlockedBy`. Tracks the *run's*
   progress, never the underlying work-item list itself. *Live reference instance:* `ac-hygiene`'s
   "Create Workflow Tasks" section (fixed sections created upfront + one dynamic task per round).
2. **A phase skeleton, 5-7 phases** (a separate, design-time axis — unaffected by the ledger
   granularity in item 1). Phase 0 initializes; a final phase finalizes (report +
   verification/teardown). Each phase carries enter/exit criteria. Never 12+ micro-PHASES — that
   guidance is about the workflow's *structural design* (how the recipe is organized), not about
   how many `TaskCreate` lines its ledger emits at runtime. A well-designed 5-7-phase workflow
   still emits an 8-12-task run ledger whenever its phases have rounds or sub-steps worth
   reporting on individually — the two counts are not meant to match.
3. **Quality gates tagged blocking vs warning.** Blocking = STOP, fix, re-run until PASS.
   Warning = note and continue. Prefer a **classifier-gate** (run only the checks the diff/
   output warrants) over a fixed unconditional battery. Independent checks run in **parallel**
   (one message / one `Workflow` fan-out); dependent ones sequential.
4. **A single source of truth for run state** — the run ledger, plus a consolidated `plan.md`
   (or, for code workflows in a bead-native repo, the bead board) — not scattered per-phase
   files unless asked.
5. **The standard tail sections:** Flexibility/Overrides, Troubleshooting, Finalization.
6. **A decision discipline:** *ask-don't-assume* on the user's calls (purpose, structure,
   consolidation, approval gates); decide-with-rationale on the rest (phase count, parallel vs
   sequential). **Never block a long run on a mid-run decision** — defer it (a deferred-decision
   record / `AskUserQuestion` only for simple bounded forks).

Pattern library with worked examples: `references/command-patterns.md`.

---

## Reference routing

| Read when… | File |
| --- | --- |
| Running an actual build | `workflows/build-workflow.md` |
| You need the pattern library (run ledger, gates, delegation, output conventions, anti-patterns) | `references/command-patterns.md` |
| Phase 2 — deciding what to ask the user | `references/decision-framework.md` |
| You want a worked, project-specific example | `references/examples/` |
| Starting a new command file from scratch | `templates/workflow-template.md` |

---

## After building a workflow

- **A new reusable pattern** → add it to `references/command-patterns.md` (versioned), not to
  a project file.
- **A standard worth enforcing on the engineering pipeline** → harvest it into
  `ac-pipeline` as (or under) an axiom — dedup first; it may already be there.
- **Durable cross-domain knowledge** → route via `context-engineering`.
