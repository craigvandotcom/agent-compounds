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
| **Output**       | Implemented code, committed per bead, pushed to wave branch                                |
| **Artifacts**    | Per-bead results in `/tmp/bead-work-<wave-slug>/bead-{id}-result.md`, progress in `/tmp/bead-work-<wave-slug>/progress.md` |
| **Verification** | Per-bead quality gate (test, lint, type-check), beads closed in `br`                       |

## Phase 0: Initialize

**MANDATORY FIRST STEP: Create task list with TaskCreate BEFORE starting (after asking user for bead count).**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

### Clean Working Tree (FIRST)

```bash
git status --short
```

If uncommitted changes exist, review them and commit in logical groups before proceeding. The goal is granular checkpoints — every commit is a revert point. Group related changes together (e.g., plan updates in one commit, script changes in another). If anything looks like a red flag (unexpected deletions, sensitive files), flag it to the user before committing. Almost always, the right action is to commit — not stash, not ignore.

**Do NOT start bead-work with a dirty working tree.** Engineers see all uncommitted files in their context and may inadvertently include unrelated changes in their diffs, forcing manual selective staging.

**Never use `git stash` at any point during or between beads — not even as a diagnostic tool.** A `stash pop` can surface pre-existing stash entries from other branches and write merge-conflict markers into files unrelated to the current session (incident: stash-corruption — `references/incidents.md`). If you need to isolate uncommitted-vs-committed differences, use `git diff HEAD` or just commit the work first — stash is not a reversible tool in a multi-branch workflow.

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

### Ensure Wave Branch (single-branch rule)

**There is always exactly ONE active wave branch in this repo.** Whatever bead-work runs joins it — a wave is a release/merge unit, not a feature unit. Never create a second wave while one is open. Multiple Claude sessions also share that single wave branch.

```bash
git fetch origin --prune
LOCAL_WAVE=$(git branch --list 'wave/*' --format='%(refname:short)' | head -1)
REMOTE_WAVE=$(git branch -r --list 'origin/wave/*' --format='%(refname:lstrip=3)' | head -1)
```

- **A wave exists (local or remote):** join it. Do NOT create a second wave.
  ```bash
  WAVE=${LOCAL_WAVE:-$REMOTE_WAVE}
  git checkout "$WAVE" && git pull --rebase
  ```

- **No wave exists anywhere:** create the next numbered wave:
  ```bash
  bash "$PROJECT_ROOT/.claude/skills/_shared/scripts/allocate-wave-branch.sh"
  ```
  Computes the next 3-digit counter from the highest-EVER wave number — live refs ∪ merge
  messages on main ∪ tags, not refs alone (`git fetch --prune` drops merged waves' refs, so a
  refs-only scan reuses a shipped number — incident: wave-collision — `references/incidents.md`);
  hard-fails with exit 1 if `wave/NNN` already appears in main's history (never auto-increments
  past a collision); on success creates `wave/NNN` from main, pushes with upstream set, and
  prints the new branch name.

- **Multiple waves found (defensive guard):** STOP and surface to user. The single-branch rule was violated upstream — let the user decide which to keep before claiming any beads.

> **Migration note (2026-05-19→):** the previous thematic naming (`wave/<feature-name>`) is being phased out. Pre-existing thematic waves finish under their current names; only newly created waves use `wave/NNN`. Once the current open wave merges, all subsequent waves follow `wave/NNN` exclusively. Do NOT propose renaming an in-flight thematic wave — let it complete naturally.

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

### Ask User

Ask one question via `AskUserQuestion`:

1. "How many beads to target this session?" (default: all unblocked)

### Configuration

```bash
TARGET_BEADS=<user input>
BEADS_COMPLETED=0
# Deterministic dir keyed on the wave slug (+ RUN_ID for parallel same-wave sessions).
# Contract: _shared/run-id.md. ac-land lands this same path.
WAVE_SLUG=$(git branch --show-current | tr '/' '-')
ARTIFACTS_DIR="/tmp/bead-work-${WAVE_SLUG}${RUN_ID:+-$RUN_ID}"   # e.g. /tmp/bead-work-wave-004
```

### Register Session Identity

Register a unique identity for this implement session — used for file reservations and pre-commit guard attribution:

```
mcp__mcp-agent-mail__macro_start_session(
  project_key: CANONICAL_PROJECT_KEY,   // the app's canonical Agent Mail key from its session-start.md (pattern: "neometa/<app-dir>", e.g. "neometa/body-compass-app") — NEVER an absolute path: abs paths fork a per-machine mailbox (split-brain)
                                        # mirror: _shared/agent-identity.md — edit there first
  program: "claude-code",
  model: "claude-opus-4-8"
)
```

Capture the returned `name` field:

```bash
# Export so the pre-commit guard reads AGENT_NAME and WORKTREES_ENABLED at commit time
export WORKTREES_ENABLED=1
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

TaskCreate(subject: "Phase 0: Initialize bead-work session", description: "Verify beads, ensure wave branch, create tasks", activeForm: "Initializing session...")

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

If `$ARTIFACTS_DIR/progress.md` exists, parse its header to recover `TARGET_BEADS`. Count entries marked `COMPLETE` to recover `BEADS_COMPLETED`. Skip completed beads. The wave-branch-based `ARTIFACTS_DIR` is stable across compaction — re-derive it with `git branch --show-current | tr '/' '-'` if the variable is lost.

If `$ARTIFACTS_DIR/` was deleted and recreated mid-session (e.g., by a partial bead-land run), result files for completed beads are lost. Note this in progress.md as "(result file lost — bead completed, committed as <hash>)".

---

## BEAD LOOP: Phases 1a–1e

### Phase 1a: Select Bead

**Re-verify branch context BEFORE claiming.** Branch state is dynamic in this workflow — multiple Claude sessions sharing one git checkout can switch the branch between operations via serial hand-off. Phase 0's branch check is a snapshot; treat it as stale on every loop iteration.

```bash
git branch --show-current
```

If the branch is NOT the wave branch you started on, STOP. Do not silently `git checkout` back (that would clobber the other session's work). Surface the drift to the user, ask whether to wait, switch back, or exit. **Do NOT create a git worktree** — single-branch-per-wave is a deliberate convention here; spawning a worktree forks the wave state (incident: worktree-drift — `references/incidents.md`).

```bash
bv --robot-next
```

This returns the top pick AND a claim command.

> ⚠️ **The claim command robot-next prints uses `bd`, but this repo's binary is `br`.** `bv --robot-next` emits `bd update <id> --status=in_progress`; running it verbatim fails with `command not found: bd`. Translate to **`br update <id> --status=in_progress`** (incident: bd-br-translation — `references/incidents.md`).

**Guard: verify the selected bead carries `refined` and is not human-gated.** Readiness is presence of `refined`, not absence of `unrefined`. Check the bead's labels — if it lacks `refined`, or has `human-gate`, skip it and pick the next one:

```bash
# Check the selected bead's labels: must have refined, must not have human-gate
br show <id> --json | jq '.labels | ((index("refined") | not) or index("human-gate"))'
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

**Once a refined, conflict-free, env-supported bead is confirmed**, run the claim command from the output — do not use `br start` (it doesn't exist).

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

Close the bead:

```bash
br close <id> --reason "Implemented and tested"
```

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

This skill is parallel-by-design — no mode switch needed: the mechanics above already handle it (single wave branch · Phase 1a reservations + Phase 0 pre-commit guard · pathspec commits · shared per-wave `ARTIFACTS_DIR` with append-only progress.md and per-bead result files).

`bv --robot-next` is global-priority, not wave-aware; conductor must filter to the wave's labels OR pick from a different epic when the wave's chain is sequentially gated.

Pre-push `pnpm build` reads the working tree — another session's uncommitted WIP can block your push. If this happens, identify the conflicting files via `git diff --stat HEAD` and check their Agent Mail reservations.

---

## Remember

- **One active `wave/*` branch, ever** — join it if it exists, never create a second; new waves are `wave/NNN` (thematic names legacy only). Engineers implement; **YOU review, YOU commit** — be extremely strict, a bead must be fully complete before moving on. Minor fixes: do them yourself; major gaps: re-spawn the engineer.
- **Compaction recovery** — progress.md is the state: parse its header for TARGET_BEADS, count COMPLETE entries for BEADS_COMPLETED; re-derive `ARTIFACTS_DIR` from `git branch --show-current | tr '/' '-'` if lost. "Bead X of N" task naming prevents drift — the task list IS the stop condition.
- **Quality cadence** — per-bead: tests + type-check + lint, and no new code without new tests (verify the engineer wrote them before approving); full quality gate at session end; UI validation runs once at session end (in bead-land), not per-bead.
