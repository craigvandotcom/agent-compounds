# Run ledger — the ceremony resume anchor (shared)

**Scope (ac-gcj.4):** the ONE definition of the run-ledger pattern the long-running
ceremonies (`ac-loop`, `ac-merge`, `ac-batch-close`, `ac-land`) all use. Each skill keeps
only its own task table + the state vars it persists; the pattern lives here.

## Why

Every conductor ceremony spans a window where the session can drop or compact (CI polls,
slow standalone gates, mid-flight compaction). A resumed session with no ledger re-polls
from scratch, re-asks answered questions, or — worst — skips teardown, leaving zombies.

## The pattern

**No Task tools in your context?** If `TaskCreate` is unavailable (subagent / fan-out
path), track the ledger inline in `progress.md` (+ `$STATE` for captured vars) in the
RUN_ID-scoped artifacts dir — same one-entry-per-section, advance-as-you-go contract,
same resume semantics. This is a sanctioned equivalent, not a deviation. Don't re-derive
this; the file IS the ledger. (Subagent/child harness contexts routinely lack
TaskCreate/TaskUpdate — 6 independent rediscoveries in one run, ac-qsz.)

1. **Declare at ceremony start:** `TaskCreate` — **one task per major section**, in run
   order, first task `in_progress`, rest `pending`. The section headers in the skill map
   to these tasks 1:1.
2. **Advance as you go:** `TaskUpdate` each task to `in_progress` when its section starts
   and `completed` when it ends — never batch-update at the end (a drop between sections
   must land on the true position).
3. **Persist captured facts:** as the run captures values a resume would need
   (`PR_NUMBER`, `ANCHOR`, `NEW_VERSION`, …), append them to `$STATE`
   (`echo "KEY=$VAL" >> "$STATE"`) so a dropped session reloads instead of re-deriving.

## The doctrine

**The ledger tracks the RUN, never the work.** It holds phases/sections — and nothing
else. Work items stay **beads**: the board is the single source of truth for *what* ships
(`ac-pipeline` axiom 1, *the bead is the atom*). The ledger is a navigation aid
over the run, not a second copy of the queue — never put bead IDs or per-bead state in
it, or the two will drift. (Artifact-of-record files like `progress.md` track *what was
accomplished*; the ledger tracks *where the run is*.)

**On resume (compaction / restart):** read the ledger FIRST — it is the resume *anchor*
(which section you were in). Then reconcile against live state, which stays ground truth:
a step the ledger calls `in_progress` may have completed in the moments before the drop.
Trust the **board/tree/CI** for work state; trust the **ledger** for run position.
