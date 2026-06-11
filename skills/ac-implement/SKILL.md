---
name: ac-implement
description: Sequential bead implementation — conductor reviews, engineer sub-agents implement, loops until the wave is done. Triggers: 'work the beads', 'implement the wave', 'bead work', 'run the wave', 'start implementation'.
---


**You are the conductor.** Engineers implement. You review, verify, and commit. One bead at a time. Quality over velocity.

For parallelism, open multiple terminal sessions — each runs `/ac-implement` independently.

---

## I/O Contract

|                  |                                                                                            |
| ---------------- | ------------------------------------------------------------------------------------------ |
| **Input**        | Unblocked beads (from `/ac-bead-refine`)                                       |
| **Output**       | Implemented code, committed per bead, pushed to wave branch                                |
| **Artifacts**    | Per-bead results in `/tmp/bead-work/bead-{id}-result.md`, progress in `/tmp/bead-work/progress.md` |
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

**Never use `git stash` at any point during or between beads — not even as a diagnostic tool.** A `stash pop` can surface pre-existing stash entries from other branches and write merge-conflict markers into files unrelated to the current session, forcing manual cleanup. Concrete incident (2026-04-08 wave/structured-modifiers session): `git stash && pnpm test && git stash pop` found nothing to save, then popped an unrelated stash entry from another branch and corrupted an unrelated plan file. If you need to isolate uncommitted-vs-committed differences, use `git diff HEAD` or just commit the work first — stash is not a reversible tool in a multi-branch workflow.

### Verify Refined Beads Exist

```bash
br ready --json
```

If no unblocked beads, STOP: "No unblocked beads. Run `/ac-beadify` first, or check `br list --json` for blocked items."

**Filter out unrefined beads.** Beads created by `/ac-beadify` carry the `unrefined` label until `/ac-bead-refine` removes it. Only beads WITHOUT this label are eligible for implementation:

```bash
# Check if any ready beads are refined (no "unrefined" label)
br ready --json | jq '[.[] | select(.labels | index("unrefined") | not)]'
```

If ALL ready beads have the `unrefined` label, STOP: "All ready beads are unrefined. Run `/ac-bead-refine` first to make them implementation-ready."

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

- **No wave exists anywhere:** create the next numbered wave. Compute the next 3-digit counter from existing remote refs:
  ```bash
  HIGHEST=$(git for-each-ref --format='%(refname:strip=3)' refs/remotes/origin/wave/ \
            | grep -oE '^[0-9]{3}$' | sort -n | tail -1)
  NEXT=$(printf "%03d" $(( ${HIGHEST:-000} + 1 )))
  git checkout -b "wave/$NEXT" main
  git push -u origin "wave/$NEXT"
  ```

- **Multiple waves found (defensive guard):** STOP and surface to user. The single-branch rule was violated upstream — let the user decide which to keep before claiming any beads.

Trunk-based: `/ac-merge` ships the wave to main and bumps the app version based on the commits.

> **Migration note (2026-05-19→):** the previous thematic naming (`wave/<feature-name>`) is being phased out. Pre-existing thematic waves finish under their current names; only newly created waves use `wave/NNN`. Once the current open wave merges, all subsequent waves follow `wave/NNN` exclusively. Do NOT propose renaming an in-flight thematic wave — let it complete naturally.

### Pre-Flight Type-Check

```bash
pnpm type-check 2>&1 | tail -5
```

If type-check fails:
- **Error in a file this session will touch:** Fix it as the first commit before starting beads
- **Error in a file owned by another agent's reservation:** Note the error in progress.md header, proceed with awareness that `--no-verify` may be needed on push. File a P0 bead if one doesn't exist for the fix.
- **Error unrelated to any bead scope:** Proceed — note it but don't block the session

### Baseline Full Test Suite

`vitest-affected` (and similar per-bead test filters) can silently mask pre-existing failures during per-bead quality gates, only surfacing them at Phase Final after beads are already committed. Run the full suite ONCE up front to expose the baseline:

```bash
pnpm test:all 2>&1 | tail -20
```

**Pre-existing failures are NOT acceptable baseline.** They are technical debt that the user gets to decide how to handle BEFORE the session starts. Do not silently absorb them. Concrete prior incident (2026-05-14 wave/curator): conductor recorded `13 failed across 3 files (3 known-pre-existing)` in progress.md and proceeded silently; user pushed back hard at land time ("why do we have failures? we should have none — why were they not addressed? and why do you persist in not addressing them?"). The 13 failures sorted into two clearly fixable buckets (env-override gap → production rate-limit, and schema-drift after migration rename) — neither was a mystery, both had deterministic fix paths. The "pre-existing = OK" framing collapsed under user scrutiny.

Behavior:

- **All pass:** Note "Baseline: all tests passing" in progress.md header. Proceed.
- **Any failures:** Capture for each failing test file:
  - Test file path
  - Failure category (production-state / schema-drift / flake / unknown — one-line judgment)
  - 1-line root-cause hypothesis if obvious
  - Whether the file overlaps the session's target bead scope

  Then surface to the user via `AskUserQuestion`:

  ```
  question: "Baseline test run shows N failures across M files: <one-line summary per file>. How to handle?"
  options:
    - "File P1 follow-up bead now and proceed" — captures debt, doesn't block session (recommended for >5 failures or substantive schema-drift)
    - "Fix first as a pre-bead commit" — pause session, fix, re-baseline (recommended for ≤2 quick wins like env-override toggles)
    - "Proceed without filing — I have an existing bead tracking these" — explicit acknowledgment; user MUST cite the bead ID
    - "Stop and let me investigate" — abort session
  ```

  Record the user's decision (and any cited bead ID) in progress.md header. Do NOT proceed silently.

- **Failures include files this session will touch:** Always fix as the first commit before starting beads, OR pick a different bead set. Do not start work where your changes will land on top of broken tests in the same files.

Specifically REJECT these failure modes from being treated as "acceptable baseline" without a fix plan:

- **Production rate-limit / egress quota errors** (`exceed_egress_quota`, 429s from external APIs) — almost always fixable via env-override to local stack, the same pattern existing tests use.
- **Schema-drift errors after migrations** (column "X" does not exist; SQLSTATE mismatches between expected CHECK and actual NOT NULL) — fixable by updating column references / assertions to match current schema.
- **"Known pre-existing" without a specific bead ID tracking the fix** — this is an evasion phrase. Either it has a bead, or it needs one filed now.

Skip this step only if `pnpm test:all` takes > 10 minutes on this machine AND the session targets fewer than 2 beads — in that case the overhead outweighs the signal. Default is to always run.

### Ask User

Ask two questions via `AskUserQuestion`:

1. "How many beads to target this session?" (default: all unblocked)
2. "Session mode?" → **Solo** (single terminal, default) or **Parallel** (multiple terminals)

### Configuration

```
TARGET_BEADS=<user input>
BEADS_COMPLETED=0
SESSION_MODE=<solo|parallel>
ARTIFACTS_DIR=/tmp/bead-work          # solo mode
# Parallel mode: use session-unique dir to prevent progress.md collisions:
# ARTIFACTS_DIR=/tmp/bead-work-$$
```

> **Parallel mode:** Use a session-unique `ARTIFACTS_DIR` (e.g., `/tmp/bead-work-$$`) to prevent progress.md overwrite collisions with other parallel sessions. Solo mode can use `/tmp/bead-work`.

```bash
mkdir -p "$ARTIFACTS_DIR"
```

### Create Workflow Tasks

**Create session config task + one task per target bead + final task.** The session config task encodes mode and bead count so they survive context compaction. Bead tasks use "X of N" numbering to make the stop condition explicit.

```
# Session config — always completed, serves as compaction-resilient state
TaskCreate(subject: "Session config: {SESSION_MODE} | {TARGET_BEADS} beads", description: "SESSION_MODE={SESSION_MODE}. TARGET_BEADS={TARGET_BEADS}. Stop after {TARGET_BEADS} beads.", activeForm: "Configuring session...")
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

If `$ARTIFACTS_DIR/progress.md` exists, parse its header to recover `TARGET_BEADS` and `SESSION_MODE`. Count entries marked `COMPLETE` to recover `BEADS_COMPLETED`. Skip completed beads.

If `$ARTIFACTS_DIR/` was deleted and recreated mid-session (e.g., by a partial bead-land run), result files for completed beads are lost. Note this in progress.md as "(result file lost — bead completed, committed as <hash>)".


Acknowledge any pending messages.

---

## BEAD LOOP: Phases 1a–1f

### Phase 1a: Select Bead

**Re-verify branch context BEFORE claiming.** Branch state is dynamic in this workflow — multiple Claude sessions sharing one git checkout can switch the branch between operations via serial hand-off. Phase 0's branch check is a snapshot; treat it as stale on every loop iteration.

```bash
git branch --show-current
```

If the branch is NOT the wave branch you started on, STOP. Do not silently `git checkout` back (that would clobber the other session's work). Surface the drift to the user, ask whether to wait, switch back, or exit. **Do NOT create a git worktree** — single-branch-per-wave is a deliberate convention here; spawning a worktree forks the wave state.

Concrete prior incident (2026-05-09 wave/research-curator-prereqs / between bd-nxtl and bd-yvhn): conductor's spawned engineer detected the branch had flipped to `wave/loading-coherence` mid-session. Engineer correctly aborted; conductor wasted ~15 min recovering by inappropriately creating a worktree. Re-verifying branch in Phase 1a (this step) eliminates the failure mode entirely.

```bash
bv --robot-next
```

This returns the top pick AND a claim command.

**Guard: verify the selected bead is refined.** Check the bead's labels — if it has `unrefined`, skip it and pick the next one:

```bash
# Check if the selected bead has the "unrefined" label
br show <id> --json | jq '.labels | index("unrefined")'
```

If the bead is unrefined:
1. Do NOT claim it
2. Log: "Skipping <id> (unrefined — needs `/ac-bead-refine` first)"
3. Get the next candidate from `br ready --json | jq '[.[] | select(.labels | index("unrefined") | not)] | .[0]'`
4. If no refined beads remain, STOP the session early

**Guard: check for file reservation conflicts.** Before claiming, attempt to reserve the bead's files. If `file_reservation_paths` returns conflicts (another agent holds exclusive reservations on overlapping files), this bead is taken:

1. Do NOT claim it
2. Log: "Skipping <id> (file conflicts with <agent> — already being worked)"
3. Get the next candidate from `br ready --json` and repeat both guards (unrefined + conflict)
4. If no conflict-free beads remain, STOP the session early

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
4. Burning a bead slot on a no-op attempt is equivalent to claiming an unrefined bead — skip it.

Concrete prior incident (2026-05-15 wave/v1-bootstrap): conductor claimed `owr.3` (P0) before recognising its spec called for `supabase migration up --local` against a local stack that doesn't exist on the project. One of the session's 8 bead slots was consumed before the env mismatch surfaced. Separately, `bv --robot-next` repeatedly recommended `n6a.2` whose remaining ACs are Mac-only — conductor had to manually filter via `br ready --json` jq each Phase 1a loop, ~4–6 min wasted across the session.

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

7. **Fresh-eyes diff scan:**

   ```bash
   git diff --stat
   git diff
   ```

UI validation is deferred to `/ac-land` where it runs once for the entire session with pre-authenticated browser state. This saves ~N browser-tester agent spawns (one per bead) without reducing coverage.

**If minor issues:** Fix them directly. You are the conductor — small fixes are faster than re-spawning.

**If major issues:** Re-spawn an engineer sub-agent for the same bead with specific feedback on what's wrong or incomplete. Include the previous result file for context. Repeat until satisfied.

**Be extremely strict.** Do not move to the next bead until this one is fully complete.

### Phase 1d: Commit + Close Bead

**Always use the pathspec commit form (`git commit -- <files>`), not `git add` + `git commit`.** This is mandatory in parallel mode (a second session sharing the checkout can sweep your staged files into THEIR commit before you call `git commit` — see commit `f64db219` in wave/app-first-feel history for the canonical incident). In solo mode it's still preferred because it's atomic and self-documenting — there's no window between staging and committing where state can drift.

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
> Concrete cost (wave/001, bd-al8p.8): the new `ci-hygiene.test.ts` failed its pathspec commit; the `br close` in the SAME bash block then ran anyway and closed the bead before any commit landed.
>
> **NEVER put `br close` in the same bash block as the `git commit`.** Bash continues past a failed commit, so a chained `br close` closes the bead in the tracker with no matching commit — a silent correctness hazard. Run the commit in one call, verify it landed (`git log --oneline -1` shows your commit, or check `$?`), then `br close` in a separate call.

> Note: pathspec commits bypass `lint-staged` (which hooks the index). This repo's `lint-staged` config has been a no-op in practice — every commit this session reported "could not find any staged files matching configured tasks" — so practical impact is zero. The pre-push `pnpm build` hook still runs on the committed snapshot regardless.

Push after every bead commit prevents stranded work if the session crashes before bead-land.

Close the bead:

```bash
br close <id> --reason "Implemented and tested"
```

### Phase 1e: Update Progress

**Mark bead task as completed:**

```
TaskUpdate(task: "Bead {BEADS_COMPLETED + 1} of {TARGET_BEADS}", status: "completed")
```

Append to `$ARTIFACTS_DIR/progress.md` (include header on first write):

```markdown
<!-- Header (first bead only) -->

TARGET_BEADS={TARGET_BEADS}
SESSION_MODE={SESSION_MODE}

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

### Full Quality Gate

Run the complete suite (this is where the full run happens):

```bash
# Run full project quality gate (see AGENTS.md > Project Commands > Quality gate)
```

If any fail, fix the issues before proceeding.

> **Parallel sessions:** If `SESSION_MODE=parallel`, failing tests may originate from other sessions' uncommitted changes in the working tree. Run `git diff --stat HEAD` to identify which files are uncommitted and which session owns them. Failures in files not touched by this session's commits are owned by the other session — note them but do not block landing.

### Next Steps

**Run `/ac-land` next (recommended).** It handles:

- Clean git push
- Retrospective learning from this session
- System upgrades (user-gated) that make the next session better

This is what makes the flywheel accelerate — don't skip it.

**Pipeline context:** Both `/ac-land` (per-session closure) and `/ac-review` (per-feature-branch review) are pre-merge gates — both must complete before `/ac-merge`. Their mutual order is flexible. The typical flow after implementing is: land the session, then run review (or vice versa), then merge. Do NOT run `/ac-merge` until both have completed.

**Present next step with `AskUserQuestion`:**

```
AskUserQuestion(
  questions: [{
    question: "Bead-work session complete ({BEADS_COMPLETED} beads). What's next?",
    header: "Next step",
    multiSelect: false,
    options: [
      { label: "Land session (Recommended)", description: "Run /ac-land — push, retrospective, system upgrades. Don't skip this." },
      { label: "Continue implementing", description: "Run /ac-implement again for more beads (land later)" },
      { label: "Done for now", description: "Stop here — remember to run /ac-land before closing" }
    ]
  }]
)
```

**TaskUpdate(task: "FINAL: Session summary + quality gate ({TARGET_BEADS} beads total)", status: "completed")**

---

## Multi-Session Parallelism

```
Terminal 1: /ac-implement   → "target 5 beads"
Terminal 2: /ac-implement   → "target 5 beads"
```

Both sessions join the **same wave branch** (single-branch rule above — never create a second wave). They pick beads with non-overlapping file footprints, not by epic/wave-affinity. `bv --robot-next` is global-priority, not wave-aware; conductor must filter to the wave's labels OR pick from a different epic when the wave's chain is sequentially gated.

Coordination via Agent Mail file reservations BEFORE editing is mandatory in parallel mode. Commit with `git commit -- <pathspec>` (limits scope) since lint-staged's stash dance can bundle the other session's WIP into your commit otherwise. Pre-push `pnpm build` reads the working tree — the other session's broken WIP can block your push.

---

## Remember

- **Single-branch rule** — always exactly one active `wave/*` branch in this repo. If one exists, join it. Never create a second wave while one is open. New waves use `wave/NNN` (3-digit counter); thematic names are legacy only.
- **YOU review, YOU commit** — engineers implement, you verify
- **Be extremely strict** — bead must be fully complete before moving on
- **Minor fixes: do them yourself. Major gaps: re-spawn engineer.**
- **Temp files survive compaction** — read from `$ARTIFACTS_DIR`, not memory
- **Progress file is compaction recovery** — parse it on restart for TARGET_BEADS + SESSION_MODE
- **Per-bead: tests + type-check + lint. Full quality gate at session end.**
- **UI validation runs once at session end** (in bead-land) — not per-bead
- **No new code without new tests** — verify engineer wrote tests before approving
- **"Bead X of N" task naming prevents drift** — the task list IS the stop condition

---

_Bead work: sequential implementation with quality gates. For bead prep: `/ac-beadify` → `/ac-bead-refine`. After implementing: `/ac-land` (session closure) + `/ac-review` (branch review), both before `/ac-merge`._
