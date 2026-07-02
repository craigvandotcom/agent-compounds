# ac-align — Weekly Pipeline Alignment (headless heartbeat)

## THIS PROMPT IS YOUR TASK — EXECUTE IMMEDIATELY

You are invoked by `pai-scheduler` (Saturday ~06:00) to run the **REVIEW** mode of the
`ac-align` skill against the Body Compass pipeline. Execute without user interaction.

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

- Verify Slack `sofi` resolves (fallback `pi`) before anything else.
- **No Agent-Mail reservation** (a raw scheduler `prompt_file` run isn't a self-registering
  entry point → would no-op; `agent-mail-project-keying-gotcha`).

### 1. Sync + abort-on-contention

```bash
git -C ~/Repos pull --ff-only     # VM rebase/merge/reset deny-listed
```

If the pull can't fast-forward OR `git status --porcelain _backlog/ _plans/` shows another
actor's dirt → **ABORT** (Slack `degraded`, zero writes), retry next cycle.

### 2–4. Run ac-align REVIEW (Phases 1–4 + emit)

Run the skill's Phases 1–4. At **Phase 4.5**, do NOT `AskUserQuestion` and do NOT `git mv`.
Instead **emit** the scored `pool → active` promotion slate:

- **Dedup first:** skip if an open `pipeline-proposal` bead already covers this slate (the
  populated `bead:` slot is the idempotency marker).
- **Atomic emit:** `br create "<title>" -t decision --labels "human-gate,pipeline-proposal"
  -p <prio> --description "<full memo>"`, capture the id, write it into the proposal's `bead:`
  slot. Write the file only AFTER `br create` succeeds.
- **Proposal file:** `_plans/_proposals/<YYYY-MM-DD>/NN-<slug>.md`; frontmatter
  `status: pending` · `bead: <id>` · `source: ac-align` · `summary`; `## What` = the scored
  slate; `## Why` = rationale **plus** the orphan/gap/sequencing findings from Phases 3–4.

Skip Phase 6 entirely. Apply nothing — active/ and pool/ counts are unchanged by this run.

### 5. Commit + push (pathspec-scoped, BCA repo only)

```bash
AGENT_NAME=FoggyCreek git commit -m "chore(align): weekly pool→active proposal" -- <exact files touched>
git push --no-verify
```

`AGENT_NAME` inline (`precommit-guard-needs-agent-name-in-shell`); never `git add -A`;
`--no-verify` (backgrounded pre-push build). All commits stay inside the BCA repo.

### 6. Verify the push landed

`git rev-parse origin/main` must equal local `HEAD`; on non-ff/rejection → Slack `degraded`
with the stranded SHA. (No auto-apply to strand, but still confirm the proposal committed.)

### 7. Notify — MANDATORY, do this last

```bash
"$HOME/Repos/infrastructure/tools/bin/slack-send" --channel sofi --card \
  --status <healthy|degraded> --title "Pipeline Alignment — $(date +%Y-%m-%d)" \
  --body "<one-line: N pooled items proposed for promotion, M sequencing findings>"
```

Confirm exit 0; a Slack failure IS a finding — retry once. Finalize `last-run.json`
(`{status: done, counts, mode, machine}`).

---

## Applying the slate later

This run only *proposes*. A human reviews the slate in `ac-human-session` and, on approval,
re-invokes `ac-align` INTERACTIVE — which re-scores `pool → active` against **live** strategy
at apply time (a stale slate self-skips because the board is read fresh). REVIEW never moves a file.
