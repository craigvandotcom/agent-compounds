# ac-tidy — Nightly Pipeline Tidy (headless heartbeat)

## THIS PROMPT IS YOUR TASK — EXECUTE IMMEDIATELY

You are invoked by `pai-scheduler` (~00:45, after the 00:30 maintenance job) to run the
**NIGHTLY** mode of the `ac-tidy` skill against the Body Compass pipeline. Execute without
user interaction.

**⚠️ AUTONOMOUS MODE — no human is watching.** Run every step by actually executing the
commands; do NOT just describe them. There is **no `AskUserQuestion`** in this run — the
mechanism for anything that needs a human is a *proposal*, not a prompt.

**Read `.claude/skills/ac-tidy/SKILL.md` first** — it defines NIGHTLY mode's three tiers and
the `## NIGHTLY Guardrails` (the Tier-2 toggle + the positive-proof gate). This heartbeat is
the *run skeleton*; the skill is the *behavior*.

---

## Run skeleton

### 0. Preflight

- **Isolated worktree (first, before any reads or writes) — the single-writer isolation gate.**
  The scheduler's live checkout is routinely dirty overnight (concurrent sessions leave
  uncommitted work + Agent-Mail reservations), and a dirty live tree spuriously aborted this
  run 4 nights straight (branch-guard 07-09/07-10, contention 07-12/07-14). Do NOT run tidy in
  the live checkout. Instead, **explicitly create a dedicated worktree** off fresh `origin/main`
  and run the entire rest of this skeleton inside it. This is EXPLICIT worktree creation in the
  workflow — never rely on the harness's background-isolation feature, which is disabled
  (`bg-worktree-isolation-disabled`: `bgIsolation=none`). This is the **scheduled-heartbeat
  carve-out** to `ac-pipeline`'s no-worktrees invariant (`ac-pipeline/SKILL.md` § Coordination
  & identity): that ban scopes to concurrent pipeline ceremonies sharing one checkout, not to a
  single-writer scheduled job in a checkout it does not control.

  ```bash
  BCA="$HOME/Repos/neometa/software/body-compass-app"   # canonical live checkout (has the board + .beads DB)
  git -C "$BCA" fetch origin main
  TIDY_WT="${TMPDIR:-/tmp}/ac_tidy_run-$(date +%Y%m%d-%H%M%S)-$$"
  # Detached at fresh origin/main so `main` staying checked out in the live tree is irrelevant —
  # a worktree cannot share the live checkout's branch, and detach sidesteps that entirely.
  git -C "$BCA" worktree add --detach "$TIDY_WT" origin/main || {
    "$HOME/Repos/infrastructure/tools/bin/slack-send" --channel sofi --card --status degraded \
      --title "Pipeline Tidy — $(date +%Y-%m-%d)" --body "abort: could not create isolated worktree"
    exit 0   # zero writes, retry next cycle
  }
  cd "$TIDY_WT"
  ```

  From here every command runs with `cwd = $TIDY_WT` (a clean tree at fresh `origin/main`), so
  the old dirty-live-tree / branch-guard aborts can no longer fire. The real single-writer guard
  is now the fresh-checkout isolation here + the push-verify (step 6). **Teardown at step 8 is
  mandatory** — every abort/exit path below must first remove this worktree (see step 8).
- Verify Slack resolves: `"$HOME/Repos/infrastructure/tools/bin/slack-send" --channel sofi --dry-run` (or a
  cheap probe); if `sofi` doesn't resolve, fall back to `pi`. Do this **before** any mutation.
- Read the **Tier-2 toggle** from `"$BCA/.claude/skills/ac-tidy/SKILL.md"`: grep the `## NIGHTLY
  Guardrails` block for `Tier-2 auto-archive:` → `ON`/`OFF`. Tier-2 auto-archive runs only if `ON`.
  > **Worktree symlink caveat (BINDING):** `.claude/skills/ac-tidy` is a *relative* symlink into
  > the sibling agent-compounds repo. It resolves correctly only from the live checkout (`$BCA`),
  > NOT from inside `$TIDY_WT` (a `/tmp` worktree would resolve `../../../agent-compounds` to a
  > nonexistent path). So always reference skill files (SKILL.md, last-run.json) via `$BCA/...`,
  > never via a `.claude/...` path relative to the worktree cwd. Board files (`_backlog/`,
  > `_plans/`, `.beads/`) are real files in the BCA tree and DO live in `$TIDY_WT` — edit those there.
- **No Agent-Mail reservation** — a raw scheduler `prompt_file` run is not a self-registering
  Agent-Mail entry point, so a reservation would silently no-op (`agent-mail-project-keying-gotcha`).
  The isolated worktree (fresh `origin/main`) + push-verify (step 6) are the real single-writer guard.
- **Rehydrate the beads DB in the worktree.** `br`'s local SQLite DB is gitignored, so a fresh
  worktree starts with only the committed `.beads/issues.jsonl` and no `.db`. Run `br sync` (or
  `br list`) once from `$TIDY_WT` before any `br create`/`br close` so br rebuilds its DB from
  that JSONL — otherwise proposal beads would be created against an empty DB and dedup (step 3)
  would false-miss. Keep all `br` ops in `$TIDY_WT`; step 5 commits the flushed `.beads/issues.jsonl`
  from there alongside the board changes, so beads + board land in the same push.

### 1. Sync + abort-on-contention

The worktree was just created from **fresh `origin/main`** (step 0 fetched, then checked out
`origin/main`), so it is already synced and clean by construction — there is no live-tree dirt
to inherit and nothing to fast-forward. The board (`_backlog/`, `_plans/`) inside `$TIDY_WT` is
therefore contention-free at scan time; the only remaining race is a concurrent pusher landing
on `origin/main` between now and step 6, which the push-verify handles (never force-push over it).

Do NOT `git status`-guard against live-tree dirt here anymore — that check belonged to the
in-live-checkout design and is exactly what caused the 4 spurious aborts. The isolated worktree
IS the replacement for it.

### 2. Scan the board

Read the board per `ac-pipeline/references/board-scan.md` (already excludes `_shipped/` + `audits/`).

### 3. Dedup, then auto-apply the sanctioned subset

- **Dedup first (idempotency key):** skip any cluster already covered by an **open
  `pipeline-proposal` bead** (its populated `bead:` slot is the marker). This makes a same-day
  re-fire (crash mid-run, misfire-grace, stale-lock takeover) re-derive, see its own open
  beads, and no-op. A lingering `last-run.json` `status: running` is advisory only — the bead
  dedup, not the lease, prevents double-emit.
- **Tier 1** (always): apply Phase 2d + 2e reconciliation.
- **Tier 2** (only if the toggle is ON): apply provably-done archives that pass the
  **positive-proof gate defined in `SKILL.md` § NIGHTLY Guardrails** — that bullet is the SINGLE
  definition of the gate *and* of which beads count toward it (proposal beads are excluded).
  Read it there; do not restate the predicate here — a second copy is how it drifted before.
  An item that fails the gate falls through to a Tier-3 proposal (§ 4 below).
  Never touch `human-gate`/`qa-blocker`.

### 4. Emit Tier-3 proposals atomically

For each remaining cluster (consolidation, dedup, finding-bead prune, or a Tier-2 item that
failed the gate / toggle-off):

```bash
br create "<title>" -t decision --labels "human-gate,pipeline-proposal" -p <prio> \
  --description "<full self-contained memo>"
```

Capture the returned id and write it into the proposal file's `bead:` slot. **Write the
proposal file only AFTER `br create` succeeds** (no orphan proposals with empty slots).

**Proposal file:** `_plans/_proposals/<YYYY-MM-DD>/NN-<slug>.md` (create the dated dir).
Frontmatter: `status: pending` · `bead: <id>` · `source: ac-tidy` · `summary: <one line>`.
Body: `## What` (the concrete list) + `## Why`. Write a per-run `INDEX.md` ONLY when the run
emits several proposals.

### 5. Commit + push (pathspec-scoped, from the isolated worktree)

No branch re-check is needed — the worktree is a detached checkout that no concurrent session
can switch out from under this run (the old TOCTOU branch-guard existed only because tidy shared
the live checkout). Commit the exact files touched and push the detached HEAD onto `main`:

Git discipline: `ac-pipeline/references/commit-discipline.md` — pathspec-only commits, no wildcard adds / stash, commit=push, deletion check.

Identity + reservations per `agent-mail/references/session-procedure.md` (mint · export · reserve · release).

```bash
# cwd is still $TIDY_WT
AGENT_NAME=FoggyCreek git commit -m "chore(tidy): nightly reconcile + proposals" -- <exact files touched>
git push --no-verify origin HEAD:main
```

`AGENT_NAME` inline — a fresh scheduler shell doesn't inherit the export and the pre-commit
guard blocks its own commits without it (`precommit-guard-needs-agent-name-in-shell`). NEVER
`git add -A` (it sweeps unrelated work). `--no-verify` — the husky pre-push build can hang/mask
its exit in a backgrounded shell. `HEAD:main` pushes the detached commit onto the shared branch;
all commits still land inside the BCA repo's `origin/main`, never a live-checkout branch.

### 6. Verify the push landed

`git rev-parse origin/main` must equal local `HEAD`. On non-ff/rejection (a concurrent-pusher
race) → Slack `degraded` with the stranded SHA, and do **not** auto-archive on a rejected push.
Never leave work silently stranded.

### 7. Notify — MANDATORY, do this last

```bash
"$HOME/Repos/infrastructure/tools/bin/slack-send" --channel sofi --card \
  --status <healthy|degraded> --title "Pipeline Tidy — $(date +%Y-%m-%d)" \
  --body "<one-line summary: N reconciled, M proposals, K archived>"
```

Confirm exit 0; a Slack failure IS a finding — retry once. Finalize `last-run.json` at its REAL
path — `"$BCA/.claude/skills/ac-tidy/workflows/last-run.json"` (the live-checkout symlink, which
resolves; never the worktree's broken one) — with `{status: done, counts, mode, machine}`. A
mutated board with no notification is the failure mode to avoid.

### 8. Teardown — MANDATORY on every exit path (success OR abort)

Remove the isolated worktree so none accumulate (AC: `git worktree list` is clean after a run):

```bash
cd "$BCA"                                   # leave $TIDY_WT before removing it
git -C "$BCA" worktree remove --force "$TIDY_WT" 2>/dev/null \
  || rm -rf "$TIDY_WT"                       # fallback if `worktree remove` refuses
git -C "$BCA" worktree prune                # drop any stale administrative refs
```

Every abort branch above (Slack-probe fail, push race at step 6, etc.) must run this teardown
before exiting — a crashed run that skips it leaves an orphaned `/tmp` worktree that
`git worktree list` will show until pruned. Detached worktrees carry no branch, so removal never
strands a ref.

---

## Applying proposals later

This run only *proposes*. A human applies approved proposals in `ac-human-session`, which
re-invokes `ac-tidy` (or `ac-align`) in its normal INTERACTIVE flow — there is no separate
apply mode here.
