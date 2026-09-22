---
name: ac-tidy
description: 'Pipeline housekeeping — reconcile backlog, plans and beads against live state: archive what is done, repair statuses and readiness labels, remove invalid labels, close moot proposals, and file a bead for anything that needs a human. Interactive on request; the nightly heartbeat runs it headless. Triggers: ''tidy the pipeline'', ''clean up the backlog'', ''reconcile plans and beads'', ''archive what is done'', ''fix bead labels''. NOT for strategy fit or pool → active promotion (ac-align), reading the board (ac-board), the human docket (ac-human), or code cleanup (ac-hygiene).'
---

**You are the pipeline janitor.** Reconcile backlog, plans and beads against live state.
Apply what is provable. File a bead for what is not. Never guess.

## Modes

| Mode | When | Step 1 | Step 3 | Step 4 |
|---|---|---|---|---|
| **INTERACTIVE** (default) | a human asked | skip — work in the live checkout | show each change, `AskUserQuestion`, apply on approval | show findings, file on approval |
| **NIGHTLY** (headless) | your scheduler, in the app checkout, cadence in `ac-pipeline/references/schedule.md` | isolate | apply without asking | file as beads, no `AskUserQuestion` |

## 1. Isolate (NIGHTLY)

Do NOT reconcile in the live checkout. `APP_ROOT=$(git rev-parse --show-toplevel)` is the live
app checkout. Fetch `origin/main`, `git worktree add --detach "$WT" origin/main`, `cd "$WT"`, then
`export BEADS_DB="$WT/.beads/beads.db"` and `br sync` to rebuild the beads DB from `issues.jsonl`
(`br` auto-discovery ignores worktree cwd, bd-6kwqo — the exported var directs every `br` call).
Skill files resolve only through $APP_ROOT/.claude/… (relative symlinks); if the worktree cannot be created, Slack degraded, exit, nothing written.

## 2. Scan

Read the board per `ac-pipeline/references/board-scan.md` (closed beads: Scan A's
`br_call list --all --status closed --json`, never a raw `br list`). Print the docket-health line,
then `post-merge-tail: <n>` — open beads still labelled `post-merge` (`beads-standards/reference/bead-conventions.md`
§ Claim semantics; a failed read is an error, never a `0`); reclaiming one is judgment: step 4.
Then run `scripts/tidy-scan.sh` — read-only; its rows are the baseline for steps 3–4: decide each yourself, record skips and additions in step 5.

### 2b. Surviving-gate verify

For each open `human-gate` bead: `br show` and confirm it is still blocked on a human. If
`$APP_ROOT/.beads/issues.jsonl` and the worktree's copy disagree on its status, skip it (the live
checkout disagrees; a newer `updated_at` is not newer semantics). Stamp the others `verified: <date>`; never de-gate, close, or edit a body.

## 3. Reconcile — provable, apply

| Condition | Action |
|---|---|
| backlog item: every task checked, or `status: complete` | move to `_backlog/_done/` |
| backlog `captured` but a plan names it | `status: planned`, add `plans:` |
| plan `beadified:` and its epic closed | move to `_plans/_done/`, stamp `delivered:` |
| plan with no frontmatter | infer status from content, add it, report the inference |
| closed bead still labelled `unrefined` | `br label remove` |
| open non-epic bead with none of `unrefined` / `refined` / `human-gate` | `br label add unrefined` (never `refined`) |
| label `beads-standards` does not name | correct or remove, report it |
| open `pipeline-proposal` bead whose target epic is closed | record `DECISION (ac-tidy): moot — target <epic> closed`, then `close-gate.sh <id> --reason "obsolete: moot — target closed"` |

Open `human-gate` and `qa-blocker` beads are untouchable except by the last row. A condition needing a judgment call ("looks done", "probably a duplicate") is not provable: step 4. A `task`-typed proposal skips the ruling path (routed by `issue_type`) and LEG-2 NOT-CHECKs; report that exit as the skip, not a failure.

## 4. Findings — judgment, never apply

One bead per finding: `br create "<title>" -t decision --labels "origin:ac-tidy,human-gate,pipeline-proposal"`,
body with a `Gate-reason:` line per `beads-standards/reference/bead-create-contract.md`. Skip a
target an open bead already names. Findings: an epic with zero open children and no `Probe:`
line · a `blocks` edge touching an epic (I2, `board-scan.md`) · a `_done/` plan whose
`beadified:` and `delivered:` disagree with its epic's state · an item that looks done but
fails its row above · duplicate or mergeable items · a `post-merge` tail bead (§ 2) — strip the label or re-queue it by ruling here, never by applying step 3.

## 5. Land

Commit the exact paths touched, per `ac-pipeline/references/commit-discipline.md`: `AGENT_NAME=FoggyCreek git commit -m "chore(tidy): <what>" -- <paths>`, then push (NIGHTLY: `git push --no-verify origin HEAD:main`, then verify from the live checkout that `git -C "$APP_ROOT" rev-parse origin/main` equals HEAD — rejected means degraded, do not retry).
Slack card via `slack-send --card --status <healthy|degraded>` on the app's ops channel, one line of counts (`drift-skipped:` — § 2b gates skipped on ledger-copy disagreement — plus `post-merge-tail:` (§ 2) and the since-last-run app-board counts `foreign status:` / `off-canon receipts:` / `unrecorded closes:` against D4/D1's canon grammar).
Before committing, append one line to `.claude/state/tidy-runs.jsonl` at the repo root you commit from (history — never rewrite a line): `{date, mode, machine, counts, scan, applied, match}` — `scan` the tidy-scan mechanical rows, `applied` the step-3 actions taken, `match` whether they are equal. It rides the commit unless the project ignores `.claude/state/`.
Remove the worktree and prune. Teardown runs on every exit path, abort included.

---

_Housekeeping only. Strategy fit and promotion: `/ac-align`. Capture: `/ac-backlog`. Docket: `/ac-human`._
