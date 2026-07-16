---
name: ac-loop
description: 'Autonomous bead-shipping loop — runs scheduled, drives orphan fixes + plan waves to merge without human checkpoints, surfaces genuine decisions as human-gate decision beads + advisory nudges, nudges human about remaining blocks until acted on. Multi-item queue clearance, no per-stage human gates; for a single named goal with human checkpoints, run the stages directly (ac-plan-init → ac-beadify → ac-bead-refine → ac-implement → ac-review → ac-batch-close) gating between them via ac-human-session — ac-pipeline is deprecated. Stop conditions: completeness, critical regression, iteration cap, human override. Triggers: "/ac-loop", scheduled PAI job, "run the loop", "ship everything available", "autonomous mode".'
---

# ac-loop — Autonomous Shipping Loop

**You are the loop conductor.** You drive refined work to merge without waiting for human sign-off at stage gates — that's the job. You delegate to the same skills `ac-pipeline` uses, but you pre-answer their operational questions (bead count, session mode, next-step choices) so they run headlessly — each in a **fresh spawned session** (see Orchestration contract below). You pause only for genuine forks — decisions only Craig can make — and only in interactive sessions.

When invoked interactively (`/ac-loop`), `AskUserQuestion` renders in the terminal for simple bounded forks. When invoked by the scheduler (headless), never `AskUserQuestion` — apply the Exhaust Rule: leave the `human-gate` decision bead in place, post an advisory Slack nudge, and keep working everything else. Decisions are answered via `ac-human-session` (the docket), not mid-run. **One exception:** the Phase 0 **width prompt** never uses `AskUserQuestion` (it has no timeout) — it is a timed plain-text ask, first output of the run (see Phase 0 § Width Prompt).

> **Scope contract:** You work the pipeline, not the backlog. You never touch raw backlog items (`_backlog/pool/`) or unrefined *plans*. **Every bead on the board that is not `human-gate` is loop-eligible** — if `unrefined`, you refine it (`ac-bead-refine`) first, then implement; if `refined`, you implement. The `unrefined` label routes a bead *through* refinement — **it is NOT a human gate** (memory `feedback-conductor-beads-need-unrefined-label`: the label forces the QA refine pass, it does not withhold sign-off). The **only** thing exempt from autonomous implementation is a **`human-gate`** bead (surfaced, never auto-closed). Craig controls what *enters* the pipeline **upstream** — at the backlog pool (`ac-backlog`) and via plan `loop-ready` sign-off; once an idea is a *bead* it is already committed work, so drive it to merge, furthest-advanced first. (Refinement *priority* still favours signed-off/furthest-advanced work — but nothing non-`human-gate` is gated *out*.)

> **Orchestration contract — 3-level, non-negotiable.** You are a *conductor*, not a doer. Every
> "Invoke `<skill>`" / "Run `<skill>`" step in this file means **spawn a fresh sub-session
> (Task/subagent) whose prompt is the delegation text, pinned `model: "opus"` on the spawn call** —
> let it load that skill and run its own workers, and you keep only the returned summary.
> Phase sub-sessions are conductors themselves (they judge, gate, and spawn workers) — they run
> opus-class, explicitly pinned, never inherited (a headless launch may not be opus-class). Their
> workers keep the per-call pins already written in each skill's reference prompts (deliberate
> sonnet/opus mix). Never set `CLAUDE_CODE_SUBAGENT_MODEL` to manage this: it sits ABOVE per-call
> pins in model precedence and silently flattens all of them (shakedown-verified 2026-07-12; see
> `rule-agent-mail-identity-setup`).
> **The VERIFY-GATE passes are phases too:** each gate-selected pass (`ac-ui-polish`,
> `ac-qa-browser`, `ac-qa-device`) runs as its own spawned opus-pinned sub-session with a
> delegation prompt — you consult `_shared/verification-gate.md` for selection + depth (that
> consult is yours), then spawn the pass; you never load a verify skill or drive a
> browser/simulator in your own context. The passes are themselves conductors over tester
> subagents (`_shared/qa-shared.md` § Conductor / worker evidence protocol).
> You **never** read a phase skill's `SKILL.md`
> (`ac-implement`, `ac-review`, `ac-batch-close`, `ac-beadify`, `ac-bead-refine`, `ac-land`,
> `ac-ui-polish`, `ac-qa-browser`, `ac-qa-device`) into your
> OWN context — that collapses to 2-level and bloats the conductor with every phase's skill +
> working detail until it compacts mid-run. Orchestrator holds *decisions*; sub-sessions hold
> *skills + file contents* (`context-engineering`). If you catch yourself about to Read a phase
> skill, stop and spawn instead.

---

## I/O Contract

| | |
|---|---|
| **Input** | Refined plans in `_plans/`, beads in `br` (any state from unrefined onward); trunk-direct on `main` (legacy branches, if any, per `.claude/legacy-branches.txt`) |
| **Output** | Merged PRs, closed beads, Slack notifications per milestone |
| **Not in scope** | Backlog capture, plan init (`ac-plan-init`), unrefined plans, human decisions |

---

## Execution Order

```
RUN START (once, before anything else):
  WIDTH PROMPT — interactive: the run's FIRST output, before registration/orient
  (2-min chunked wait → default 2); headless: no prompt, width = 2.
  Sets PARALLEL_WIDTH for the run. See Phase 0 § Width Prompt + Efficiency § Parallelism.

EACH ITERATION:  (phase ORDER is preserved; within each numbered step, up to
                 PARALLEL_WIDTH HOMOGENEOUS children may run — same-kind only,
                 never a refine child beside an implement child — see Efficiency § Parallelism)
  0. BUG LANE  (Rule 0 — health-first; drains COMPLETELY before steps 1-2)
      ├─ pull ready bugs: issue_type=="bug", br ready, non-human-gate — EVERY priority (the Bug-Lane filter)
      ├─ if unrefined: ac-bead-refine the bug first, then implement (refined bugs go first within the lane)
      ├─ CLAIM the ready-bug set as ONE batch (claim-at-selection): mark all in_progress + assignee
      │      ($AGENT_NAME) in one br update, mint the claim id, write .claim-id — then ac-implement
      │      commits each fix DIRECTLY to main, one bug per commit, each independently green on affected
      │      tests BEFORE the next starts — main is never broken mid-sequence. A fix that goes bad is
      │      REVERTED (its own commit) and the bead reopened, never a blocker. Cap ~8 bugs/batch;
      │      overflow forms the next batch after this one closes.
      │      SOLO close (ship immediately as a batch-of-one): P0/urgent; migration- or native-touching;
      │      conductor judges the fix risky enough to isolate. Never fold a bug into a feature wave.
      └─ the BATCH runs the chain ONCE: ac-implement (per bug, sequential, direct-to-main) → VERIFY-GATE
             → ac-review → BEADS-CLOSED-GATE → ac-batch-close → Slack notify   (one batch-close for the whole drain)
      ⟳ RE-CHECK the Bug-Lane filter after every close; repeat until ZERO unblocked bugs remain, THEN step 1
  1. Orphan beads  (refined, no plan wave — the "maintenance wave"; ships after the bug lane is dry)
      └─ ac-implement → VERIFY-GATE → ac-review → BEADS-CLOSED-GATE → ac-batch-close → Slack notify
  2. Next plan's wave  (highest-priority loop-ready plan with refined ready beads)
      ├─ [if plan has no beads yet] ac-beadify → ac-bead-refine
      │      (prep — only now, AFTER the bug lane + maintenance wave have shipped)
      └─ claim-at-selection (loop owns this, not ac-implement — direct to main, no branch) →
         ac-implement → VERIFY-GATE → ac-review → BEADS-CLOSED-GATE → ac-batch-close → Slack notify

  VERIFY-GATE = consult _shared/verification-gate.md → run only the selected
                passes (ui-polish / qa-browser / qa-device) at the selected depth.
  BEADS-CLOSED-GATE = the loop's own pre-merge gate (ac-batch-close no longer checks beads
                itself) — genuine (non-post-merge) open beads block the close; advisory
                Slack nudge, not a hard stop.
  3. Loop — RE-CHECK the bug lane FIRST (a just-merged non-bug may have unblocked a bug), then orphans/plans
  4. Nothing left → Phase ARIA (unlock human blocks, then stop)

STOP CONDITIONS checked before each iteration (see below).

ON EXIT — ALWAYS, every stop path (C1/C2/C3/C4, Phase ARIA, or an error):
  run ac-land. Land is the loop's single closing ritual — it TEARS DOWN (kills
  spawned tasks, sweeps orphaned waiters, releases+deregisters Agent Mail, clears
  temp, asserts a clean tree) AND LEARNS (reflect + system upgrades). ac-land runs
  LAST, after the final wave's merge — not per-wave (it was wrongly in the per-wave
  path before). The loop is NOT done until it has landed: a run that ships waves but
  never lands leaves zombies + strands every lesson in the transcript.
```

> The run's progress through these phases is tracked in the Phase 0 **run ledger**
> (`TaskCreate`) — update it at each phase boundary; it is the anti-early-exit anchor
> and the resume point after compaction.

---

## Phase 0: Orient

### Width Prompt (FIRST — before registration, before any board read)

**Interactive runs only.** The run's **very first output** — before
`macro_start_session`, before any `br`/`bv` call — is the width question, so the
human can answer in the opening seconds and leave the loop unattended for the rest
of the run:

> **"Max parallel sub-sessions for this run? Reply with a number — defaulting to 2 in 2 minutes."**

Then wait for the reply in short chunks — e.g. 8 × 15-second shell sleeps. **A reply
= any user message that has arrived when a wait chunk returns** (in a turn-based
harness, messages typed mid-chunk are delivered as the chunk's call completes — so an
early answer costs at most ~one chunk, not the full window). After ~120 s of silence,
proceed with the **default of 2**. Never use `AskUserQuestion` for this fork — it has
no timeout, and a walked-away human would stall the run at second zero.

- The answer sets **`PARALLEL_WIDTH`** for this run (doctrine: Efficiency §
  Parallelism). **1 is a legal answer** — the serial escape hatch when the machine is
  loaded (live CI job on this Mac, sibling-app loop). An unparseable reply → default 2.
- **Headless runs never prompt** (Exhaust Rule) — width is 2. Likewise if the
  environment refuses the timed wait: treat as headless, width 2, move on — but flag
  it (see next bullet) so a silently-skipped prompt is visible, never mistaken for a
  human choice.
- Carry the outcome into the run ledger when it's created — annotate the orient task
  `width=N chosen` / `width=2 defaulted` / `width=2 defaulted (no-wait env)`.

### Register Loop Identity

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

Register a unique identity for this loop run — gives the conductor a readable name in the agent registry and pre-commit attribution:

```
mcp__mcp-agent-mail__macro_start_session(
  human_key: CANONICAL_PROJECT_KEY,   // this tool takes human_key (other tools take project_key) — canonical "neometa/<app-dir>" key; key-format + never-absolute rule: _shared/agent-identity.md § Project key format
  program: "claude-code",
  model: "claude-opus-4-8"
)
```

Capture the returned `name` field:
> **Two call-scoped facts (shakedown-verified 2026-07-08):** (1) also capture the
> returned `registration_token` — `file_reservation_paths`, `release_file_reservations`,
> and `send_message` REQUIRE it (as `registration_token`/`sender_token`) unless this MCP
> session already authenticated as the agent; carry it through every Agent Mail call.
> (2) `export` lives only in the bash call that ran it — every later bash call is a
> fresh shell, so re-assert `AGENT_NAME` (and any env the pre-commit guard reads) in the
> SAME call as each `git commit`/`git push`, or the guard will treat you as anonymous
> and block against your own reservation.

```bash
export GIT_IDENTITY_ENABLED=1   # Agent Mail git identity/attribution — NOT worktree isolation (WORKTREES_ENABLED made subagents worktree; see rule-agent-mail-identity-setup)
export AGENT_NAME=<returned-name>   # e.g. "BlueLake" — unique per loop run
export RUN_ID="$(date +%Y%m%d-%H%M%S)-$$"   # scopes THIS run's /tmp scratch dirs; passed to every spawned stage (_shared/run-id.md)
```

Sub-skills invoked by the loop (ac-implement, ac-land, etc.) start their own fresh sessions and self-register independently — the loop's `AGENT_NAME` is not inherited (Tier-1 minting, the two-tier contract: `_shared/agent-identity.md` — parallel children must be distinct identities for reservations to protect between them).

### Read Current Board State

Read the current state of the board. This is the map you navigate by.

> **Discovery uses `bv` for triage, `br` for data — NEVER bare `br ready`.**
> `br ready` **defaults to `--limit 20`** and silently truncates: a board with >20 ready
> beads shows only the first 20, and the default sort can bury all the shippable ones below
> the cut (this stranded 23 refined maintenance beads and derailed a whole run, 2026-07-08).
> **ALWAYS pass `--limit 0`.** `bv --robot-triage` is the dependency-aware "what to work on"
> engine (no truncation; correctly treats parent-child *containment* edges as non-blocking);
> `br` remains the **create/modify/close** engine + the labeled data source. Roles, not
> substitutes: **bv = discovery/triage, br = mutations + data** (AGENTS.md bv/br split). Use
> bv to see + sanity-check the true actionable set/counts, then `br ready --limit 0` for the
> labeled rows the jq filters need. If bv is unavailable (headless), `br ready --limit 0` is
> the correct fallback on its own.

```bash
# TRIAGE (dependency-aware, no truncation) — read the TRUE counts first; if these disagree
# with your br filters below, trust these and debug the filter (a 20-row answer = you forgot --limit 0).
bv --robot-triage 2>/dev/null | jq '.triage.quick_ref | {actionable: .actionable_count, blocked: .blocked_count, in_progress: .in_progress_count, open: .open_count}'

# --- Full labeled ready set. ALWAYS --limit 0 (bare `br ready` caps at 20). ---

# Refined, non-human-gate ready beads (the shippable pool: orphans + plan-wave beads)
br ready --limit 0 --json | jq '[.[] | select(
  (.labels | index("refined")) and (.labels | index("human-gate") | not)
)]'

# UNREFINED, non-human-gate ready beads → these ALL get ac-bead-refine, THEN implement.
# `unrefined` = "route through refinement", NOT a human gate. Nothing here is gated out;
# only the REFINE-PRIORITY differs (signed-off / furthest-advanced first — see Work priority).
br ready --limit 0 --json | jq '[.[] | select(
  (.labels | index("refined") | not) and (.labels | index("human-gate") | not)
)]'

# Human-gate ready beads (the ONLY exempt class — for Phase ARIA)
br ready --limit 0 --json | jq '[.[] | select(.labels | index("human-gate"))]'

# BUG LANE (Rule 0 — see Work priority). ALL unblocked bugs drain before ANY non-bug work.
# issue_type == "bug", ready (= unblocked, deps satisfied), non-human-gate — EVERY priority.
# `br ready` already excludes blocked bugs; blocked / human-gate bugs are surfaced, never shipped.
br ready --limit 0 --json | jq '[.[] | select(
  (.issue_type == "bug") and (.labels | index("human-gate") | not)
)]'

# Legacy branches still in flight (trunk-direct works on `main`; wave-branches are retired —
# mirror ac-merge/ac-review's .claude/legacy-branches.txt awareness)
LEGACY_FILE="$(git rev-parse --show-toplevel)/.claude/legacy-branches.txt"
[ -f "$LEGACY_FILE" ] && grep -v '^[[:space:]]*$' "$LEGACY_FILE" 2>/dev/null

# Plans marked loop-ready (Craig's explicit gate — only these enter the loop)
grep -l "status: loop-ready" _plans/*.md 2>/dev/null
```

> **The loop-ready gate:** Only plans with `status: loop-ready` in their frontmatter are touched by the loop. Plans marked `refined`, `draft`, or anything else are invisible to the loop — Craig has not yet signed them off for autonomous execution. This is intentional: Craig sets `loop-ready` at the end of `ac-plan-refine` (optionally after running `ac-plan-clean`), which is the explicit hand-off signal.

> **Plan-frontmatter `depends-on:` convention (plan-level admission gate).** A loop-ready
> plan MAY declare a machine-readable `depends-on:` frontmatter field naming a blocking
> **epic id** OR **plan path** — e.g. `depends-on: bd-abc12` or
> `depends-on: _plans/2026-07-01-foo.md`. It means "do not admit this plan to the beadify
> phase until the named epic/plan is closed/merged." The conductor honours it in
> Phase 2 § Pick the next plan (the admission gate below). Unrelated plans (no declared
> `depends-on`) may parallelize within the beadify phase. Bead-level `depends-on` edges +
> `bv --robot-plan` tracks continue to govern within-*implement* partitioning. Prior art:
> memory `plan-internal-gates-outrank-blanket-loop-directives` — this structuralizes what
> plan prose already did.

Summarise: N orphan beads (carrying `refined`), M plan beads across K plans, any legacy branches in flight, H human-gated waiting, L loop-ready plans with no beads yet, U unrefined non-`human-gate` beads needing refine (classified by absence of `refined`, whether labeled `unrefined` or lacking any lifecycle label). **All U are loop-eligible** — refine then ship; the split below is a *priority* ordering, not a gate.

> **Rule 0 — the Bug Lane (preempts the entire order below).** Health first: **nothing broken ships alongside new work.** Before selecting ANY non-bug item, drain every *unblocked* bug (`issue_type == "bug"`, `br ready`, non-`human-gate`) — **every priority, P0 through P4** — across BOTH stages: implement the `refined` bugs, then refine-and-ship the `unrefined` ones. Only when zero unblocked bugs remain do you touch the non-bug order below.
> - **Bugs are preemptive, re-checked every selection.** After each merge, re-run the Bug-Lane filter *before* picking the next unit of work — a just-merged non-bug may have unblocked a bug, and that bug now goes first. This is what makes "all unblocked bugs first *always*" hold across a run.
> - **Blocked bugs can't ship — so they never freeze the loop.** A bug with an unmet dependency is not in `br ready`; a `human-gate` bug is exempt. Both are *surfaced* (advisory nudge / Phase ARIA), set aside, and picked up automatically on a later pass once their blocker merges through the non-bug flow. "Within reason" = a bug you can't act on does not hold up the world.
> - **Execution: the drain ships as ONE trunk-direct batch (claim-at-selection, direct-to-main, `ac-batch-close`).** This is the SAME model Phase 1/2 use — no branch is ever minted. Claim the full ready-bug set in one `br update` (`in_progress` + assignee `$AGENT_NAME`), mint the claim id, write `.claim-id`; `br ready` then naturally excludes them for every other conductor. `ac-implement` commits each fix **directly to main**, one bug per commit, each independently green on affected tests before the next starts, so main is never broken mid-sequence (same safe-sequencing contract as wave beads). The batch then runs implement → VERIFY-GATE → review → BEADS-CLOSED-GATE → `ac-batch-close` **once**: one batch-close, one CI dispatch — a 9-bug drain costs one close ceremony, not nine (the 2026-07-10 all-nighter post-mortem: per-bug branches spent ~3h in CI for ~1h of fixes). A fix that turns out bad is **reverted (its own commit)** and its bead reopened — it never blocks siblings (this replaces the old "never bundle unrelated bugs" rationale). **Solo-close exceptions (ship immediately as a batch-of-one):** P0/urgent fixes that must not wait for the batch; migration- or native-touching fixes; anything the conductor judges needs isolation — each still commits to main and runs its own `ac-batch-close`, never a branch. Cap ~8 bugs per batch — overflow forms the next batch after this one closes. Never fold a bug into an unrelated feature wave; a bug *structurally* part of an in-flight wave is `blocked-by` that wave's beads (so not `br ready`) and rides the wave naturally — no special handling.
>
> *(Historical — superseded 2026-07-12, trunk-direct migration bd-u2lo1: the bug lane formerly minted a `bugs/batch-<YYYYMMDD>-<n>` branch and ran one PR / one CI run. That branch model is retired — `ac-implement` HARD STOPs on any non-main branch and `bugs/batch-*` cannot be pre-allowlisted, so the drain now ships claim-at-selection direct to main. Reversible if Craig overrules at the post-migration reassessment — see bd-smrcb.)*

**Work priority order (NON-BUG work — runs only after the Bug Lane is dry)** — ship ready maintenance first, then drive the *furthest-advanced* refinement work before pulling less-advanced work in. Nothing here except `human-gate` is gated *out*; ordering just decides what to do first:
1. Orphan refined beads → Phase 1 (the maintenance wave — ready-to-ship fixes go first: cheapest, safest, often time-sensitive)
2. Unrefined non-`human-gate` beads, **furthest-advanced first** — (a) from a loop-ready plan (`wave-NNN` marker), OR part of a beadified epic / plan-traceable group; then (b) lone captures (triage/hygiene/reflect/`ac-bead-capture` follow-ups). Run `ac-bead-refine` on them, then drive to merge (delegation: "ac-loop autonomous run, skip next-step question; return bead IDs refined + anything blocked, ≤200 words"). **Do NOT stop to ask** — a captured bead is committed work; refine-and-finish it. (The backlog *pool* is the "not-yet-committed" holding area, upstream of beads — that is where human promotion happens, not here.) A beadified epic outranks #3.
3. Loop-ready plans with no beads → run `ac-beadify` then `ac-bead-refine` (prep) (delegation: "ac-loop autonomous run, always proceed to ac-bead-refine, no confirmation needed; return bead IDs created/refined + anything blocked, ≤200 words")
4. Plan wave refined beads → Phase 2

> **Orphans ship before prep** — `ac-beadify` + `ac-bead-refine` is the loop's most expensive prep step, so a session that ends early (compaction / human override / iteration cap) still delivers the ready work if the cheap fixes go first.

### Create the Run Ledger

Once you've oriented and know what's queued, lay down a **run-level task list** with `TaskCreate` — the loop's own progress, made legible and resumable. This is the anti-early-exit anchor and the "where is the loop right now" view a headless operator otherwise lacks.

```
TaskCreate — one task per run phase; add a Plan-wave task per queued loop-ready wave (up to the iteration cap):
  1. Orient + read board                  → in_progress  (this pass)
  2. Bug lane: drain all unblocked bugs    → pending      (Rule 0; omit if no ready bugs; re-checked each loop)
  3. Orphan / maintenance wave → merge     → pending      (omit if no orphans)
  4. Plan wave: <plan-name> → merge        → pending      (one per queued wave, cap 3)
  5. Phase ARIA + ac-land                  → pending
```

`TaskUpdate` each task to `in_progress` when its phase starts and `completed` at its merge/exit; mark task 1 `completed` when this orient pass finishes. If the board is empty, the ledger is just task 1 + task 4.

> **The ledger tracks the RUN, never the work.** It holds *phases and iterations* — orient, which wave, ARIA/land — and nothing else. Work items stay **beads**: the bead board is the single source of truth for *what* ships (`ac-pipeline-builder` axiom 1, *the bead is the atom*). The ledger is a navigation aid over the run, not a second copy of the queue — never put bead IDs or per-bead state in it, or the two will drift.

> **On resume (compaction / restart):** read the ledger first — it's your resume *anchor* (which phase you were in). Then reconcile against live board state, which remains ground truth: a wave the ledger calls `in_progress` may have merged in the moments before compaction. Trust the **board** for work state; trust the **ledger** for run position.

If **no refined beads, no unrefined non-`human-gate` beads, no loop-ready plans to beadify, and only `human-gate` beads remain** → go straight to Phase ARIA.

---

## Phase 1: Orphan Beads

**Orphans = refined, non-human-gate beads with no wave affinity.** These are typically bugs and quick fixes surfaced by `ac-triage` or `ac-bead-capture`. Ship them first — they often unblock other work or are time-sensitive production fixes.

> **Seam contract with `ac-triage`:** triage findings ALWAYS arrive `unrefined` — there is
> no fast lane, however well-evidenced the defect (source permalink + suspected wave/commit
> + repro + verification path just makes its `ac-bead-refine` pass converge in one round
> instead of several). They only become orphans once `ac-bead-refine` stamps `refined`; the
> loop's refine-and-finish path (Work priority #2 above) picks up triage's `unrefined`
> beads in the same run as plan-beads and beadified epics — never a shortcut into Phase 1.

```bash
# Orphan beads: refined, no wave-NNN marker label, no human-gate.
# --limit 0 is MANDATORY — bare `br ready` caps at 20 and will silently hide orphans.
br ready --limit 0 --json | jq '[.[] | select(
  (.labels | index("refined")) and
  (.labels | index("human-gate") | not) and
  (.labels | map(test("^wave-[0-9]+$")) | any | not)
)]'
```

> If no wave is open, all refined ready beads are orphans.

If orphans exist:
1. **Claim the batch (loop's job, before any implementation — CLAIM-AT-SELECTION)** — mark
   the FULL set of N orphan beads `in_progress` + assignee (`AGENT_NAME`, this run's Agent
   Mail identity from Phase 0) in ONE call, up front — never incrementally as ac-implement
   works through them:
   ```bash
   # HARD RULE (ac-ycr.6; doctrine _shared/agent-identity.md): FoggyCreek is the Tier-2
   # chore identity and may NEVER claim beads. If AGENT_NAME fell back to it (a fresh shell
   # that didn't re-assert the Phase-0 minted name), FAIL LOUDLY here rather than claim a
   # batch under the shared chore identity (which silently misattributes and breaks the gate).
   [ "$AGENT_NAME" = "FoggyCreek" ] && { echo "FATAL: AGENT_NAME=FoggyCreek — cannot claim beads under the Tier-2 chore identity; re-assert the Phase-0 minted loop name" >&2; exit 2; }
   br update <id1> <id2> ... --status in_progress --assignee "$AGENT_NAME"
   ```
   This is the precedent from body-compass-app memory
   `claim-adopted-beads-before-planning` (claim before you plan/implement, generalized here
   to every batch) — once claimed, **`br ready` naturally excludes these beads** for every
   other conductor (its status filter already returns only open/unclaimed beads — no new
   gating logic needed). Mint the batch's CLAIM ID **once**, at this moment:
   `<first-claimed-bead-id>-<YYYYMMDD>` (e.g. `bd-u2lo1.1-20260712`). Write it to
   `$ARTIFACTS_DIR/.claim-id` (first line = the claim id — a FILE, not an env var, since
   downstream skills read it from a fresh process) and mirror it as the first line of
   `$ARTIFACTS_DIR/progress.md`'s header. Downstream skills (RUN_ID re-keying, bd-u2lo1.9)
   read the claim id verbatim from `.claim-id`.
2. **Invoke `ac-implement`** — use this delegation prompt to suppress overhead questions.
   *At width >1:* split into up to WIDTH tree-disjoint child delegations per Efficiency
   § Parallelism (each child: own bead subset, own `TARGET_BEADS`, own claim id +
   artifacts dir); verify → review → close still run ONCE for the whole batch after all
   children return:
   > "Run ac-implement targeting all N orphan beads (IDs: `<list>`, already claimed —
   in_progress + assignee `<AGENT_NAME>`, claim id `<claim-id>`). `CLAIM_ASSIGNEE=<AGENT_NAME>`
   (MY loop identity) — make EVERY bead claim, including any incremental/replacement claim,
   under `--assignee <AGENT_NAME>`, NOT your own session name, so the BEADS-CLOSED-GATE sees
   them. TARGET_BEADS=N. `RUN_ID=<RUN_ID>` (scopes the bead-work dir — `_shared/run-id.md`).
   Skip the bead-count setup question — answer is pre-supplied. For baseline test failures:
   file a P1 bead and proceed (do not ask). Report when complete as a compact structured
   summary (≤400 words, cap unchanged: beads shipped/closed with IDs, gate outcomes, anything
   blocked, every Agent Mail identity you claimed beads under, AND a structured `friction:`
   block — one item per stage that hit friction, keys `stage` / `cost` / `lesson` / `class`
   (`friction: []` if the stage was clean); see the Child friction schema below) — the loop
   advances to verify → review → close."

   > **Child friction schema (D1)** — the `friction:` block the summary contract above asks
   > for. Structured (not prose) so the conductor can aggregate it mechanically and `dream`
   > can key on `stage`/`cost` later. One list item per stage that hit friction; a clean
   > stage returns `friction: []`. Lives INSIDE the existing ≤400-word summary cap — it is a
   > slot in that summary, not a new unbounded field.
   > ```
   > friction:
   >   - stage: implement          # pipeline stage that hit it
   >     cost: material|minor       # + optional "~Nmin" when quantifiable
   >     lesson: "vi.mock hoist trap swallowed the first two runs"
   >     class: defect|improvement|observation   # child's pre-classification HINT
   > ```
   > `class` is a HINT only — `ac-land`/`reflect` re-adjudicate it against the objective bar;
   > never treat it as authoritative. Both `ac-implement` delegation prompts (Phase 1, Phase 2)
   > and the `## Remember` child-summary bullet name this same block — keep the four keys
   > identical across all three (bd-jv33f.2 aggregates on them).
3. **Verify (gated)** — consult **`_shared/verification-gate.md`**: classify the batch diff, run **only** the selected passes (`ac-ui-polish` / `ac-qa-browser` / `ac-qa-device`) at the selected depth. Do NOT run all three unconditionally. Emit the gate's decision line into the Slack notify (which ran, which skipped + why). Beads any pass files feed the retrospective; an open `qa-blocker` bead stops at merge.
4. **Invoke `ac-review`** — use this delegation prompt:
   > "Run ac-review (trunk-direct: on main, scope = batch since the review-mark — no branch argument). This is an autonomous loop run. For DESIGN_DECISION or SCOPE_ESCALATION items: apply the Exhaust Rule (create decision beads, do not AskUserQuestion). Do not ask 'what's next?' at Phase 8 — exit after printing the summary with VERDICT: line."
5. **Read `VERDICT:` from ac-review output** — `APPROVED` → proceed to merge. `NEEDS_DECISION` with open blockers → hard stop (C2).
6. **Verify beads closed (the loop's own pre-close gate — `ac-batch-close` no longer checks this itself):**
   ```bash
   export AGENT_NAME="$AGENT_NAME"   # re-assert in THIS call — exports don't persist across bash calls
   # Pass the UNION of every identity that claimed into this batch: MY loop identity PLUS each
   # delegated ac-implement identity from its summary (bd-w504y — querying only the loop identity
   # would MISS a delegate's incremental claim and fail OPEN). Threading CLAIM_ASSIGNEE above
   # already funnels those claims to $AGENT_NAME, so <delegated-identities…> is belt-and-suspenders.
   bash "$PROJECT_ROOT/.claude/skills/_shared/scripts/beads-closed-gate.sh" "$AGENT_NAME" <delegated-identities…>
   # prints the genuinely-open bead set; exit 0 = empty (safe to close), exit 1 = open beads remain,
   # exit 2 = FAIL-CLOSED (empty claimed-set / no identity — surface, do NOT proceed to close)
   ```
   `post-merge`-labelled beads are excluded — they're deliberately un-closeable until the
   merge ships (carried forward as known tails, listed in the PR body), never blockers. If
   any genuinely open (non-`post-merge`) beads remain for this batch (exit 1), do NOT merge —
   surface via the loop's Slack-nudge pattern instead: "batch `<batch-id>` has `<N>` beads
   still open — not merging" (advisory nudge, no `AskUserQuestion` — this is not a genuine
   human fork). Only proceed to Invoke `ac-batch-close` once this set is empty (exit 0).
7. **Invoke `ac-batch-close`** — use this delegation prompt:
   > "Run ac-batch-close for batch `<batch-id>`. CI config for this project: `<cached-answer>`. Version bump: accept recommended default without asking. For uncertain PR feedback items: create decision beads (Exhaust Rule). Do not ask 'what's next?' after merge."
8. **Slack notify** (see Milestone Notifications).
9. **Loop** — return to Phase 0 check after merge. **`ac-land` does NOT run per-wave** — it runs ONCE at loop exit (see ON EXIT / Exit-Land); per-wave landing was the leftover the "land runs LAST" reconciliation retired.

If `ac-review` surfaces a **Critical regression** → hard stop (see Stop Conditions §C2).

---

## Phase 2: Plan Wave

After orphans are clear (or if no orphans), advance the highest-priority plan with refined ready beads.

### Pick the next plan

```bash
# Loop-ready plans (Craig's explicit gate)
LOOP_READY_PLANS=$(grep -l "status: loop-ready" _plans/*.md 2>/dev/null)

# Of those, find which have refined, non-human-gate ready beads (--limit 0 mandatory — bare `br ready` caps at 20)
br ready --limit 0 --json | jq '[.[] | select(
  (.labels | index("refined")) and
  (.labels | index("human-gate") | not) and
  (.labels | map(test("^wave-[0-9]+$")) | any)
)] | group_by(.labels[] | select(test("^wave-[0-9]+$"))) | sort_by(.[0].priority) | .[0]'
```

Cross-reference with `$LOOP_READY_PLANS` — only advance a plan wave if its parent plan file has `status: loop-ready`. If no loop-ready plan waves exist, skip to Phase ARIA.

> **Plan-admission gate (`depends-on:`).** Before admitting a plan to the **beadify** phase,
> read its `depends-on:` frontmatter (convention: Phase 0 § loop-ready gate). If it names an
> epic id or plan path that is NOT closed/merged (`br show <id>` status ≠ closed, or the named
> plan not yet merged), the plan is NOT admitted this pass — it stays queued; move to the next
> loop-ready plan. Unrelated plans (no declared `depends-on`) parallelize freely within the
> beadify phase. This is the plan-level counterpart to bead-level `depends-on` edges (which
> govern within-implement partitioning via `bv --robot-plan`).

### Execute the wave

1. **Claim the batch (loop's job — CLAIM-AT-SELECTION)** — same mechanism as Phase 1 step 1: mark ALL refined ready beads for this plan `in_progress` + assignee (`AGENT_NAME`) in ONE `br update` call, mint the claim id (`<first-claimed-bead-id>-<YYYYMMDD>`), write it to `$ARTIFACTS_DIR/.claim-id` + the `progress.md` header. `br ready` naturally excludes them for every other conductor — no branch to pre-allocate or join. **Same FoggyCreek guard as Phase 1 step 1** — assert `AGENT_NAME != FoggyCreek` before the `br update` (`[ "$AGENT_NAME" = "FoggyCreek" ] && { echo "FATAL: cannot claim beads as the Tier-2 chore identity" >&2; exit 2; }`); a plan batch claimed under the shared chore identity is the same misattribution bug the gate rejects (doctrine `_shared/agent-identity.md`).
2. **Invoke `ac-implement`** with delegation prompt. *At width >1:* same split rule as
   Phase 1 step 2 (up to WIDTH tree-disjoint children, each with own subset /
   `TARGET_BEADS` / claim id + artifacts dir; one verify → review → close for the batch):
   > "Run ac-implement targeting all refined ready beads for plan `<plan-name>` (IDs: `<list>`, already claimed — in_progress + assignee `<AGENT_NAME>`, claim id `<claim-id>`). `CLAIM_ASSIGNEE=<AGENT_NAME>` (MY loop identity) — make EVERY bead claim, including incremental/replacement claims, under `--assignee <AGENT_NAME>`, not your own session name, so the BEADS-CLOSED-GATE sees them. TARGET_BEADS=N. `RUN_ID=<RUN_ID>` (`_shared/run-id.md`). Skip bead-count setup question. Baseline test failures: file P1 bead and proceed. Report when complete as a compact structured summary (≤400 words, cap unchanged: beads shipped/closed with IDs, gate outcomes, anything blocked, every Agent Mail identity you claimed beads under, AND a structured `friction:` block — one item per stage that hit friction, keys `stage` / `cost` / `lesson` / `class` (`friction: []` if the stage was clean); see the Child friction schema in Phase 1 step 2) — the loop advances to verify → review → close."
3. **Verify (gated)** — consult **`_shared/verification-gate.md`**: classify the batch diff, run **only** the selected passes at the selected depth (never all three unconditionally). Emit the decision line into the Slack notify. Open `qa-blocker` bead → stops at merge.
4. **Invoke `ac-review`** with delegation prompt:
   > "Run ac-review (trunk-direct: on main, scope = batch since the review-mark — no branch argument) (ac-loop autonomous run). DESIGN_DECISION/SCOPE_ESCALATION: Exhaust Rule — create decision beads, do not AskUserQuestion. Exit after Phase 8 summary with VERDICT: line."
5. **Read `VERDICT:`** — APPROVED → merge. NEEDS_DECISION with blockers → C2 stop.
6. **Verify beads closed (the loop's own pre-close gate — `ac-batch-close` no longer checks this itself):**
   ```bash
   export AGENT_NAME="$AGENT_NAME"   # re-assert in THIS call — exports don't persist across bash calls
   # Pass the UNION: MY loop identity + each delegated ac-implement identity from its summary
   # (bd-w504y — a delegate's incremental claim under its own name would otherwise be MISSED,
   # failing the gate OPEN). CLAIM_ASSIGNEE threading already funnels claims to $AGENT_NAME.
   bash "$PROJECT_ROOT/.claude/skills/_shared/scripts/beads-closed-gate.sh" "$AGENT_NAME" <delegated-identities…>
   # prints the genuinely-open bead set; exit 0 = empty (safe to close), exit 1 = open beads remain,
   # exit 2 = FAIL-CLOSED (empty claimed-set / no identity — surface, do NOT proceed to close)
   ```
   `post-merge`-labelled beads are excluded — carried forward as known tails in the PR body,
   never blockers. If any genuinely open (non-`post-merge`) beads remain for this batch (exit 1),
   do NOT merge — advisory Slack nudge instead: "batch `<batch-id>` has `<N>` beads still open — not
   merging" (no `AskUserQuestion`). Only proceed once this set is empty (exit 0).
7. **Invoke `ac-batch-close`** with delegation prompt:
   > "Run ac-batch-close for batch `<batch-id>` (ac-loop autonomous run). CI config: `<cached>`. Version bump: accept recommended default. Uncertain feedback: Exhaust Rule — decision beads. No next-step question after merge."
8. **Slack notify** — batch shipped.
9. **Check stop conditions** — then loop back to Phase 0. (No per-wave `ac-land`; it lands once at exit.)

If `ac-review` surfaces a **Critical regression** → hard stop (see Stop Conditions §C2).

---

## Phase ARIA: Human Unlock

> **ARIA = Autonomy-Regulated Intelligent Assistance.** Fire only when there is no more eligible work to implement — the loop is idle because of human gates, not because the agent gave up.

This phase persists. The loop does not exit after a nudge — it re-checks at interval and nudges again until Craig acts. Bottlenecks need pressure, not a single polite mention.

### Decision Matrix

| Signal | Action |
|--------|--------|
| `human-gate` bead with ≤3 options, question answerable in ≤10 words | Interactive session: `AskUserQuestion` in-terminal. Headless: advisory Slack nudge (card), bead stays open for `ac-human-session` — never pause |
| `human-gate` bead with complex/open-ended answer | Advisory Slack nudge (card) — do NOT pause |
| Plan exists but all beads are `unrefined` | Advisory nudge: "Plan X has N beads awaiting refinement — run `/ac-bead-refine`" |
| Unrefined non-`human-gate` bead of ANY origin (lone capture, beadified epic, or plan-traceable) | **NOT an ARIA case** — these are eligible work. The loop refines them (`ac-bead-refine`) and ships them in Phase 1/2 per Work priority #2; they should never reach ARIA idle. Only nudge if refinement itself is *blocked* (e.g. `ac-bead-refine` couldn't converge and surfaced a `human-gate` decision) — then it's the `human-gate` row above. A captured bead is committed work, not a raw idea awaiting promotion (that lives in the backlog *pool*). |
| Refined plans exist but no beads yet | Advisory nudge: "Plan X is ready for `/ac-beadify`" |
| Backlog items (raw ideas, not plans) | Advisory nudge ONLY — Craig decides what enters the pipeline |
| Nothing at all (no backlog, no plans, no beads) | Session-end notify: "Pipeline clear — nothing waiting" |

### Advisory nudge format

Post via `slack-send --channel sofi --card` (or the app's channel):

```
🔒 *Pipeline blocked — your input needed*

<N> items waiting for you:
• <bead title> — <one-line decision needed>
• Plan "<name>" — N unrefined beads waiting for /ac-bead-refine
...

Run the relevant skill or click a bead to unblock.
```

### AskUserQuestion (simple forks, interactive sessions only)

For `human-gate` beads with clear options, when a human is at the terminal (never headless):

```
AskUserQuestion(
  questions: [{
    question: "<the decision question from the bead spec>",
    header: "<bead title, ≤12 chars>",
    multiSelect: false,
    options: [
      { label: "<option A>", description: "<bead's option A description>" },
      { label: "<option B>", description: "<bead's option B description>" },
      ...
    ]
  }]
)
```

On answer: record the decision in the bead (`br comments add <id> "DECISION (Craig): <choice> — <answer text>"`), execute the consequence (remove `human-gate` label, unblock dependents), then continue the loop.

### Re-nudge cadence

After a nudge, re-check on the next scheduled loop fire. If the block persists: send another nudge (do not suppress). The nudge IS the signal — Craig needs to feel the bottleneck until he clears it.

---

## Efficiency & Validators (cost discipline)

The loop is expensive when validators run too often, at the wrong boundary, or while
fighting the machine. Hold these:

**Pushing**
- Push loop commits with `git push --no-verify`. The husky pre-push `pnpm build` is
  redundant with CI and, in a backgrounded/piped shell, **silently swallows the push** —
  the commit lands locally, origin never moves, and `… | tail` masks the real exit code.
  After EVERY push assert `git rev-parse origin/<branch>` == local HEAD before moving on.
  (See memory `prepush-build-hook-swallows-background-pushes`.)

**Validators — each fires ONCE, at its correct boundary**
- Per-bead AND per-wave correctness → `pnpm test` (the affected runner). NEVER `test:all` per bead
  or per wave.
- The batch-final gate (inside `ac-batch-close`, pre-close) is the AGGREGATED affected run pinned to
  the anchor: `VITEST_AFFECTED_REF=origin/main pnpm test`. Per-bead runs tested each change
  against main's history at that moment; only the aggregated run sees the whole batch/wave diff against
  CURRENT main (semantic conflicts with concurrent main drift, review fixups).
  It is still affected-only — cheap — and shrinks what the publish-start full run can be first to find.
- Full `test:all` no longer fires at close (bd-pwt44 retired the async close-time dispatch) —
  waves/batches merge on affected only, and the between-publish full-suite proof now happens at
  PUBLISH START instead: `ac-publish` calls `ac-prove ensure --fix-forward`, which runs the
  exhaustive gate SHA-pinned to the commit being published. That publish-start run is the
  integration/masking backstop; a nightly idle-time full run (`ac-prove`/`workflows/scheduled.md`)
  is planned but DEFERRED/unwired. Not per bead, not per wave, not to "prove" a flake.
- "Is this a flake?" is a CHEAP question → re-run the ONE failing file in isolation. Never
  answer it with a full-suite re-run — that's the heaviest tool on the cheapest question.
- The wave-level `ac-review` is scoped to **cross-bead integration** (per-bead conductor
  reviews already cover each bead's internals). If a dedicated pass already cleared a
  dimension on a bead (e.g. a `security-reviewer` on a privacy keystone), the wave review
  **skips that dimension** instead of re-deriving the same verdict.

**Pacing & contention**
- Match the wakeup to the wait. A known ~5-min job → poll ~270s (stay in the prompt-cache
  window); reserve 1200–1800s for genuinely idle ticks. Don't sleep 20 min on a 5-min job.
- **The CI runner IS this Mac** (self-hosted). Do NOT run local `test:all`/builds while a
  CI job is live on the runner — you starve your own runner and triple every duration
  (a ~21-min suite became ~50 min at load-68). See `bca-ci-and-ios-build-ops`.
- **Bulk `br` write-loops run FOREGROUND** (batch claim/label/dep sweeps of >~10–20
  sequential `br` writes) — a backgrounded bulk-`br` loop can stall silently; kill and
  retry foreground before assuming `br` is broken (`_shared/bead-conventions.md` § Bulk
  `br` write-loops).
- **Wait for your OWN long-running local command in-shell — never detach** (`_shared/delegation-contract.md`
  § clause 5, self-detachment). Backgrounding a local `pnpm test`/build/CI-poll via
  `run_in_background` + `Monitor` and ending your turn "waiting for completion" is the
  self-detachment stall — the same silent-resume-break as an abandoned child, pointed at
  yourself. Foreground it with a generous Bash timeout (or a foreground `pgrep`/poll
  until-loop); the turn does not end until the command returns.

**Parallelism — the `PARALLEL_WIDTH` dial (fan-out under ONE conductor)**
- The conductor may hold up to **`PARALLEL_WIDTH`** phase sub-sessions in flight —
  set per run by the Phase 0 width prompt (default 2; headless 2; 1 = fully serial).
  More width means more sub-sessions under THIS one orchestrator, never additional
  loops/conductors (single-conductor fan-out plan, body-compass-app
  `_plans/2026-07-12-2354-single-conductor-fanout-dial.md`).
- **Machine headroom:** up to 3 opus sub-sessions + a live CI job all share this ONE
  Mac (the runner is self-hosted); the per-run width prompt is the throttle — keep the
  ramp-evidence discipline (below) unchanged and don't ramp the default past green windows.
- **What may parallelize — HOMOGENEOUS within-phase fan-out.** Widening a phase runs up
  to `PARALLEL_WIDTH` children **of the SAME kind of work** — you never mix an implement
  child with a refine or beadify child. The three parallelizable phase kinds:
  **(a) implement** — implementers on **tree-disjoint** independent beads (dep-graph
  antichains — `bv --robot-plan` computes the parallel tracks); **(b) refine** —
  `ac-bead-refine` children on **disjoint unrefined-bead subsets** (no two children
  refine the same bead); **(c) beadify** — `ac-beadify` children on **independent plans**
  (no shared `depends-on`). **The invariant:** all children in flight at one moment are
  the same kind — uniform supervision, clean failure attribution. Genuinely read-only
  sessions (board triage/discovery reads) still run freely alongside any phase.
  **Tree-disjointness check before dispatch (implement):** compare the beads' expected
  file sets from their bead specs (the lists each child will reserve in ac-implement
  Phase 1a — reservations themselves don't exist until the child starts); any overlap →
  serialize those beads behind each other. When a dependency chain exists (A blocks B),
  stay sequential.
- **How width is enacted (per-phase fan-out):** at width >1, partition the phase's work
  into up to WIDTH children along that phase's **disjointness unit** — implement →
  `bv --robot-plan` tracks (file-set disjoint); refine → disjoint unrefined-bead subsets
  (no two children refine the same bead); beadify → independent plans (no shared
  `depends-on`). Each child gets its OWN delegation: its work subset, its own
  `TARGET_BEADS`, and its own claim id (`<first-bead-of-subset>-<YYYYMMDD>`) → own
  `.claim-id` + artifacts dir + `progress.md` — children NEVER share a progress file
  (shared counting breaks TARGET_BEADS recovery after compaction). The ceremony
  (verify → review → close) still runs **once** per batch, after ALL children return;
  the BEADS-CLOSED-GATE already takes the union of every child identity.
- **What NEVER parallelizes:** **heterogeneous phase mixing / cross-phase pipelining is
  OFF** — prep (refine/beadify) never runs concurrently with implement, and phases never
  pipeline (no beadifying plan B while wave A implements). *Accepted trade-off (chosen
  knowingly):* run wall-clock = sum of phases, and batch-of-one phases idle the width —
  revisit heterogeneous lanes only later, on evidence that prep is the bottleneck. Also
  serial: batch-close ceremonies (serial by construction); two writers on the same file;
  the **bug-lane drain** (Rule 0 stays literal — nothing else even preps while bugs drain;
  its contract is each fix independently green BEFORE the next starts, so sequencing IS the
  safety property); cross-batch overlap (reviewing batch A while batch B implements) — OFF
  at this ramp stage, one batch in flight at a time, width applies WITHIN the batch;
  prove/publish (outside the loop, unchanged).
- **Mandatory at width >1** (best-practice at width 1): ledger touch at every
  dispatch/return; ≤200–400-word child summaries; a watchdog/poke on every child
  (background resume chains break silently); strict repo + pathspec instructions per
  child. Pull heavy sub-steps (e2e / prod-build) OUT of the implementer into their own
  gated step so they're visible and pace-able — don't let one bead's engineer run
  100+ min hidden inside a sub-agent.
- **Ramp evidence:** the exit retrospective (ac-land) notes any tree collisions, child
  stalls, or conductor compactions this run — Craig moves width run-by-run at the
  prompt; the skill default only rises after green windows at the current default.

---

## Stop Conditions

Check before each iteration begins.

| # | Condition | Action |
|---|-----------|--------|
| **C1** | No eligible work and no human-gate unblocks remaining | End session cleanly. Notify Slack: "Pipeline clear." |
| **C2** | `ac-review` returns a Critical blocking finding (regression) | Hard stop. Do NOT merge. Notify Slack with the finding. File a P0 bead. Wait for human. |
| **C3** | Iteration cap reached (default: 3 plan waves per session) | Stop after current merge. Notify Slack: "Iteration cap reached." |
| **C4** | Human override (Slack message "stop" / "pause the loop") | Honour immediately after current bead. Notify confirmation. |

C2 is the only **hard** stop — it never merges a regression. C1/C3/C4 are clean stops (current work finishes, then exit).

**Every stop path ends in `ac-land`** (the teardown + learn close) — including C2's hard stop. A regression stop still tears down spawned processes, releases Agent Mail, and reflects the lesson before halting. "Stopped" without landing = not stopped, just abandoned.

### Friction aggregation — the loop-retro carrier (D2)

As each phase child returns, the conductor collects its `friction:` block (the D1 schema —
Phase 1 step 2 "Child friction schema") and rolls the items up **per stage** into one carrier
file, `/tmp/loop-retro-<RUN_ID>.md` (RUN_ID convention — `_shared/run-id.md`; ephemeral, NOT
`progress.md`). Append as children return, or aggregate once after each batch's children
return — either is fine, provided the file is written **before** the Exit-Land spawn below so
`ac-land` can reference it deterministically.

Structure: one `## <stage>` section per stage that ran **and produced ≥1 friction item**, that
stage's children's `friction:` items listed under it. **Zero-friction rule:** a stage that ran
but returned only `friction: []` is **OMITTED** — no empty `## <stage>` header. A fully-clean
run therefore yields an empty-or-absent carrier, and `ac-land` (the consume leg) degrades
gracefully to today's behavior when the carrier is empty/absent — nothing downstream ever
parses an empty stage section.

> **Why a dedicated carrier file, not `progress.md` and not conductor-side `reflect`** (recorded
> so this isn't relitigated): children NEVER share a `progress.md` (shared counting breaks
> `TARGET_BEADS` recovery after compaction — the "children NEVER share a progress file" invariant
> in Efficiency § above); a separate carrier keeps that invariant intact and gives `ac-land` ONE
> path to read. Moving `reflect` to the conductor top-level (the rejected alternative) violates the
> 3-level orchestration contract — the conductor never reads a phase skill's `SKILL.md`, and
> `reflect` lives inside `ac-land`, a phase skill. The carrier is the typed hand-off across that
> boundary.

### Exit-Land — the loop's single closing invocation

ac-land runs **once here**, not per-wave. The loop shipped one or more waves, each writing
`/tmp/bead-work-<wave-slug>-<RUN_ID>`; land closes the whole **session**. Pass `RUN_ID` so land
scopes to *this run's* dirs (never a stale or foreign one) and learns from **every** wave shipped:

> "Run ac-land to close this loop session (autonomous run). `RUN_ID=<RUN_ID>`. Land the WHOLE
> session, not one wave: the retrospective reads every `/tmp/bead-work-*-<RUN_ID>/progress.md`
> (all waves this run shipped — `RUN_ID` scopes them safely), and teardown sweeps all of them.
> ALSO read the friction carrier `/tmp/loop-retro-<RUN_ID>.md` if it exists (the per-stage
> aggregated friction packet — an absent or empty carrier means a clean run; proceed as today)
> and pass its items to `reflect` as typed candidate lessons for disposition.
> You are post-merge on `main`. This is a HEADLESS land: system-upgrade proposals become
> deduped `human-gate` decision beads per `_shared/disposition.md` — never Slack cards,
> never `AskUserQuestion`, do NOT block.
> This is the loop's final step — exit after landing." (`_shared/run-id.md`)

### Deregister the conductor identity (Layer 1 — the loop's true last act)

`ac-land` releases and deregisters the child identities on the roster it was handed (Layer 2),
but it **cannot** deregister the conductor's own name — the conductor is still alive, invoking
it. So **after `ac-land` returns**, the conductor's actual final act is to deregister its OWN
minted `AGENT_NAME` (the one registered in Phase 0). By name — `registration_token` optional
(doctrine: `_shared/agent-identity.md` Deregistration, Layer 1):

```
mcp__mcp-agent-mail__deregister_agent(
  project_key: CANONICAL_PROJECT_KEY,
  agent_name: AGENT_NAME   # the loop conductor's own Phase-0 name, re-asserted inline
)
```

Only then does the loop process exit.

> **No token-budget stop** (removed deliberately) — an unmeasurable budget only becomes a
> vague excuse to quit early; the loop is bounded by the **measurable** conditions instead:
> C1 (pipeline empty) or C3 (iteration cap). A run needing a hard ceiling gets one
> explicitly (an iteration cap or a stated goal).

---

## Milestone Notifications

Always notify on Slack at meaningful milestones. Use `slack-send --channel sofi --card` (replace `sofi` with the app's configured channel).

| Event | Message |
|-------|---------|
| Orphan beads shipped | "✅ Shipped <N> orphan fix(es) — <bead titles> — merged to main." |
| Plan batch shipped | "🚀 Batch for *<plan name>* merged — <N> beads shipped (claim `<batch-id>`)." |
| Critical regression found | "🛑 Loop stopped — ac-review found a critical regression in `<file>`. Needs your review before merge." |
| Iteration cap | "⏹️ Iteration cap reached (<N> waves this session). Remaining work queued for next run." |
| Pipeline clear | "✓ Pipeline clear — no eligible work remaining. <H> human-gate items waiting if you want to review." |
| ARIA nudge | See Phase ARIA advisory format above. |

---

## Scheduling

ac-loop is designed to run as a scheduled PAI job (headless). Configure in `infrastructure/jobs/<app>.json`:

```json
{
  "name": "ac-loop-<app>",
  "prompt": "Load the ac-loop skill and run the autonomous shipping loop for <app>. Working directory: <app-path>.",
  "schedule": "0 */4 * * *",
  "enabled_on": ["<hostname>"],
  "channel": "<slack-channel-id>"
}
```

Headless runs never `AskUserQuestion` — all decisions fall through to advisory nudges + open `human-gate` decision beads by design (Exhaust Rule). The channel ID is used by the scheduler to post nudges and thread updates.

Run `ac-triage` as a **separate** scheduled job before `ac-loop` (e.g., 30 min earlier). Triage feeds beads into the board; the loop ships them. Keep them decoupled so triage failures don't block shipping.

---

## What Craig Controls (Never Automated)

| Item | Why |
|------|-----|
| Moving backlog → plan | Product/priority decision |
| Unrefined plans | Scope and intent need human sign-off before beadify |
| Closing `human-gate` decision beads | Domain/taste/risk — agent prepares, human decides |
| Pipeline entry | Plan `loop-ready` sign-off + beadify approval ratify the spec contract wholesale; per-bead refine executes it autonomously — deviations come back as `human-gate` decision beads |

The loop never touches these. It nudges Craig when they're bottlenecks.

---

## Remember

- **Width prompt first** — interactive runs open with the `PARALLEL_WIDTH` question as the very first output (2-min chunked wait → default 2) so the human can answer and walk away; headless = width 2, no prompt. Fan-out stays under the ONE conductor; ceremonies and same-file writers stay serial
- **Never trust bare `br ready`** — it caps at `--limit 20` and silently hides the rest. Discovery = `bv --robot-triage` (true counts, dependency-aware) + `br ready --limit 0` (labeled rows). A 20-row answer means you forgot `--limit 0`. bv = discovery, br = mutations — not substitutes
- **Only `human-gate` beads are gated** — every other bead (refined → implement; unrefined → `ac-bead-refine` then implement) is loop-eligible. `unrefined` routes *through* refinement, it does not withhold sign-off. The "not-yet-committed" gate is the backlog *pool*, upstream of beads
- **Orphans first** — fixes and production bugs ship before new feature waves
- **Claim-at-selection** — mark the FULL batch `in_progress` + assignee, mint the claim id, and write `.claim-id` up front, before any implementation — never incrementally per bead
- **Delegate to fresh sub-sessions, never inline** — every phase (`ac-implement`, `ac-review`, `ac-batch-close`, `ac-land`, `ac-beadify`, `ac-bead-refine`) runs in a spawned session with its delegation prompt; you never Read its `SKILL.md` into your own context (Orchestration contract). Holding only decisions + returned summaries is what keeps the conductor alive across a long run
- **Every child summary carries a `friction:` block** — the structured D1 slot inside the ≤400-word summary (keys `stage` / `cost` / `lesson` / `class`; `friction: []` for a clean stage; `class` is a re-adjudicated HINT). Canonical schema: Phase 1 step 2 "Child friction schema (D1)". This is the evidence packet the conductor aggregates per stage into the loop-retro carrier and `ac-land`/`reflect` dispose of — never let a child return prose-only lessons the aggregator can't key on
- **Keep the run ledger current** — `TaskUpdate` at every phase/wave boundary; it's the anti-early-exit anchor and the compaction resume point. Beads stay the work atom; the ledger tracks only the run
- **ARIA gating** — `AskUserQuestion` only for simple, bounded forks in interactive sessions; headless = advisory nudge + open decision bead. Everything else is advisory
- **Persistent nudge** — re-nudge every session until Craig acts. Silence enables bottlenecks
- **C2 is the only hard stop** — critical regression never merges
- **Always Slack-notify** — shipped waves, blocked stops, clear pipeline. Headless means Craig has no other visibility
- **Never close `human-gate` beads** — record the decision, execute consequences, then close only after Craig's recorded answer
