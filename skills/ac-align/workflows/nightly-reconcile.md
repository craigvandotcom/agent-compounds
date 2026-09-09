# ac-align — Nightly Pipeline Reconcile (headless heartbeat)

## THIS PROMPT IS YOUR TASK — EXECUTE IMMEDIATELY

You are invoked by `pai-scheduler` (~00:45, after the 00:30 maintenance job) to run the
**NIGHTLY** reconcile of the pipeline — the cadence the retired tidy skill used to own,
folded here. Execute
without user interaction.

**⚠️ AUTONOMOUS MODE — no human is watching.** Run every step by actually executing the
commands; do NOT just describe them. There is **no `AskUserQuestion`** in this run — the
mechanism for anything that needs a human is a *proposal*, not a prompt.

**Read `.claude/skills/ac-align/SKILL.md` first** — its REVIEW-mode rules (propose, never
apply, at Phase 4.5) and the nightly-specific tiers + guardrails below. This heartbeat is the
*run skeleton*; the skill is the *behavior*. The reconcile phases (archive, status repair,
label lint) are defined here in the skeleton — they were the retired tidy skill's and this
file is now their
home.

---

## Run skeleton

### 0. Preflight

- **Isolated worktree (first, before any reads or writes) — the single-writer isolation gate.**
  The scheduler's live checkout is routinely dirty overnight (concurrent sessions leave
  uncommitted work + Agent-Mail reservations), and a dirty live tree spuriously aborted this
  run 4 nights straight. Do NOT reconcile in the live checkout. Instead, **explicitly create
  a dedicated worktree** off fresh `origin/main` and run the entire rest of this skeleton
  inside it. This is EXPLICIT worktree creation in the workflow — never rely on the harness's
  background-isolation feature, which is disabled (`bg-worktree-isolation-disabled`:
  `bgIsolation=none`). This is the **scheduled-heartbeat carve-out** to `ac-pipeline`'s
  no-worktrees invariant: that ban scopes to concurrent pipeline ceremonies sharing one
  checkout, not to a single-writer scheduled job in a checkout it does not control.

  ```bash
  BCA="$(git rev-parse --show-toplevel)"   # canonical live checkout (has the board + .beads DB) — the scheduler cwd is the app
  git -C "$BCA" fetch origin main
  RECON_WT="${TMPDIR:-/tmp}/ac_align_reconcile-$(date +%Y%m%d-%H%M%S)-$$"
  git -C "$BCA" worktree add --detach "$RECON_WT" origin/main || {
    "$HOME/Repos/infrastructure/tools/bin/slack-send" --channel sofi --card --status degraded \
      --title "Pipeline Reconcile — $(date +%Y-%m-%d)" --body "abort: could not create isolated worktree"
    exit 0   # zero writes, retry next cycle
  }
  cd "$RECON_WT"
  ```

  From here every command runs with `cwd = $RECON_WT` (a clean tree at fresh `origin/main`).
  **Teardown at step 8 is mandatory** — every abort/exit path below must first remove this
  worktree (see step 8).
- Verify Slack resolves: `"$HOME/Repos/infrastructure/tools/bin/slack-send" --channel sofi --dry-run` (or a
  cheap probe); if `sofi` doesn't resolve, fall back to `pi`. Do this **before** any mutation.
- **Worktree symlink caveat (BINDING):** `.claude/skills/ac-align` is a *relative* symlink into
  the sibling agent-compounds repo. It resolves correctly only from the live checkout (`$BCA`),
  NOT from inside `$RECON_WT` (a `/tmp` worktree would resolve to a nonexistent path). So
  always reference skill files via `$BCA/...`, never via a `.claude/...` path relative to the
  worktree cwd. Board files (`_backlog/`, `_plans/`, `.beads/`) are real files in the BCA tree
  and DO live in `$RECON_WT` — edit those there.
- **No Agent-Mail reservation** — a raw scheduler `prompt_file` run is not a self-registering
  Agent-Mail entry point, so a reservation would silently no-op. The isolated worktree (fresh
  `origin/main`) + push-verify (step 6) are the real single-writer guard.
- **Rehydrate the beads DB in the worktree.** `br`'s local SQLite DB is gitignored, so a fresh
  worktree starts with only the committed `.beads/issues.jsonl` and no `.db`. Run `br sync` (or
  `br list`) once from `$RECON_WT` before any `br create`/`br close` so br rebuilds its DB from
  that JSONL. Keep all `br` ops in `$RECON_WT`; step 5 commits the flushed `.beads/issues.jsonl`
  from there alongside the board changes, so beads + board land in the same push.

### 1. Sync + abort-on-contention

The worktree was just created from **fresh `origin/main`** (step 0 fetched, then checked out
`origin/main`), so it is already synced and clean by construction. The only remaining race is
a concurrent pusher landing on `origin/main` between now and step 6, which the push-verify
handles (never force-push over it).

### 2. Scan the board

Read the board per `ac-pipeline/references/board-scan.md`. Print Scan A's `docket-health` line
(open human-gate count + reason-less count; ALARM if `>25` open gates OR any reason-less gate
older than `48h`).

### 2b. Surviving-gate verify (prep pass — not de-gating)

For every OPEN `human-gate` bead still on the docket (Scan A's set — exclude deferred and
future `defer_until`):

1. Re-read live state (`br show <id>`). Confirm the work is still blocked on a human.
2. **Skip any id whose LIVE-checkout ledger record disagrees with this worktree's.** An
   unpushed ruling in the live checkout is invisible here, and stamping it writes a stale-open
   record over a real close. Never reconcile the disagreement here.

   ```bash
   rec() { python3 -c 'import json,sys
   for l in open(sys.argv[1]):
       r=json.loads(l)
       if r.get("id")==sys.argv[2]: print(r.get("status"), r.get("closed_at")); break' "$1" "$2"; }
   [ "$(rec "$BCA/.beads/issues.jsonl" "$id")" = "$(rec .beads/issues.jsonl "$id")" ] \
     || { echo "skip $id — live checkout disagrees"; continue; }
   ```

   List the skipped ids in step 7's notification.
3. Stamp a comment `verified: <YYYY-MM-DD>` on the bead so the docket is not a stale snapshot.
4. Do **not** remove `human-gate`, close, or rewrite the gate body. De-gating is a
   human/session act, not nightly housekeeping.

### 3. Dedup, then reconcile the sanctioned subset

- **Dedup first (idempotency key):** skip any cluster already covered by an **open
  `pipeline-proposal` bead** (its populated `bead:` slot is the marker). A same-day re-fire
  re-derives, sees its own open beads, and no-ops.
- **Tier 1** (always): the non-destructive reconciliations:
  - archive completed backlog items and beadified/completed plans (`_backlog/_done/`,
    `_plans/_done/`),
  - update backlog status for planned items (`captured → planned`),
  - fix/infer missing plan frontmatter,
  - **readiness-label repair:** strip a stale `unrefined` label from any CLOSED bead —
    including one labelled `human-gate`/`qa-blocker` (a closed bead is past refinement by
    definition; `br label remove <id> unrefined`, verify via the issues.jsonl) — and stamp
    fail-safe `unrefined` onto any OPEN bead with a lifecycle-label gap (never `refined`,
    that stamp is only earned), per the lint in `beads-standards` § Lifecycle labels,
  - reconcile stale epic-close proposals whose target epic is already closed (close the
    proposal bead `obsolete: moot — target <id> already closed`).
- **Tier 2 — auto-apply provably-done archive:** ONLY when the Tier-2 toggle is ON *and* the
  positive-proof gate passes. Otherwise the item falls through to a Tier-3 proposal.
- **Never touch OPEN `human-gate` or `qa-blocker` beads** — gated, not housekeeping. Exception:
  an OPEN `human-gate,pipeline-proposal` bead whose target epic is already closed IS in scope
  (the gate is spent). `qa-blocker` beads are never in scope.
- **Provable, never heuristic** — keyword/similarity-inferred "looks done" is a Tier-3
  proposal, never an auto-move.

### 4. Emit Tier-3 proposals as FILES only — BEAD FILING DISABLED

For each remaining cluster (orphans, consolidation, dedup, finding-bead prune, or a Tier-2
item that failed the gate / toggle-off): write the full self-contained memo as a proposal FILE
with an empty `bead:` slot. Do **NOT** `br create** — under the no-self-beads doctrine,
pipeline proposals never become beads; the human tuning session reads the proposal queue and
disposes of them there.

**Proposal file:** `_plans/_proposals/<YYYY-MM-DD>/NN-<slug>.md` (create the dated dir).
Frontmatter: `status: pending` · `bead: <id>` · `source: ac-align` · `summary: <one line>`.
Body: `## What` (the concrete list) + `## Why`. Write a per-run `INDEX.md` ONLY when the run
emits several proposals.

### 5. Commit + push (pathspec-scoped, from the isolated worktree)

No branch re-check is needed — the worktree is a detached checkout that no concurrent session
can switch out from under this run. Commit the exact files touched and push the detached HEAD
onto `main`:

Git discipline: `ac-pipeline/references/commit-discipline.md` — pathspec-only commits, no wildcard adds / stash, commit=push, deletion check.

Identity + reservations per `agent-mail/references/session-procedure.md` (mint · export · reserve · release).

```bash
# cwd is still $RECON_WT
AGENT_NAME=FoggyCreek git commit -m "chore(reconcile): nightly reconcile + proposals" -- <exact files touched>
git push --no-verify origin HEAD:main
```

`AGENT_NAME` inline — a fresh scheduler shell doesn't inherit the export and the pre-commit
guard blocks its own commits without it. NEVER `git add -A`. `--no-verify` — the husky
pre-push build can hang/mask its exit in a backgrounded shell. `HEAD:main` pushes the detached
commit onto the shared branch.

### 6. Verify the push landed — durably (a receipt sha must outlive the worktree)

Verify from the LIVE checkout (`$BCA`), never from `$RECON_WT`:

```bash
BCA_SHA=$(git rev-parse HEAD)   # cwd is still $RECON_WT; capture before teardown
git -C "$BCA" cat-file -e "$BCA_SHA^{commit}" \
  && [ "$(git -C "$BCA" rev-parse origin/main)" = "$BCA_SHA" ]
```

On non-ff/rejection (a concurrent-pusher race) → Slack `degraded` with the stranded SHA and
do **not** auto-archive on a rejected push. Never leave work silently stranded.

### 7. Notify — MANDATORY, do this last

```bash
"$HOME/Repos/infrastructure/tools/bin/slack-send" --channel sofi --card \
  --status <healthy|degraded> --title "Pipeline Reconcile — $(date +%Y-%m-%d)" \
  --body "<one-line summary: N reconciled, M proposals, K archived>"
```

Confirm exit 0; a Slack failure IS a finding — retry once. Finalize `last-run.json` at its
REAL path — `"$BCA/.claude/skills/ac-align/workflows/last-run.json"` (the live-checkout
symlink, which resolves; never the worktree's broken one) — with
`{status: done, counts, mode, machine}`.

**The receipt is a committed artifact, not a local write — and its `pushed_sha` must resolve
in the repo the probe audits it from (agent-compounds).** Record BOTH, each against its own
repo:

```bash
AC_REPO="${AC_REPO:-$(dirname "$BCA")/agent-compounds}"   # the registry checkout the receipt lands in
# commit + push the receipt itself to agent-compounds main (isolated worktree off fresh
# origin/main when the live checkout is dirty — same carve-out as step 0)
RECEIPT_BASE=$(git -C "$AC_REPO" rev-parse origin/main)   # state the receipt lands on
# ... commit + push the receipt ...
git -C "$AC_REPO" cat-file -e "$RECEIPT_BASE^{commit}" \
  && git -C "$AC_REPO" merge-base --is-ancestor "$RECEIPT_BASE" origin/main
```

- `pushed_sha` = `$RECEIPT_BASE` — the agent-compounds commit the receipt's own push landed
  on, written ONLY after the `cat-file -e` + `merge-base --is-ancestor` check above passed.
  This is the field a later audit re-verifies with
  `git cat-file -e "$(jq -r .pushed_sha skills/ac-align/workflows/last-run.json)"`.
- `bca_pushed_sha` = `$BCA_SHA` from step 6 — the board-reconcile push, verified per step 6.
- Either verification fails → `push_verified: false`, the failing sha in `stranded_sha`, Slack
  `degraded`. A receipt that cannot verify its own shas is a degraded report, not a healthy one.

### 8. Teardown — MANDATORY on every exit path (success OR abort)

Remove the isolated worktree so none accumulate:

```bash
cd "$BCA"                                   # leave $RECON_WT before removing it
git -C "$BCA" worktree remove --force "$RECON_WT" 2>/dev/null \
  || rm -rf "$RECON_WT"                     # fallback if `worktree remove` refuses
git -C "$BCA" worktree prune                # drop any stale administrative refs
```

Every abort branch above must run this teardown before exiting — a crashed run that skips it
leaves an orphaned `/tmp` worktree that `git worktree list` will show until pruned.

---

## Applying proposals later

This run only *proposes*. A human applies approved proposals in `ac-human-session`, which
re-invokes `ac-align` (or the reconcile flow above) in its normal INTERACTIVE flow — there is
no separate apply mode here.