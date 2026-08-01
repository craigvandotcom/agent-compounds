# Dream Queue Management - Daily Run

## THIS PROMPT IS YOUR TASK - EXECUTE IMMEDIATELY

You are invoked at 02:00 daily (root-level scheduled procedure — memory-wiki-upgrade
Phase 2c retired the persistent per-level agent pattern; identity now loads from
`skills/CORE/`, this is pure procedure) for dream cycle queue management. Execute this
workflow now.

## Your Task

Manage the dream cycle review queue **and apply what is safe to apply unattended.**
Weekly synthesis remains Sunday 05:00 (that EMITS proposals, never applies). This daily run
is the **apply engine**: it auto-applies the deterministic safe tier, applies Craig's
already-approved backlog, posts only what genuinely needs his decision, and reports.

Policy (read it — it is the contract): the **auto-act rubric**
(`.claude/skills/dream/references/auto-act-rubric.md`). The split is enforced
deterministically by `infrastructure/dream-cycle/classify.py` — you do NOT re-judge it.

### 1. Sync + check the queue
```bash
git -C ~/Repos pull --ff-only 2>&1 | tail -1   # another machine may have emitted overnight
ls -la infrastructure/dream-cycle/proposals/*/
cat infrastructure/dream-cycle/last-run.json
```

### 2. Classify every pending proposal (deterministic — no judgment)
```bash
for d in infrastructure/dream-cycle/proposals/*/; do
  python3 infrastructure/dream-cycle/classify.py --dir "$d"
done
```
Each line is `<tier>\t<path>\t<reason>`. `auto` = safe to apply now; `gated` = needs Craig.

### 3. Apply the AUTO tier (unattended — Stage-1 autonomy)
The `auto` tier has two shapes — the classifier's reason names which (`Tier-1` or `Tier-0`):

**Tier-1 — new memory note (the agent applies the prose):**
- Write the new note to its `target_file` (the paste-ready content in the proposal's `## What`),
  and add its one index line to `infrastructure/memory/auto/MEMORY.md`.
- Set the proposal's frontmatter `status: applied`.
- If the `target_file` somehow already exists (race with another machine), SKIP it, set
  `status: pending`, and let it fall to the gated path — never overwrite.

**Tier-0 — mechanically re-derivable lint-fix (the SCRIPT applies; do NOT hand-edit):**
- `python3 infrastructure/dream-cycle/classify.py --apply-tier0 <proposal.md>` — the script
  re-derives the fix from the filesystem, re-verifies it matches the proposal, writes the
  target, and flips `status: applied` itself. Exit 2 = it refused (drift already gone /
  mismatch) → leave it untouched (the classifier routes it to `gated` anyway).

Both are **root-repo, revertible changes by construction** (the classifier guarantees it) —
Git discipline: `ac-pipeline/references/commit-discipline.md` — pathspec-only commits, no wildcard adds / stash, commit=push, deletion check. <!-- net-growth-ok: ac-gcj.7 Pass C canon binding -->

commit them to root: `git add infrastructure/ && git commit -m "dream: auto-apply <N> (Tier-0/1 rubric)" && git push`.

### 4. Apply the APPROVED backlog (legacy — pre-bead Slack approvals)
Any proposal at `status: approved` (Craig tapped Approve on a prior Slack card, before the
bead-docket cutover) is applied now, same as REVIEW mode — **respecting repo boundaries**
(apply + commit INSIDE the target repo; never commit across repo boundaries). After applying,
set `status: applied`. If a target drifted semantically, leave it `approved` and note it for
the human instead of guessing. (New gated proposals no longer take this path — they are filed
as decision beads in Step 7 and worked via `ac-human-session`, the decision docket.)

### 5. Queue health
For each still-`pending` proposal: flag if waiting >7 days, check for duplicates/superseded
items, verify valid frontmatter. Confirm inputs from earlier runs landed (context-mining
01:30, knowledge triage 01:00, infra health 00:30).

### 6. Generate Report
Save to `infrastructure/health/reports/dream-queue-<date>.json`:
auto-applied (count + slugs), approved→applied (legacy count), filed-as-beads (count + repo:bead-id),
open-dream-beads (count), stale warnings, Sunday input readiness.

### 7. File the GATED proposals as decision beads (the decision surface)
```bash
python3 infrastructure/dream-cycle/file-beads.py
git -C ~/Repos push 2>&1 | tail -2   # MANDATORY — the script commits but does NOT push
```
`file-beads.py` re-runs the classifier and files **only `gated` + `pending` + unfiled**
proposals as `-t decision` + `human-gate,dream-proposal` beads in each proposal's **target
repo** — the full memo inline for private repos, pointer-only for agent-compounds (its
`issues.jsonl` is public). It writes the bead id back into the proposal's `bead:` frontmatter
(the dedup marker — a second run never double-files) and commits each touched repo's `.beads/`
plus the root frontmatter changes (boundaries respected; it does NOT push — hence the explicit
push above for root). Auto-tier items are never filed. **Gated decisions are now worked via
`ac-human-session` (the decision docket), not a Slack tap** — Slack is only the Step-8 nudge.
(If zero fileable, it says so and exits — the Step 8 digest still fires.)

### 8. Notify Slack — MANDATORY, DO THIS LAST, DO NOT SKIP
Actually run the CLI (don't describe it). One digest **nudge** card (Slack is no longer the
decision surface — it just points at the docket). `--status`: `healthy` if open dream beads
<20 and none stale >7d, else `degraded`. Get the open-bead count from the cross-repo sweep
(REVIEW mode step 1: `br list --json` per beads repo, filter label `dream-proposal`, status
open); if that's not cheap this run, report the filed-this-run count and say "see docket".
```bash
infrastructure/tools/bin/slack-send --channel pi --card \
  --status <healthy|degraded> \
  --title "Dream Queue — $(date +%Y-%m-%d)" \
  --field "Auto-applied=<N>" --field "Filed as beads=<N this run>" \
  --field "Open dream beads=<M / see docket>" --field "Stale >7d=<N / none>" \
  --body "<one line: what was auto-remembered + N beads filed for your decision docket, or 'all clear'>" \
  --context "02:00 dream queue · decide via ac-human-session (\`br ready --label dream-proposal\`) · auto-applied notes are git-revertible"
```
Confirm exit 0; retry once on error. The job is NOT complete until this posts.

## Success Criteria
- Auto-tier applied + committed + pushed (root) — or none eligible
- Legacy approved backlog applied in-repo (boundaries respected) — or none waiting
- Gated proposals filed as decision beads + bead ids recorded + root pushed — or none fileable
- Open dream beads <20, none >7 days old
- Report saved successfully
- **Digest nudge card posted to #pi (confirmed exit 0)**, stating auto-applied / filed-as-beads / open-dream-beads counts
