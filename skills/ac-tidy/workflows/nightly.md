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

- Verify Slack resolves: `"$HOME/Repos/infrastructure/tools/bin/slack-send" --channel sofi --dry-run` (or a
  cheap probe); if `sofi` doesn't resolve, fall back to `pi`. Do this **before** any mutation.
- Read the **Tier-2 toggle** from `.claude/skills/ac-tidy/SKILL.md`: grep the `## NIGHTLY
  Guardrails` block for `Tier-2 auto-archive:` → `ON`/`OFF`. Tier-2 auto-archive runs only if `ON`.
- **No Agent-Mail reservation** — a raw scheduler `prompt_file` run is not a self-registering
  Agent-Mail entry point, so a reservation would silently no-op (`agent-mail-project-keying-gotcha`).
  The clean-tree check (step 1) + push-verify (step 6) are the real single-writer guard.

### 1. Sync + abort-on-contention

```bash
git -C ~/Repos pull --ff-only     # VM rebase/merge/reset are deny-listed
```

If the pull **can't fast-forward**, OR `git status --porcelain _backlog/ _plans/` shows
pre-existing dirt from another actor → **ABORT the whole run**: Slack `degraded`, zero writes,
retry next cycle. Emitting proposals anyway would still commit+push and race the very writer
just detected. Never fix divergence unattended.

### 2. Scan the board

Read the board per `_shared/board-scan.md` (already excludes `_shipped/` + `audits/`).

### 3. Dedup, then auto-apply the sanctioned subset

- **Dedup first (idempotency key):** skip any cluster already covered by an **open
  `pipeline-proposal` bead** (its populated `bead:` slot is the marker). This makes a same-day
  re-fire (crash mid-run, misfire-grace, stale-lock takeover) re-derive, see its own open
  beads, and no-op. A lingering `last-run.json` `status: running` is advisory only — the bead
  dedup, not the lease, prevents double-emit.
- **Tier 1** (always): apply Phase 2d + 2e reconciliation.
- **Tier 2** (only if the toggle is ON): apply provably-done archives that pass the
  positive-proof gate (`N_matching > 0` AND `N_closed == N_matching` AND parseable non-empty
  `br` result — else fall through to a Tier-3 proposal). Never touch `human-gate`/`qa-blocker`.

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

### 5. Commit + push (pathspec-scoped, BCA repo only)

```bash
AGENT_NAME=FoggyCreek git commit -m "chore(tidy): nightly reconcile + proposals" -- <exact files touched>
git push --no-verify
```

`AGENT_NAME` inline — a fresh scheduler shell doesn't inherit the export and the pre-commit
guard blocks its own commits without it (`precommit-guard-needs-agent-name-in-shell`). NEVER
`git add -A` (it sweeps a concurrent session's work). `--no-verify` — the husky pre-push build
can hang/mask its exit in a backgrounded shell. All commits stay inside the BCA repo.

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

Confirm exit 0; a Slack failure IS a finding — retry once. Finalize `last-run.json`
(`{status: done, counts, mode, machine}`). A mutated board with no notification is the failure
mode to avoid.

---

## Applying proposals later

This run only *proposes*. A human applies approved proposals in `ac-human-session`, which
re-invokes `ac-tidy` (or `ac-align`) in its normal INTERACTIVE flow — there is no separate
apply mode here.
