# Command Patterns — the library

Reusable patterns for orchestrated command workflows (content **and** code). Loaded on demand
from `../SKILL.md` Phase 3. Engineering-specific forms of several patterns are hardened axioms
in `ac-pipeline` — those are cross-referenced, not restated.

**Contents:** 1 Run ledger · 2 Phase skeleton · 3 Orchestrator role · 4 Delegation
· 5 Quality gates · 6 Deferred decisions · 7 Output conventions · 8 Flexibility · 9
Troubleshooting · 10 Finalization · Anti-patterns.

---

## 1 · Run ledger first (mandatory)

Every non-trivial workflow opens by declaring a **run ledger** with `TaskCreate` — the run's
own progress, made legible and resumable.

```
TaskCreate — one task per high-level phase (5-7 max):
  subject: "<phase>"   status: pending   metadata: {phase: N}
  dependencies: addBlockedBy for sequencing
TaskUpdate each: pending → in_progress (phase start) → completed (phase exit).
```

**Why:** prevents early exit, gives an at-a-glance "where is the run now", and is the resume
anchor after compaction/interruption.

**The ledger tracks the RUN, never the work items.** It holds phases/iterations only. Work
items live in their own store — a `plan.md`, a task file, or (in a bead-native code repo) the
bead board, which stays the single source of truth for *what* ships (`ac-pipeline`
axiom 1, *the bead is the atom*). Never copy work-item state into the ledger, or the two drift.
*Live reference instance:* `ac-loop` Phase 0.

---

## 2 · Phase skeleton (5-7 phases)

```
Phase 0  Initialize     run ledger + folder/branch/setup
Phase 1..N  Core work    (research → produce → check)
Phase N  Quality         parallel/classifier gates
Phase N+1  Finalize       report + verification/teardown
```

Each phase: an enter line (`TaskUpdate → in_progress`), the steps, an exit line
(`→ completed`). Include a duration estimate if a human waits on it (content); it matters less
for headless runs. **Never 12+ micro-phases** — context-switching overhead, hard to track.

---

## 3 · Orchestrator, not executor

The general form of `ac-pipeline`'s *altitude separation* axiom. The command runs as
**conductor**: coordinate agents, synthesize, judge gates, decide tactically, complete the
run. It does **not** write the content/code itself, skip gates, or exit early. Put a short
reminder at the end of every command file.

---

## 4 · Delegation (stance + skill, parallel by judgment)

Delegate work to a **stance**, loading the relevant **skill** for domain depth — never mint a
per-workflow agent (fat skills, thin agents; one shared registry).

```
researcher  — gather & distill, read-only        (Phase 1, fact-checks)
implementer — produce the artifact                (the core work)
validator   — adversarial check vs a rubric, RO   (quality gates)
```

**Sequential** when later work needs an earlier output or a decision sits between steps.
**Parallel** when steps are independent — spawn them in one message (or one `Workflow`
fan-out). Parallelism is a **judgment, not a blanket rule**: independent items → concurrent;
a dependency chain → sequential. Pull heavy sub-steps (e2e, prod-build, long renders) out into
their own gated, pace-able step rather than hiding them inside one agent.

For *deterministic* structure (known fan-out, N-way gates, loop-until-done, per-item
pipelines) use the **`Workflow` tool** instead of prose delegation.

---

## 5 · Quality gates — blocking vs warning, classifier over battery

Tag every gate:
- **Blocking** — STOP, fix, re-run until PASS (tests, build, voice/brand, fact-check, security).
- **Warning** — note and continue (suggestions, optimizations, future enhancements).

Prefer a **classifier-gate**: inspect the diff/output and run **only** the checks it warrants,
at the right depth — not a fixed unconditional battery. (Engineering instance:
`ac-pipeline/references/verification-gate.md`, which classifies the wave diff and runs only
the selected passes.)

Run independent gates in **parallel**; dependent gates sequential. A validator reports `PASS`
or concrete issues; on issues, fix and re-run only what failed (don't re-run the whole battery
to answer a cheap "is this a flake?" — re-run the one failing unit).

---

## 6 · Deferred decisions (never block a long run)

A long autonomous run must not stall on a decision. Two paths:
- **Simple, bounded fork** (≤3 options, answerable in a few words) → an in-line prompt
  (`AskUserQuestion`) — interactive sessions only; headless runs defer instead.
- **Anything else** → **defer it**: record the decision as a durable item the human clears
  later (a deferred-decision note; in the eng pipeline, a *decision bead* — the **Exhaust
  Rule** in `ac-pipeline`), and keep moving.

Never convert an open-ended decision into a blocking mid-run question.

---

## 7 · Output conventions

**Timestamped per-topic folder** for content workflows:
```bash
TS=$(date +%Y-%m-%d-%H%M); SLUG="kebab-topic"
FOLDER="<base>/${TS}-${SLUG}"; mkdir -p "$FOLDER/<subdirs>"
```
Self-organizing, easy archival, no filename clashes. Watch BSD-vs-GNU `date` portability.

**Consolidated source of truth** — one `plan.md` that each phase appends to (content), or the
bead board (bead-native code repo). Avoid scattering state across `patterns.md` /
`dependencies.md` / etc. unless the user asks.

---

## 8 · Flexibility & overrides

Every command documents how the user can adapt it: skip a phase, run a quick version, change
structure mid-run. Show 2-3 concrete override examples and trust the user's context. (For an
autonomous loop, overrides are deliberately minimal — usually just stop/pause.)

---

## 9 · Troubleshooting

Every command lists common failure → resolution: agent reports a blocker; a gate fails; a push
silently no-ops; missing input; the user rejects a plan/output; a build/deploy fails; a resume
after interruption. Map each to a concrete action so a run isn't stranded.

---

## 10 · Finalization (always)

Every exit path ends in a finalize phase: report what shipped, verify it, and **tear down**
(kill spawned tasks, release any coordination locks/identities, assert a clean tree). A run
that produces output but never finalizes leaves zombies and strands lessons. (Engineering
instance: `ac-land` as the loop's single closing ritual.)

---

## Anti-patterns

| Anti-pattern | Fix |
| --- | --- |
| No run ledger | Mandatory `TaskCreate` first step |
| 12+ micro-phases | 5-7 meaningful phases |
| Orchestrator does the work | "Conductor not musician" reminder |
| Sequential when independent | One message / one fan-out = parallel |
| Fixed gate battery every run | Classifier-gate: run only what's warranted |
| Gate doesn't actually block | Explicit STOP + re-run-until-PASS |
| Blocking the run on a decision | Defer it (deferred-decision record) |
| **Per-workflow dedicated agent** | **Stance + loaded skill; one shared registry** |
| No troubleshooting / overrides | Always include both tail sections |
| No finalize/teardown | Always finalize; tear down on every exit path |

> **Note on the old "agent duplication" pattern:** earlier PAI guidance recommended a
> dedicated agent per workflow (`newsletter-reviewer`, `build-reviewer`). That is now an
> **anti-pattern** — it contradicts *fat skills, thin agents, one shared registry*. Use a
> stance with the right skill loaded.

---

**Pattern evolution:** when a new pattern proves out, add it here (versioned). If it's an
engineering-pipeline standard, harvest it into `ac-pipeline` instead — dedup first.
