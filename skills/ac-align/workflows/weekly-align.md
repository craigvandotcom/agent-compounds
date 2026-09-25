# ac-align — Weekly Pipeline Alignment (headless heartbeat)

## THIS PROMPT IS YOUR TASK — EXECUTE IMMEDIATELY

You are invoked by your scheduler (Saturday ~06:00) to run the **REVIEW** mode of the
`ac-align` skill against the app whose checkout is the scheduler cwd. Execute without user interaction.

**⚠️ AUTONOMOUS MODE — no human is watching.** Run every step by actually executing the
commands. This run **applies NOTHING** — it is pure propose. There is no `AskUserQuestion`;
the output is a proposal, not a prompt.

**Read `.claude/skills/ac-align/SKILL.md` first** — run its Phases 1–4 exactly (strategy
ingest → scan → alignment audit → sequencing), then follow REVIEW-mode behavior at Phase 4.5
(emit, don't move) and skip Phase 6. This heartbeat is the *run skeleton*; the skill is the
*behavior*.

---

## Run skeleton

### 0. Preflight

- **Resolve the repo trunk first, through the shared resolver:**
  ```bash
  TRUNK_TOOL="$PWD/.claude/skills/_tools/trunk.sh"
  [ -x "$TRUNK_TOOL" ] || TRUNK_TOOL="skills/_tools/trunk.sh"
  TRUNK="$(bash "$TRUNK_TOOL")" || exit 2
  ```

- **Branch guard (first, before anything else):** `git branch --show-current` must equal
  `$TRUNK`. If it doesn't — **ABORT the entire run**: Slack `degraded` with reason
  `branch-guard: <branch> checked out`, zero writes, retry next cycle. A wave branch left
  checked out on the scheduler's cwd must never receive a weekly-align commit.
- Verify the Slack channel `$ALIGN_SLACK_CHANNEL` (fallback `$DEFAULT_SLACK_CHANNEL`)
  resolves before anything else.
- **No Agent-Mail reservation** (a raw scheduler `prompt_file` run isn't a self-registering
  entry point → would no-op; `agent-mail-project-keying-gotcha`).

### 1. Sync + abort-on-contention

```bash
git pull --ff-only                # the app checkout; rebase/merge/reset deny-listed
```

If the pull can't fast-forward OR `git status --porcelain _backlog/ _plans/` shows another
actor's dirt → **ABORT** (Slack `degraded`, zero writes), retry next cycle.

### 2–4. Run ac-align REVIEW (Phases 1–4 + emit)

Run the skill's Phases 1–4. At **Phase 4.5**, do NOT `AskUserQuestion` and do NOT `git mv`.
Instead **emit** the scored `pool → active` promotion slate:

- **Dedup first:** skip if an open `pipeline-proposal` bead already covers this slate (the
  populated `bead:` slot is the idempotency marker).
Bead creation per `beads-standards/reference/bead-conventions.md` — types, unrefined-at-creation, anchor-dedupe, body template.

- **Atomic emit:** `br create "<title>" -t decision --labels "origin:ac-align,human-gate,pipeline-proposal"
  -p <prio> --description "<full memo>"`, capture the id, write it into the proposal's `bead:`
  slot. Write the file only AFTER `br create` succeeds.
- **Proposal file:** `_plans/_proposals/<YYYY-MM-DD>/NN-<slug>.md`; frontmatter
  `status: pending` · `bead: <id>` · `source: ac-align` · `summary`; `## What` = the scored
  slate; `## Why` = rationale **plus** the orphan/gap/sequencing findings from Phases 3–4.

Skip Phase 6 entirely. Apply nothing — active/ and pool/ counts are unchanged by this run.

### 5. Commit + push (pathspec-scoped, this app's repo only)

Re-verify the branch guard immediately before committing: `git branch --show-current` must
still equal `$TRUNK`. A concurrent session can switch the checked-out branch between preflight
(step 0) and this step (TOCTOU) — if it's no longer `$TRUNK`, **ABORT**: Slack `degraded` with
reason `branch-guard: <branch> checked out`, zero writes, retry next cycle.

Git discipline: `ac-pipeline/references/commit-discipline.md` — pathspec-only commits, no wildcard adds / stash, commit=push, deletion check.

Identity + reservations per `agent-mail/references/session-procedure.md` (mint · export · reserve · release).

```bash
AGENT_NAME=FoggyCreek git commit -m "chore(align): weekly pool→active proposal" -- <exact files touched>
git push --no-verify
```

`AGENT_NAME` inline (`precommit-guard-needs-agent-name-in-shell`); never `git add -A`;
`--no-verify` (backgrounded pre-push build). All commits stay inside this app's repo.

### 6. Verify the push landed

`git rev-parse "origin/$TRUNK"` must equal local `HEAD`; on non-ff/rejection → Slack `degraded`
with the stranded SHA. (No auto-apply to strand, but still confirm the proposal committed.)

### 7. Notify — MANDATORY, do this last

```bash
if command -v slack-send >/dev/null 2>&1; then
  slack-send --channel "$ALIGN_SLACK_CHANNEL" --card \
    --status <healthy|degraded> --title "Pipeline Alignment — $(date +%Y-%m-%d)" \
    --body "<one-line: N pooled items proposed for promotion, M sequencing findings>"
else
  echo "slack-send not found on PATH — skipping notification" >&2
fi
```

Confirm exit 0 when `slack-send` ran; a Slack failure IS a finding — retry once. A
missing `slack-send` degrades loudly (the message above), never silently. Finalize
`last-run.json` (`{status: done, counts, mode, machine}`).

The Slack body's one-line rollup also carries the board's docket counters, read from Scan A's
`docket-health:` line (never recomputed): `plan-gap: N · gate-incomplete: N`.

---

## Applying the slate later

This run only *proposes*. A human reviews the slate in `ac-human` and, on approval,
re-invokes `ac-align` INTERACTIVE — which re-scores `pool → active` against **live** strategy
at apply time (a stale slate self-skips because the board is read fresh). REVIEW never moves a file.
