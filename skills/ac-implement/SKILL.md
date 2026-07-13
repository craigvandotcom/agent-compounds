---
name: ac-implement
description: 'Sequential bead implementation — conductor reviews, engineer sub-agents implement, loops until the wave is done. Triggers: ''work the beads'', ''implement the wave'', ''bead work'', ''run the wave'', ''start implementation''.'
---


**You are the conductor.** Engineers implement. You review, verify, and commit. One bead at a time. Quality over velocity.

Multiple sessions can safely share a wave — file reservations via Agent Mail prevent conflicts.

---

## I/O Contract

|                  |                                                                                            |
| ---------------- | ------------------------------------------------------------------------------------------ |
| **Input**        | Unblocked beads (from `/ac-bead-refine`)                                       |
| **Output**       | Implemented code, committed per bead, pushed directly to `main` (trunk-direct)             |
| **Artifacts**    | Per-bead results in `/tmp/bead-work-<wave-slug>/bead-{id}-result.md`, progress in `/tmp/bead-work-<wave-slug>/progress.md` |
| **Verification** | Per-bead quality gate (test, lint, type-check), beads closed in `br`                       |

## Phase 0: Initialize

**MANDATORY FIRST STEP: Create task list with TaskCreate BEFORE starting (after asking user for bead count).**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

### Inventory the Working Tree — H7d: Never Commit Foreign WIP (FIRST)

```bash
git status --short
```

Under trunk-direct, every session works directly on `main` with no branch isolation — a non-empty `git status --short` is EXPECTED and, by itself, is NOT a blocker. It may contain another concurrent session's in-flight, not-yet-committed work.

**Inventory it; do not touch it.** Uncommitted changes in files you have not reserved via Agent Mail (Phase 1a) belong to someone else's session. Leave them exactly as found — do not stage them, do not commit them "on their behalf," do not group them into "logical" commits, do not delete or revert them. If anything in the inventory looks like a genuine red flag (unexpected deletions, sensitive files, something clearly orphaned rather than in-flight), flag it to the user before proceeding — otherwise, proceed past it.

**The rule that keeps committed state clean under concurrent editing: only files YOU reserved may enter YOUR commits.** Every commit in this workflow — Phase 0 onward — is pathspec-mandatory: `git commit -- <file1> <file2> ...`. **Never `git add -A`, never `git add .`, never `git commit -a`.** A wildcard add sweeps in whatever foreign WIP happens to be sitting in the shared working tree at that moment and ships it under your bead's commit message — misattributing someone else's unreviewed work to your commit record and to your bead.

Exception: machine-local scaffolding (`.beads/` runtime DB, `.claude/` symlinks, tool caches) is neither committed nor a blocker — leave it untracked regardless of who "owns" it.

**Never use `git stash` at any point during or between beads — not even as a diagnostic tool.** A `stash pop` can surface pre-existing stash entries from other sessions and write merge-conflict markers into files unrelated to the current session (incident: stash-corruption — `references/incidents.md`). If you need to isolate uncommitted-vs-committed differences, use `git diff HEAD` — stash is not a reversible tool in a shared, concurrently-edited working tree.

### Verify Refined Beads Exist

```bash
br ready --json
```

If no unblocked beads, STOP: "No unblocked beads. Run `/ac-beadify` first, or check `br list --json` for blocked items."

> **Hard intake gate — no exceptions.** Before working ANY bead — regardless of who
> supplied its ID, including conductor delegation — verify it carries the `refined`
> label. A bead without `refined` is NOT workable: add `unrefined` to it (if it lacks
> a lifecycle label), skip it, and report it back for the refine queue. `human-gate`
> beads are never implemented directly. Readiness = presence of `refined`, never the
> absence of `unrefined` (`skills/_shared/bead-conventions.md`) — a well-written
> description is not a refined spec.

**Filter to beads carrying `refined`, excluding human-gated beads.** Beads created by `/ac-beadify` (or `ac-triage`, or `ac-bead-capture`) carry the `unrefined` label until `/ac-bead-refine` — the label's sole source, with no exceptions — stamps `refined` on convergence. Beads labeled `human-gate` (decision beads — see `skills/_shared/bead-conventions.md`) may be ENRICHED by agents but never selected for implementation or closed. Only beads carrying `refined` and NOT carrying `human-gate` are eligible:

```bash
# Ready beads that are refined AND not human-gated
br ready --json | jq '[.[] | select((.labels | index("refined")) and (.labels | index("human-gate") | not))]'
```

If NO ready beads carry the `refined` label, STOP: "No refined beads ready. Run `/ac-bead-refine` first to make them implementation-ready." If only `human-gate` beads remain, STOP: "Remaining ready beads need the human — run `/ac-human-session` for the decision docket."

### Work Directly on Main (trunk-direct — no wave branch)

**There is no wave branch.** Under trunk-direct, ac-implement sessions commit straight to `main` — nothing is created, allocated, or joined. Concurrency across sessions is coordinated entirely by Agent Mail file reservations (H3, unchanged) plus claim-at-selection in Phase 1a; it is no longer coordinated by branch isolation. Whole-project truth lives only at committed-state CI layers on `main`, not on a per-wave branch.

```bash
git checkout main 2>/dev/null || true
git pull --rebase
```

Confirm you're on `main` (`git branch --show-current`) before doing anything else. If you find yourself on some other branch, `git checkout main` — there is nothing to "join," and no second branch to defensively guard against.

### Install Pre-Commit Guard

```
mcp__mcp-agent-mail__install_precommit_guard(
  project_key: CANONICAL_PROJECT_KEY,   // the app's canonical Agent Mail key from its session-start.md (pattern: "neometa/<app-dir>", e.g. "neometa/body-compass-app") — NEVER an absolute path: abs paths fork a per-machine mailbox (split-brain)
                                        # mirror: _shared/agent-identity.md — edit there first
  code_repo_path: PROJECT_ROOT
)
```

Idempotent — safe to re-run every session. Installs a git hook that blocks commits to files reserved by another agent. Closes the window between Phase 1a's conflict check and the actual commit — a second enforcement layer on top of the reservation.

### Pre-Flight Type-Check

```bash
pnpm type-check 2>&1 | tail -5
```

If type-check fails:
- **Error in a file this session will touch:** Fix it as the first commit before starting beads
- **Error in a file owned by another agent's reservation:** Note the error in progress.md header, proceed with awareness that `--no-verify` may be needed on push. File a P0 bead if one doesn't exist for the fix.
- **Error unrelated to any bead scope:** Proceed — note it but don't block the session

### Baseline Check (read the loop-close run; don't re-run full per wave)

Confirm you're starting from a green `main` before building on it. With the `vitest-affected`
fixture-cascade upgrade, affected-mode is trustworthy, so the full-suite masking-catch is
**relocated to the loop-close CI run** (`ac-land` fires it; `ac-publish` reads it SHA-pinned —
parallel-execution doctrine §5 Tier 2). Read that result instead of re-running the suite per wave.
**Guard first** — only body-compass-app has this workflow today; if `quality-gate.yml` doesn't
exist in this repo, skip straight to the local fallback:

```bash
if gh workflow list --json name --jq '.[].name' 2>/dev/null | grep -qi quality-gate; then
  gh run list --workflow=quality-gate.yml --branch main --event workflow_dispatch \
    --limit 1 --json conclusion,headSha,createdAt
else
  echo "No quality-gate.yml workflow — falling back to local baseline."
fi
```

- **Green (recent)** → baseline clean; proceed.
- **Red** → `main` carries a failure; handle it BEFORE building (flow below).
- **No recent loop-close run, or no CI workflow** (standalone use, `main` advanced since, or the
  app has no full-test CI gate) → run the full suite once locally to establish the baseline:
  `pnpm test:all 2>&1 | tail -20`.

**Pre-existing failures are NOT acceptable baseline.** They are technical debt that the user gets to decide how to handle BEFORE the session starts. Do not silently absorb them — silent absorption removes the user's opportunity to catch real regressions dressed as "known" debt (incident: baseline-preexisting — `references/incidents.md`).

Behavior:

- **All pass:** Note "Baseline: all tests passing" in progress.md header. Proceed.
- **Any failures:** Capture for each failing test file:
  - Test file path
  - Failure category (production-state / schema-drift / flake / unknown — one-line judgment)
  - 1-line root-cause hypothesis if obvious
  - Whether the file overlaps the session's target bead scope

  Then surface to the user via `AskUserQuestion` — Ask: "Baseline test run shows N failures across M files: <one-line summary per file>. How to handle?" — options: "File P1 follow-up bead now and proceed" (captures debt, doesn't block session (recommended for >5 failures or substantive schema-drift)) / "Fix first as a pre-bead commit" (pause session, fix, re-baseline (recommended for ≤2 quick wins like env-override toggles)) / "Proceed without filing — I have an existing bead tracking these" (explicit acknowledgment; user MUST cite the bead ID) / "Stop and let me investigate" (abort session).

  Record the user's decision (and any cited bead ID) in progress.md header. Do NOT proceed silently.

- **Failures include files this session will touch:** Always fix as the first commit before starting beads, OR pick a different bead set. Do not start work where your changes will land on top of broken tests in the same files.

Specifically REJECT these failure modes from being treated as "acceptable baseline" without a fix plan:

- **Production rate-limit / egress quota errors** (`exceed_egress_quota`, 429s from external APIs) — almost always fixable via env-override to local stack, the same pattern existing tests use.
- **Schema-drift errors after migrations** (column "X" does not exist; SQLSTATE mismatches between expected CHECK and actual NOT NULL) — fixable by updating column references / assertions to match current schema.
- **"Known pre-existing" without a specific bead ID tracking the fix** — this is an evasion phrase. Either it has a bead, or it needs one filed now.

The baseline read is cheap — always do it. Only the fallback full run (when no loop-close run is available) is expensive; skip that fallback only if it takes > 10 minutes AND the session targets fewer than 2 beads.

### Scoped Per-Commit Readiness Gate (H7 v3) + Push Cadence

This is the gate that runs at **every** commit for the rest of the session (Phase 1d), not just once here — establishing it in Phase 0 so it's binding for the whole loop. Under trunk-direct there is no wave branch acting as a buffer, so this gate — plus post-push CI — is the only thing keeping `main` clean.

**The gate is scoped to YOUR OWN diff, never the whole project:**

1. **Format** — `lint-staged` (or the project's equivalent) on YOUR OWN staged files only.
2. **`ubs <changed-files>`** — pass the exact list of files YOU changed. **Never `ubs .`** — a whole-project scan is a jef-flywheel anti-pattern: it re-surfaces every pre-existing issue in the repo on every commit and buries your own signal in noise that isn't yours to fix.
3. **`pnpm test` (vitest-affected) scoped to YOUR OWN diff** — not the full suite (that's session-end and loop-close territory, per the Baseline Check note above).
4. **Whole-project `tsc`** — this one check is necessarily whole-project (TypeScript has no per-file mode), so triage its output by attribution rather than treating every red line as yours to fix:
   > A `tsc` error in a file you didn't touch that does NOT import your changed files is foreign-WIP noise → log it and proceed (push-CI re-checks committed state in ~4 min). An error in your own file, or in a file that imports your changes, is yours → fix it before committing.

**Cadence: commit every 15–20 minutes.** Do not batch a whole bead — or worse, a whole session — into one commit; granular commits are both the revert points and the unit of concurrency-safety under H7d.

**Commit = push. Always. Mandatory, not optional.** There is no wave branch holding your work safe in the interim — origin is the only durability record. The sequence for every commit:

```bash
git pull --rebase
# pre-push trip-wire runs here (installed hook) — see the --no-verify note below
git commit -- <file1> <file2> ...
git push --no-verify origin main
git rev-parse HEAD                     # local
git ls-remote origin main              # origin — confirm the SHAs match
```

`--no-verify` is deliberate: the installed pre-push hook runs a full-tree build, and under trunk-direct another session's uncommitted WIP can be sitting in that same working tree and false-positive the hook (see Multi-Session Parallelism, below) — real verification for state you don't own comes from the per-commit gate above plus post-push CI, not from a hook scanning the whole tree. **Never sit on local-only commits** — a crashed or abandoned session with unpushed commits is lost work, not "recoverable from the branch," because there is no branch.

> **Race handling (unchanged):** if `git push` collides with another session's push, `git pull --rebase` and re-push — never force-push over another session's committed work.

### Ask User

Ask one question via `AskUserQuestion`:

1. "How many beads to target this session?" (default: all unblocked)

### Configuration

```bash
TARGET_BEADS=<user input>
BEADS_COMPLETED=0
# Deterministic dir keyed on the CLAIM/BATCH ID, never the branch — trunk-direct puts every
# conductor on `main`, so `git branch --show-current` no longer discriminates concurrent
# sessions (bd-u2lo1.9 re-keying). Contract: _shared/run-id.md. ac-land lands this same path.
#
# If ac-loop already claimed this batch and delegated (claim id handed in the prompt, e.g.
# "claim id `bd-u2lo1.1-20260712`"), use it verbatim below — do not re-derive.
#
# If this is a standalone first run (no claim id handed down yet), Phase 1a's
# claim-at-selection is the moment the batch is actually *claimed* (mint format:
# <first-claimed-bead-id>-<YYYYMMDD>), but it writes `.claim-id` INTO $ARTIFACTS_DIR — which
# needs to already exist. Resolve that ordering (contract: _shared/run-id.md "Mint order") by
# computing the identical string here, ahead of the `br update` mutation: the first bead ID in
# the refined, non-human-gate ready-bead candidate list already gathered above ("Verify
# Refined Beads Exist") + today's date. Phase 1a recomputes the same string when it actually
# claims, from the same unmutated candidate-list ordering and the same date — no mismatch.
CLAIM_ID="${CLAIM_ID:-<first-candidate-bead-id>-$(date +%Y%m%d)}"   # handed-down or self-derived
WAVE_SLUG="$CLAIM_ID"   # alias for other in-file references to this key (task labels, progress.md header) — same value, not a re-derivation
# Mint RUN_ID if the orchestrator didn't hand one down (contract: _shared/run-id.md).
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"
ARTIFACTS_DIR="/tmp/bead-work-${CLAIM_ID}${RUN_ID:+-$RUN_ID}"   # e.g. /tmp/bead-work-bd-u2lo1.1-20260712
```

### Register Session Identity

Register a unique identity for this implement session — used for file reservations and pre-commit guard attribution:

```
mcp__mcp-agent-mail__macro_start_session(
  human_key: CANONICAL_PROJECT_KEY,   // NOTE: this tool takes human_key (other agent-mail tools take project_key) — the app's canonical Agent Mail key from its session-start.md (pattern: "neometa/<app-dir>", e.g. "neometa/body-compass-app") — NEVER an absolute path: abs paths fork a per-machine mailbox (split-brain)
                                        # mirror: _shared/agent-identity.md — edit there first
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
# Export so the pre-commit guard reads AGENT_NAME + GIT_IDENTITY_ENABLED at commit time
export GIT_IDENTITY_ENABLED=1   # Agent Mail git identity/attribution — NOT worktree isolation (WORKTREES_ENABLED made subagents worktree; see rule-agent-mail-identity-setup)
export AGENT_NAME=<returned-name>   # e.g. "SunnyBear" — unique per session
```

Each parallel ac-implement session runs its own `macro_start_session` and gets a distinct adjective+noun — no manual discriminators needed.

```bash
mkdir -p "$ARTIFACTS_DIR"
```

### Create Workflow Tasks

**Create session config task + one task per target bead + final task.** The session config task encodes mode and bead count so they survive context compaction. Bead tasks use "X of N" numbering to make the stop condition explicit.

```
# Session config — always completed, serves as compaction-resilient state
TaskCreate(subject: "Session config: {TARGET_BEADS} beads | {WAVE_SLUG}", description: "TARGET_BEADS={TARGET_BEADS}. ARTIFACTS_DIR={ARTIFACTS_DIR}. Stop after {TARGET_BEADS} beads.", activeForm: "Configuring session...")
TaskUpdate(task: "Session config", status: "completed")

TaskCreate(subject: "Phase 0: Initialize bead-work session", description: "Verify beads, confirm on main (trunk-direct), create tasks", activeForm: "Initializing session...")

# "X of N" naming — makes the boundary crystal clear even after compaction
for i in 1..TARGET_BEADS:
    TaskCreate(subject: "Bead {i} of {TARGET_BEADS}", description: "Select next bead via bv --robot-next, implement with TDD, review, commit. Bead ID assigned when selected.", activeForm: "Implementing bead {i} of {TARGET_BEADS}...")

TaskCreate(subject: "FINAL: Session summary + quality gate ({TARGET_BEADS} beads total)", description: "Full quality gate (format, lint, type-check, test, build), report results, hand off to bead-land. Do NOT implement more beads after this.", activeForm: "Running final quality gate...")
```

**As each bead is selected in Phase 1a, update the corresponding task:**

```
TaskUpdate(task: "Bead {N} of {TARGET_BEADS}", subject: "Bead {N} of {TARGET_BEADS}: <actual-bead-id> - <bead-title>", status: "in_progress", description: "Implementing bead <id>: <title>", activeForm: "Implementing <bead-title>...")
```

**TaskUpdate(task: "Phase 0", status: "completed")**

### Compaction Recovery

If `$ARTIFACTS_DIR/progress.md` exists, parse its header to recover `TARGET_BEADS`. Count entries marked `COMPLETE` to recover `BEADS_COMPLETED`. Skip completed beads. The claim-id-keyed `ARTIFACTS_DIR` is stable across compaction — recover it from the `Session config` TaskCreate description (which stores the literal resolved path) or from the `.claim-id` file inside a located dir if the variable is lost; never re-derive from `git branch --show-current` (trunk-direct collapses every branch to the constant `main` — no longer a valid key).

If `$ARTIFACTS_DIR/` was deleted and recreated mid-session (e.g., by a partial bead-land run), result files for completed beads are lost. Note this in progress.md as "(result file lost — bead completed, committed as <hash>)".

---

## BEAD LOOP: Phases 1a–1e

### Phase 1a: Select Bead

**First iteration only — claim the target batch (CLAIM-AT-SELECTION).** Before selecting
the first bead this session works, determine the candidate set it will draw from (the same
`refined`, non-`human-gate` ready-bead filter used above) and claim ALL of them up front, in
ONE call — not incrementally as beads are picked:

```bash
# CLAIM_ASSIGNEE is the identity ALL bead claims land under this session — the
# batch claim AND every later incremental/replacement claim (Phase 1a below).
# When ac-loop delegated to you it hands its OWN Agent Mail identity as
# CLAIM_ASSIGNEE (in the delegation prompt); use it verbatim so the loop's
# BEADS-CLOSED-GATE — which queries the LOOP identity — can see your claims.
# Standalone (no delegation), it defaults to your own session AGENT_NAME.
# NOTE: this is the bead ASSIGNEE only; Agent Mail FILE reservations still use
# your own session AGENT_NAME (they coordinate the shared checkout per-session).
CLAIM_ASSIGNEE="${CLAIM_ASSIGNEE:-$AGENT_NAME}"
br update <id1> <id2> ... --status in_progress --assignee "$CLAIM_ASSIGNEE"
```

This is the CLAIM-AT-SELECTION mechanism (precedent: body-compass-app memory
`claim-adopted-beads-before-planning` — claim before you plan/implement, generalized here to
every batch): a claimed bead's status is `in_progress`, so `br ready` naturally excludes it
for every other conductor — no new gating logic needed. If this session was itself invoked by
`ac-loop`, the loop already did this claim before delegating — skip re-claiming beads whose
IDs were handed to you as "already claimed" in the delegation prompt.

> **Single-identity contract (bd-w504y).** The loop's pre-close BEADS-CLOSED-GATE scopes by
> bead ASSIGNEE. If a delegated session claimed replacement beads under its OWN self-registered
> name instead of the loop's, `br list --assignee <loop-identity>` would MISS them and the gate
> would fail OPEN (green-light a merge with a genuinely open in-scope bead). Threading
> `CLAIM_ASSIGNEE` onto EVERY claim keeps the whole batch visible under one identity. The gate
> ALSO unions any delegated identities it was told about (defense in depth), but do not rely on
> that — claim under `CLAIM_ASSIGNEE` and report your registered name back in your summary.

Mint the batch's CLAIM ID **once**, at the moment of claiming: `<first-claimed-bead-id>-<YYYYMMDD>`
(e.g. `bd-u2lo1.1-20260712`). Write it to `$ARTIFACTS_DIR/.claim-id` (first line = the claim
id — a FILE, not an env var, since downstream skills read it from a fresh process) and mirror
it as the first line of `$ARTIFACTS_DIR/progress.md`'s header. Downstream skills (RUN_ID
re-keying, bd-u2lo1.9) read the claim id verbatim from `.claim-id`.

On later loop iterations within the same session, only claim a bead individually (same
`--status in_progress --assignee "$CLAIM_ASSIGNEE"` call — the SAME identity as the batch, never
your own session name when delegated) if it falls OUTSIDE the batch already claimed above
(e.g. a candidate went blocked mid-session and was replaced by the next-ready bead) — the
rest of the batch is already claimed and stays that way until closed.

**Re-verify branch context BEFORE claiming.** Branch state is dynamic in this workflow — multiple Claude sessions sharing one git checkout can switch the branch between operations via serial hand-off. Phase 0's branch check is a snapshot; treat it as stale on every loop iteration.

```bash
git branch --show-current
```

If the branch is not `main`, STOP. Do not silently `git checkout` back (that could clobber another session's uncommitted work sitting in the shared tree). Surface the drift to the user, ask whether to wait, switch back, or exit. **Do NOT create a git worktree** — trunk-direct means a single shared checkout is the deliberate convention here; spawning a worktree forks state invisibly (incident: worktree-drift — `references/incidents.md`).

```bash
bv --robot-next
```

This returns the top pick AND a claim command.

> ⚠️ **The claim command robot-next prints uses `bd`, but this repo's binary is `br`.** `bv --robot-next` emits `bd update <id> --status=in_progress`; running it verbatim fails with `command not found: bd`. Translate to **`br update <id> --status=in_progress`** (incident: bd-br-translation — `references/incidents.md`).

**Guard: verify the selected bead carries `refined` and is not human-gated.** Readiness is presence of `refined`, not absence of `unrefined`. Check the bead's labels — if it lacks `refined`, or has `human-gate`, skip it and pick the next one:

```bash
# Check the selected bead's labels: must have refined, must not have human-gate
br show <id> --json | jq '.[0].labels | ((index("refined") | not) or index("human-gate"))'
```

If the bead is not `refined`:
1. Do NOT claim it
2. If it carries no lifecycle label at all, add `unrefined`: `br label add <id> "unrefined"`
3. Log: "Skipping <id> (missing `refined` — needs `/ac-bead-refine` first)"
4. Get the next candidate from `br ready --json | jq '[.[] | select(.labels | index("refined"))] | .[0]'`
5. If no refined beads remain, STOP the session early

**Guard: reserve bead files via Agent Mail.** Before claiming, reserve the bead's files using `AGENT_NAME` (registered via `macro_start_session` in Phase 0 — unique per session). If the call returns a conflict, this bead is taken:

```
mcp__mcp-agent-mail__file_reservation_paths(
  project_key: CANONICAL_PROJECT_KEY,   // the app's canonical Agent Mail key from its session-start.md (pattern: "neometa/<app-dir>", e.g. "neometa/body-compass-app") — NEVER an absolute path: abs paths fork a per-machine mailbox (split-brain)
                                        # mirror: _shared/agent-identity.md — edit there first
  agent_name: AGENT_NAME,
  paths: ["<files listed in bead spec>"],
  ttl_seconds: 7200,
  exclusive: true
)
```

On `FILE_RESERVATION_CONFLICT`:
1. Do NOT claim it
2. Log: "Skipping <id> (file conflict with <agent> — already being worked)"
3. Get the next candidate from `br ready --json` and repeat both guards (refined + conflict)
4. If no conflict-free beads remain, STOP the session early

On success: reservation is held. The pre-commit guard (installed in Phase 0) will enforce it at commit time as a second layer.

**Guard: verify environment prerequisites.** Bead specs sometimes assume infrastructure that isn't available in the current session (Mac/Xcode for iOS native, local Supabase for integration tests, Android emulator for ADB-driven tests). `bv --robot-next` does NOT check this — it scores by priority and unblocks only, and it will happily recommend `in_progress` beads whose remaining ACs are Mac-only or whose specs reference local infra that was never set up.

After `br show <id>` + `br comments <id>` but BEFORE claiming, scan the spec's Files / Steps / Acceptance Criteria for these signals:

| Signal in bead spec | Required env |
|---|---|
| `*.swift`, `*.metal`, `xcodebuild`, `npx cap open ios`, "Mac-only", "TestFlight" | macOS + Xcode |
| `supabase migration up --local`, `pnpm test:integration`, `supabase_db_*` container, `supabase status` | Local Supabase stack |
| `*.kt`, `gradle`, `adb`, "emulator" | Android SDK + emulator |

If the bead requires absent infrastructure:
1. Do NOT claim it
2. Add a comment via `br comments add <id> "Env-blocked: <reason>. Needs <required-env> or a /ac-bead-refine round to pick an alternative path."`
3. Get the next candidate from `br ready --json`
4. Burning a bead slot on a no-op attempt is equivalent to claiming a not-yet-`refined` bead — skip it. (incident: env-blocked-claims — `references/incidents.md`)

**Guard: premise-check `## Consumes` (I/O contract, `_shared/bead-conventions.md` §Bead I/O contract).** For each Consumes line (`<blocker-id> → <artifact>`; a literal `- none` passes trivially), verify the premise holds on the CURRENT tree before spending an engineer session on it: the named artifact exists (file path `ls`-checks, symbol/route/table greps, migration file present) and the blocker bead is closed (`br show <blocker-id> --json`). Also check the blocker's close comment — it records delivered artifact paths (Phase 1d), which is the fastest verification. If any consumed artifact is missing:

1. Do NOT claim it; do NOT dispatch an engineer
2. `br comments add <id> "Premise failure: consumes <artifact> from <blocker-id> — not found on main (checked: <what you checked>). World moved since refinement."`
3. De-stamp: `br label remove <id> refined && br label add <id> unrefined` — stale premises are refine's to reconcile; only `/ac-bead-refine` re-earns the stamp (stripping `refined` on hard evidence is allowed; adding it never is)
4. Release any reservation taken for it, get the next candidate from `br ready --json`, repeat all guards

A bead with no `## Consumes` header at all predates the contract (legacy) — log it and proceed; do not bounce legacy beads for missing paperwork.

**Once a refined, conflict-free, env-supported, premise-verified bead is confirmed**, run the claim command from the output — do not use `br start` (it doesn't exist).

Then read bead details:

```bash
br show <id>
br comments <id>
```

**Update the corresponding bead task with the actual bead ID and title:**

```
TaskUpdate(task: "Bead {BEADS_COMPLETED + 1} of {TARGET_BEADS}", subject: "Bead {BEADS_COMPLETED + 1} of {TARGET_BEADS}: <bead-id> - <bead-title>", status: "in_progress", activeForm: "Implementing <bead-title>...")
```

### Phase 1b: Identify Skills + Spawn Engineer Sub-Agent

**Reality-check the spec's existence claims (conductor's job, ~30s).** For every file, type, test target, or "X already exists / has N tests" claim in the bead spec, run a quick grep/ls verification BEFORE spawning the engineer, and paste any corrections into the engineer prompt. Bead specs go stale between refine and implement — refine verifies against the codebase as of ITS run, and intervening beads invalidate claims (incident: stale-spec-claims — `references/incidents.md`). Do this for every bead, not just ones the native-testing skill flags.

**Engineering skill first (conductor's job):** Before identifying domain skills, load this project's engineering standard declared in `CORE/SKILL.md` (§ "Engineering standard"). For all current neoMeta apps this is `capacitor` (`capacitor/SKILL.md`). Include it in the engineer prompt for any bead touching UI, navigation, data fetching, auth, storage, lifecycle, or build.

**Skill routing (conductor's job):** Read the bead spec and identify relevant domain skills from `AGENTS.md` > "Available Skills". Include the relevant skill paths in the engineer prompt below.

Give the engineer the bead's full spec (self-contained — no plan reference needed):

Spawn the engineer using the prompt in **`references/engineer-prompt.md`** — paste the bead's full `br show <id>` + `br comments <id>` into its `### Bead Spec` section, and add the relevant domain skill paths (from `AGENTS.md > Available Skills`) after the AGENTS.md line. The prompt carries the TDD flow, the no-stash rule, the scope contract, cross-bead shared-invariant rules, the four-location test-sweep guidance, and the mandatory result-file `### Output` contract.

### Phase 1c: Review Quality (Conductor's Core Job)

**YOU are the quality gate.** Read the engineer's result file and verify:

**Worktree mode only:** Before copying files from a worktree, verify no uncommitted changes: `git -C <worktree> status --porcelain`. If uncommitted changes exist, commit them in the worktree first. `cp` reads the filesystem (committed state), not the working tree — uncommitted edits will be silently lost.

1. **Run bead-relevant tests IN THE MAIN REPO** (not full suite — just what this bead touches). Do NOT trust worktree test results — module resolution and mock behavior may differ between the worktree and main repo. Run tests AFTER copying files but BEFORE committing:

   ```bash
   pnpm test    # vitest-affected (~30s) — per-bead canonical
   # Or scoped: pnpm vitest run <specific test files> for targeted verification.
   #
   # NEVER `pnpm test:all` per-bead — that runs the full 6500+ suite (~10 min)
   # with the affected plugin disabled. test:all is reserved for Phase Final
   # (session-end quality gate) and merge.
   ```

   **For beads with e2e specs or bundle-exclusion ACs: always re-run independently, regardless of what the engineer's result file claims.**
   - E2e: `pnpm playwright test tests/e2e/<spec>.spec.ts --reporter=line`
   - Bundle exclusion: `pnpm build && pnpm verify:no-scripted` (fresh build, not cached `.next/`)

   These two claim types had a 2/2 false-green rate on first engineer rounds (incident: false-green-claims — `references/incidents.md`). Do NOT approve until you have personally observed green output.

2. **Pre-existing test regression check** — For each file the engineer modified, use the Grep tool (pattern: `<module-path>`, glob: `*.test.*`, paths: `__tests__/` and `features/`) to find existing tests. Run any found. This catches regressions the engineer missed (e.g., container tests broken by new imports).

3. **Lint + type-check** — catch errors early:

   ```bash
   # Run project lint and type-check commands
   # See AGENTS.md > Project Commands > Lint, Type-check
   ```

   (Full build deferred to session-end quality gate — too slow per-bead.)

4. **Test coverage verification** — confirm the engineer actually wrote new tests:
   - Read the engineer's result file for "Test files created/modified"
   - If the bead adds new functionality (modules, handlers, utilities, etc.) there MUST be new test files or new test cases
   - If the engineer's report lists zero new tests for new code, **re-spawn the engineer** with explicit instructions to add test coverage
   - Pure refactors or config changes may not need new tests — use judgment

5. **Acceptance criteria check** — does the implementation match the bead's spec? Tests passing is necessary but not sufficient. If the spec says "move" a file, verify the original is deleted and all imports updated — leaving the original creates dead code.

6. **Human-gate check** — if the bead has a `human-gate` label, the conductor MUST present each substantive decision to the user for approval BEFORE committing. Gate decisions, ground truth values, classification rationales, and any domain-knowledge claims require explicit user sign-off. Do NOT auto-close human-gate beads based on passing tests alone — the human review IS the gate.

7. **Migration-validate gate (detection-by-artifact)** — if the bead's diff adds or changes a `supabase/migrations/*.sql` file AND the app's `CORE/supabase.md` documents a local-validate requirement, the bead is NOT "done" until the app's local-validate gate is green (typically `pnpm db:verify` = `supabase db reset` replay-from-zero + local integration tests). This is the one place an RLS/escalation bug surfaces before it touches shared prod — passing units is not sufficient. Trigger on the migration FILE in the diff, not a label (labels get forgotten). Skip silently for apps with no local stack or for purely additive/reversible migrations the app's doctrine exempts. The prod `db push` itself stays a separate, human-approved step (handled at merge, never auto-run here). See the `supabase` skill § "Local-validate gate (risk-tiered)".

8. **Fresh-eyes diff scan:**

   ```bash
   git diff --stat
   git diff
   ```

UI validation is deferred to `/ac-land` where it runs once for the entire session with pre-authenticated browser state. This saves ~N browser-tester agent spawns (one per bead) without reducing coverage.

**If minor issues:** Fix them directly. You are the conductor — small fixes are faster than re-spawning.

**If major issues:** Re-spawn an engineer sub-agent for the same bead with specific feedback on what's wrong or incomplete. Include the previous result file for context. Repeat until satisfied.

**Be extremely strict.** Do not move to the next bead until this one is fully complete.

### Phase 1d: Commit + Close Bead

**Always use the pathspec commit form (`git commit -- <files>`), not `git add` + `git commit`.** A second session sharing the checkout can sweep your staged files into THEIR commit before you call `git commit` (incident: staged-sweep — `references/incidents.md`). Pathspec commits are atomic and self-documenting — there's no window between staging and committing where state can drift.

```bash
git commit -m "feat(<scope>): <bead title>

Bead: <id>
Co-Authored-By: Claude <noreply@anthropic.com>" -- <file1> <file2> <file3>
git push
```

The `--` separator tells git: "ignore the index, commit exactly these working-tree paths." Your `git add` work and any other session's `git add` work both stay isolated.

For many files at once, globs work in the pathspec: `git commit -m "..." -- 'features/auth/**/*.ts' '.beads/issues.jsonl'`.

> **New (untracked) files need `git add` first.** Pathspec commits only operate on git-tracked paths. For a brand-new file (a new test guard, a new module), `git commit -- <newfile>` fails with `pathspec did not match any file(s) known to git` and exits non-zero. Stage it first, then pathspec-commit exactly that path — still scope-safe, since the pathspec limits the commit to your file regardless of what else is staged:
> ```bash
> git add path/to/new-file.ts
> git commit -m "..." -- path/to/new-file.ts
> ```
> (incident: untracked-pathspec-close — `references/incidents.md`)
>
> **NEVER put `br close` in the same bash block as the `git commit`.** Bash continues past a failed commit, so a chained `br close` closes the bead in the tracker with no matching commit — a silent correctness hazard. Run the commit in one call, verify it landed (`git log --oneline -1` shows your commit, or check `$?`), then `br close` in a separate call.

Push after every bead commit prevents stranded work if the session crashes before bead-land.

**Verify commit landed before closing.** (`git log --oneline -1` shows your commit hash, confirming it succeeded.) Only then:

**Delivers gate (I/O contract, `_shared/bead-conventions.md` §Bead I/O contract):** before closing, verify each `## Delivers` item exists in the committed result — same grep/ls-level check as the Phase 1a premise guard, against what you just committed. A promised artifact that doesn't exist means the bead is NOT done: back to Phase 1c review, don't close around it. Then record the delivered artifacts in the close reason — downstream beads' premise checks read this:

```bash
br close <id> --reason "Implemented and tested. Delivered: <artifact paths, comma-separated>"
```

(Legacy beads with no `## Delivers` header: close with the plain reason as before.)

Release the file reservation using the **same paths reserved in Phase 1a** (the bead spec file list, not just the files committed — releasing over-reserved paths is harmless; leaving them locked starves parallel sessions):

```
mcp__mcp-agent-mail__release_file_reservations(
  project_key: CANONICAL_PROJECT_KEY,   // the app's canonical Agent Mail key from its session-start.md (pattern: "neometa/<app-dir>", e.g. "neometa/body-compass-app") — NEVER an absolute path: abs paths fork a per-machine mailbox (split-brain)
                                        # mirror: _shared/agent-identity.md — edit there first
  agent_name: AGENT_NAME,
  paths: ["<same paths passed to file_reservation_paths in Phase 1a>"]
)
```

> **If the commit failed:** do NOT release reservations. The files still need to be worked. Fix the commit issue first (see the pathspec note above), then release after a verified commit.

### Phase 1e: Update Progress

**Mark bead task as completed:**

```
TaskUpdate(task: "Bead {BEADS_COMPLETED + 1} of {TARGET_BEADS}", status: "completed")
```

Append to `$ARTIFACTS_DIR/progress.md` (include header on first write):

```markdown
<!-- Header (first bead only) -->

TARGET_BEADS={TARGET_BEADS}
WAVE={WAVE_SLUG}

### Bead <id>: <title>

- Status: COMPLETE
- Commit: <hash>
- Files: <list of modified files>

COMPLETED: {BEADS_COMPLETED} / {TARGET_BEADS}
```

Increment `BEADS_COMPLETED`.

**Loop control:**

- If `BEADS_COMPLETED >= TARGET_BEADS` → exit loop
- If no more unblocked beads (`br ready --json` returns empty) → exit loop
- Otherwise → loop back to Phase 1a

---

## Phase Final: Session Summary

**TaskUpdate(task: "FINAL: Session summary + quality gate ({TARGET_BEADS} beads total)", status: "in_progress")**

### Report

Output summary:

- Beads completed (count + list with IDs)
- Beads remaining (`br ready --json`)
- Any issues encountered

### Wave Quality Gate (affected)

Run the wave's **affected** tests — the full suite is relocated to the loop-close CI run
(`ac-land` fires it; parallel-execution doctrine §5 Tier 2), so it no longer runs per wave:

```bash
pnpm test 2>&1 | tail -20     # vitest-affected across the whole wave's diff vs main
```

If any fail, fix the issues before proceeding. **Standalone, non-loop use:** if you will NOT run
`ac-land` / a loop-close full run before shipping this wave, run `pnpm test:all` here instead —
nothing else will run the full suite.

> **Parallel sessions:** Failing tests may originate from another session's uncommitted changes in the working tree. Run `git diff --stat HEAD` to identify which files are uncommitted — check their Agent Mail reservations to determine which session owns them. Failures in files not touched by this session's commits are owned by the other session — note them but do not block landing.

### Next Steps

**Run `/ac-review` next (recommended).** `/ac-review` is the sole pre-merge gate — it must complete before `/ac-merge`. `/ac-land` is NOT a pre-merge gate: it's the closing ritual (teardown + retrospective) that runs LAST, after the wave has merged to main — run it manually when not driven by `/ac-loop`. Do NOT run `/ac-merge` until review has completed. Do NOT run `/ac-land` before merge — it has nothing to close out yet.

**Present next step with `AskUserQuestion`** — Ask (header: "Next step", single-select): "Bead-work session complete ({BEADS_COMPLETED} beads). What's next?" — options: "Review branch (Recommended)" (Run /ac-review — the pre-merge gate. Then /ac-merge.) / "Continue implementing" (Run /ac-implement again for more beads (review + merge later)) / "Done for now" (Stop here — remember to run /ac-review then /ac-merge before closing; /ac-land runs after merge).

**TaskUpdate(task: "FINAL: Session summary + quality gate ({TARGET_BEADS} beads total)", status: "completed")**

---

## Multi-Session Parallelism

```
Terminal 1: /ac-implement   → "target 5 beads"
Terminal 2: /ac-implement   → "target 5 beads"
```

This skill is parallel-by-design — no mode switch needed: the mechanics above already handle it (trunk-direct on `main` · Phase 1a reservations + Phase 0 pre-commit guard · pathspec commits · shared `ARTIFACTS_DIR` with append-only progress.md and per-bead result files).

`bv --robot-next` is global-priority, not wave-aware; conductor must filter to the wave's labels OR pick from a different epic when the wave's chain is sequentially gated.

Pre-push `pnpm build` reads the working tree — another session's uncommitted WIP can block your push. If this happens, identify the conflicting files via `git diff --stat HEAD` and check their Agent Mail reservations.

---

## Remember

- **Trunk-direct: work on `main`, never create a branch** — commits are pathspec-limited to your reserved files, and every commit is immediately pushed (commit = push). Engineers implement; **YOU review, YOU commit** — be extremely strict, a bead must be fully complete before moving on. Minor fixes: do them yourself; major gaps: re-spawn the engineer.
- **Compaction recovery** — progress.md is the state: parse its header for TARGET_BEADS, count COMPLETE entries for BEADS_COMPLETED; recover `ARTIFACTS_DIR` from the `Session config` task description or `.claim-id` if lost (never re-derive from `git branch --show-current` — trunk-direct collapses every branch to `main`). "Bead X of N" task naming prevents drift — the task list IS the stop condition.
- **Quality cadence** — per-bead: tests + type-check + lint, and no new code without new tests (verify the engineer wrote them before approving); full quality gate at session end; UI validation runs once at session end (in bead-land), not per-bead.
