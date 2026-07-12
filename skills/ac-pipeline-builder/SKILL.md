---
name: ac-pipeline-builder
disable-model-invocation: true
description: 'The engineering-pipeline doctrine — the canonical design of how work goes from idea to shipped (stage order, each stage''s contract, the cross-cutting invariants, and the standards for changing the pipeline). Read/maintain this when DESIGNING or EVOLVING the pipeline itself; the runtime conductor (ac-loop) and humans consult it for order + gates. Triggers: "pipeline architecture", "how should the pipeline work", "change/add a pipeline stage", "pipeline standards", "pipeline design", "ac-pipeline-builder". NOT for running the pipeline (that is ac-loop) or executing one stage (that is the stage''s own skill).'
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
- **`ac-tidy` / `ac-align` = the scheduled propose-half.** Both gain a headless mode (nightly
  tidy, weekly align REVIEW) that *emits proposals* (dream-style `human-gate` beads) on a
  schedule without executing intent-bearing writes. This is a disciplined split of a single
  stage: the *propose* half is schedulable; the *apply* half stays human-gated.

**Front of funnel is human-gated — no conductor for apply.** `align → plan-init → beadify`
are decisions about *what enters the pipeline*; invoke those stage skills directly for any
write. `ac-tidy` and `ac-align` now have a scheduled *propose* pass (headless, emits
`human-gate` proposal beads, no writes) — that half runs on a schedule. The *apply* half
(archiving, `pool → active` promotion) stays human-gated: errors in *intent* are an order of
magnitude harder to correct than errors in *execution*. A bug in code costs a bead; building
the wrong thing costs a wave.

---

## The canonical chain

```
   (human-gated, invoke directly)            (conducted by ac-loop)
ac-align → ac-plan-init → ac-beadify ┃ implement → verify → review → merge → land
```

(†) `ac-tidy` and `ac-align` also have a scheduled *propose* pass that runs headless before
the human-gated apply; the chain above shows the apply half, which stays human-gated.

| Stage | Owns | Gate to advance | Skill |
|-------|------|-----------------|-------|
| Align & Select | pipeline reconciled with strategy; `pool → active` promoted; next item chosen | no orphaned/missequenced work; one item picked | `ac-align` |
| Plan | an approved plan file | `_plans/…` exists + signed off | `ac-plan-init` |
| Beadify | beads from the plan | `br` shows the wave | `ac-beadify` (+`ac-bead-refine`) |
| **Implement** | code + per-bead **affected** tests; safety-push at session end | per-bead gate green | `ac-implement` |
| **Verify** | gate-selected ui-polish / QA at selected depth | selected passes PASS; no open `qa-blocker` | `_shared/verification-gate.md` |
| **Review** | code correctness; blocking findings | VERDICT: APPROVED | `ac-review` |
| **Merge** | rebase → **affected tests (local)** → version bump → push → PR → CI-confirm → merge → tag | affected green + checks pass | `ac-merge` |
| **Land** | close stragglers · session teardown/cleanup · reflect/compound | session closed cleanly | `ac-land` |
| **Publish** *(manual, post-loop)* | SHA-pinned full-CI read + full device/browser QA + migration expand/contract → ship web + native | green-for-this-SHA + QA pass + migration-safe | `ac-publish` |

> **Publish is NOT part of the autonomous loop.** The loop ends at Land; `ac-publish` is a separate,
> **human-triggered** release gate (parallel-execution doctrine §6) — Craig decides when production
> ships. It reads the loop-close full `test:all` (fired by `ac-land`) SHA-pinned to `main`; it never
> bumps (that is `ac-merge`'s sole ownership) and never re-runs affected tests.

---

## The three operational loops

Axiom 4's outer loop (product compounds) decomposes operationally into **three concurrent
loops at different cadences and altitudes**. All three converge on beads (axiom 1) and are
consumed by the same single conductor (`ac-loop`) — they differ in *what puts work on the
board* and *how often*.

| Loop | Altitude | Cadence | Puts work on the board via | Skills |
|---|---|---|---|---|
| **1 · Dev loop** | Build what we decided to build | Continuous (per human session / loop run) | human intent: strategy → plans → waves | `ac-align → ac-plan-* → ac-beadify` ┃ `ac-loop` conducts implement → verify → review → merge → land |
| **2 · Triage loop** | Fix what reality reports | Scheduled daily (≥30 min before any loop run) | production signal: Sentry, TestFlight/ASC feedback, feedback reports (Supabase logs, PostHog, store reviews — planned) → defect beads / backlog candidates | `ac-triage` (inbound counterpart of `ac-distribute`) |
| **3 · Audit loop** | Harden what we built | Periodic, human-triggered today (target: recurring — cadence TBD) | proactive senior-engineer sweeps: severity-scored findings → beads (epic → child beads, per the `ac-hygiene` pattern) | `audit` (security · performance · tests · qa · ui) + `ac-hygiene` (reuse/simplification) |

- **Loop 1 is intent-driven** (the human decides what), **loop 2 is reactive** (users and
  production decide what), **loop 3 is proactive** (the standard decides what — resilience,
  reliability, security, performance beyond any single wave's scope).
- **Find-and-file is the default.** Triage and audit *find and file* (beads with severity +
  source labels); the dev loop ships the fixes. One sanctioned exception: `ac-hygiene`
  auto-applies bounded cleanups (its severity/consensus rules) on a `hygiene/*` branch,
  merged behind the full quality gate + CI; everything else it finds becomes a per-run
  epic of beads.
- The **inner loop** (axiom 4: land → reflect → dream) is orthogonal to all three — it
  improves the *factory*, not the product. `ac-registry-audit` belongs to the inner loop
  (it audits the skill corpus, not app code).
- Housekeeping (`ac-tidy`) is not a fourth loop — it keeps the board itself clean so the
  three loops read true state.

---

## Invariants (load-bearing structural decisions)

> Through-threads are universal — they apply to any pipeline. Invariants are specific structural choices *this* pipeline made, each with an explicit justification. Change an invariant here first; then bring stage skills into conformance.

1. **Green-main.** A **trustworthy** affected-runner (`vitest-affected`, post fixture-cascade
   upgrade) + a full suite at **loop-close** keep main green: each loop starts from a
   loop-close-green main, every branch starts green, and **affected-only runs are sound during the
   branch's life** (a trustworthy affected set covers everything the branch could break). The
   keystone is the *pairing* — trustworthy affected per wave **plus** one full run at loop-close
   (relocated off the per-wave path, parallel-execution doctrine §5); `ac-publish` reads that full
   run SHA-pinned as the final backstop. **If the affected runner is NOT trustworthy this inverts** —
   the full run must move back onto the per-wave (merge) path.

2. **Incremental in the loop; exhaustive once, at the boundary, on shipping code.** Every
   validation surface follows this shape:

   | Surface | In the loop (incremental) | Exhaustive once, at… |
   |---|---|---|
   | Unit tests | `vitest-affected` (per-bead + per-wave) | **loop-close** (CI `workflow_dispatch`, async) |
   | Browser QA | affected journeys / smoke (verify gate) | **publish** (full crawl) |
   | Device QA | smoke iff native-touched (verify gate) | **publish** |
   | ui-polish | scoped to changed surfaces | release boundary (whole-app) |
   | Build | deferred per-bead | **merge** (shipping code) |
   | Format | per-bead scoped | **land** (repo-wide sweep, own commit) |
   | type-check / lint | every gate — *cheap, exempt* | n/a |

3. **Post-rebase truth.** The exhaustive run tests the *rebased* code (your changes + latest
   main = what actually ships), never the isolated branch. So it runs **after** the rebase.

4. **In-session catch; CI confirms.** The exhaustive run is the **async loop-close CI run**
   (Invariant 1), relocated off the per-wave path so it never blocks a merge. The in-session/
   local principle still governs what actually runs *in* the loop — affected tests + smoke QA
   at merge, fixed with full context by the agent that did the work. Reality today: only
   **body-compass-app** has a live CI full-test gate (self-hosted macOS); ASA + the rest have
   no loop-close CI path yet and fall back to a local full run there instead. So:
   **exhaustive-at-loop-close is universal; CI executes it where present, local fallback where
   not.**

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

8. **The branch is the merge unit; gate on the full diff, not authorship.** In a batched,
   multi-agent flow most legitimate changes on a branch were **not** authored by whoever merges
   it — concurrent sessions share the checkout, and a scheduled job (triage, an ops fix) commits
   onto whatever branch happens to be checked out. So a merge **includes the whole branch by
   default** and validates it *as a unit*: CI + full-diff review + secret-scan are the gate —
   never "did I make this change." **Exclusion is a positive, logged exception**, triggered by a
   real signal (a `WIP`/`DO-NOT-MERGE` marker, a CI failure, a gitleaks hit, or an explicit
   scope conflict) — never a hunch about authorship. And **surface, don't silently decide**: the
   PR body must name the cross-cutting changes the branch carries beyond its headline scope (an
   `.env`/secret edit, a migration, a foreign commit from another session) so a human sees what
   actually shipped. *Rationale — the asymmetry:* excluding a good change loses **recoverable**
   work (it's still on the branch, the author notices); including a bad change ships a **defect**
   silently. That asymmetry is defused by the gate + the visible manifest, **not** by trusting
   authorship — which is why include-by-default is correct only when paired with a real gate and
   a surfaced manifest. Binds `ac-merge`, `ac-hygiene`, `ac-review`, `ac-loop`.

9. **Runtime proof over static presence.** Every app maintains a journey registry
   (`CORE/journeys/*.md` frontmatter) naming its critical surfaces, each with a
   criticality tier and required proof class. QA passes write journey-level PASS stamps
   (build + SHA + date); gates consume stamps mechanically — the merge smoke selects
   journeys by diff-class × criticality, and **no store submission proceeds with a
   stale or missing stamp on a `review-critical` journey**. Static checks (dep
   installed, chunk bundled, key baked, plugin registered) are necessary but never
   sufficient; the only sufficient evidence for a critical surface is a fresh drive of
   its journey in the environment users experience. *Rationale:* all five layers of the
   BCA 2.1(b) chain passed every static check; verification debt that lives only in
   prose is decoration (the system tracked "live walk pending" through four App Store
   rejections and nothing read it). Schema + selection rules:
   `_shared/verification-gate.md` §Journey registry. Binds `ac-qa-device`,
   `ac-qa-browser`, `ac-merge`, `ac-distribute`, `ac-publish`, `ac-hygiene`,
   `ac-dashboard`.

---

## Cross-cadence schedule (the single home for scheduling rules)

Several stages also run **headless, on a schedule**, independent of any single pipeline
invocation. Their cadences are cross-cutting (they interleave with every wave in flight),
so this table is the **single home** for "when does X run" — consumers (job configs, stage
skills) point here rather than restating times in more than one place.

| Job | Cadence | Mode | Skill |
|---|---|---|---|
| Curator | Daily ~23:00 | scheduled run (ingredient review/amend) | `curate` |
| Tidy | Nightly ~00:45 (after the 00:30 maintenance job) | NIGHTLY — propose + bounded auto-act | `ac-tidy` |
| Align | Weekly, Saturday ~06:00 | REVIEW — propose only, no writes | `ac-align` |
| Dream | Weekly, Sunday ~05:00 | CYCLE — propose only, no writes | `dream` |
| Triage | Must fire **≥30 min before** any `ac-loop` run | scheduled, feeds beads ahead of shipping | `ac-triage` |
| Hygiene | Weekly per active repo (manual until the first monitored run signs off scheduling) | 7-lens panel; fixes commit direct to `main` (trunk-direct), close via `ac-batch-close`; deferred → epic beads. Doubles as the standing review of `main` when no batch shipped in >7 days | `ac-hygiene` |
| Audit | **Not yet scheduled** — human-triggered today; checklists serve as reference depth behind the weekly hygiene panel | findings → beads, never fixes in place | `audit` |

**Triage-before-loop ordering** is the one cadence rule with a *hard dependency* on another
job (it must feed the board before the loop consumes it) rather than a fixed wall-clock slot.
It's enforced today at `ac-loop`'s own "Scheduling" section — decoupled on purpose so a triage
failure never blocks shipping — this table is the cross-cutting reference point for that rule;
`ac-loop` remains the owner of the enforcement mechanism.

---

## Branch policy (the single rule)

**Only code changes live on wave branches. Everything else commits directly to main.**

| Work type | Branch | Who manages it |
|---|---|---|
| Code — implement → verify → review → merge | `wave/NNN` | ac-loop only |
| Hygiene auto-fixes | `main` — always (trunk-direct) | ac-hygiene only |
| Plans, docs, backlog, bead captures | `main` — always | No branch, ever |

Wave branches protect main from in-progress code and make the green-main invariant hold. That protection is code-specific — plans are markdown, they can't break a test. Branching for docs creates two parallel histories that need reconciling and is the source of the "simultaneous plan session created another branch" problem.

**Hygiene is trunk-direct (migrated 2026-07-12, bd-u2lo1.14):** it no longer uses a
worktree/`hygiene/*` branch/PR ceremony. Its 7-lens panel IS the pre-push review, auto-fixes
commit directly to `main` as pathspec commits under the full H7 discipline (`ac-implement`
Phase 0) while it is actively editing, and the close ceremony is `ac-batch-close` (patch bump),
never `ac-merge`. The run report commits to `.claude/reviews/` root and does not advance the
`.claude/reviews/batch/` review-mark.

**Enforcement:**
- `ac-loop` is the sole branch manager — only it creates, checks out, and merges `wave/NNN`
- `ac-plan-init` and `ac-plan-refine-*` switch to main in Phase 0 before any git operation
- `ac-hygiene` creates no branch — it commits fixes directly to `main` (trunk-direct)
- No other skill creates or checks out branches

---

## Coordination & identity (how sessions don't collide)

The pipeline shares one checkout (no worktrees), so concurrent work is kept safe by **identity-scoped file reservations**, not branch isolation. Two invariants govern it:

- **Identity is minted at the top-level invocation and inherited by everything it spawns.** One
  Agent Mail name per invocation (an `ac-loop` run · a human `/ac-<skill>` invocation · a casual
  editor session); all its sub-stages and subagents share it. The **reservation lock is grained at the
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
  in `_shared/qa-shared.md`; session teardown in `ac-land` Phase 4 (a shared
  `_shared/session-teardown.md` is *planned* — see the conformance checklist, not yet built).
- **Naming.** `ac-*` = the pipeline family; `-builder` = the doctrine/method meta-skill
  (cf. `skill-builder`, `agent-builder`).

---

## Conformance status (stage skills vs this spec)

The doctrine is the target; these stage edits bring reality into line:

- [x] **Verify gate** — `_shared/verification-gate.md` built; `ac-loop`/`ac-pipeline`/`ac-merge` consult it.
- [x] **Land after merge** — `ac-loop` already runs `ac-implement → VERIFY-GATE → ac-review → ac-merge`, land once at exit; old `ac-pipeline` runtime conductor retired via deprecation banner (this sweep, 2026-07-03).
- [ ] **Land refocus** — strip 1b `test:all` + 1c UI suite; add scoped `_shared/session-teardown.md`; reassign push to merge. (tracked: Wave B plan — land refocus — restructure, not sweep)
- [x] **Test placement** — `ac-implement` final → affected; `ac-merge` post-rebase → affected only (no `test:all` at merge). (done 2026-07-05: AGENTS.md pre-merge row → `pnpm test`; ac-merge rebase-before-gate; ac-implement baseline reads loop-close CI)
- [ ] **QA placement** — retire `ac-land` 1c; one exhaustive browser crawl at publish. (tracked: Wave B plan — land refocus — restructure, not sweep)
- [x] **Conductor dedup** — old `ac-pipeline` → this doctrine (deprecation banner added); `ac-loop` confirmed sole runtime conductor (this sweep, 2026-07-03).
- [x] **Journey registry + stamp gates (Invariant 9)** — schema + selection in `_shared/verification-gate.md` §Journey registry; QA twins write `last_pass` stamps; `skills/_tools/journey-stamp-check.sh` gates store submissions via `ac-distribute`; `ac-publish` 1b refreshes stamps; dashboard/human-session surface journey debt; anti-pattern lenses in `_shared/anti-patterns.md` (wave 2026-07-07). App-side journey tagging: BCA first, then siblings (plan §6 step 9 — in progress).

---

## Pointers

- Runtime conductor: `ac-loop/SKILL.md`
- Stage skills: `ac-align` · `ac-plan-init` · `ac-beadify` · `ac-bead-refine` · `ac-implement` · `ac-review` · `ac-merge` · `ac-land` · `ac-distribute`
- Shared method: `_shared/verification-gate.md` (selection) · `_shared/qa-shared.md` (QA how) · `_shared/session-teardown.md` (cleanup — *planned*, not yet built)
- Context/memory doctrine (sibling): `context-engineering`
