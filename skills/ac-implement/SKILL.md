---
name: ac-implement
description: 'Sequential bead implementation — conductor reviews, engineer sub-agents implement, loops until the wave is done. Triggers: ''work the beads'', ''implement the wave'', ''bead work'', ''run the wave'', ''start implementation'' (of a refined bead wave). NOT for a bare coding request with no bead behind it — just write the code.'
---


**You are the conductor.** Engineers implement. You review, verify, and commit. One bead at a time. Quality over velocity.

Multiple sessions can safely share a wave — file reservations via Agent Mail prevent conflicts.

---

## I/O Contract

|                  |                                                                                            |
| ---------------- | ------------------------------------------------------------------------------------------ |
| **Input**        | Unblocked beads (from `/ac-bead-refine`)                                       |
| **Output**       | Implemented code, committed per bead, pushed directly to `main` (trunk-direct)             |
| **Artifacts**    | Under `/tmp/bead-work-<claim-id>-<child-id>[-<run-id>]/`: per-bead results in `bead-{id}-result.md`, progress in `progress.md` |
| **Verification** | Per-bead quality gate (test, lint, type-check), beads closed in `br`                       |

## Phase 0: Initialize

**MANDATORY FIRST STEP: declare the run ledger (`ac-pipeline/references/run-ledger.md` — one task per section, advance as you go) with TaskCreate BEFORE starting (after asking user for bead count).**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

### Inventory the Working Tree — H7d: Never Commit Foreign WIP (FIRST)

```bash
git status --short
```

Under trunk-direct, every session works directly on `main` with no branch isolation — a non-empty `git status --short` is EXPECTED and, by itself, is NOT a blocker. It may contain another concurrent session's in-flight, not-yet-committed work.

**Inventory it; do not touch it.** Uncommitted changes in files you have not reserved via Agent Mail (Phase 1a) belong to someone else's session. Leave them exactly as found — do not stage them, do not commit them "on their behalf," do not group them into "logical" commits, do not delete or revert them. If anything in the inventory looks like a genuine red flag (unexpected deletions, sensitive files, something clearly orphaned rather than in-flight), flag it to the user before proceeding — otherwise, proceed past it.

**The rule that keeps committed state clean under concurrent editing (H7d): only files
YOU reserved may enter YOUR commits — pathspec-mandatory, `git commit -- <files>`, never
a wildcard add.** Full canon + rationale: `ac-pipeline/references/commit-discipline.md`. Binding from
Phase 0 onward.

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
> absence of `unrefined` (`skills/beads-standards/reference/bead-conventions.md`) — a well-written
> description is not a refined spec.

**Filter to beads carrying `refined`, excluding human-gated beads.** Beads created by `/ac-beadify` (or `ac-triage`, or `ac-bead-capture`) carry the `unrefined` label until `/ac-bead-refine` — the label's sole source, with no exceptions — stamps `refined` on convergence. Beads labeled `human-gate` (decision beads — see `skills/beads-standards/reference/bead-conventions.md`) may be ENRICHED by agents but never selected for implementation or closed. Only beads carrying `refined` and NOT carrying `human-gate` are eligible:

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
  project_key: CANONICAL_PROJECT_KEY,   // canonical "neometa/<app-dir>" key — key-format + never-absolute rule: agent-mail/references/agent-identity.md § Project key format
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

### Baseline Check (read the last full-suite run; don't re-run full per wave)

Confirm you're starting from a green `main` before building on it. With the `vitest-affected`
fixture-cascade upgrade, affected-mode is trustworthy, so the full-suite masking-catch is
**relocated to PUBLISH START** (`ac-publish` runs `ac-prove ensure --fix-forward`, SHA-pinned to
the commit being published — bd-pwt44; `ac-land` fires nothing at loop close).
Read the most recent full-suite result instead of re-running the suite per wave.
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
- **No recent full-suite run, or no CI workflow** (standalone use, `main` advanced since, or the
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

> **Wait for long local runs IN-SHELL — never detach from your own command** (`ac-pipeline/references/delegation-contract.md` § clause 5, self-detachment). The expensive fallback `pnpm test:all` here — and the wave quality gate's `pnpm test` at session end — are long-running LOCAL commands. Do NOT `run_in_background` them, arm a `Monitor`, and end your turn "waiting for completion": that is the self-detachment stall (this exact ac-implement phase stalled twice, RUN_ID=20260710-170558-52993). Run them in the foreground with a generous Bash timeout, or a foreground `pgrep`/poll until-loop — the turn does not end until the command returns and you have read its result.

### Scoped Per-Commit Readiness Gate (H7 v3) + Push Cadence

This is the gate that runs at **every** commit for the rest of the session (Phase 1d), not just once here — establishing it in Phase 0 so it's binding for the whole loop. Under trunk-direct there is no wave branch acting as a buffer, so this gate — plus post-push CI — is the only thing keeping `main` clean.

**The gate is scoped to YOUR OWN diff, never the whole project:**

1. **Format (belt-and-braces — do NOT rely on the pre-commit hook firing).** Run `lint-staged` (or the project's equivalent) on YOUR OWN staged files, THEN — independent of whether the git pre-commit hook actually executed — explicitly verify those same staged files are prettier-clean before committing: `pnpm prettier --check <your staged paths>` (staged paths only — keep it cheap). If it reports any unformatted file, `pnpm prettier --write <those paths>`, re-stage, and re-check until clean; do not commit while it reports failure. This gate keys on the staged paths themselves, never on a hook side effect: the `.husky/pre-commit` → `lint-staged` chain is correct and effective, but a bypassed or non-firing hook (an ad-hoc `--no-verify` on commit, or a working tree where `hooksPath`/`lint-staged` env isn't active) can let an unformatted staged file reach a commit and fail CI's whole-repo prettier check. Git objects don't record whether a hook ran, so this is a belt-and-braces check that survives a bypassed hook, NOT a fix for a specific known bypass path.
2. **`ubs <changed-files>`** — pass the exact list of files YOU changed. **Never `ubs .`** — a whole-project scan is a jef-flywheel anti-pattern: it re-surfaces every pre-existing issue in the repo on every commit and buries your own signal in noise that isn't yours to fix.
3. **`pnpm test` (vitest-affected) scoped to YOUR OWN diff** — not the full suite (that's session-end and loop-close territory, per the Baseline Check note above).
4. **Whole-project `tsc`** — this one check is necessarily whole-project (TypeScript has no per-file mode), so triage its output by attribution rather than treating every red line as yours to fix:
   > A `tsc` error in a file you didn't touch that does NOT import your changed files is foreign-WIP noise → log it and proceed (push-CI re-checks committed state in ~4 min). An error in your own file, or in a file that imports your changes, is yours → fix it before committing.

**Cadence: commit every 15–20 minutes.** Do not batch a whole bead — or worse, a whole session — into one commit; granular commits are both the revert points and the unit of concurrency-safety under H7d.

**Commit = push. Always. Mandatory, not optional.** There is no wave branch holding your
work safe in the interim — origin is the only durability record; a crashed session with
unpushed commits is lost work, not "recoverable from the branch," because there is no
branch. **The full sequence (fetch/0-behind check, pathspec commit, `--no-verify` push +
its rationale, SHA verify) and the foreign-WIP escalation ladder (fetch+fast-forward;
discard foreign generated files you did NOT author — never stash) are canon: `ac-pipeline/references/commit-discipline.md`** § Commit +
push sequence, § No-stash escalation ladder. Push collision → `git pull --rebase` and
re-push; never force-push over another session's committed work.

### Ask User

Ask one question via `AskUserQuestion`:

1. "How many beads to target this session?" (default: all unblocked)

### Configuration

```bash
TARGET_BEADS=<user input>
BEADS_COMPLETED=0
# Deterministic dir keyed on the CLAIM/BATCH ID, never the branch — trunk-direct puts every
# conductor on `main`, so `git branch --show-current` no longer discriminates concurrent
# sessions (bd-u2lo1.9 re-keying). Contract: ac-pipeline/references/run-id.md. ac-land lands this same path.
#
# If ac-loop already claimed this batch and delegated (claim id handed in the prompt, e.g.
# "claim id `bd-u2lo1.1-20260712`"), use it verbatim below — do not re-derive.
#
# If this is a standalone first run (no claim id handed down yet), Phase 1a's
# claim-at-selection is the moment the batch is actually *claimed* (mint format:
# <first-claimed-bead-id>-<YYYYMMDD>), but it writes `.claim-id` INTO $ARTIFACTS_DIR — which
# needs to already exist. Resolve that ordering (contract: ac-pipeline/references/run-id.md "Mint order") by
# computing the identical string here, ahead of the `br update` mutation: the first bead ID in
# the refined, non-human-gate ready-bead candidate list already gathered above ("Verify
# Refined Beads Exist") + today's date. Phase 1a recomputes the same string when it actually
# claims, from the same unmutated candidate-list ordering and the same date — no mismatch.
CLAIM_ID="${CLAIM_ID:-<first-candidate-bead-id>-$(date +%Y%m%d)}"   # handed-down or self-derived
WAVE_SLUG="$CLAIM_ID"   # alias for other in-file references to this key (task labels, progress.md header) — same value, not a re-derivation
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"   # mint if no orchestrator handed one down
# net-growth-ok: ac-wno per-child bead-work key
# Per-child key — UNCONDITIONAL, every implement session, fanned out or not (ac-wno; precedent
# bd-baudw @ ac-bead-refine/references/workflow.md:64-71): CLAIM_ID+RUN_ID are batch/run-scoped so
# neither separates siblings; `$$` covers AGENT_NAME being unset this early (identity is minted
# below); RUN_ID stays LAST or ac-land's `/tmp/bead-work-*-$RUN_ID` glob stops matching.
CHILD_ID="$(printf '%s' "${AGENT_NAME:-anon}" | command tr -cd 'A-Za-z0-9')-$$"
ARTIFACTS_DIR="/tmp/bead-work-${CLAIM_ID}-${CHILD_ID}${RUN_ID:+-$RUN_ID}"
```

### Register Session Identity

Register a unique identity for this implement session — used for file reservations and
pre-commit guard attribution. **Run the mint + token/export discipline per
`agent-mail/references/session-procedure.md` (§ Mint, § Export)** — capture `name` + `registration_token`;
explicit token threading and the per-shell `AGENT_NAME` re-assert (which the pre-commit
guard depends on at every `git commit`) live there. Parallel ac-implement sessions each
mint their own distinct name — no manual discriminators.

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
# HARD RULE (ac-ycr.6; doctrine agent-mail/references/agent-identity.md): FoggyCreek is the Tier-2 chore
# identity and may NEVER be a bead assignee. If CLAIM_ASSIGNEE resolved to it (a dropped
# delegation value, or $AGENT_NAME fell back to the settings.json default in a fresh shell),
# FAIL LOUDLY — never claim the batch under the shared chore identity (silent misattribution
# the BEADS-CLOSED-GATE then rejects anyway).
[ "$CLAIM_ASSIGNEE" = "FoggyCreek" ] && { echo "FATAL: CLAIM_ASSIGNEE=FoggyCreek — cannot claim beads under the Tier-2 chore identity; pass the loop's minted identity (or re-assert this session's AGENT_NAME)" >&2; exit 2; }
br update <id1> <id2> ... --status in_progress --assignee "$CLAIM_ASSIGNEE"
# Strip `post-merge` from every bead being claimed (single bead-conventions claim-semantics
# rule — beads-standards/reference/bead-conventions.md § post-merge claim semantics). An exhaust bead adopted
# into THIS batch must be closeable again; leaving `post-merge` on it strands a gate-invisible
# zombie (open forever, never counted by beads-closed-gate.sh). Harmless no-op if unlabeled.
for id in <id1> <id2> ...; do br label remove "$id" post-merge 2>/dev/null || true; done
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
rest of the batch is already claimed and stays that way until closed. **This incremental /
replacement claim strips `post-merge` too** (`br label remove <id> post-merge`) — the
strip-at-claim rule holds on EVERY claim path, not just the up-front batch claim, so no
adopted exhaust bead ever re-enters work still carrying its gate-excluding label.

**Re-verify branch context BEFORE claiming.** Branch state is dynamic in this workflow — multiple Claude sessions sharing one git checkout can switch the branch between operations via serial hand-off. Phase 0's branch check is a snapshot; treat it as stale on every loop iteration.

```bash
git branch --show-current
```

If the branch is not `main`, STOP. Do not silently `git checkout` back (that could clobber another session's uncommitted work sitting in the shared tree). Surface the drift to the user, ask whether to wait, switch back, or exit. **Do NOT create a git worktree** — trunk-direct means a single shared checkout is the deliberate convention here; spawning a worktree forks state invisibly (incident: worktree-drift — `references/incidents.md`).

```bash
bv --robot-next
```

This returns the top pick AND a claim command.

> **`bv` ≥ 0.18 emits `br` natively.** `bv --robot-next`'s `claim_command` is already `br update <id> --status=in_progress`, so run it verbatim. The old `bd`→`br` translation was only needed on `bv` ≤ 0.16 and is retired. **Version assumption:** cross-machine `bv` parity is assumed, not re-checked per run; if some machine is pinned ≤ 0.16 and emits `bd update`, translate it to `br update`. History: `references/incidents.md` § bd-br-translation.

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
  project_key: CANONICAL_PROJECT_KEY,   // canonical "neometa/<app-dir>" key — key-format + never-absolute rule: agent-mail/references/agent-identity.md § Project key format
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

**Guard: premise-check `## Consumes` (I/O contract, `beads-standards/reference/bead-conventions.md` §Bead I/O contract).** For each Consumes line (`<blocker-id> → <artifact>`; a literal `- none` passes trivially), verify the premise holds on the CURRENT tree before spending an engineer session on it: the named artifact exists (file path `ls`-checks, symbol/route/table greps, migration file present) and the blocker bead is closed (`br show <blocker-id> --json`). That same call returns `.close_reason`, where Phase 1d records delivered artifact paths — the fastest verification. If any consumed artifact is missing:

1. Do NOT claim it; do NOT dispatch an engineer
2. `br comments add <id> "Premise failure: consumes <artifact> from <blocker-id> — not found on main (checked: <what you checked>). World moved since refinement."`
3. De-stamp: `br label remove <id> refined && br label add <id> unrefined` — stale premises are refine's to reconcile; only `/ac-bead-refine` re-earns the stamp (stripping `refined` on hard evidence is allowed; adding it never is)
4. Release any reservation taken for it, get the next candidate from `br ready --json`, repeat all guards

A bead with no `## Consumes` header at all predates the contract (legacy) — log it and proceed; do not bounce legacy beads for missing paperwork.

<!-- net-growth-ok: premise-check data-values guard (dream ac-tmp, Craig-applied) -->
**Guard: premise-check embedded factual claims.** Beyond artifact-existence, grep the
bead's spec for any stated data value or factual claim the fix logic depends on (a DB
row's field value, "column already exists", an assumed parent/child relationship) and
re-verify it against LIVE ground truth — DB query, schema, git tree — before coding.
Do not trust the refined spec's premise at face value even post-refine: specs go stale
between filing and implementation. A falsified premise turns the bead into a revert or a
close, not a fix.

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

<!-- net-growth-ok: dream ac-r5g affected-graph subset rule -->
**The affected-graph can silently subset an explicit test selection (conductor's job to pre-empt).** `vitest --affected` derives the suite set from the import graph, so a test asserting against a shared interface that does NOT import the changed file is silently dropped — and the run still exits 0. When the bead touches a shared interface (a type, schema, mock, fixture, API contract): (1) **name the affected suites in the engineer prompt** — the conductor knows what changed, the child sees only its own diff; (2) find the mock/assertion owners with `grep -rl "<changed symbol>" --include='*.test.*' .` — any hit outside the changed file's own suite is in scope; (3) `VITEST_AFFECTED_DISABLED=1` is pre-authorized for this case — the child does not need to ask.

**Engineering skill first (conductor's job):** Before identifying domain skills, load this project's engineering standard declared in `CORE/SKILL.md` (§ "Engineering standard"). For all current neoMeta apps this is `capacitor` (`capacitor/SKILL.md`). Include it in the engineer prompt for any bead touching UI, navigation, data fetching, auth, storage, lifecycle, or build.

**Skill routing (conductor's job):** Read the bead spec and identify relevant domain skills from `AGENTS.md` > "Available Skills". Include the relevant skill paths in the engineer prompt below.

**Doc/config-bead branch — no RED test, conductor-direct allowed.** The engineer-delegation default below is TDD/code-shaped: write a failing test first, then implement to green. That path is N/A for beads whose `## Delivers` are exclusively `doc:` / `config:` artifacts (skill text, doctrine, workflow JSON, prose — no code or tests), which is the shape of every SKILL-DOC/PROCESS bead. For those:

- The conductor MAY edit the artifact directly (these edits are small, precise, and anchor-verified — often faster than a round-trip), OR spawn a non-TDD doc-implementer with the same scope contract but no "write a RED test first" gate.
- The acceptance gate is NOT a passing test — it is the bead's own grep/diff on the edited artifact (the AC block), plus prettier-clean on touched files and a re-verify that the edit anchor still matched (skill line numbers drift between refine and implement).
- Everything else in this workflow still applies: pathspec-scoped commit of only your files, commit=push, per-bead close with `Delivered:` artifact refs. If a bead's Delivers mix code AND doc, treat it as code-shaped (TDD path below).

**Conductor-direct extension for mechanical CODE beads.** In addition to the doc/config path above, the conductor MAY implement a **code** bead directly (no engineer spawn) **only when ALL of the following hold**:

1. **Grep-checkable file+line edits** — the refined spec names exact file+line (or unique anchor) edits with acceptance criteria that are themselves grep/diff-checkable (not open-ended behavior).
2. **Mechanical over code with existing test coverage** — the edit is a mechanical transform over already-covered code (rename, wire an existing helper, one-line guard that existing tests already exercise). **No new behavioral surface** without existing coverage: if the bead introduces new behavior that current tests do not cover, conductor-direct is **forbidden** — spawn an implement child on the TDD path as today.
3. **Affected-test gate green post-edit** — after the edit, the conductor runs the project's affected tests (`pnpm test` / vitest-affected, or the bead's named test targets) and they pass green. This is the hard guard: **grep-checkable ≠ behaviorally safe**. The zero-defect record rode on the affected-test-green gate; never close a conductor-direct code bead on grep alone.

If any of the three fails (or is uncertain), fall through to the engineer-spawn path below. The doc/config conductor-direct doctrine above is unchanged and does not require the affected-test gate (its AC is the bead's own grep/diff).

For code/test-shaped beads that do **not** qualify for conductor-direct, give the engineer the bead's full spec (self-contained — no plan reference needed):

Spawn the engineer using the prompt in **`references/engineer-prompt.md`** — paste the bead's full `br show <id>` + `br comments <id>` into its `### Bead Spec` section, and add the relevant domain skill paths (from `AGENTS.md > Available Skills`) after the AGENTS.md line. The prompt carries the TDD flow, the no-stash rule, the scope contract, cross-bead shared-invariant rules, the four-location test-sweep guidance, and the mandatory result-file `### Output` contract.

### Phase 1c: Review Quality (Conductor's Core Job)

**YOU are the quality gate.** Read the engineer's result file and verify:

1. **Run bead-relevant tests** (not full suite — just what this bead touches). Run tests AFTER the engineer's edits land in the tree but BEFORE committing:

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

2. **Pre-existing test regression check** — For each file the engineer modified, use the Grep tool (pattern: `<module-path>`, glob: `*.test.*`, paths: `__tests__/` and `features/`) to find existing tests. Run any found. This catches regressions the engineer missed (e.g., container tests broken by new imports). **When the diff widens a shared type or changes which client/method a route calls, this grep must reach the mock OWNERS too** (hand-rolled `requireAuth`/supabase mocks), you must run that named set with **`VITEST_AFFECTED_DISABLED=1`** — `pnpm test <named-files>` INTERSECTS your explicit list with the git-diff set and silently runs a subset (observed 2-of-5 and 7-of-12) *while reporting green* — and the conductor must **pre-authorize the mock-owning suites in the engineer's scope contract**, or the child correctly refuses to edit the very files it must update (incident: affected-graph-intersects-explicit-selection — `references/incidents.md`).

   > **Red-test classification requires EVIDENCE — never accept "pre-existing" or "concurrent-session" at face value** (memory `verify-red-tests-against-history-before-preexisting-claim`). When an engineer's result file (or your own triage) classifies a failing test as pre-existing debt or another session's WIP rather than a regression THIS bead caused, that classification is only valid with one of two concrete proofs, recorded in the bead's progress/result notes:
   > - **History proof:** the same test was already red BEFORE this bead's diff — cite the Phase 0 Baseline Check result (the loop-close/`quality-gate.yml` run, or the local baseline) showing that test failing, or re-run it pinned to the pre-wave SHA with `VITEST_AFFECTED_REF=<pre-wave-SHA> pnpm test`. Do NOT use `git stash` or spawn a `git worktree` to get this (both banned under trunk-direct — Phase 0), OR
   > - **Symbol proof:** the failing assertions reference only symbols/files that this wave's diff does not touch (`git diff --stat` shows the test's subject-under-test is untouched by any commit in this session).
   >
   > Absent either proof, treat the red test as YOURS and fix it before closing. "Known pre-existing" without a proof is the same evasion phrase the Baseline Check rejects (`references/incidents.md` § baseline-preexisting).

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

Per-bead UI validation is deferred — `ac-land`'s 1c UI validation suite is **retired** (Wave-B). Web-UI journey coverage is now owned by **`ac-batch-close`'s QA Smoke Gate** (a conditional, web-UI-diff-triggered delegation to `ac-qa-browser` at smoke depth — a finer, per-batch cadence than the old once-per-session 1c pass; its registry-driven selection covers every journey with `criticality ≥ core` per `ac-pipeline/references/verification-gate.md`, so breadth ≥ 1c) and, for cross-batch interactions, **`ac-qa-browser`'s exhaustive crawl at publish**. This saves ~N per-bead browser-tester agent spawns without reducing coverage.

**If minor issues:** Fix them directly. You are the conductor — small fixes are faster than re-spawning.

**If major issues:** Re-spawn an engineer sub-agent for the same bead with specific feedback on what's wrong or incomplete. Include the previous result file for context. Repeat until satisfied.

**Be extremely strict.** Do not move to the next bead until this one is fully complete.

### Phase 1d: Commit + Close Bead

**Commit per the canon — `ac-pipeline/references/commit-discipline.md`:** the full one-stop sequence — fetch, 0-behind check, H7d pathspec
commit, `git add` first for NEW untracked files, `--pathspec-from-file` for route-group
paths `(…)`/`[…]`, no-stash escalation ladder — lives there; do not re-derive it here.
Bead-work commit shape:

```bash
git commit -m "feat(<scope>): <bead title>

Bead: <id>
Co-Authored-By: Claude <noreply@anthropic.com>" -- <file1> <file2> <file3>
git push
```

> **NEVER put `br close` in the same bash block as the `git commit`** — a chained close
> records the wrong SHA when the commit fails (`beads-standards` § br gotchas). Commit,
> verify it landed, then close in a separate call.

Push after every bead commit prevents stranded work if the session crashes before bead-land.

**Verify commit landed before closing.** (`git log --oneline -1` shows your commit hash, confirming it succeeded.) Only then:

**Delivers gate (I/O contract, `beads-standards/reference/bead-conventions.md` §Bead I/O contract):** before closing, verify each `## Delivers` item exists in the committed result — same grep/ls-level check as the Phase 1a premise guard, against what you just committed. A promised artifact that doesn't exist means the bead is NOT done: back to Phase 1c review, don't close around it. Then record the delivered artifacts in the close reason — downstream beads' premise checks read this:

```bash
br close <id> --reason "Implemented and tested. Delivered: <artifact paths, comma-separated>"
```

(Legacy beads with no `## Delivers` header: close with the plain reason as before.)

**Per-type close evidence** (`beads-standards/reference/bead-conventions.md` § Per-type close artifacts): after
the outcome verb, cite the evidence the bead's TYPE closes with — a `bug` names its regression
test, an `investigation` its findings + spawned fix beads (the `discovered-from` trail), a
`task`/`feature` its delivered-artifact refs (the `Delivered:` list above already satisfies
task/feature). Convention-enforced, not lint-checked.

**Worker-identity stamp (per bead, at close).** The bead's assignee is the CONDUCTOR (loop)
identity — the actual implementer is a per-child session + model, otherwise unrecoverable. So
immediately after `br close`, stamp WHO/WHAT implemented it as a structured comment (uses
`beads-standards` § Worker-identity stamp — a stable greppable prefix, sibling to the VERDICT grammar):

```bash
br comments add <id> "WORKER: model=<model-id> session=<AGENT_NAME> skill@version=<agent-compounds SHA at skill-load> duration=<wall-clock claim→close>"
```

- `skill@version` = the agent-compounds git SHA resolved at skill-load (skills load via symlink
  from this repo) — the skills-eval before/after axis for measuring doctrine changes.
- `duration` = wall-clock from bead-claim to bead-close in the child session.
- **Per-bead TOKEN cost is deliberately OUT** — a child can't see its own token usage, so a
  per-bead number would be fabricated precision. Token cost lands at BATCH/child granularity in
  `ac-batch-close`'s report (the conductor receives per-child usage in task notifications).

**On close, check for memory facts that cite this bead.** A freeze/pin or other
lifecycle-scoped fact often names the exact bead whose closure retires it (e.g. an
`app-version-pinned-*` fact tied to an App Store-submission bead). When you close such a
bead, grep the memory substrate for facts referencing its id and retire/update any that
are now stale — otherwise the fact stays silently wrong until some later session trusts it:
`grep -rl "<bead-id>" memory/auto/` (a manual reminder is enough; even a one-line check
here would have caught a 7-day-stale version pin within a day). This is the retirement
trigger the freeze-check in `ac-merge` (§ Version Bump) relies on upstream.

Release the file reservation using the **same paths reserved in Phase 1a** (the bead spec file list, not just the files committed — releasing over-reserved paths is harmless; leaving them locked starves parallel sessions):

```
mcp__mcp-agent-mail__release_file_reservations(
  project_key: CANONICAL_PROJECT_KEY,   // canonical "neometa/<app-dir>" key — key-format + never-absolute rule: agent-mail/references/agent-identity.md § Project key format
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

Append to `$ARTIFACTS_DIR/progress.md` (include header on first write). **This exact
shape is parsed by `beads-closed-gate.sh` — reproduce it literally: APPEND sections to
the one `progress.md`, never a sibling per-bead result file in its place; a fanned-out
implement child inherits this contract verbatim** <!-- net-growth-ok: dream ac-3ao -->:

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

Run the wave's **affected** tests — the full suite is relocated to PUBLISH START
(`ac-publish` → `ac-prove ensure --fix-forward`, bd-pwt44), so it no longer runs per wave:

```bash
pnpm test 2>&1 | tail -20     # vitest-affected across the whole wave's diff vs main
```

If any fail, fix the issues before proceeding. **Standalone, non-loop use:** if this wave will
NOT reach a publish (nothing downstream runs the full suite), run `pnpm test:all` here instead.

> **Parallel sessions:** Failing tests may originate from another session's uncommitted changes in the working tree. Run `git diff --stat HEAD` to identify which files are uncommitted — check their Agent Mail reservations to determine which session owns them. Failures in files not touched by this session's commits are owned by the other session — note them but do not block landing.

### Next Steps

**Run `/ac-review` next (recommended).** `/ac-review` is the sole pre-close gate — it must complete before the closing ceremony (`/ac-batch-close` under trunk-direct, the default; `/ac-merge` only on the legacy PR-branch path — see `ac-merge` § When to use). `/ac-land` is NOT a pre-close gate: it's the closing ritual (teardown + retrospective) that runs LAST, after the wave has closed to main — run it manually when not driven by `/ac-loop`. Do NOT run the closing ceremony until review has completed. Do NOT run `/ac-land` before it — it has nothing to close out yet.

**Present next step with `AskUserQuestion`** — Ask (header: "Next step", single-select): "Bead-work session complete ({BEADS_COMPLETED} beads). What's next?" — options: "Review work (Recommended)" (Run /ac-review — the pre-close gate. Then /ac-batch-close, or /ac-merge on a PR branch.) / "Continue implementing" (Run /ac-implement again for more beads (review + close later)) / "Done for now" (Stop here — remember to run /ac-review then the closing ceremony; /ac-land runs after it).

### Deregister Session Identity (Layer 1 — true last act)

This session minted a Tier-1 identity in Phase 0 and released each bead's file reservations
in its Phase 1d as that bead closed. As the session's **final act — after the last bead's
reservation release** — deregister its own minted `AGENT_NAME` per
`agent-mail/references/session-procedure.md` § Release + self-deregister (Layers 2/3 backstops noted there).

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

<!-- diet: restated content deleted — live body twins verified; the Remember-only rule survives below -->

- **No new code without new tests** — verify the engineer actually wrote them before approving a bead (per-bead: tests + type-check + lint; full quality gate at session end)
