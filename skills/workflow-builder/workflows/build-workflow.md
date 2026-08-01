# Building an Orchestrated Command Workflow

The 6-phase meta-process for turning a repeatable outcome — **content or code** — into a
reusable `/command` (or scheduled job) that an orchestrating agent runs. This is the
procedure behind the standards in `../SKILL.md`; the pattern library it references is
`../references/command-patterns.md`.

> **General vs specialized:** this is the *general* method for authoring any orchestrated
> workflow. The ac-* engineering factory is one hardened instance — when you're building or
> evolving *that*, `ac-pipeline` owns its axioms and this method defers to them (e.g.
> beads are the engineering progress atom; a TaskCreate run-ledger is the general one).

---

## Before you start: full process or quick pattern?

**Quick Composability Pattern** — for a simple, single-user, reversible, or exploratory
workflow, skip the six phases: state the outcome in plain language, list the tools the agent
may use, and let it compose the steps. Reach for the full process only when the workflow is
**reusable by others, multi-stakeholder, or high-stakes**. Decision guidance:
`../references/decision-framework.md` (head).

---

## Phase 0 · Discovery (read first)

**Goal:** understand existing patterns before inventing new ones. **~5-10 min.**

1. Read 2-3 existing workflows of a similar shape — how they structure phases, delegate, gate.
2. Locate the source process you're encoding (an SOP, a checklist, a manual routine, an
   existing ad-hoc script).
3. Identify the criteria the output must meet (brand/voice for content; correctness/tests for
   code).
4. Note which existing **skills** already hold the domain knowledge a sub-agent would need.

**Done when:** you can point to 2-3 concrete examples and the source process. **Common miss:**
assuming how the system works instead of reading a working example.

---

## Phase 1 · Research (delegate)

**Goal:** deep pattern analysis, synthesized — not designed by you yet. **~15-25 min.**

Spawn a **researcher** (read-only stance) to analyze and return a cited summary of:
- the structural patterns in the example workflows (phases, gates, delegation, outputs),
- the source process's real steps and decision points,
- high-performing external examples *if* this is a first-of-type workflow,
- the open questions that need a human decision in Phase 2.

**Done when:** you have a pattern analysis, a recommended structure with rationale, and a list
of decisions to put to the user. **Common miss:** designing the workflow yourself instead of
delegating the analysis.

---

## Phase 2 · Refinement (decide *with* the user)

**Goal:** resolve assumptions before building. **~10-20 min.** Work through
`../references/decision-framework.md` and put the **user's calls** to the user — don't assume:

- **Purpose** — the outcome and the transformation it delivers; standalone vs part of a chain.
- **Structure** — required sections/steps; length or scope target; format/quality constraints.
- **Organization** — per-folder vs flat; single consolidated record vs separate files; naming;
  archival.
- **Quality** — what "good" means here; which gates block vs warn; what can be a classifier-gate.
- **Interaction** — where the workflow pauses for approval; what the user can override; which
  decisions get deferred rather than blocking the run.

Decide-with-rationale (don't burden the user): phase count, parallel-vs-sequential, which
skills a sub-agent loads.

**Done when:** the decision template is filled. **Common miss:** assuming purpose or structure
— the two most expensive things to get wrong.

---

## Phase 3 · Design (full specification)

**Goal:** a complete spec ready to implement. **~20-30 min.**

1. **Command file skeleton** — frontmatter `description` (WHEN it fires, not a how-to summary);
   the run-ledger opener; the phase list; the tail sections (Flexibility, Troubleshooting,
   Finalization).
2. **Phase structure** — Phase 0 initializes (run ledger + setup); Phases 1-N are the core
   work; the last phase finalizes (report + verification/teardown). Aim for **5-7 phases**.
3. **Delegation plan** — for each phase, which **stance** does the work and what skill it loads:
   - *model-driven* steps → the `Agent` trio (researcher / implementer / validator);
   - *deterministic* fan-out, N-way gates, or loop-until-done → the `Workflow` tool;
   - never mint a per-workflow agent — load a skill into a stance.
4. **Quality gates** — each tagged **blocking** or **warning**; prefer a classifier-gate (run
   only what the diff/output warrants); independent gates fan out in parallel, dependent gates
   run in sequence.
5. **Run-state & outputs** — the run ledger is the run's source of truth; for artifacts, a
   timestamped per-topic folder + a consolidated `plan.md` (content), or the bead board (a
   bead-native code repo). Don't scatter state across per-phase files.
6. **Decision handling** — define which decisions pause the run (simple, bounded → an
   in-line prompt) and which are **deferred** so a long run never blocks (a deferred-decision
   record the human clears later).

Full templates and worked patterns: `../references/command-patterns.md`.

**Done when:** the command file is fully specified — phases, delegation, gates, outputs, decision
handling, and all three tail sections. **Common miss:** over-granular phases, or unspecified
parallel-vs-sequential.

---

## Phase 4 · Implementation (write the files)

**Goal:** create the command file and any supporting references. **~10-20 min.**

1. Write the `/command` file in the correct location — confirm it's the **canonical** copy, not
   a symlinked consumer copy.
2. Create any new reference docs the workflow needs; durable domain knowledge belongs in a
   **skill** (use `skill-builder`), referenced from the command, not pasted in.
3. Validate mechanics: delegation syntax, file paths, any shell (folder creation, date stamps —
   watch BSD-vs-GNU `date` portability), `Workflow` script `meta`/phases.
4. Update any index/registry that should list the new workflow.

**Done when:** all files exist, syntax validates, indexes updated. **Common miss:** editing a
non-canonical copy whose edits get overwritten on the next sync.

---

## Phase 5 · Verification (test end-to-end)

**Goal:** prove it runs, gates bite, and it resumes. **~30-60 min for a full test.**

1. **Dry run** with real input — the run ledger populates, outputs land, the right stances spawn.
2. **Watch execution** — outputs land in the right place; parallel gates actually run in parallel.
3. **Test the gates** — force a failing case; confirm a blocking gate *stops* the flow.
4. **Test edge cases** — an override, a missing input, an agent reporting a blocker, a resume
   after interruption (the ledger is the anchor).
5. **Iterate** until a clean full run completes and someone else could invoke it.

**Done when:** one clean end-to-end run, gates verified to block, edge cases handled, a second
person could invoke it. **Common miss:** declaring done after the file is written but before a
full run — where the syntax errors and unclear steps surface.

---

## Reuse & evolution

- A new reusable pattern → add it to `../references/command-patterns.md` (versioned).
- A standard worth enforcing across the **engineering** pipeline → harvest it into
  `ac-pipeline` as (or under) an axiom — dedup first, it may already be there.
- Worked, project-specific instances of this whole process live in `../references/examples/`
  (illustrative, not doctrine).
