# ac-triage — Scheduled Daily Run (headless heartbeat)

## THIS PROMPT IS YOUR TASK — EXECUTE IMMEDIATELY

You are invoked by `pai-scheduler` to run the **`ac-triage`** skill against this app's
pipeline (the job's `cwd` is the app repo). Execute without user interaction.

**⚠️ AUTONOMOUS MODE — no human is watching.** There is **no `AskUserQuestion`** in this
run. Anything that needs a human becomes an ops/`human-gate` bead + a Slack mention —
never a prompt. Run every step by actually executing the commands; do NOT just describe them.

**Read `.claude/skills/ac-triage/SKILL.md` first, then the app's
`.claude/skills/CORE/triage.md`** (enabled sources, severity bar, fetch specifics, Slack
channel). This heartbeat is the *run skeleton*; the skill is the *behavior*.

---

## Run skeleton

### 0. Preflight

- **Isolated worktree (first, before any reads or writes) — the single-writer isolation gate.**
  There is **no branch guard any more, by design.** The old one (`git branch --show-current`
  must equal `main`, else abort the whole run) aborted this heartbeat wholesale for three
  consecutive cycles on 2026-07-27 when the app checkout sat in detached HEAD: zero sources
  fetched, zero watermarks advanced, no report — and, because the abort forbade all writes, it
  could not even file the bead that would have escalated itself. Do NOT run triage in the live
  checkout. **Explicitly create a dedicated worktree** off fresh `origin/<default-branch>` and
  run the entire rest of this skeleton inside it — the pattern is ac-tidy's
  (`ac-tidy/workflows/nightly.md` § 0). This is EXPLICIT worktree creation in the workflow —
  never rely on the harness's background-isolation feature, which is disabled
  (`bg-worktree-isolation-disabled`: `bgIsolation=none`).

  **App-generic: capture the root from the invocation, never hardcode one app.** This job runs
  `cwd`'d into whichever app scheduled it, so the live checkout is derived, not pinned (ac-tidy
  can hardcode `BCA=…` because it only ever runs against body-compass-app; this workflow cannot):

  ```bash
  APP_ROOT="$(git -C "$(pwd)" rev-parse --show-toplevel)"   # the live checkout: board + .beads DB live here
  DEFAULT_BRANCH="$(git -C "$APP_ROOT" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's:^origin/::')"
  DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
  git -C "$APP_ROOT" fetch origin "$DEFAULT_BRANCH"
  TRIAGE_WT="${TMPDIR:-/tmp}/ac_triage_run-$(date +%Y%m%d-%H%M%S)-$$"
  # Detached at fresh origin/<default> — so whatever the live tree has checked out (main, a
  # feature branch, or a detached HEAD) is irrelevant: this run never reads or writes it.
  git -C "$APP_ROOT" worktree add --detach "$TRIAGE_WT" "origin/$DEFAULT_BRANCH" || {
    "$HOME/Repos/infrastructure/tools/bin/slack-send" --channel <channel from CORE/triage.md> \
      "TRIAGE DEGRADED: could not create isolated worktree — zero writes, retry next cycle"
    exit 0
  }
  cd "$TRIAGE_WT"
  ```

  From here every command runs with `cwd = $TRIAGE_WT` (a clean tree at fresh
  `origin/<default>`), so **the old branch-guard abort can no longer fire** — its cause is
  deleted, not made smarter. The real single-writer guard is now this fresh-checkout isolation
  plus the push-verify (step 4). **Teardown at step 6 is mandatory** — every abort/exit path
  below must remove this worktree first.

- **Worktree-creation failure is the ONE pre-write abort that survives** (the `||` branch
  above), and that is accepted precedent, not a residual defect: it escalates over Slack and
  `exit 0`s with zero writes, deliberately touching nothing in the app checkout, exactly as
  `ac-tidy/workflows/nightly.md` § 0 handles its own. It cannot file a bead because there is no
  safe tree to write one into; Slack is the whole channel. Use ac-triage's own
  `TRIAGE DEGRADED: <reason>` vocabulary (step 5) — `slack-send` takes the message
  positionally; do not reach for another skill's `--card`/`--status` flags here.

- **Worktree symlink caveat (BINDING).** `.claude/skills/ac-triage` and
  `.claude/skills/CORE` are *relative* symlinks into the sibling agent-compounds repo. They
  resolve only from the live checkout (`$APP_ROOT`), NOT from inside a `/tmp` worktree (which
  would resolve `../../../agent-compounds` to a nonexistent path). So read every skill file —
  `SKILL.md`, `CORE/triage.md` — via `"$APP_ROOT/.claude/skills/…"`, never via a `.claude/…`
  path relative to the worktree cwd. Board/state files (`.beads/`, `.claude/state/`,
  `_backlog/pool/`) are real files in the app tree and DO exist in `$TRIAGE_WT` — read and
  write those there.

- **Rehydrate the beads DB in the worktree — before any `br create`/`br close`.** `br`'s local
  SQLite DB is gitignored, so a fresh worktree starts with only the committed
  `.beads/issues.jsonl` and no `.db`. Run `br sync` (or `br list`) once from `$TRIAGE_WT` so br
  rebuilds its DB from that JSONL. **Skipping this silently breaks the run's whole point:**
  Phase-3 dedup against open beads would false-miss on an empty DB and re-file the same
  findings every single day. Keep all `br` ops in `$TRIAGE_WT`; step 4 commits the flushed
  `.beads/issues.jsonl` from there alongside the state changes, so beads + report land in one push.

- **Slack probe (before any mutation):**
  `"$HOME/Repos/infrastructure/tools/bin/slack-send" --channel <channel from CORE/triage.md> --dry-run`
  (absolute path — this job runs `cwd`'d into the app). If the channel doesn't resolve,
  fall back to `pi`.
- **No Agent-Mail reservation** — a raw scheduler `prompt_file` run is not a
  self-registering Agent-Mail entry point (`agent-mail-project-keying-gotcha`). The
  append-only write set (step 3) is the collision guard.

### 1. Run the skill (Phases 0–4, exactly per SKILL.md)

- Watermarks from `.claude/state/triage-watermarks.json`; advance a source's watermark
  ONLY after its successful fetch.
- Fetch every source CORE/triage.md marks live. **Configured-but-failing → escalate**
  (ops `human-gate` bead, deduped against open ones), never silent-skip, never advance
  that watermark.
- Cluster, severity-filter, dedupe against open beads AND open pool candidates.
- Route by shape: defects → beads, ALWAYS `unrefined` (**the Phase-3a readiness bar** —
  permalink + suspected commit + repro + verification path — is evidencing guidance, not a
  stamping decision; only `/ac-bead-refine` ever applies `refined`, and a
  refined-by-construction bead just converges there fast); themes → `_backlog/pool/`
  candidates with `status: candidate`.

### 2. Group + refine (per-run epic + in-session `ac-bead-refine`)

- **Per-run epic:** if this run created 2+ finding-beads (Phase 3a), group them under one
  epic (`br create -t epic "Triage <date> — findings"`, children linked via parent-child
  deps). 0–1 beads → no epic.
- **In-session refine, before the report:** if this run created ≥1 bead, run
  `ac-bead-refine` NOW — scoped to the epic if one exists, to the single bead otherwise.
  0 beads → skip. Triage never stamps `refined` itself — that comes from this
  `ac-bead-refine` invocation's own convergence (SKILL.md Phase 3c).

### 3. Report + persist (even on a zero-findings run)

- Write the Phase-4 report to `.claude/state/triage-last-run.md` — an empty run still
  writes it (proof-of-life; a dead scheduler and a quiet prod must not look identical).
- Post the same report via `slack-send` to the app's channel.

### 4. Commit + push (pathspec-scoped ONLY)

- Stage only what triage owns: `.beads/*.jsonl`, `.claude/state/`, `_backlog/pool/`.
  Never sweep unrelated dirty files (concurrent sessions share this checkout).
Identity + reservations per `agent-mail/references/session-procedure.md` (mint · export · reserve · release). <!-- net-growth-ok: ac-gcj.7 Pass C canon binding -->

- Commit **from inside `$TRIAGE_WT`** (a detached checkout — there is no branch to re-check,
  and no concurrent session can switch it out from under this run), with `AGENT_NAME=<name>`
  inline and a pathspec-scoped `--` file list; then push the detached HEAD onto the default
  branch. Never `git add -A`.

  ```bash
  # cwd is still $TRIAGE_WT
  AGENT_NAME=<name> git commit -m "chore(triage): daily findings + report" -- <exact files touched>
  git push --no-verify origin "HEAD:$DEFAULT_BRANCH"   # HEAD:main in every current neoMeta app
  ```

  `AGENT_NAME` inline — a fresh scheduler shell doesn't inherit the export and the pre-commit
  guard blocks its own commits without it (`precommit-guard-needs-agent-name-in-shell`).
  `--no-verify` — the pre-push build hook swallows background pushes.
- **Verify the push landed:** `git rev-parse "origin/$DEFAULT_BRANCH"` must equal local `HEAD`.
  On non-ff/rejection (a concurrent-pusher race) → Slack `TRIAGE DEGRADED:` with the stranded
  SHA. Never leave work silently stranded.

### 5. Degrade loudly

Any failed step → `slack-send` a `TRIAGE DEGRADED: <reason>` line to the app's channel.
Exit without partial watermark advances.

### 6. Teardown — MANDATORY on every exit path (success OR abort)

Remove the isolated worktree so none accumulate (AC: `git worktree list` is clean after a run):

```bash
cd "$APP_ROOT"                                        # leave $TRIAGE_WT before removing it
git -C "$APP_ROOT" worktree remove --force "$TRIAGE_WT" 2>/dev/null \
  || rm -rf "$TRIAGE_WT"                              # fallback if `worktree remove` refuses
git -C "$APP_ROOT" worktree prune                     # drop any stale administrative refs
```

Every abort branch above — Slack-probe fail, source-fetch escalation, push race at step 4,
degrade at step 5 — must run this teardown before exiting. A leaked `/tmp` worktree per day is
its own defect. Detached worktrees carry no branch, so removal never strands a ref. (The one
exception is the worktree-*creation* failure in step 0: there is nothing to tear down.)
