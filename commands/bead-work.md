---
description: Sequential bead implementation — conductor reviews, engineers implement, one bead at a time
---

**You are the conductor.** Engineers implement. You review, verify, and commit. One bead at a time. Quality over velocity.

For parallelism, open multiple terminal sessions — each runs `/bead-work` independently.

---

## I/O Contract

|                  |                                                                                            |
| ---------------- | ------------------------------------------------------------------------------------------ |
| **Input**        | Unblocked beads (from `/bead-refine` or `/beadify`)                                       |
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

### Verify Refined Beads Exist

```bash
br ready --json
```

If no unblocked beads, STOP: "No unblocked beads. Run `/bead-refine` first, or check `br list --json` for blocked items."

**Filter out unrefined beads.** Beads created by `/beadify` carry the `unrefined` label until `/bead-refine` removes it. Only beads WITHOUT this label are eligible for implementation:

```bash
# Check if any ready beads are refined (no "unrefined" label)
br ready --json | jq '[.[] | select(.labels | index("unrefined") | not)]'
```

If ALL ready beads have the `unrefined` label, STOP: "All ready beads are unrefined. Run `/bead-refine` first to make them implementation-ready."

### Ensure Wave Branch

Check if a `wave/` branch exists for this work:

```bash
git branch --list 'wave/*'
```

- **No wave branch exists:** Ask user for a wave name, then create it:
  ```bash
  git checkout -b wave/<feature-name>
  ```
- **One wave branch exists:** Switch to it if not already on it:
  ```bash
  git checkout wave/<feature-name>
  git pull --rebase
  ```
- **Multiple wave branches:** Ask user which to join via `AskUserQuestion`.

All parallel sessions join the same wave branch. Trunk-based — merge to main when wave is complete.

### Pre-Flight Type-Check

```bash
pnpm type-check 2>&1 | tail -5
```

If type-check fails:
- **Error in a file this session will touch:** Fix it as the first commit before starting beads
- **Error in a file owned by another agent's reservation:** Note the error in progress.md header, proceed with awareness that `--no-verify` may be needed on push. File a P0 bead if one doesn't exist for the fix.
- **Error unrelated to any bead scope:** Proceed — note it but don't block the session

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
2. Log: "Skipping <id> (unrefined — needs `/bead-refine` first)"
3. Get the next candidate from `br ready --json | jq '[.[] | select(.labels | index("unrefined") | not)] | .[0]'`
4. If no refined beads remain, STOP the session early

**Guard: check for file reservation conflicts.** Before claiming, attempt to reserve the bead's files. If `file_reservation_paths` returns conflicts (another agent holds exclusive reservations on overlapping files), this bead is taken:

1. Do NOT claim it
2. Log: "Skipping <id> (file conflicts with <agent> — already being worked)"
3. Get the next candidate from `br ready --json` and repeat both guards (unrefined + conflict)
4. If no conflict-free beads remain, STOP the session early

**Once a refined, conflict-free bead is confirmed**, run the claim command from the output — do not use `br start` (it doesn't exist).

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

```
Task(subagent_type: "general-purpose", model: "sonnet", prompt: """
You are an implementation engineer. Your job: implement one bead with strict TDD, following project conventions exactly.

Read AGENTS.md first for project context, coding standards, and conventions.
{If relevant skills identified: "Read the relevant skill file for domain patterns (see AGENTS.md > Available Skills)."}

## Your Task

Implement this bead using strict TDD (RED → GREEN).

### TDD Flow

1. **Write tests FIRST** — based on the bead spec's acceptance criteria
2. **Run tests — confirm RED** (tests fail because code doesn't exist yet)
3. **Implement the code** — minimal code to make tests pass
4. **Run tests — confirm GREEN** (all tests pass)
5. **Only modify tests if you're certain there's a bug in the test itself** — not to make failing tests pass

### Bead Spec

<paste full br show + br comments output here>

### Requirements

- Follow existing code patterns (read neighboring files first)
- Follow domain skill guidelines (loaded above)
- Follow project type discipline (see AGENTS.md > Rules)
- **Before implementing**, search for existing test files that import or test the files you will modify (use the Grep tool with pattern `from.*<module>` and glob `*.test.*` across `__tests__/` and `features/`). Run these after your changes to confirm no regressions. List any existing test files you verified in your report.
- **CRITICAL: Run ALL pre-existing tests for modified files.** If any test file imports a module you changed (added exports/imports, changed signatures), run that test and fix failures your changes caused. List each pre-existing test and its result. If none found, state "No pre-existing tests found."
- Run ALL project quality checks before finishing (see AGENTS.md > Project Commands > Quality gate)

### Output

MANDATORY: Write your implementation report to $ARTIFACTS_DIR/bead-<id>-result.md BEFORE reporting done.
This file is the primary artifact for retrospective analysis and MUST survive until bead-land runs.
Do NOT delete or overwrite result files from earlier beads in this session.
- Files created/modified (with paths)
- Test files created/modified (with paths) — list EVERY new test
- Verification results (quality checks — all must pass)
- Any decisions made or assumptions
- Any issues encountered
""")
```

### Phase 1c: Review Quality (Conductor's Core Job)

**YOU are the quality gate.** Read the engineer's result file and verify:

**Worktree mode only:** Before copying files from a worktree, verify no uncommitted changes: `git -C <worktree> status --porcelain`. If uncommitted changes exist, commit them in the worktree first. `cp` reads the filesystem (committed state), not the working tree — uncommitted edits will be silently lost.

1. **Run bead-relevant tests IN THE MAIN REPO** (not full suite — just what this bead touches). Do NOT trust worktree test results — module resolution and mock behavior may differ between the worktree and main repo. Run tests AFTER copying files but BEFORE committing:

   ```bash
   # Run project test command scoped to relevant test files
   # See AGENTS.md > Project Commands > Test
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

6. **Fresh-eyes diff scan:**

   ```bash
   git diff --stat
   git diff
   ```

UI validation is deferred to `/bead-land` where it runs once for the entire session with pre-authenticated browser state. This saves ~N browser-tester agent spawns (one per bead) without reducing coverage.

**If minor issues:** Fix them directly. You are the conductor — small fixes are faster than re-spawning.

**If major issues:** Re-spawn an engineer sub-agent for the same bead with specific feedback on what's wrong or incomplete. Include the previous result file for context. Repeat until satisfied.

**Be extremely strict.** Do not move to the next bead until this one is fully complete.

### Phase 1d: Commit + Close Bead

```bash
git add <specific files>
git commit -m "feat(<scope>): <bead title>

Bead: <id>
Co-Authored-By: Claude <noreply@anthropic.com>"
git push
```

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

**Always run `/bead-land` next.** It handles:

- Clean git push
- Retrospective learning from this session
- System upgrades (user-gated) that make the next session better

This is what makes the flywheel accelerate — don't skip it.

**Present next step with `AskUserQuestion`:**

```
AskUserQuestion(
  questions: [{
    question: "Bead-work session complete ({BEADS_COMPLETED} beads). What's next?",
    header: "Next step",
    multiSelect: false,
    options: [
      { label: "Land session (Recommended)", description: "Run /bead-land — push, retrospective, system upgrades. Don't skip this." },
      { label: "Continue implementing", description: "Run /bead-work again for more beads (land later)" },
      { label: "Done for now", description: "Stop here — remember to run /bead-land before closing" }
    ]
  }]
)
```

**TaskUpdate(task: "FINAL: Session summary + quality gate ({TARGET_BEADS} beads total)", status: "completed")**

---

## Multi-Session Parallelism

```
Terminal 1: /bead-work   → "target 5 beads"
Terminal 2: /bead-work   → "target 5 beads"

Each session independently:
- bv --robot-next picks best available bead (no pre-assigned ranges)
- Sessions may work on interleaved bead numbers — that's fine
```

---

## Remember

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

_Bead work: sequential implementation with quality gates. For planning: `/bead-refine`. For landing: `/bead-land`._
