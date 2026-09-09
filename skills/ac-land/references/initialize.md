# ac-land Phase 0 — initialize mechanics

<!-- mirror: ac-pipeline/references/run-id.md § Prefixes · run-ledger.md § pattern -- edit there first -->

## ARTIFACTS_DIR resolution

Resolve `ARTIFACTS_DIR` deterministically, per `ac-pipeline/references/run-id.md`. ac-land runs at
loop-exit (post-merge/batch-close, on `main`) — it never claimed a batch itself, so it CANNOT
mint or independently recompute a claim id; the orchestrator hands it the key. Never glob as
the primary path. There is no branch-based fallback in this chain.

```bash
# 0. Loop-exit: RUN_ID set → ALL this run's dirs (scoped glob is SAFE — RUN_ID excludes
#    foreign/stale dirs). The retrospective spans every batch this run shipped; teardown sweeps
#    them all.
# 1. Handed ARTIFACTS_DIR (single bead-work session, no RUN_ID) → use verbatim.
# 2. Last resort → newest dir, with a logged warning (it was guessed).
if [ -n "$RUN_ID" ]; then
  ARTIFACTS_DIRS=$(ls -1dt /tmp/bead-work-*-"$RUN_ID"/ 2>/dev/null | sed 's:/$::')
  ARTIFACTS_DIR=$(printf '%s\n' "$ARTIFACTS_DIRS" | head -1)   # primary (newest batch) for single-dir steps
  [ -z "$ARTIFACTS_DIR" ] && ARTIFACTS_DIR=/tmp/bead-work     # run shipped nothing landable
elif [ -n "$ARTIFACTS_DIR" ]; then
  :                                                   # handed by orchestrator — use verbatim
else
  ARTIFACTS_DIR=$(ls -1dt /tmp/bead-work-*/ 2>/dev/null | head -1 | sed 's:/$::')
  [ -z "$ARTIFACTS_DIR" ] && ARTIFACTS_DIR=/tmp/bead-work
  echo "WARN: ARTIFACTS_DIR not handed and no RUN_ID scope — GUESSED $ARTIFACTS_DIR" >&2
fi
echo "ARTIFACTS_DIR=$ARTIFACTS_DIR"
[ -n "$ARTIFACTS_DIRS" ] && echo "ARTIFACTS_DIRS (all batches this run, retrospective spans all): $ARTIFACTS_DIRS"
```

**You MUST substitute the resolved `$ARTIFACTS_DIR` into all sub-agent prompts below.** The
literal string `/tmp/bead-work` is a placeholder — for parallel sessions you write the actual
resolved path into each spawned agent's prompt. Do NOT pass the variable name; sub-agents don't
share the parent shell.

## Run ledger

Declare the run ledger per `ac-pipeline/references/run-ledger.md` (pattern + resume doctrine
there), with **each of Phase 1's three sub-steps as its own task** so a resume never skips teardown:

```
TaskCreate (one per section, in run order):
  1. Initialize                            in_progress
  2. File remaining work (1a)              pending
  3. Quality gates (1b)                    pending
  4. Git ops — commit + push (1c)          pending
  5. Learn (retrospective)                 pending
  6. Compound (system upgrades)            pending
  7. Hand off                              pending
  8. Teardown                              pending
```

The section headers map to these tasks 1:1; mark task 1 `completed` now. A compacted conductor
reads the ledger to know whether teardown (task 8) still owes work. If TaskCreate is unavailable
(subagent / fan-out path), track the same 8 sections inline in `$ARTIFACTS_DIR/progress.md`; this
is a sanctioned equivalent, not a deviation.

## Session context gather

```bash
# What beads were completed this session
br list --json

# Recent commits (the session's work)
git log --oneline -20

# Current state
git status
git diff --stat
```