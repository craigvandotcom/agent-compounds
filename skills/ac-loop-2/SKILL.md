---
name: ac-loop-2
description: 'Phase-gated autonomous shipping loop — spec-heavy refinement at a frozen HEAD, maximally parallel gate-free implementation on a single shared tree, one batched converge phase (global checks + mechanical bisect attribution + fix-forward + sampled mutation probes), then verify/ship. Successor experiment to ac-loop (which remains the continuous-width default). Triggers: ''/ac-loop-2'', ''run loop v2'', ''phase-gated loop''.'
disable-model-invocation: true
---

# ac-loop-2 — Phase-Gated Autonomous Shipping Loop

> **EXPERIMENTAL successor to `ac-loop`.** `ac-loop` remains the default autonomous
> conductor and owns every scheduled run. `ac-loop-2` runs ONLY when a human explicitly
> invokes it (`/ac-loop-2`, "run loop v2", "phase-gated loop"). Never select it as a
> substitute for `ac-loop`, never wire it into a scheduled job without a human decision,
> and never mix the two models inside one run.

**You are the loop conductor.** You drive cycles through five phases separated by
strict barriers. Delegate every phase to a fresh spawned session and keep only the
returned summary. Do not pause at Phase 1. Headless stops at C1 before Phase 2.

**The v2 bet, in one line:** move the cost of correctness OUT of implementation (where
per-bead gates serialise a shared tree) and INTO specification (Phase 1) and one batched
convergence pass (Phase 3), so implementation can run at maximum width with no gates at all.

Headless: never `AskUserQuestion` — apply the Exhaust Rule (leave the `human-gate`
decision bead in place, post an advisory Slack nudge, keep working). Interactive:
`AskUserQuestion` is permitted only in Phase ARIA — simple bounded forks (≤3 options,
answerable in ≤10 words).

> **Scope contract.** You work the pipeline, not the backlog. You never touch raw backlog
> items (`_backlog/pool/`) or unrefined *plans*. **Every bead on the board that is not
> `human-gate` is loop-eligible** — `unrefined` routes a bead *through* Phase 1, it is NOT
> a human gate. The only class exempt from autonomous implementation is `human-gate`
> (surfaced, never auto-closed). **`cross-repo` is not an exemption.** Those IDs live on
> THIS board; the target repo's beads db does not have them. This cycle implements them.
> Workers commit in the repo that tracks the files
> (`ac-pipeline/references/commit-discipline.md` § Cross-repo skill/infra beads). Craig
> controls what *enters* the pipeline upstream (`ac-backlog`, plan `loop-ready` sign-off).

> **Orchestration contract — 3-level, non-negotiable.** Every "Invoke `<skill>`" / "Run
> `<skill>`" step means **spawn a fresh sub-session whose prompt is the delegation text,
> pinned `model: "opus"` on the spawn call**. Phase sub-sessions are conductors themselves
> (they judge and spawn workers) — opus-class, explicitly pinned, never inherited. Their
> workers keep the per-call pins in each skill's reference prompts. Never set
> `CLAUDE_CODE_SUBAGENT_MODEL` — it sits ABOVE per-call pins and silently flattens them
> (`rule-agent-mail-identity-setup`).
> **Every child delegation prompt OPENS with the Child-spawn preamble from
> `ac-pipeline/references/delegation-contract.md` § Child-spawn preamble, included
> VERBATIM** — a pointer is not sufficient (children act before they read); the pasted
> copy lives in `references/delegation-prompts.md`.
> You **never** read a phase skill's `SKILL.md` (`ac-beadify`, `ac-bead-refine`,
> `ac-implement`, `ac-batch-close`, `ac-land`, `ac-ui-polish`, `ac-qa-browser`,
> `ac-qa-device`) into your OWN context — that collapses to 2-level and bloats the
> conductor until it compacts mid-run. Orchestrator holds *decisions*; sub-sessions hold
> *skills + file contents*. If you catch yourself about to Read a phase skill, spawn instead.

---

## I/O Contract

| | |
|---|---|
| **Input** | Beads in `br` (any state from unrefined onward); loop-ready plans in `_plans/`; ONE shared checkout on `main` — **no worktrees, no branches** |
| **Output** | One pathspec-scoped commit per bead on `main`, closed beads, the phase report (`repair%` + `hollow%`), Slack notifications per phase |
| **Not in scope** | Backlog capture, plan init (`ac-plan-init`), unrefined plans, human decisions, release (`ac-publish` stays human) |

---

## Execution Order

```
RUN START (once): register identity, mint RUN_ID, sweep stale reservations, create the run ledger.

EACH CYCLE until C1 (no eligible work except human-gate):
PHASE 0 — GRAPH     (conductor, solo)
      board-scan → epic lanes (ordered, territory-disjoint) + human decision docket
   ══ BARRIER ══
PHASE 1 — SPEC      (width 5–6 · HEAD FROZEN · beads-DB writes only)
      beadify-all → refine-all → every lane bead carries an IMPLEMENTATION CONTRACT
   ══ BARRIER — print A+B; headless C1; interactive proceeds ══
PHASE 2 — BUILD     (width 6–9 · one shared tree · NO GATES)
      lane QUEUE + refill: on coordinator return, next territory-disjoint lane takes the slot
      one bead = one assignment = ONE pathspec commit
      └─ SERIAL RISK QUEUE at the phase tail: migration + native beads, locally verified
   ══ BARRIER — lane queue empty AND risk queue done ══
PHASE 3 — CONVERGE  (one batched check pass)
      global checks → bisect attribution → fix-forward (gated) → loop to green
      → sampled mutation probes → emit repair% + hollow%
   ══ BARRIER — green + metrics emitted ══
PHASE 4 — VERIFY & SHIP
      verification gate → journey stamps → beads-closed gate → ac-batch-close → Slack
      → eligible work remains? re-enter Phase 0 (do not land)
      → else C1

BYPASS LANE (any time, cuts every barrier): a P0/P1 urgent bead ships as a fully-checked solo.

STOP CONDITIONS checked at every barrier (see below).

ON EXIT — ALWAYS, every stop path (C1/C2/C3/C4, Phase ARIA, or an error): run ac-land,
then spawn reflect, then deregister. A run that ships but never lands leaves zombies and
strands every lesson in the transcript.
```

> **Barriers are strict.** No Phase-2 dispatch before Phase 1's barrier clears; no Phase-3
> check before the Phase-2 lane queue is empty and every worker has returned; no Phase-4
> pass before Phase 3 is green. A cycle ships; the run drains — Phase 4 is not exit.
> Crossing a barrier early deletes the reason the phase has no gates. The only legal
> barrier crossing is the bypass lane. A worker must never pull `br ready` for the next
> bead: refill is the next already-spec'd lane, not raw board work.

> Track the run's position in the Phase-0 **run ledger** (`TaskCreate`) — update it at every
> barrier; it is the anti-early-exit anchor and the resume point after compaction. Doctrine:
> `ac-pipeline/references/run-ledger.md` (ledger tracks the RUN, never the work). If
> TaskCreate is unavailable (subagent / fan-out path), track the ledger inline in
> progress.md; this is a sanctioned equivalent, not a deviation.

---

## Phase 0 — GRAPH

### Register, scope, sweep

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

Mint a unique identity for this run per `agent-mail/references/session-procedure.md`
(§ Mint, § Export) — capture `name` + `registration_token`. Loop-specific export:

```bash
export RUN_ID="$(date +%Y%m%d-%H%M%S)-$$"   # scopes THIS run's /tmp scratch (ac-pipeline/references/run-id.md)
```

Then sweep reservations stranded by a prior run that died before its `ac-land` teardown
(`agent-mail/references/agent-identity.md` Deregistration, Layer 3): for any hold older
than the 7200 s TTL floor, call `force_release_file_reservation` with the canonical
`neometa/<app-dir>` project key. This is a stale-**RESERVATION** sweep ONLY — never
`retire_agent`/`deregister_agent` (name-only cross-session retire is rejected at runtime,
decision `ac-ycr.8`).

### Read the board

> **Canonical scan spec: `ac-pipeline/references/board-scan.md`.** ac-loop-2 is a
> **CONSUMER** of that spec — do NOT fork the scans, and do not re-derive what "orphan" or
> "illegal edge" means. Adopt all four detectors: parentage-gap orphan (I1), authored
> epic-edge (I2 — report ALWAYS), Scan E scheduled-CI gate health, Scan F board truth.

```bash
# TRUE counts first (dependency-aware, no truncation). If these disagree with the filters
# below, trust these and debug the filter (a 20-row answer = a missing --limit 0).
bv --robot-triage 2>/dev/null | jq '.triage.quick_ref | {actionable: .actionable_count, blocked: .blocked_count, in_progress: .in_progress_count, open: .open_count}'

# Refined, non-human-gate ready beads (implementable today)
br ready --limit 0 --json | jq '[.[] | select((.labels | index("refined")) and (.labels | index("human-gate") | not))]'

# Unrefined, non-human-gate ready beads → ALL of these go through Phase 1
br ready --limit 0 --json | jq '[.[] | select((.labels | index("refined") | not) and (.labels | index("human-gate") | not))]'

# Human-gate ready beads (the only exempt class — the decision docket + Phase ARIA)
br ready --limit 0 --json | jq '[.[] | select(.labels | index("human-gate"))]'

# P0/P1 bypass candidates (see § Bypass lane)
br ready --limit 0 --json | jq '[.[] | select((.priority <= 1) and (.labels | index("human-gate") | not))]'

# Plans marked loop-ready (Craig's explicit gate — only these enter the loop)
grep -l "status: loop-ready" _plans/*.md 2>/dev/null
```

**PRINT both probe lines EVERY run, `ok`/`0` included** — a probe that is computed and not
printed reproduces the blackout it exists to catch:

- `ci-gates: <n> scheduled · <wf>=<green|red×N|unknown>(<sched-age>h) · ci_health: <ok|warn|ALARM|unknown|none>` — **`unknown` is NOT green**; it means the probe COULD NOT CHECK.
- `board-truth: <n> open bead(s) cited by a later non-bookkeeping commit — VERIFY, never auto-close` — adjudicate each flagged bead (read its `## Delivers`, check those artifacts at HEAD) **before** it enters a lane. Scan F flags only; a false STALE skips real work.

### Build the lanes

1. **Cluster orphans into synthetic epics by file territory.** Run
   `board-scan.md` § File-cluster density over the ready orphan set; each dense cluster
   becomes a **synthetic epic** for this run (a lane, not a persisted bead). Orphans citing
   no file path form one residual lane, scheduled last.
2. **Compute a territory manifest per epic** — the union of its member beads' `## Delivers`
   file lists. An epic with no computable manifest does not get a lane; it goes to the
   docket for a human to scope.
3. **Order the lanes from cross-epic BEAD edges only.** Derive inter-epic sequence from
   `blocks` edges between beads in different epics. **An authored epic→epic edge is an I2
   violation** — report it, never obey it.
4. **Enforce disjointness.** Two epics whose territory manifests overlap are **sequenced**
   (one lane after the other) or **merged under one coordinator**. They NEVER run
   concurrently. Territory disjointness is what makes Phase 2 safe without gates.
5. **Reserve at epic granularity** — one Agent Mail reservation per lane over its territory
   manifest, held by the lane coordinator. Never per-file reservations (per-file churn at
   width 9 costs more than it protects).

**Phase 0 output:** an ordered list of territory-disjoint epic lanes, plus the **human
decision docket — WAVE-SCOPED**: only `human-gate` beads that BLOCK a lane bead (a `blocks`
edge into the lane set), plus THIS run's I2 violations, un-scopable epics and `board-truth`
flags. Every other `human-gate` bead is `ac-human-session`'s standing backlog — report the
count, never dock it. A docket that grows with the board instead of with the wave is unusable.

### Create the run ledger

```
TaskCreate — one task per phase, plus one per epic lane:
  1. Phase 0 graph + docket            → in_progress
  2. Phase 1 spec (frozen HEAD)        → pending
  3. Phase 1 drain report              → pending
  4. Phase 2 build: lane <name>        → pending   (one per lane)
  5. Phase 2 serial risk queue         → pending   (omit ONLY if `br ready` has zero refined non-hg beads flagged native/migration — a BOARD count, never "none after I filtered them out of the wave")
  6. Phase 3 converge                  → pending
  7. Phase 4 verify + ship             → pending
  8. ac-land + conductor-reflect       → pending
```

If there are no beads, no loop-ready plans, and only `human-gate` beads remain → C1,
then Phase ARIA. A run that continues after Phase 4 appends the next cycle's tasks —
do not treat Phase 4 complete as run-complete.

---

## Phase 1 — SPEC (width 5–6, HEAD FROZEN)

**HEAD is frozen for the whole phase: no implementation commit lands.** Record
`FREEZE_SHA=$(git rev-parse HEAD)` in the run ledger at phase open — every anchor verifies
against it, and the Phase-1 staleness check diffs against it. Every child in this
phase writes to the beads DB only, so children are collision-free at width and the anchors
they verify cannot move under them.

1. **Beadify-all** — one child per loop-ready plan with no beads (`ac-beadify`). Plans
   parallelize unless a plan declares `depends-on:` naming an upstream plan that is not yet
   complete; a `depends-on:` naming an epic id is the deprecated form — **ERROR**, skip that
   plan's admission this pass, post an advisory nudge, never a hard stop.
2. **Refine-all** — a DRAIN over every unrefined non-`human-gate` bead (plus freshly
   beadified ones): one child per group, successive waves of `width` until the set is EMPTY.
   Width bounds concurrency, never coverage. The conductor decides ORDER, never MEMBERSHIP —
   never cut by priority, which ranks who filed a bead, not its value. Grouping, order and
   the `refine-drain` barrier assertion: **`references/refine-drain.md`**.

### The IMPLEMENTATION CONTRACT (what refinement must produce)

A bead leaves Phase 1 only when its spec carries **all six** elements. This is the whole
v2 bet: Phase 2 has no gates *because* these are true.

| # | Element | Bar |
|---|---|---|
| 1 | **Verified anchors** | Every cited `file:line` was OPENED at the frozen HEAD. An unopened citation is a fabrication. |
| 2 | **Executed baselines** | Every countable claim was RUN and its literal output pasted. A reasoned count is a failure, not a shortcut. |
| 3 | **Territory manifest** | The exact file list this bead may touch — the worker's whole write permission in Phase 2 — plus **which test tiers that territory can break**. |
| 4 | **Declared RED expectation** | "Test X added by this bead must FAIL pre-fix with approximately this error." Phase 3's mutation sampler consumes this verbatim. |
| 5 | **Sequence position + risk flags** | Position within its epic, plus `migration` / `native` / `hot-tier` / `cold-tier`. |
| 6 | **No-op-proof ACs** | Acceptance criteria adversarially checked to be **unsatisfiable by a no-op**. |

Schema (including test-tier slugs) lives in
`beads-standards/reference/bead-conventions.md` § Implementation contract —
`ac-beadify` stamps elements 3+5, `ac-bead-refine` verifies all six and
withholds `refined` if any is missing. Loop-2 consumption (freeze SHA,
mutation sampler, Phase 3 tier report): **`references/implementation-contract.md`**.

Convergence discipline carries over from `ac-bead-refine` unchanged: **execute-at-draft**
(run the command while drafting, never after), **`br lint` first**, and a final
**adversarial round** whose job is to break the contract, not to bless it.

### Phase 1 close

PRINT **(A) parallel lanes** and **(B) serial risk queue** (every refined ready
non-`human-gate` bead flagged `native`/`migration`, or territory
`ios/`/`android/`/`supabase/migrations`). Wave-blocking `human-gate`: Exhaust Rule
(leave the bead, drop dependents, keep going). HOLDs stay out. **`cross-repo` stay
in** — commit in the target repo (commit-discipline § Cross-repo). Never `minus native`.

**Interactive:** proceed. **Headless:** Slack A+B, C1 — do not enter Phase 2.

Require the **drain report** (`U > 0` names each id, skips it, continues) and the
**staleness check** (`git diff --name-only $FREEZE_SHA..HEAD` ∩ each territory →
re-refine those beads).

---

## Phase 2 — BUILD (width 6–9, one shared tree, NO GATES)

**The conductor owns the global width and the lane queue.** Phase 0's ordered list is the
queue. Hold up to `width` slots (budgets sum within the phase band). Dispatch one
coordinator per in-flight lane; a coordinator never exceeds its grant. On coordinator
return: release its territory lock, then give that slot to the next lane that is
territory-disjoint from every in-flight lane — a **fresh** coordinator (lanes are slots,
not souls). Overlapping leftovers become eligible when the conflicting sibling returns.
Phase 2 ends when the lane queue is empty AND the serial risk queue has run. Never park
a leftover lane for "the next run" while a slot is free.

Workers are **lane-sticky inside one lane** where the harness allows — a worker that
keeps its lane keeps its warm model of that territory. **One bead = one assignment =
ONE pathspec-scoped commit.** Do not pull `br ready` / `bv --robot-next` for the next
bead; that is unspec'd work and belongs in the next cycle's Phase 1.

**There are three worker rules. There is no fourth.**

- **(a) Territory.** Write only inside your bead's territory manifest. Nothing else, ever.
- **(b) COMMIT MUTEX.** Take the global commit lock around `add` + `commit` + `push`. The
  git index and the push are the ONE unavoidable collision on a shared tree.
- **(c) Trust no global signal mid-phase.** The tree is legitimately dirty with siblings'
  in-flight work. A local run scoped to your own files is permitted as advisory
  information; **it is never blocking, and a red global signal is never yours to act on.**

The commit mutex is a lock directory (`$(git rev-parse --git-common-dir)/ac-loop2-commit.lock` **of the repo
you are committing into**; `mkdir` is atomic). A `cross-repo` skill edit takes the
lock under agent-compounds (or root), not under the app checkout — two git indexes,
two locks. Bounded (480s; 240 x 2s < 600s Bash cap), stale-stealable (a lock older than 10 min belongs to a dead worker —
EXIT traps do not fire on SIGKILL), self-releasing on exit. The origin==HEAD assert runs
INSIDE the lock — after release, a sibling's commit false-fails it. **The ONE canonical
script is `references/delegation-prompts.md` § Build-worker prompt** — workers execute the
prompt, never this spine; never fork a second copy here.

**Discoveries are FILED, never fixed.** A worker that finds an adjacent defect, a missing
test, or a better shape creates an `unrefined` bead for the NEXT cycle's spec phase and
moves on. Fixing inline breaks the one-bead-one-commit invariant that Phase 3's bisect
attribution depends on — an unattributable failure costs more than the defect did.

**No test gates. No type gates. No smokes.** Not "deferred" — absent. Phase 3 owns all of it.

### SERIAL RISK QUEUE (non-negotiable carve-out)

**Migration and native beads NEVER run in the parallel body of Phase 2.** They stay
**in-cycle** and run **serially at the tail**, one at a time, each with immediate
local verification. Do not start Phase 3 while risk-set (B) is non-empty and this
queue is unrun. Compaction resume re-derives (B) from `br ready`, never from "none claimed":

| Class | Immediate verification (before the next risk bead starts) |
|---|---|
| **migration** | Local-stack RED→GREEN: apply against the local Supabase stack, prove the failing state before and the passing state after |
| **native** | Compile + simulator launch |

A broken migration poisons the shared local stack for every worker and cannot defer to
Phase 3 — by the time the batched pass runs, every downstream result is contaminated. A
risk bead that fails its immediate verification is **reverted (its own commit)** and its
bead reopened; the queue continues.

**Sequence rule:** a lane bead sequenced after a risk bead in its epic follows it to the
phase tail and runs only after the risk bead verifies — never build against a stack the
migration has not reached. The exception: a contract that explicitly declares independence
from the risk bead's effect.

---

## Phase 3 — CONVERGE (the check batch)

Every check Phase 2 skipped fires here, once, over a quiescent tree.

1. **One global pass** — tree-wide type-check, the full test suite, lint/format. Output is
   **the failure set**, not a verdict. **A green is not reportable until the phase
   report enumerates the test tiers the command covered and names the ones it
   excluded.** If any bead's `### Test-tier exposure` names a tier the standing
   pass does not run, that tier MUST be run (repo command from AGENTS.md) before
   the phase can call those beads green.
2. **Mechanical attribution.** For each failing test, `git bisect run` over the phase's
   commit range. One bead = one commit is what makes this work; there is no judgment call
   and no reading of diffs to guess an author.
3. **Fix-forward.** One repair worker per failure cluster. Repair workers **DO run per-fix
   checks** — the tree is quiescent now, so a gate here costs nothing and catches
   everything. A repair that cannot be made safe reverts its bead's commit and reopens
   the bead.
4. **Loop the global pass until green.** Cap: **2 repair loops** — a third means the phase
   cannot converge → **C2**.
5. **SAMPLED MUTATION PROBES.** Revert **~20%** of the phase's fixes (sample across lanes,
   not the cheapest), confirm each bead's **declared RED expectation** fires, restore. A
   test that stays green with its fix reverted is **hollow** — reopen its bead.
6. **Emit the two governing metrics** in the phase report:

   | Metric | Definition | Healthy | Above threshold |
   |---|---|---|---|
   | `repair%` | repair items / beads in the phase | **≤ 10%** | Tighten Phase 1's contract — the specs are not carrying their weight |
   | `hollow%` | hollow / sampled | **≤ 5%** | Tighten element 4 (declared RED) — tests are being written to pass, not to catch |

   Both are **guidance thresholds, not gates**: they steer the next cycle's spec pressure.
   Sustained breach of either is the documented signal to fall back to the
   **per-landing-check variant** for the hot tier (gates back inside Phase 2 for hot-tier
   beads only, cold tier stays gate-free).

Bisect invocation, cluster formation, sampling rule and the probe protocol:
**`references/converge-phase.md`**.

---

## Phase 4 — VERIFY & SHIP

1. **Verification gate (whole cycle diff).** Consult
   **`ac-pipeline/references/verification-gate.md`**: classify the whole cycle's diff, run
   **only** the selected passes (`ac-ui-polish` / `ac-qa-browser` / `ac-qa-device`) at the
   selected depth. **Do not re-specify the gate here** — the consult is yours, each selected
   pass is its own spawned opus-pinned sub-session. Emit the gate's decision line (which ran,
   which skipped, why) into the Slack notify. An open `qa-blocker` bead is a hard stop (C2).
2. **Journey stamps** — record the passes run and their depth against the cycle, per the
   gate's own stamp contract.
3. **Beads-closed gate** — the loop's own pre-close gate (`ac-batch-close` no longer checks
   this). Pass the UNION of identities (conductor + EVERY child identity this run), every
   bead id claimed this run, and every child progress file. Flag rationale:
   **`references/beads-closed-gate-invocation.md`**.
   ```bash
   export AGENT_NAME="$AGENT_NAME"   # re-assert in THIS call — exports don't persist across bash calls
   PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel)}"   # re-derive HERE
   ARTIFACTS_DIR="/tmp/bead-work-<claim-id>-$RUN_ID"   # the conductor's own dir (run-id.md formula)
   GATE="$PROJECT_ROOT/skills/ac-pipeline/scripts/beads-closed-gate.sh"                    # registry layout
   [ -f "$GATE" ] || GATE="$PROJECT_ROOT/.claude/skills/ac-pipeline/scripts/beads-closed-gate.sh"   # harness layout
   bash "$GATE" \
     --beads "<every-bead-id-claimed-this-run,comma-separated>" \
     --progress "$ARTIFACTS_DIR/progress.md" [--progress <each-other-child-progress.md>…] \
     "$AGENT_NAME" <delegated-identities…>
   # exit 0 = safe to close · exit 1 = open beads remain · exit 2 = FAIL-CLOSED (empty claimed-set
   # / no identity — surface, do NOT proceed to close)
   ```
   On exit 1, do NOT close — post the advisory nudge "cycle `<claim-id>` has `<N>` beads
   still open — not closing" and proceed to exit. Proceed to step 4 only on exit 0.
4. **Invoke `ac-batch-close`** — dispatch the **Batch-close prompt** from
   `references/delegation-prompts.md` VERBATIM. One close, one CI dispatch, one report commit.
5. **Slack notify** (see Milestone Notifications). Then re-query eligible work (same
   Phase-0 filters: non-`human-gate`, ready or unrefined, plus loop-ready plans with no
   beads). Any remain → re-enter Phase 0 for the next cycle (do not land).
   None remain → C1, then `ac-land`.

> **`post-merge` lifecycle — stamp at creation, strip at claim** (`beads-standards/reference/bead-conventions.md` § Claim semantics — `post-merge` exhaust). Every exhaust bead created during the run — Phase-2 discoveries, QA-pass beads, Exhaust-Rule decision beads — is **stamped `post-merge` AT CREATION** and parented into its epic; an unstamped follow-up under the run's identity is a genuinely-open in-scope bead that blocks the run's own close. Every claim path **strips `post-merge` at claim**, so an adopted bead is closeable again. The two halves are one rule; never do one alone.

**Publish stays human.** `ac-loop-2` never releases — that is `ac-publish`, invoked by Craig.

---

## Bypass lane (P0/P1 urgent)

A broken build or a red `main` does not wait for a phase. An urgent bead — P0/P1, or any
bead whose failure is blocking the cycle itself — **cuts across every barrier and ships as a
fully-checked solo at any time**: claim it, fix it, run its own affected tests AND the
smoke net, commit, close. Full checks, no batching, no lane.

Classify by CAUSE via source-trace, never by description keywords: anything touching
persistence, auth, money, or producing wrong values is bypass-eligible regardless of its
P-label. When a bead plausibly reads both ways, default to bypass.

The bypass lane is the ONLY legal barrier crossing. It never carries a non-urgent bead
along for the ride.

A bypass ship during Phase 1 moves the frozen HEAD: record the new `FREEZE_SHA` and
re-verify the anchors of any in-flight spec bead whose territory intersects the bypass
commit.

---

## Invariants that hold across all five phases

- **The conductor is the beads-ledger's only git writer.** Children run their `br` verbs
  directly — stamps and discovery filings ARE their deliverable — but never stage or commit
  `.beads/`; it is outside every territory manifest. The conductor flushes and commits the
  ledger at each barrier (`br sync --flush-only`;
  `beads-ledger-shared-file-conductor-should-own-final-commit`). Canon:
  `ceremony-batching-pool.md` § Beads-DB mutation deferral — the prep-hold binds only
  while a ceremony is in flight, and a barrier phase has none.
- **Reservations are epic-level territory locks**, held by lane coordinators — never per-file.
- **`AGENT_NAME` is handed to EVERY child**, claiming or not. `FoggyCreek` is the Tier-2
  chore identity and may NEVER claim beads — assert `[ "$AGENT_NAME" != "FoggyCreek" ]`
  before any claim and FAIL LOUDLY if it is (`ac-ycr.6`).
- **Children never share a progress file** — each gets its own artifacts dir and
  `progress.md` whose header carries the claim id, `TARGET_BEADS=<n>` and `KIND=`.
- **After every push, assert `git rev-parse origin/<branch>` == local HEAD — INSIDE the
  commit mutex** (after release, a sibling's commit false-fails it). Push with
  `git push --no-verify`: the husky pre-push build is redundant with CI and silently
  swallows backgrounded pushes (`prepush-build-hook-swallows-background-pushes`).
- **Wait for your OWN long-running command in-shell** — never background it and end the
  turn (`ac-pipeline/references/delegation-contract.md` clause 5, self-detachment).
- **The CI runner IS this Mac.** Never run a local full suite or build while a CI job is
  live on the runner. Bulk `br` write-loops run FOREGROUND.
- **"Is this a flake?" is a CHEAP question** — re-run the ONE failing file. Never a
  full-suite re-run.

---

## Stop Conditions

Checked at every barrier.

| # | Condition | Action |
|---|-----------|--------|
| **C1** | No eligible work (only `human-gate` / HOLD / unscopable remain), or this run is headless at the Phase-1 barrier | End cleanly. Slack: "Pipeline clear" / "Wave specified — headless stop before Phase 2." |
| **C2** | **Phase 3 cannot reach green within 2 repair loops**, OR the verification gate files an open `qa-blocker` | Hard stop. Do NOT close. Slack the finding, file a P0 bead, wait for human. **Skips `ac-batch-close`, so the acceptance mark does NOT advance — by design.** |
| **C3** | Safety cap — **default none** (run until C1). Honoured only when the invoke names one (`cap=N` cycles or a wall-clock) | Stop after the current phase. Slack: "Safety cap reached — <N> eligible remain." A stuck refine contract is a **named skip**, not C3. |
| **C4** | Human override ("stop" / "pause the loop") | Honour at the next barrier, or immediately if between beads. Notify confirmation. |

C2 is the only **hard** stop. C1/C3/C4 are clean stops.

**Every stop path ends in `ac-land`** — including C2. "Stopped" without landing is not
stopped, just abandoned.

---

## Run telemetry + friction carrier

The conductor writes ONE carrier per run, `/tmp/loop-retro-<RUN_ID>.md`
(`ac-pipeline/references/run-id.md`; ephemeral, NOT `progress.md`), **before** the
Exit-Land spawn so `ac-land` reads it deterministically. Schema:
**`references/run-carrier.md`**.

**Telemetry header — ALWAYS written, clean run included:** per-phase width requested vs
observed peak, idle slots with a closed-set reason, `repair%` and `hollow%`, and one line
per barrier crossing. **Friction sections — conditional:** roll each returning child's
`friction:` block up per phase; a phase returning only `friction: []` is OMITTED, so a
clean run yields a header-only carrier.

---

## Phase ARIA — human unlock

> **ARIA = Autonomy-Regulated Intelligent Assistance.** Fires only when there is no more
> eligible work — the loop is idle because of human gates, not because it gave up. This
> phase persists: re-check at interval and nudge again until Craig acts.

| Signal | Action |
|--------|--------|
| `human-gate` bead, ≤3 options, answerable in ≤10 words | Interactive: `AskUserQuestion` in-terminal. Headless: advisory Slack card, bead stays open for `ac-human-session` — never pause |
| `human-gate` bead, complex/open-ended | Advisory Slack card — do NOT pause |
| Wave specified but this run is headless | Advisory nudge: "Wave for `<lanes>` is specified — run `/ac-loop-2` interactively to continue" |
| Unrefined non-`human-gate` bead of any origin | **NOT an ARIA case** — that is Phase 1 work. Nudge only if refinement itself surfaced a `human-gate` fork (then it is row 1) |
| Loop-ready plans exist but no beads | **NOT an ARIA case** — Phase 1 beadifies them |
| Backlog items (raw ideas, not plans) | Advisory nudge ONLY — Craig decides what enters the pipeline |
| Nothing at all | Session-end notify: "Pipeline clear — nothing waiting" |

Advisory nudges post via `slack-send --channel sofi --card` (or the app's channel), listing
each waiting item with its one-line decision. On an answered `AskUserQuestion`: record it
(`br comments add <id> "DECISION (Craig): <choice> — <answer>"`), execute the consequence
(remove `human-gate`, unblock dependents), continue.

---

## Exit — land, reflect, deregister

**1. `ac-land`** — runs ONCE, at exit, on every stop path. Spawn it with:

> "Run ac-land to close this ac-loop-2 session (autonomous, phase-gated run).
> `RUN_ID=<RUN_ID>`. Land the WHOLE cycle, not one phase: the retrospective reads every
> `/tmp/bead-work-*-<RUN_ID>/progress.md` and teardown sweeps all of them. ALSO read the run
> carrier `/tmp/loop-retro-<RUN_ID>.md` — it ALWAYS exists: a telemetry header (per-phase
> width, `repair%`, `hollow%`, barrier lines) plus per-phase friction sections only where
> friction occurred; a header with no sections is a clean run. Carry the metrics line into
> the retrospective. Run your tier router (T1/T2 filing) as normal, but SKIP your Step 0
> reflect delegation — the CONDUCTOR spawns reflect after you return; hand the
> pre-classified T3 subset + skill-scoped tags back in your return summary instead. ALSO
> sweep the Agent Mail roster (Layer 2, `agent-mail/references/agent-identity.md`):
> `AGENT_MAIL_ROSTER=<conductor-name>,<child-1>,<child-2>,…` — this run's own name plus every
> child identity registered. Teardown is **reservations-only**: `force_release_file_reservation`
> on each stale hold, then verify the roster is clean. Do NOT `retire_agent`/`deregister_agent`
> the roster names — name-only cross-session retire is rejected at runtime (`ac-ycr.8`). You
> are post-merge on `main`. This is a HEADLESS land: system-upgrade proposals become deduped
> `human-gate` decision beads per `ac-pipeline/references/disposition.md` — never Slack cards,
> never `AskUserQuestion`, do NOT block. This is the loop's final step — exit after landing."

**2. Spawn `reflect`** (after land returns) — never read `reflect/SKILL.md` yourself. Hand it,
as literal paths + text: the friction carrier, the T3 subset + skill-scoped tags from land's
summary, and your own ≤300-word **decision trace** (lanes picked/merged/sequenced, barrier
timings, C-stop reasons, the two metrics — the run perspective only the conductor holds;
write it to `/tmp/loop-decision-trace-<RUN_ID>.md` first). Exactly ONE reflect per run.

**3. Deregister the conductor identity** — the true last act. `ac-land` cannot deregister a
still-live conductor, so after it returns:

```
mcp__mcp-agent-mail__deregister_agent(
  project_key: CANONICAL_PROJECT_KEY,
  agent_name: AGENT_NAME   # this run's own Phase-0 name, re-asserted inline
)
```

This is the Layer-1 SELF path in the SAME MCP session that registered, so its binding
authorizes a token-free call (`ac-g93`); pass the captured `registration_token` if held.
Every CROSS-session call threads the token. Only then does the process exit.

---

## Milestone Notifications

`slack-send --channel sofi --card` (replace with the app's configured channel).

| Event | Message |
|-------|---------|
| Phase 0 complete | "🗺️ Graph: <L> lanes, <B> beads, <D> docket items. Ordering: <lane sequence>." |
| Phase 1 complete | "📐 Spec complete — <B> beads carry a full implementation contract. Interactive: proceeding (A+B). Headless: awaiting invoke." |
| Phase 2 complete | "🔨 Build complete — <B> commits across <L> lanes, <R> risk-queue beads verified locally." |
| Phase 3 complete | "🧪 Converge green — repair <X>% · hollow <Y>%/<S> sampled. <N> beads reopened." |
| Cycle shipped | "🚀 Cycle <K> shipped — <B> beads closed (claim `<claim-id>`). <N> eligible remain — <continuing \| C1>." |
| Hard stop (C2) | "🛑 ac-loop-2 stopped — <converge failed to reach green in 2 loops \| qa-blocker in `<file>`>. Needs review before close." |
| Safety cap | "⏹️ Safety cap reached. <N> eligible remain." |
| Pipeline clear | "✓ Pipeline clear — <H> human-gate items waiting if you want to review." |
| ARIA nudge | See Phase ARIA. |

---

## Scheduling

PAI job config, triage decoupling, keep-awake layers: **`references/scheduling.md`**.
**ac-loop-2 is not scheduled by default** — headless stops at C1 before Phase 2.

---

## What Craig Controls (never automated)

| Item | Why |
|------|-----|
| Moving backlog → plan | Product/priority decision |
| Unrefined plans | Scope and intent need sign-off before beadify |
| Closing `human-gate` decision beads | Domain/taste/risk — agent prepares, human decides |
| Release (`ac-publish`) | Production exposure |

---

## Remember

- **A cycle ships; the run drains.** Phase 4 is not exit. Re-graph until C1. Land once.
- **Barriers, not gates, are the safety mechanism.** Every rule Phase 2 drops is paid for by
  a Phase-1 contract element or a Phase-3 check. Crossing a barrier early (outside the
  bypass lane) deletes the payment and keeps the cost.
- **One bead = one commit is load-bearing, not stylistic** — it is the entire basis of
  Phase 3's mechanical attribution. A worker that folds two beads into one commit has
  broken the phase, not tidied it.
- **A declared RED expectation that never gets sampled is a comment.** The mutation probe is
  what makes element 4 real; skipping it turns the contract into paperwork.
- **Findings route by KIND, then by BAR** (`references/filing-bar.md`). Machinery — pipeline,
  skill text, lint, bead schema, CI wrappers, harness ergonomics, tool flags, local stack —
  goes in `friction:`, never a bead. Product reaches the board ONLY at priority `0`/`1` with a
  verified reproduction; product at `2`-`4` goes to the session report's product-findings list,
  never `friction:`. A gate that failed to catch product defects IS a bead, at any priority.
