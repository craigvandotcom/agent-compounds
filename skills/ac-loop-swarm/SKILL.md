---
name: ac-loop-swarm
description: 'Pull-based parallel bead swarm: N fungible workers each pull the next ready refined bead (atomic `br --claim`), reserve files, implement, scoped-check, flock-commit to main, Delivers-gate, close, repeat until the queue is dry. Orchestrator only asks width, spawns, waits, owns the one ledger commit + batch CI. Triggers: ''swarm the beads'', ''ac-loop-swarm'', ''run the swarm'', ''parallel bead pull''. NOT for conductor-dispatched waves (ac-loop), one bead (ac-implement), unrefined work (ac-bead-refine).'
disable-model-invocation: true
---

**You are the orchestrator of a pull-based bead swarm on `main`.** Ask for width, spawn N
identical workers, close out when they finish. Never pick beads, never review code, never
dispatch work. Workers pull. Coordination lives in artifacts — `br` claims, Agent Mail
reservations, `## Consumes` / `## Delivers` — not in you.

## Phase 0 — Orient (interactive)

1. Branch is `main`. Note dirty files as foreign WIP; workers never stage them. Never
   stash, reset or clean.
2. `RUN_ID=$(date +%Y%m%d-%H%M%S)-$$`.
3. `macro_start_session(human_key:"<repo human_key>", program:"claude-code",
   model:"<your model>", task_description:"ac-loop-swarm orchestrator <RUN_ID>")`. Keep the
   `registration_token`. `install_precommit_guard(project_key, repo_path)` once — workers do
   not install it.
4. Count the pickable pool with the workers' filter:
   ```bash
   RUST_LOG=error br ready --json -l refined | python3 -c '
   import json,sys
   SKIP={"human-gate","device","epic","unrefined"}
   p=[i for i in json.load(sys.stdin)
      if not SKIP & set(i.get("labels") or [])
      and i.get("issue_type")!="decision" and i.get("status")=="open"]
   print(len(p))'
   ```
   Zero → report and stop. Refining beads is `ac-bead-refine`'s lane.
5. Width prompt — plain text, timed, never `AskUserQuestion` (no timeout; a headless
   session hangs). Print:
   `Pool: <count> pickable beads. Width (workers) [2] · Cap (beads/worker) [3] · Filter (e.g. "type=bug p<=2") [none] — reply in 120s or defaults apply.`
   Headless runs never prompt: width 2, cap 3, no filter.
6. Write `{RUN_ID, WIDTH, CAP, FILTER, pool, started_at}` to
   `.claude/reports/ac-loop-swarm-<RUN_ID>/run.json`.

## Phase 1 — Spawn

Spawn WIDTH identical workers in one message with the `Agent` tool:
`subagent_type: "general-purpose"` (workers need the Agent Mail MCP tools; the
`implementer` stance is Bash-only), `model: "opus"` pinned per call (never
`CLAUDE_CODE_SUBAGENT_MODEL`). Prompt = `references/worker-seed.md` verbatim with
`<K> <N> <RUN_ID> <CAP> <FILTER> <REPO_HUMAN_KEY>` substituted. Workers are fungible;
`K` only staggers the first pick.

Then wait for the completion notifications. Do not poll `br`, do not read worker
transcripts, do not work beads yourself.

## Phase 2 — Close-out (after the last worker returns)

1. **Orphan sweep.** `RUST_LOG=error br coordination status --json`. Every `in_progress`
   claim held by a `swarm-<RUN_ID>-*` actor is an orphan:
   `br update <id> --status open --assignee "" --json` + comment
   `"Orphaned by dead worker <actor> run <RUN_ID>"`. `force_release_file_reservation` for
   each worker that returned no report.
2. **Reconcile git.** If `git log origin/main..HEAD` is non-empty: stash only if the tree is
   dirty (`git stash push -u -m "ac-loop-swarm <RUN_ID> WIP"`), `git pull --rebase origin main
   && git push`, pop if stashed. A rebase conflict is a human gate: abort, file a
   `human-gate` bead (`Gate-reason: action`), report.
3. **Ledger — the one commit.** Workers close beads in the shared `beads.db` only.
   ```bash
   RUST_LOG=error br sync --flush-only
   git add -- .beads/issues.jsonl
   git commit -m "chore(beads): ac-loop-swarm RUN <RUN_ID> ledger [no-bead]"
   git push
   ```
   A husky beads guard firing here is a stop: report, never bypass.
4. **Batch CI.** Invoke `ac-batch-close` in a fresh sub-session. Clean-HEAD CI is the only
   authoritative test signal for the run; workers ran scoped checks only.
5. **Report** to `.claude/reports/ac-loop-swarm-<RUN_ID>/report.md` and the human: closed ·
   blocked · gated · premise-failed · orphaned · unpushed-reconciled · CI run URL ·
   per-worker counts. Route each worker's `discoveries` through `ac-bead-capture` and its
   `friction` to this skill's FRICTIONS.md. Release reservations, `deregister_agent`.

---

## Invariants

- Pick from `br ready --json -l refined`, filtered and sorted in code — bugs first, then
  priority, then FIFO (beads-standards § Pick-order). Not `bv --robot-next`: no exclude, label-blind.
- Claim with `br update <id> --claim --actor "$ACTOR"`. The second claimant gets
  `VALIDATION_FAILED`, `retryable: true`; it re-picks. This refusal replaces the conductor.
- Skip labels `human-gate`, `epic`, `device`, `unrefined` and type `decision`. Epics sit in
  `br ready` typed `task`/`feature`. `device` beads share one simulator.
- Premise-check `## Consumes` before claiming; Delivers-gate before closing. A closed bead's
  `close_reason` is the next bead's premise proof. Canon: beads-standards § Delivers/Consumes.
- Workers never stage `.beads/issues.jsonl`. One committer per scope: beads-standards § One committer.
- No `git pull --rebase` inside a worker: it needs a clean tree and siblings always have
  WIP. One checkout is one HEAD; workers diverge only from a foreign push, reconciled once
  at close-out.
- Commit under `flock "$(git rev-parse --git-common-dir)/swarm-commit.lock"`, asserting
  `main` inside the lock. Never `.git/<name>.lock`: `.git` is a FILE in every neoMeta app,
  so that path never opens and the mutex silently does nothing. Replaces `index.lock` retries.
- Scoped checks only. Never the full suite; never unfiltered `tsc`. A shared dirty tree
  reports siblings' half-edits as your failures. `vitest related` with
  `VITEST_AFFECTED_DISABLED=1` (the plugin seeds from whole-tree `git diff`); assert the
  reported result-file count, and strip ANSI before grepping `tsc` output — both collapse
  to a false green.
- A failure in a file a sibling has reserved is not yours: wait 60s, retry once, then own it.
- Workers report adjacent discoveries; they never fix or file them mid-run.
- No build slots. Spawned workers hold no token for them; the push-assert is the guarantee.
- No blocking question. A decision becomes a `human-gate` bead.

## First-run defaults

`WIDTH=2 CAP=3 FILTER="type=bug p<=2"`. Observe one run, then width 3. Practical ceiling
for one orchestrator context: 4–8 workers.

## Accepted limits

- No independent review per bead. Batch CI and `ac-hygiene` on cadence carry it; keep the
  review panel for risky scopes.
- Shared-tree check poisoning is reduced, not removed. Worktrees remove it and bring back
  per-DB ledger races.
- `vitest related` is static-graph, shallower than `vitest-affected`. Follow-up: a seed-list
  env in vitest-affected lets workers use full affected selection.
- One self-hosted runner serialises CI. N× implementation is not N× shipping.
- Worker context can run out mid-bead: hence `CAP`, the claim-time comment, the orphan
  sweep.
