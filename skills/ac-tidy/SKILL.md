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
| **NIGHTLY** (headless) | pai-scheduler in the app checkout, cadence in `ac-pipeline/references/schedule.md` | isolate | apply without asking | file as beads, no `AskUserQuestion` |

## 1. Isolate (NIGHTLY)

Do NOT reconcile in the live checkout. `BCA=$(git rev-parse --show-toplevel)` is the live app
checkout. Fetch `origin/main`, `git worktree add --detach "$WT" origin/main`, `cd "$WT"`, then
`br sync` to rebuild the beads DB from `issues.jsonl`. Skill files resolve only through
`$BCA/.claude/…` (relative symlinks). If the worktree cannot be created: Slack degraded, exit,
nothing written.

## 2. Scan

Read the board per `ac-pipeline/references/board-scan.md`. Closed beads come from
`.beads/issues.jsonl`, never `br list`. Print the docket-health line.

### 2b. Surviving-gate verify

For each open `human-gate` bead: `br show`, confirm it is still blocked on a human. If
`$BCA/.beads/issues.jsonl` and the worktree's copy disagree on its status, skip it: the
live checkout disagrees, and a newer `updated_at` is not newer semantics. On every other bead
Stamp a comment `verified: <date>`. Never de-gate, close, or edit the body.

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
| open `pipeline-proposal` bead whose target epic is closed | close: `obsolete: moot — target closed` |

Open `human-gate` and `qa-blocker` beads are untouchable except by the last row. A condition
that needs a judgment call ("looks done", "probably a duplicate") is not provable: step 4.

## 4. Findings — judgment, never apply

One bead per finding: `br create "<title>" -t decision --labels "origin:ac-tidy,human-gate,pipeline-proposal"`,
body with a `Gate-reason:` line per `beads-standards/reference/bead-create-contract.md`. Skip a
target an open bead already names. Findings: an epic with zero open children and no `Probe:`
line · a `blocks` edge touching an epic (I2, `board-scan.md`) · a `_done/` plan whose
`beadified:` and `delivered:` disagree with its epic's state · an item that looks done but
fails its row above · duplicate or mergeable items.

## 5. Land

Commit the exact paths touched, per `ac-pipeline/references/commit-discipline.md`:
`AGENT_NAME=FoggyCreek git commit -m "chore(tidy): <what>" -- <paths>`, then push
(NIGHTLY: `git push --no-verify origin HEAD:main`). NIGHTLY also: verify from the live checkout
that `git -C "$BCA" rev-parse origin/main` equals HEAD — rejected means degraded, do not retry;
Slack card via `slack-send --card --status <healthy|degraded>` on the app's ops channel, one line
of counts; write `$BCA/.claude/skills/ac-tidy/workflows/last-run.json` with date, counts,
pushed_sha, status; remove the worktree and prune. Teardown runs on every exit path, abort included.

---

_Housekeeping only. Strategy fit and promotion: `/ac-align`. Capture: `/ac-backlog`. Docket: `/ac-human`._
