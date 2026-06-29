---
name: ac-pipeline-builder
description: The engineering-pipeline doctrine — the canonical design of how work goes from idea to shipped (stage order, each stage's contract, the cross-cutting invariants, and the standards for changing the pipeline). Read/maintain this when DESIGNING or EVOLVING the pipeline itself; the runtime conductor (ac-loop) and humans consult it for order + gates. Triggers: "pipeline architecture", "how should the pipeline work", "change/add a pipeline stage", "pipeline standards", "pipeline design", "ac-pipeline-builder". NOT for running the pipeline (that is ac-loop) or executing one stage (that is the stage's own skill).
---

# Pipeline Builder — Engineering Pipeline Doctrine

The **design reference** for the ac-* engineering pipeline. This is the map, never the
territory: it owns *stage order, each stage's contract, and the cross-cutting invariants*
— **not** how any stage executes (that lives in the stage's own skill). Small by design.
The engineering-pipeline parallel to `context-engineering` (the context/memory doctrine).

---

## First principles (why the factory is designed this way)

These axioms are the root — every stage contract, invariant, and standard in this document
is a downstream consequence of one or more of them. When a proposed change feels wrong,
check which axiom it violates.

### The four axioms

**1. The bead is the atom.**
All work, all findings, all state is a bead — never prose, never session memory. Findings
file immediately, like failing tests; beads are the source of truth once created; one bead
per fingerprint, no cold trails. The whole factory is a bead-transformation engine:
intake → refine → implement → ship → observe → repeat.

**2. Humans own intent; the factory owns execution.**
The human decides *what* and *why* — strategy, plans, priorities, taste, destructive moves.
The pipeline decides and does *how*. The boundary is explicit and defended: scope contracts
(ac-loop), "strategy guides pipeline not the reverse" (ac-align), human-gated approvals
(ac-plan-init), human-gated compounding (ac-land), and front-of-funnel left to direct
invocation. Breaking this boundary in either direction is a design flaw.

**3. Altitude separation: thinking ≠ doing.**
The orchestrating agent decides and *is* the quality gate; spawned sub-agents do the work.
The conductor maintains altitude — overview, synthesis, gate-judgment — while engineers
have depth. "YOU synthesize, explorers find" (ac-plan-init). "YOU review, engineers
implement" (ac-implement). "YOU synthesize, engineers fix" (ac-review). The moment a
conductor starts digging, it loses the vantage to decide — that is a *system design error*
with predictable failure modes: scope creep, gate drift, context collapse.

**4. The line is a loop — every cycle compounds.**
Two loops run simultaneously at different scales:

**Outer loop (product compounds):** distribute → listen back → bead → plan → implement → ship.
"Listen back" has three inbound channels, all converging to beads:
- *Machine signal* (ac-triage): crashes, errors, logs — Sentry, Supabase, PostHog; automated, scheduled
- *In-session signal* (ac-bead-capture): ideas and bugs handed in conversation
- *Staged ideas* (ac-backlog): parked, not yet ready for planning; surfaces when the timing is right

**Inner loop (factory compounds):** session → land (reflect) → dream (synthesis across sessions)
→ better skills + memory → next session is faster. The factory eats its own output.

Most factories only design the outer loop. Explicitly designing the inner loop is the
compounding advantage. Shipping collects the return from the outer; landing collects it
from the inner.

---

### The eight through-threads

These laws recur across every stage. When a proposed pipeline change violates one,
re-examine the change — not the law.

| Law | Evidenced by |
|---|---|
| **State lives on disk; absence of artifact = gate never ran.** Progress files are compaction recovery; resumable by design. Silence is not "nothing happened" — it is evidence the gate was skipped. | ac-plan-init, ac-implement, ac-review, ac-hygiene, ac-land, verification-gate |
| **Gates are accountability handoffs, not checkpoints.** Demand a fresh artifact, not a memory. A bug caught at review means implement let it through; a bug caught at merge means review was insufficient. Gates reveal *where the failure originated* — that is why they must be hard and artifact-verified. | ac-pipeline-builder, ac-merge, ac-implement, ac-distribute |
| **Exhaust before escalating; escalate once, batched.** Auto-apply consensus + clear technical fixes; conductor triages before the human; only irreducible design/taste/strategy forks go up, once. | ac-review, ac-hygiene, ac-land |
| **Proportional effort: incremental in the loop, exhaustive at the boundary.** Affected-only during dev; green-main makes this sound; "don't invent issues, finish early if clean." (See Invariant 2 for the full per-surface table.) | verification-gate, ac-hygiene, ac-human-session |
| **You can't self-validate — confidence requires independence.** The agent that did the work cannot fully review it; the model that found a bug can rationalize it away. Independent agents/models, same-round and cross-round consensus, is the only reliable signal. | ac-review, ac-hygiene, ac-plan-refine |
| **One concern, one home; compose, don't duplicate.** "Don't reimplement the bead side." "Three skills, three concerns — don't merge them." Doctrine = map not territory. | ac-triage, ac-distribute, ac-pipeline-builder |
| **Fail safe; never silently destroy — and leave no live debris.** Idempotent ops; confirm before archive/move/delete; abort always available; never chain `br close` to a commit. **Every background waiter you spawn needs a hard cap (`for`/`seq`, `timeout`) — never an unbounded `until`; a waiter that can't time out is a future zombie.** This binds at the moment you *write* the loop (a stage-authoring constraint), not only at teardown. | ac-tidy, ac-align, ac-merge, ac-implement, ac-land, ac-loop |
| **Minimize WIP; prefer nearest-to-done.** Single active wave; nearest-to-ready first; a half-shipped bead has zero compound value. | ac-implement, ac-human-session, ac-loop |

---

### The tensions the factory deliberately holds

Sophistication is balancing opposites. Each tension has a named mechanism that resolves
*where the balance sits* — not which side wins.

- **Autonomy ↔ human judgment** → *Exhaust Rule*: resolve all the agent can; human-gate only the irreducible.
- **Velocity ↔ safety** → *Incremental loop + exhaustive boundary*: cheap fast feedback, one authoritative gate.
- **Momentum ↔ correctness** → *Single wave + hard gates*: keep moving, but never on faith.
- **Compound aggressively ↔ protect identity** → *Never auto-apply system/identity changes*: ac-land is the one human-gated stage — the factory can't improve itself without the human owning that step.

---

## Two conductors, one chain

- **`ac-loop` = the machine.** The single runtime conductor. Selects work (orphans → plan
  waves), runs the back-of-funnel chain, handles ARIA / Slack / scheduling / stop-conditions.
  Works both headless (scheduled) and interactive (terminal). Consults this doctrine for
  order + gates.
- **`ac-pipeline-builder` = the blueprint.** This file. Design, audit, evolve the pipeline.

**Front of funnel is human-gated — no conductor.** `align → next → plan-init → beadify`
are decisions about *what enters the pipeline*; invoke those stage skills directly. The
conductor only drives the mechanical back of the funnel — the front is human-gated because
errors in *intent* are an order of magnitude harder to correct than errors in *execution*.
A bug in code costs a bead; building the wrong thing costs a wave.

---

## The canonical chain

```
   (human-gated, invoke directly)            (conducted by ac-loop)
ac-align → ac-plan-init → ac-beadify ┃ implement → verify → review → merge → land
```

| Stage | Owns | Gate to advance | Skill |
|-------|------|-----------------|-------|
| Align & Select | pipeline reconciled with strategy; `pool → active` promoted; next item chosen | no orphaned/missequenced work; one item picked | `ac-align` |
| Plan | an approved plan file | `_plans/…` exists + signed off | `ac-plan-init` |
| Beadify | beads from the plan | `br` shows the wave | `ac-beadify` (+`ac-bead-refine`) |
| **Implement** | code + per-bead **affected** tests; safety-push at session end | per-bead gate green | `ac-implement` |
| **Verify** | gate-selected ui-polish / QA at selected depth | selected passes PASS; no open `qa-blocker` | `_shared/verification-gate.md` |
| **Review** | code correctness; blocking findings | VERDICT: APPROVED | `ac-review` |
| **Merge** | rebase → **full `test:all` post-rebase (local)** → version bump → push → PR → CI-confirm → merge → tag | green + checks pass | `ac-merge` |
| **Land** | close stragglers · session teardown/cleanup · reflect/compound | session closed cleanly | `ac-land` |

---

## Invariants (load-bearing structural decisions)

> Through-threads are universal — they apply to any pipeline. Invariants are specific structural choices *this* pipeline made, each with an explicit justification. Change an invariant here first; then bring stage skills into conformance.

1. **Green-main.** The full suite passes at the merge gate → main is always green → every
   branch starts green → **affected-only runs are sound during the branch's life** (the only
   thing that can be red is what this branch touched). The single full run at merge is what
   *makes the cheap runs valid* — it is the keystone, not mere dedup.

2. **Incremental in the loop; exhaustive once, at the boundary, on shipping code.** Every
   validation surface follows this shape:

   | Surface | In the loop (incremental) | Exhaustive once, at… |
   |---|---|---|
   | Unit tests | `vitest-affected` (per-bead) | **merge**, post-rebase, local |
   | Browser QA | affected journeys / smoke (verify gate) | **merge** (full crawl) |
   | Device QA | smoke iff native-touched (verify gate) | **`ac-distribute`** |
   | ui-polish | scoped to changed surfaces | release boundary (whole-app) |
   | Build | deferred per-bead | **merge** (shipping code) |
   | Format | per-bead scoped | **land** (repo-wide sweep, own commit) |
   | type-check / lint | every gate — *cheap, exempt* | n/a |

3. **Post-rebase truth.** The exhaustive run tests the *rebased* code (your changes + latest
   main = what actually ships), never the isolated branch. So it runs **after** the rebase.

4. **In-session catch; CI confirms.** The exhaustive run is **local at merge** so the agent
   that did the work fixes failures with full context. CI (where it exists) is the *hermetic
   backstop* — a clean-env confirm + un-fudgeable gate, not the debug loop. Reality today:
   only **body-compass-app** has a live CI full-test gate (self-hosted macOS); ASA + the rest
   rely on the local merge run. So: **local-at-merge is universal; CI confirms where present.**

5. **Verify = selection, not caching.** The verification gate reasons *forward* from the diff
   (which passes can this change affect?), it does not cache results. No SHA-keyed
   verification-ledger — deliberate placement beats fragile memoization. (Failure mode of
   selection is wasted work; failure mode of caching is a shipped bug.)

6. **Land is last.** Closure/cleanup/reflect happen *after* merge (a richer retrospective —
   it can see the merge too; cleanup can tear down resources merge still needed). **Push is
   merge's job**; implement does a thin safety-push per session so multi-session waves never
   strand work.

7. **Orphans before prep.** The orphan "maintenance wave" (ready fixes) ships before any
   expensive prep (`ac-beadify`/`ac-bead-refine`) for the next feature wave.

---

## Branch policy (the single rule)

**Only code changes live on wave branches. Everything else commits directly to main.**

| Work type | Branch | Who manages it |
|---|---|---|
| Code — implement → verify → review → merge | `wave/NNN` | ac-loop only |
| Plans, docs, backlog, bead captures | `main` — always | No branch, ever |

Wave branches protect main from in-progress code and make the green-main invariant hold. That protection is code-specific — plans are markdown, they can't break a test. Branching for docs creates two parallel histories that need reconciling and is the source of the "simultaneous plan session created another branch" problem.

**Enforcement:**
- `ac-loop` is the sole branch manager — only it creates, checks out, and merges `wave/NNN`
- `ac-plan-init` and `ac-plan-refine-*` switch to main in Phase 0 before any git operation
- No other skill creates or checks out branches

---

## Coordination & identity (how sessions don't collide)

The pipeline shares one checkout (no worktrees), so concurrent work is kept safe by **identity-scoped file reservations**, not branch isolation. Two invariants govern it:

- **Identity is minted at the top-level invocation and inherited by everything it spawns.** One
  Agent Mail name per invocation (an `ac-loop` run · a human `/ac-command` · a casual editor
  session); all its sub-stages and subagents share it. The **reservation lock is grained at the
  identity**, so the protection boundary is the *invocation* — two invocations exclude each
  other; *inside* one, there is no lock granularity, so **the conductor serializes writers**
  (ac-implement is one-bead-at-a-time). To parallelize, spawn a *separate invocation* (its own
  identity), never a second writer under one name. Full contract: `_shared/agent-identity.md`.
- **Enforcement is edit-time, not just commit-time.** Reservations are advisory; the
  global `PreToolUse(Edit\|Write)` guard blocks editing a file held by a *different* identity
  before the write lands (fail-open), with the pre-commit guard as the commit-time backstop.
  Private scratch (`$ARTIFACTS_DIR`) is keyed deterministically, never guessed: `_shared/run-id.md`.

> Worktrees are deliberately rejected (filesystem multiplication, cross-worktree edits corrupt
> state — `jef-flywheel` lesson 21). Single checkout + identity reservations is the chosen model.

---

## Standards for changing the pipeline

- **Edit the spec first.** Change the chain *here*, then bring the stage skills into
  conformance — never the reverse.
- **One runtime conductor.** `ac-loop`. Don't grow a second. If a stage's order changes, it
  changes here once; the conductor reads it.
- **Stay thin / map not territory.** This doc names stages and gates; it never restates a
  stage's internal logic. Selection logic lives in `_shared/verification-gate.md`; QA method
  in `_shared/qa-shared.md`; session teardown in `_shared/session-teardown.md`.
- **Naming.** `ac-*` = the pipeline family; `-builder` = the doctrine/method meta-skill
  (cf. `skill-builder`, `agent-builder`).

---

## Conformance status (stage skills vs this spec)

The doctrine is the target; these stage edits bring reality into line:

- [x] **Verify gate** — `_shared/verification-gate.md` built; `ac-loop`/`ac-pipeline`/`ac-merge` consult it.
- [ ] **Land after merge** — re-order `ac-loop`; retire old `ac-pipeline` runtime conductor.
- [ ] **Land refocus** — strip 1b `test:all` + 1c UI suite; add scoped `_shared/session-teardown.md`; reassign push to merge.
- [ ] **Test placement** — `ac-implement` final → affected; `ac-merge` full `test:all` → post-rebase, local.
- [ ] **QA placement** — retire `ac-land` 1c; one exhaustive browser crawl at merge.
- [ ] **Conductor dedup** — old `ac-pipeline` → this doctrine; `ac-loop` sole runtime conductor.

---

## Pointers

- Runtime conductor: `ac-loop/SKILL.md`
- Stage skills: `ac-align` · `ac-plan-init` · `ac-beadify` · `ac-bead-refine` · `ac-implement` · `ac-review` · `ac-merge` · `ac-land` · `ac-distribute`
- Shared method: `_shared/verification-gate.md` (selection) · `_shared/qa-shared.md` (QA how) · `_shared/session-teardown.md` (cleanup)
- Context/memory doctrine (sibling): `context-engineering`
