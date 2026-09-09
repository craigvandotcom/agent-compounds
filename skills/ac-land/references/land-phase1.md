# ac-land Phase 1 — land mechanics

<!-- mirror: ac-pipeline/references/commit-discipline.md § pathspec canon -- edit there first -->

## 1a. File Remaining Work

- Check for any started-but-unclosed beads: `br list --json` — look for claimed/in-progress items
- For each: either close it (if done) or add a comment documenting where you left off
- Create new beads for any loose ends discovered during the session:
  Bead creation per `beads-standards/reference/bead-conventions.md` — types, unrefined-at-creation, anchor-dedupe, body template.

  ```bash
  # Dedup first: br list --json | grep -i "<keyword>"  — skip if an open match already exists.
  # -t = kind of work (task/bug/investigation; -t bug only for a shipped product defect).
  # unrefined routes the raw bead through ac-polish (bead mode) instead of treating it as already-refined.
  br create "Follow-up: <description>" -t <type> --priority P1 --labels origin:ac-land,followup,unrefined --description "Discovered during bead-work session. Context: ..."
  ```

Mark ledger task 2 `completed`; `TaskUpdate` task 3 `in_progress`.

## 1b. Quality Gates

> **Quality gates at land (tiered-testing model — parallel-execution doctrine §5).**
> Format / lint / type-check are cheap — always run. Do NOT run a blocking local `test:all` or
> fire a full-suite CI run here. Two exceptions: (1) a GREEN full `test:all` / Quality-Gate pass
> for the current HEAD already exists (legacy PR path, or a publish just ran) — **note-and-skip**,
> don't validate the same HEAD twice; (2) standalone landing with **no CI path at all** — run a
> local `test:all` once here.

> **`in_progress` ≠ stuck — COMPUTE elapsed before flagging, never eyeball.** At land time, the
> just-merged commit's own CI Quality Gate for HEAD is frequently STILL RUNNING (the merge step
> fires it and landing follows immediately after) — an `in_progress` run is the EXPECTED state,
> not an anomaly. **Never report a run as "stuck"/"hung"/"wedged" from its status alone or with a
> duration you did not measure.** A run is stuck ONLY if its _computed_ elapsed time far exceeds
> the suite's norm: derive it from `gh run view <id> --json createdAt,jobs` (or the job's
> `startedAt`) vs `date -u` now, and flag only when elapsed > ~2× typical (this suite is ~15-20
> min → threshold ~40 min+). Under the threshold → report "CI in-progress, on track (Nm elapsed)"
> and move on; do NOT alarm, do NOT block landing. Asserting an unmeasured duration is a
> **fabricated finding**. If you flag a run, paste the two timestamps + the arithmetic.

```bash
# Format / lint / type-check run fast — terminal-only output is fine.
pnpm format && pnpm lint && pnpm type-check

# Build check (fast — terminal-only).
pnpm build:check
```

> **STANDALONE ONLY — else SKIP.** Only run the block below if this is a standalone landing with
> no full-suite CI path (no `quality-gate.yml` workflow in this repo, or a manual land with no
> Phase 1c to follow). In the normal loop/tiered close, SKIP entirely: Phase 1c no longer fires any
> full-suite CI run (that proof now happens at publish start via `ac-prove`), and a blocking local
> full run here is the exact run §5 moves off the critical path.
>
> ```bash
> # tee to a log so failure detail survives tail-truncation.
> pnpm test:all 2>&1 | tee "$ARTIFACTS_DIR/test-all.log" | tail -30
> ```

If any fail:

- **Fixable in <5 min:** Fix them now, commit the fix
- **Larger issues:** Create a P0 bead, document the failure, continue landing

**Repo-wide format sweep (separate commit).** Run it here:

```bash
{ git diff --name-only; git diff --cached --name-only; } | sort -u > /tmp/pre-sweep-dirty-${RUN_ID}.txt   # foreign WIP inventory (one path per line — no porcelain column-parsing: renames list their NEW path, spaces survive) — NEVER commit these
pnpm format   # or equivalent repo-wide prettier --write .
git diff --stat
```

If the sweep modified any file, commit ONLY the files the sweep itself newly touched —
**never `git add -A` / `git add .`** (H7d, `ac-pipeline/references/commit-discipline.md`:
a wildcard add ships concurrent sessions' WIP under this sweep's message).
Files that were already dirty before the sweep belong to other sessions — the sweep may have
reformatted them, but they are theirs to commit:

```bash
git diff --name-only | sort | comm -23 - /tmp/pre-sweep-dirty-${RUN_ID}.txt > /tmp/fmt-pathspec-${RUN_ID}.txt
[ -s /tmp/fmt-pathspec-${RUN_ID}.txt ] && git commit --pathspec-from-file=/tmp/fmt-pathspec-${RUN_ID}.txt -m "chore: format sweep (prettier)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

If nothing changed (tree was already formatted), or every reformatted file was pre-sweep
dirty (foreign WIP), skip the commit.

Mark ledger task 3 `completed`; `TaskUpdate` task 4 `in_progress`.

## 1c. Git Operations

```bash
git add <specific files>
git commit -m "chore: bead-work session cleanup

Co-Authored-By: Claude <noreply@anthropic.com>"
```

Only commit if there are uncommitted changes (cleanup, format fixes, etc.).

```bash
git pull --rebase
git push
git status   # Must show "up to date with origin"
```

**If push fails:** Resolve and retry. Do not proceed until pushed.

**No full-suite CI fire here.** ac-land's job here is done once `main` is pushed and up to date:
no CI dispatch, nothing to wait on.

Mark ledger task 4 `completed`; `TaskUpdate` task 5 `in_progress`.