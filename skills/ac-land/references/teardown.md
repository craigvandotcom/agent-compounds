# ac-land teardown — cleanup + operational teardown mechanics

<!-- mirror: ac-pipeline/references/shell-guardrails.md § delete shapes · agent-mail/references/agent-identity.md § tiers -- edit there first -->

Landing means leaving NO live debris. Run regardless of how the session reached land
(clean finish, iteration cap, regression stop, human "stop", or error). **Child-path
teardown-resume:** if TaskCreate is unavailable (subagent / fan-out path), the resume
artifact is `$ARTIFACTS_DIR/progress.md` section `### Teardown` — write it `in_progress`
before this section starts and `completed` only after Final Verification. A compacted
child that cannot find that section still owes teardown; do not skip it.

## Cleanup temp files

Remove session artifacts (they've been consumed by retrospective). Run each block separately to avoid shell chaining that triggers safety hooks.

**Concurrency-safe, two-tier teardown.** Scheduled ac-implement swarm runs can overlap in time, and one run's mixed-kind children each hold their own dir, so a blind `rm -rf /tmp/<prefix>-*` would delete a concurrently-LIVE run's in-flight artifact dirs. Two tiers, covering all 11 targets (10 glob prefixes + the bare literal `/tmp/bead-work`):

- **Tier 1 — universal content-aware age-gate (LOAD-BEARING).** A dir is stale ONLY if nothing inside it — nor the dir itself — was modified within `STALE_MIN` minutes: `find "$d" -mmin -$STALE_MIN -print -quit` returning non-empty means something is fresh ⇒ LIVE ⇒ keep; empty output ⇒ demonstrably abandoned ⇒ delete. Do NOT gate on the parent dir's own mtime: in-place rewrites of files like `progress.md` do NOT bump the containing dir's mtime, so a dir-mtime gate would reap a live long-running run. Each loop is keyed to its exact `/tmp/<prefix>-*/` glob (or the literal `/tmp/bead-work`) — nothing can reach unrelated `/tmp` content.
- **Tier 2 — RUN_ID exact-match (optimization; the 7 embedding prefixes ONLY).** Immediately delete THIS run's own dirs so it cleans up after itself without waiting out the age gate. The `[ -n "$RUN_ID" ]` guard on every line is MANDATORY: with `RUN_ID` unset or empty, the unguarded glob degenerates right back to the original unscoped bug. `work-review-*`, `batch-close-*`, external `plan-refine-*`, and bare `/tmp/bead-work` get NO tier-2 line — a RUN_ID glob never matches them, and a silent no-op masquerading as cleanup is worse than no line — they rely on the age gate alone.

Every candidate is PRINTED (`STALE:` / `OWN:` lines) and nothing is deleted inside the loops — deletion happens in the compose step below, so a wrongful sweep is diagnosable post-hoc.

```bash
STALE_MIN=1440   # 24h — max plausible gap between WRITES in a live run (NOT a bound on total run duration)

# Tier 1 — universal content-aware age-gate, ONE selector over all 12 targets (11 glob
# prefixes + literal /tmp/bead-work; globs expand at the CALL SITE, so the function only
# ever sees concrete dirs — identical per-dir semantics to writing 12 loops longhand).
# Prefix inventory: ac-pipeline/references/run-id.md § Prefixes — keep the argument list in sync.
stale() { for d in "$@"; do [ -d "$d" ] || continue
  [ -z "$(find "$d" -mmin -$STALE_MIN -print -quit 2>/dev/null)" ] && echo "STALE: $d"; done; }
stale /tmp/bead-work/ /tmp/bead-work-*/ /tmp/plan-init-*/ /tmp/batch-close-*/ \
      /tmp/plan-refine-internal-*/ /tmp/plan-refine-*/ /tmp/plan-clean-*/ \
      /tmp/bead-refine-*/ /tmp/beadify-*/ /tmp/hygiene-*/ /tmp/work-review-*/

# Tier 2 — immediate self-cleanup by exact RUN_ID match, 7 embedding prefixes only.
# The [ -n "$RUN_ID" ] guard is MANDATORY (unset RUN_ID degenerates the globs to the
# original unscoped bug — one guard, wrapping every glob).
if [ -n "$RUN_ID" ]; then
  for d in /tmp/bead-work-*-"$RUN_ID"/ /tmp/plan-init-*-"$RUN_ID"/ \
           /tmp/plan-refine-internal-*-"$RUN_ID"/ /tmp/plan-clean-*-"$RUN_ID"/ \
           /tmp/bead-refine-*-"$RUN_ID"/ /tmp/beadify-*-"$RUN_ID"/ /tmp/hygiene-*-"$RUN_ID"/; do
    [ -d "$d" ] && echo "OWN: $d"
  done
fi
```

**Step 2 — compose the delete from the PRINTED LITERALS (the dcg contract).** The loops
above are SELECTORS ONLY — they print candidates and delete nothing. `rm -rf "$d"` inside
a loop is a dynamic-path delete and dcg blocks it. Read the `STALE:`/`OWN:` lines and
issue ONE command with the printed paths pasted verbatim as literals:

```bash
# example — paste the actual printed paths; never $VAR, never $( ), never a bare loop var
rm -rf /tmp/bead-work-buglane-20260719-102946-27401 /tmp/bead-refine-20260719-102946-27401-refA
```

Allowed/blocked delete shapes are canon — `ac-pipeline/references/shell-guardrails.md`
(literal `/tmp/...` paths + distinctive globs allowed; variable/substituted paths and
home/repo `rm -rf` blocked — the version-pinned details live THERE, not here). For
repo-tree debris (a stale `.next.stale-*`, an orphaned scratch file): `git rm` if tracked;
else gitignore-and-flag or `dcg allow-once` — don't fight the guard. Zero `STALE:`/`OWN:`
lines printed = nothing to delete; step 2 is skipped.

Mark ledger task 7 `completed`; `TaskUpdate` task 8 `in_progress`.

## Teardown (operational)

1. **Kill spawned background tasks/waiters.** Long-running poll/wait loops are the classic
   zombie — a `until cond; do sleep N; done` whose condition never fires runs forever.
   Stop them by IDENTITY, not a broad sweep:
   - For harness-tracked background tasks: `TaskStop` each one you started this session.
   - For stray shells, list candidates and confirm each is yours before killing — match the
     specific command, never a blanket pattern:
     ```bash
     ps -Ao pid,etime,command | grep -iE "until .*sleep|seq 1 .*gh (run|pr)|pnpm test:all" | grep -v grep
     # kill -TERM <pid> ONLY for loops you recognize as this session's. Do NOT kill the
     # self-hosted Actions runner, the dev server someone else owns, or unrelated jobs.
     ```
   - Then confirm none survive: re-run the `ps … grep` → expect empty.
   - **Prevention**: every waiter you create needs a hard cap (`for i in $(seq 1 N)` /
     `timeout`), never an unbounded `until`. A waiter that can't time out is a future zombie —
     and the rule binds when you _write_ the loop, not just when teardown sweeps for it here.
2. **Agent Mail:** if THIS land session minted a Tier-1 identity, first release its
   reservations (`release_file_reservations`, all paths), then Layer-1 self-deregister with its
   `registration_token` (`deregister_agent` — never `retire_agent`: name-only cross-session
   retire is rejected at runtime, decision `ac-ycr.8`). Don't leave reservations to TTL-expire.
   A land session running as the Tier-2 chore identity (the normal case for the format-sweep /
   report / learnings commits) holds no reservations and must NEVER be deregistered or retired
   (`agent-mail/references/agent-identity.md` § Tier 2).
   Then perform the **Layer-2 roster sweep** (doctrine `agent-mail/references/agent-identity.md`
   wiring `ac-ycr.5`): the Exit-Land prompt handed you `AGENT_MAIL_ROSTER` = the loop conductor's
   name plus every child identity this run registered.

   **Project-key resolution (bd-8kdjl).** Any Agent Mail call that still takes `project_key` /
   `human_key` MUST use the pinned literal from `.claude/hooks/session-start.md`
   (the `human_key:` field). READ that file — do not derive a key from cwd,
   `$PROJECT_ROOT`, `git rev-parse --show-toplevel`, or any absolute path. An absolute
   path slugifies into a **forked mailbox** and the sweep reports "roster clean" by
   absence. Observed resolver (run this, do not invent the string):

   ```bash
   PINNED_KEY=$(sed -n 's/.*human_key: *"\([^"]*\)".*/\1/p' \
     .claude/hooks/session-start.md | head -1)
   [ -n "$PINNED_KEY" ] || { echo "FATAL: no pinned human_key in session-start.md" >&2; exit 2; }
   # Layer-2 existence check uses ONLY $PINNED_KEY (never $PROJECT_ROOT / pwd).
   ```

   Layer 2's *release* sweep itself is **not** keyed on one project_key — use the
   sqlite query in `agent-mail/references/agent-identity.md` § "The sweep is NOT
   project-key-agnostic" so a forked mailbox cannot hide holds. `whois` / verify
   calls that still need a key use `$PINNED_KEY` only.

   Layer 2 is **reservations-only** — for each name on that roster (skip the live conductor —
   it deregisters itself after you return), run ONLY `force_release_file_reservation` on any
   stale holds it left (the tool validates abandonment heuristics before releasing). Do NOT
   `retire_agent`/`deregister_agent` the roster names: name-only cross-session identity retire
   is rejected at runtime (decision `ac-ycr.8`; tokens live with the minting session), so a dead
   child's identity persists as harmless roster noise until the upstream admin-sweep primitive
   lands. Then VERIFY the reservations are clear — re-list the project's holds and confirm no
   swept child reservation remains. This is the backstop for children that died before their own
   Layer-1 self-deregister; do not skip it on an empty-looking roster.

   **Pre-commit guard.** This is separate from the roster sweep above and deregisters/retires
   nobody. Uninstall the mcp-agent-mail guard **only when this repo's hooks are TRACKED** —
   i.e. `git config core.hooksPath` names a directory whose `pre-commit` appears in
   `git ls-files`. That is the only shape in which the chain-runner wraps the repo's own
   tracked hook and dirties the working tree; everywhere else the guard lives in the untracked
   gitdir hooks directory, is invisible to the tree, and must be LEFT IN PLACE.
   Do NOT gate on "did THIS session install it" — neither tool carries session or agent
   identity, so that condition is trivially true and gates nothing.
   Do NOT call it unconditionally either: the guard is repo-scoped, two concurrent ac-implement
   swarm runs can share this checkout (§ Concurrency-safe, two-tier teardown), and idempotence
   is not concurrency-safety — an unconditional uninstall strips a live sibling session's
   protection. Fail safe toward leaving it: `ac-implement` re-installs it idempotently every
   session, so leaving it costs nothing while removing it wrongly does. When the condition
   holds, call `uninstall_precommit_guard(code_repo_path)` — repo path ONLY, no `project_key`
   (unlike its `install_precommit_guard` sibling). A `removed:false` result simply means nothing
   was installed — a clean no-op that needs no error handling and no "is a guard present?" probe
   first.

   **Tracked-hook integrity check — run this UNCONDITIONALLY** (it is read-only unless something
   was actually modified). Resolve the hooks directory with `git rev-parse --git-path hooks`, or
   honour `core.hooksPath`; never assume a fixed path inside the gitdir, which does not even
   resolve in a submodule (there `.git` is a file, not a directory). The check can only bite in
   repos whose hooks are tracked — in the common untracked case there is nothing to find, so do
   not hunt for a modification that cannot exist. If a tracked hook comes back modified, restore
   it from the committed version: `git checkout -- <hook-path>`, or read the pristine copy with
   `git show HEAD:<hook-path>` when the tree must not be touched. The file is tracked by
   definition of the condition, so no snapshot or backup mechanism exists or needs inventing.
3. **Working tree:** resolve or EXPLICITLY flag non-wave junk. A dirty tree the next session
   trips over is a teardown failure. If concurrent-session files are present and not yours
   (unmerged `UU`, stray staged files), surface them in the summary — don't silently leave
   them, and don't blindly discard another agent's uncommitted work.

## Final verification

```bash
git status          # Clean working tree
git log --oneline -1  # Latest commit pushed
br ready --json     # What's left
```

Mark ledger task 8 `completed` — the run is landed.