---
name: ac-batch-close
description: 'Trunk-direct batch closing ceremony — a THIN committed-state checkpoint: batch-anchored CI dispatch + one light review pass + commit the batch report (review-mark advance + feedback pending-write). Version mint, tag, deploy-verification, and the heavy 6-dim review all moved to ac-publish (bd-pwt44 epic). Triggers: ''batch close'', ''close the batch'', ''ac-batch-close'', ''ship the batch''.'
---


**You are the conductor closing out a batch of trunk-direct commits on `main`.** Agents commit
directly to `main` — no wave branch, no PR. This is the periodic (or on-demand) closing
ceremony: gate the batch through a light review, dispatch Tier 1 CI for the batch, and commit a
thin batch-report checkpoint that advances the review-mark. **It is deliberately thin** — under
3-5 concurrent conductors the heavy freight (version bump, tag, deploy-verification, the full
6-dimension review) no longer belongs at every batch; that freight consolidates at the publish
boundary (`ac-publish`, bd-pwt44 epic "Publish-Anchored Quality — The Batch-Close Diet"). Fired
once per batch, not per commit.

This skill is a retarget of `ac-merge` (`skills/ac-merge/SKILL.md`) for the trunk-direct flow.
`ac-merge` is **unchanged** and remains the PR-merge path for legacy branches (dependabot,
human feature branches — `.claude/legacy-branches.txt`). Nothing from `ac-merge` is silently
dropped: the PR ceremony below is removed with cause; everything else is either retargeted to
the batch anchor or relocated to `ac-publish` (also with cause, see below).

## Removed from ac-merge (PR ceremony — `ac-merge` still owns this path)

There is no branch and no PR on trunk-direct, so these have nothing to attach to:

- `gh pr create`, PR body assembly (`ac-merge/references/pr-body-template.md`), `gh pr merge`,
  `--delete-branch`, local branch deletion, branch-rebase-onto-main.
- The interactive "Does this project have GitHub CI checks…" `AskUserQuestion` — Tier 1 CI
  dispatch (Act 1) is now a fixed mechanism, not a per-project optional wait; the only
  remaining conditional is a file-existence check (does `quality-gate.yml` exist at all).

## Removed from this skill's own earlier (7-phase) design — relocated to `ac-publish`

This skill previously carried a version bump, a git tag, and a deploy-verification act of its
own (pre-`bd-pwt44.3`). **All three are gone from batch-close entirely** — they are not
"skipped conditionally," they do not exist in this skill anymore:

- **Version bump + native-surface propagation** → relocated to `ac-publish` Phase 0
  ("mint-at-publish" — `ac-publish/SKILL.md`, `version-bump-defaults-to-patch`). Batch-close
  never touches `package.json`.
- **Git tag** → relocated to `ac-publish` (tags at the explicit release candidate `R`, once
  the publish-side heavy-review/promote work lands — bd-pwt44.6). Batch-close never tags.
- **Deploy verification (Vercel served-version + intermediate-commit scan, native
  archive-watch-head)** → not batch-close's job anymore; `ac-publish` is the definitive
  ship/verify gate for the boundary that actually matters (mint + prove + ship).
- **The full 6-dimension review panel** → stays `ac-review`'s own standalone mechanism
  (feature-branch / on-demand) and becomes `ac-publish`'s heavy pre-tag gate (bd-pwt44.6);
  batch-close keeps only the single light `VERDICT` pass described in Act 2 below.

If you're looking for any of the above, it now lives in `ac-publish/SKILL.md`.

Everything else below is the same mechanism, retargeted anchor and audience.

---

## I/O Contract

|                  |                                                                                            |
| ---------------- | ------------------------------------------------------------------------------------------ |
| **Input**        | `main`, with implementation commits already pushed directly since the last batch anchor (no branch, no PR) |
| **Output**       | Batch reviewed (light `VERDICT: APPROVED`), Tier 1 CI confirmed for the batch, batch report committed, review-mark advanced, in-scope `triage,feedback` beads marked `fixed_pending_release` |
| **Not in scope** | Version bump/tag, deploy verification, the 6-dim review panel (all `ac-publish`) |
| **Artifacts**    | Batch-close summary in `.claude/reviews/batch/`, scratch in `$ARTIFACTS_DIR`                |
| **Verification** | Light-review `VERDICT: APPROVED`; Tier 1 CI dispatch green for the batch                    |

## Prerequisites

- On `main` (trunk-direct — no branch-name check; if invoked on a branch, that's `ac-merge`'s job, not this skill's)
- `gh` CLI authenticated
- Agent Mail MCP tools available (`acquire_build_slot`/`renew_build_slot`/`release_build_slot`) —
  see Build Slot below
- Implementation commits already landed directly on `main` (from `ac-implement`, trunk-direct — no wave branch to check out)
- A `quality-gate.yml` workflow with `workflow_dispatch` inputs `reason` + `batch_anchor`
  (added by the sibling bead bd-u2lo1.10). If the workflow doesn't exist yet, Tier 1 CI
  dispatch (Act 1) is skipped silently — same escape hatch `ac-merge`'s CI-config question
  offered, now inferred from file presence instead of asked.

---

## Session Identity (Tier 1 — mint FIRST, before the build slot)

ac-batch-close is a **Tier-1 session**: on a red Tier-1 CI dispatch it **fix-forwards** —
edits code, commits, pushes to `main` (Act 1 triage). Mint a unique identity at ceremony
start (doctrine: `_shared/agent-identity.md` — Tier 1 lifecycle). Minting is also the
**prerequisite for the build slot**: `acquire_build_slot` needs a real `registration_token`
for a pre-existing identity, and the mint is what yields one — a loop-spawned session that
skips this step holds no token (this closes bd-kskxg's token-less graceful-degrade path):

```
mcp__mcp-agent-mail__macro_start_session(
  human_key: CANONICAL_PROJECT_KEY,   // this tool takes human_key — canonical Agent Mail key (pattern: "neometa/<app-dir>") — NEVER an absolute path (split-brain)
  program: "claude-code",
  model: "claude-opus-4-8"
)
```

Capture the returned `name` and `registration_token` (the build slot below and every fix-forward
commit consume them):

```bash
export GIT_IDENTITY_ENABLED=1
export AGENT_NAME=<returned-name>   # re-assert inline at each git commit (exports don't survive across bash calls)
```

---

## Build Slot (advisory coordination across concurrent conductors)

This ceremony can be invoked more than once concurrently under 3-5 concurrent conductors
(`trunk-direct-execution-doctrine`). Wrap the run in an **advisory** Agent Mail build_slot —
`acquire_build_slot` **always grants** and returns a `conflicts` list; it never blocks or
refuses (memory `agent-mail-build-slot-advisory`). Correctness is entirely on the caller:

```
acquire_build_slot(key="batch-close:main", registration_token=<the token from macro_start_session above>, ttl=<covers the expected CI-poll wall-clock>)
  → read the returned `conflicts` list
  → if another agent's active lease is present, this is advisory, not a lock: proceed only if
    your batch anchor genuinely does not overlap theirs (different ANCHOR..HEAD ranges are
    fine); if ranges overlap, back off and retry after a short bounded wait — report the
    conflict, never proceed blind
  → renew_build_slot before TTL expiry if the ceremony runs long (the CI poll below can eat
    most of a lease); renew CANNOT resurrect a lapsed lease — check its return and hard-stop if
    the lease is already gone
  → release_build_slot() at the very end, after Act 3's report commit lands — release even on
    abort, so a stalled conductor doesn't leave a stale advisory lease for the next run
```

> **Token custody + concurrency assertion (bd-kskxg field-test, resolved).** The Session
> Identity mint above gives this ceremony a real `registration_token`, so `acquire_build_slot`
> succeeds — there is no longer a token-less path to degrade around. What remains, unconditionally,
> is the concurrency assertion the slot only ever *hinted* at: assert `git rev-parse origin/main`
> equals your local `HEAD` immediately before and after each CI-affecting step (dispatch, any
> fix-forward push, the Act 3 report commit). A mismatch is the real signal a concurrent conductor
> moved `main` under you — the slot is advisory (memory `agent-mail-build-slot-advisory`), so this
> assertion, not the lease, is what actually protects the range.

No mutual exclusion is enforced by the primitive itself — this is a presence signal for a
conflicting concurrent run to notice, not a queue or a lock.

---

## Run Ledger

Same rationale as `ac-merge`: this ceremony spans a CI poll where a session can drop. One task
per section, so a resumed run re-enters at the exact section instead of re-polling from
scratch:

```
TaskCreate (one per section, in run order):
  1.  Acquire build slot; determine batch anchor + scope + quality gate   in_progress
  2.  QA smoke gate (conditional)                                         pending
  3.  Gitleaks scan + Tier 1 CI dispatch + fix-forward (Act 1)            pending
  4.  Light review gate — VERDICT required (Act 2)                       pending
  5.  Feedback pending-write + commit batch report (Act 3)               pending
  6.  Report + Slack + release build slot + finalize                     pending
```

`TaskUpdate` each to `in_progress`/`completed` as you go. Persist `ANCHOR`, `DISPATCH_RUN_ID` to
`$STATE` as you capture them (`echo "ANCHOR=$ANCHOR" >> "$STATE"`) so a dropped session reloads
instead of re-deriving.

### Determine the Batch Anchor

No rebase step — trunk-direct commits already landed on `main` directly, there's nothing to
rebase onto. The only sync risk is a **concurrent pusher race** (another agent pushed to
`main` since your last fetch): pull-rebase, never force.

```bash
git fetch origin main
git pull --rebase origin main   # never --force; re-verify HEAD after
```

The **batch anchor** — same mechanism `ac-review` uses to find its scope (`ac-review/SKILL.md`
Phase 1 "Scope Detection"), computed identically here so both skills agree on the range:

```bash
ANCHOR=$(git log -1 --format=%H -- .claude/reviews/batch/)
if [ -z "$ANCHOR" ]; then
  # Bootstrap fallback: no batch review-mark exists yet. The `batch_anchor`
  # workflow input is a COMMIT SHA (quality-gate.yml peels it via `^{commit}`
  # and diffs `<anchor>...HEAD`), so resolve the newest v* tag to the SHA it
  # POINTS TO — never pass the bare tag NAME. Passing a tag name works only
  # while checkout fetches tags (fetch-depth:0); if that ever narrows, an
  # unresolvable tag name silently degrades to the full-scope root-commit
  # fallback. A resolved SHA keeps the contract honest.
  ANCHOR=$(git rev-list -n1 "$(git describe --tags --match 'v*' --abbrev=0)")
fi
BATCH_RANGE="$ANCHOR..HEAD"
echo "ANCHOR=$ANCHOR" >> "$STATE"
```

Deterministic `$ARTIFACTS_DIR` per `_shared/run-id.md` (prefix `batch-close`) — trunk-direct
has no wave branch to key on, so the key is the anchor SHA instead of a branch slug:

```bash
# Mint RUN_ID if the orchestrator didn't hand one down (contract: _shared/run-id.md
# mint-if-absent rule). Not folded into ARTIFACTS_DIR below: this dir is keyed on the
# anchor SHA (stable across a resumed/dropped session), and RUN_ID is re-minted per
# invocation — appending it would break resume detection (`[ -f "$STATE" ]` below relies
# on recomputing the SAME path on retry).
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"
ARTIFACTS_DIR="/tmp/batch-close-${ANCHOR:0:8}"
mkdir -p "$ARTIFACTS_DIR"
STATE="$ARTIFACTS_DIR/state.env"
[ -f "$STATE" ] && . "$STATE"   # on resume, reload instead of re-deriving
```

### Gather Batch Context (retarget of "Gather PR Context" — no PR body, just scope)

```bash
br list --json > "$ARTIFACTS_DIR/beads.json"           # the claim set this batch is closing
git log $BATCH_RANGE --oneline > "$ARTIFACTS_DIR/commits.txt"
git diff $BATCH_RANGE --stat > "$ARTIFACTS_DIR/diff-stats.txt"
```

No PR body is constructed. This context feeds the Act 3 batch-close report only.

Mark ledger task 1 `completed`; `TaskUpdate` task 2 `in_progress`.

---

## Act 1 — Batch-Anchored CI Dispatch

Covers the pre-flight quality gate, the QA smoke safety net, a gitleaks backstop, and the
batch's single Tier 1 CI dispatch.

### Quality Gate (post-sync)

Same order `ac-merge` mirrors from `_shared/verification-gate.md` §Format-first — format FIRST
(auto-fix), then type-check, lint, tests:

```bash
# format (auto-fix) -> type-check -> lint -> tests
# Tests = the AGGREGATED affected run, pinned to the BATCH ANCHOR (the trunk-direct
# equivalent of ac-merge's origin/main merge-base pin — here we're already on main, so
# the anchor is the older boundary that matters):
VITEST_AFFECTED_REF=$ANCHOR pnpm test
```

> **Runner self-contention (bd-kskxg field-test).** On a single self-hosted Mac runner, this
> local affected pre-flight and the Tier 1 CI dispatch fired below run on the SAME machine —
> executing the local suite while CI is already dispatched makes both contend for one runner and
> stretches wall-clock. Sequence them: finish (or skip) this local pre-flight BEFORE firing the
> dispatch; never overlap them.

**If any fail:** fix before proceeding — same rule as `ac-merge`: never dispatch Tier 1 CI with
failing local checks.

### QA Smoke Gate (conditional — safety net)

This is the **post-push re-proof** (J5 — the trunk-direct successor of ac-merge's
"post-rebase re-proof": same gate logic, re-prove after the diff changes; only the
trigger-event name changed, since there is no rebase without a branch to rebase onto).
Identical structure and conditions to `ac-merge`'s QA Smoke Gate (hybrid/native apps only,
native-touching diff, Mac-only for the device twin), retargeted to the batch range:

```bash
[ -d ios ] || SKIP_SIM_SMOKE=1
git diff $ANCHOR...HEAD --name-only | grep -qE '^ios/|capacitor\.config|cap-build|@capacitor' \
  || git diff $ANCHOR...HEAD -- package.json | grep -qE '@capacitor|capacitor' \
  || SKIP_SIM_SMOKE=1
[ "$(uname)" = "Darwin" ] || SKIP_SIM_SMOKE=mac-needed
```

Same escalation rules on FAIL (STOP before proceeding, report `QA_VALIDATION`, ask abort vs
proceed), same `mac-needed` non-blocking note, same web-shell twin (`ac-qa-browser` smoke on
`git diff $ANCHOR...HEAD` web-UI changes).

**QA-blocker check (unchanged):**

```bash
br list --json --limit 1000 | jq '[.issues[] | select(.labels // [] | index("qa-blocker")) | select(.status != "closed")] | length'
```

Open `qa-blocker` beads STOP the same way `ac-merge` treats them.

Mark ledger task 2 `completed`; `TaskUpdate` task 3 `in_progress`.

### Gitleaks scan (CI backstop — bd-pwt44.4)

The pre-commit `gitleaks protect --staged` hook is `--no-verify`-bypassable — zero CI
enforcement existed before. `bd-pwt44.4` wires a gitleaks step into `quality-gate.yml`'s
batch-close leg, scanning `$BATCH_RANGE` (honoring the repo-root `.gitleaksignore`). Nothing
extra to invoke here — that step rides inside the SAME `reason=batch-close` dispatch fired
below, not a separate call. If bd-pwt44.4 hasn't landed yet, the dispatched workflow simply
doesn't have that step (same silent-gap handling as any other pre-existing-infra dependency).

### Fire the Tier 1 CI dispatch

```bash
gh workflow run quality-gate.yml -f reason=batch-close -f batch_anchor="$ANCHOR"
```

If `quality-gate.yml` has no `workflow_dispatch` trigger yet (pre-bd-u2lo1.10), skip this
phase silently and note the gap in the Act 3 report — do not block the batch on
infrastructure another bead is landing.

### Poll for the dispatched run against HEAD — FOREGROUND ONLY

Same bounded-wait discipline as `ac-merge`'s PR-checks poll (`_shared/delegation-contract.md`:
hard-capped, timeout-terminal — a stalled CI run is a reportable outcome, not a pause). **This
poll runs in the foreground, inside this turn, to completion or the cap below — never fork it
to a background process that outlives the session.** The `$STATE` persistence above covers a
session that drops and resumes; it does not license spawning a detached poller that keeps
running after this turn ends.

```bash
HEAD_SHA=$(git rev-parse HEAD)
# Resolve the dispatched run's id ONCE (list + match by headSha to get its databaseId), then
# poll THAT id deterministically with `gh run view <id>` — re-listing + jq-selecting by headSha
# every iteration is fragile (bd-kskxg field-test). The run may take a cycle to register, so
# keep resolving until the id is known, then switch to the deterministic view.
RUN_DB_ID=""
for i in $(seq 1 20); do
    sleep 30
    if [ -z "$RUN_DB_ID" ]; then
        RUN_DB_ID=$(gh run list --workflow=quality-gate.yml --branch main \
          --json databaseId,headSha --limit 10 2>/dev/null \
          | jq -r --arg sha "$HEAD_SHA" '[.[] | select(.headSha == $sha)][0].databaseId // empty')
        [ -z "$RUN_DB_ID" ] && { echo "Run not registered yet... ($i/20)"; continue; }
    fi
    MATCH=$(gh run view "$RUN_DB_ID" --json databaseId,status,conclusion,url 2>/dev/null)
    STATUS=$(echo "$MATCH" | jq -r '.status // empty')
    if [ "$STATUS" = "completed" ]; then
        echo "Dispatch run completed."
        break
    fi
    echo "Waiting... ($i/20)"
done
echo "$MATCH" >> "$ARTIFACTS_DIR/dispatch-run.json"
```

### Triage on failure (same core-work rule as ac-merge)

**THIS IS YOUR CORE WORK. Do not delegate triage.** Source of findings here is the dispatch
run's failed jobs (`gh run view <id> --log-failed`) — not PR comments/agent reviews (the light
review is Act 2, which runs after this act). Same classification `ac-merge` uses:

- **Auto-fix:** obvious CI failures (lint/type/format), clear single-fix issues.
- **Conductor decides:** high-severity items with clear fixes, easy improvements.
- **Present to user:** architectural/debatable items (Exhaust Rule applies if headless —
  `br create -t bug --labels review-finding` rather than blocking silently).

Apply fixes, then commit under the minted Tier-1 identity — **re-assert `AGENT_NAME` inline in
the fix-forward commit shell** (exports don't survive across bash calls; the pre-commit guard
reads it, and a fix-forward as `FoggyCreek` would be a Tier-2-boundary violation):

```bash
export AGENT_NAME=<minted-name>   # re-assert inline — the Phase-0 mint's name
git commit -m "batch-close: fix-forward CI failure — <summary>" -- <fixed files>
git push origin main || { git pull --rebase origin main && git push origin main; }
```

Re-dispatch, re-poll (5-minute cap, same as `ac-merge`'s re-poll) — **still foreground**, never
backgrounded. **If checks still fail after fixes:** present failures and ask abort vs
proceed-anyway (interactive), or file a `qa-blocker` bead + STOP (autonomous/headless).

Mark ledger task 3 `completed`; `TaskUpdate` task 4 `in_progress`.

### Verdict comment (VERDICT grammar)

The Tier 1 CI dispatch result is a verification verdict — record it on the batch's anchor /
scope beads as a structured comment per **`beads-standards` § Verification verdicts**:
`VERDICT: passed:` on a green dispatch, `VERDICT: failed:` when the run red-Xed (put the
fix-forward SHA in the detail), `VERDICT: blocked:` for a stalled/timeout-terminal run. CI
is a *verifier* ceremony — the verdict is written here, never by the implementer whose
commit is under test (Goodhart guard). A finding filed from a CI failure carries the
`ci-finding` catch-stage label (the CI token in beads-standards' closed set) plus
`discovered-from: <bead-id|unknown>`.

---

## Act 2 — One Light Review Pass

This ceremony **NEVER closes an unreviewed batch** — the gate is unconditional. This is
deliberately **NOT** `ac-review`'s full 6-dimension panel (correctness/security/perf/
architecture/test-quality/contracts) — that panel remains `ac-review`'s own mechanism when run
standalone on a feature branch, and becomes `ac-publish`'s heavy pre-tag gate (bd-pwt44.6).
Batch-close's gate is a single lightweight `VERDICT` pass, same as before this bead's diet.

What widens on trunk-direct is only the *source* of the review verdict: Act 2 accepts **either**
a standard `ac-review` run **or** an equivalent-review artifact the invoking conductor
pre-supplies. In both cases the accepted artifact must carry an explicit `VERDICT:` line and
land in `.claude/reviews/batch/`.

**(a) Pre-supplied equivalent-review artifact.** If the delegation prompt hands you a completed
review of this same diff — e.g. `ac-hygiene`'s 7-lens panel run report (same severity bar,
already adversarial) — do **not** re-run `ac-review` on the same diff (double-review). Take that
report as the review artifact: confirm it contains an explicit `VERDICT:` line, then carry it
into `.claude/reviews/batch/` via **Act 3's commit** (the same commit that lands the batch-close
summary), so the trunk-direct review-mark is backed by a committed artifact exactly as the
`ac-review` path is. Read its `VERDICT:` and gate on it below. No supplied artifact, or one
lacking an explicit `VERDICT:` line → fall through to (b); never proceed unreviewed.

**(b) No artifact supplied → run `ac-review` yourself.** There is no PR to attach a review to, so
`ac-review` runs directly on `main` and its `VERDICT` gates this ceremony — the same severity bar
`ac-merge` enforced at PR-merge, moved here since there's no PR-merge choke point left on
trunk-direct. Delegate (do not inline its work — `ac-review/SKILL.md` is a full skill, not a
sub-step of this one):

> "Run ac-review on main (trunk-direct mode, single light pass — not the full 6-dim panel unless
> ac-review's own default routing says otherwise). report_dest=.claude/reviews/batch/"

`ac-review`'s own Phase 6 commits its findings report to that destination and pushes — this
provisionally advances the review-mark; Act 3's commit below supersedes it (see that section's
note on why).

**Read the supplied-or-produced artifact for `VERDICT:`.**

- **`VERDICT: APPROVED`** → proceed to Act 3.
- **`VERDICT: NEEDS_DECISION`** → STOP. Do not dispatch further, do not commit the batch report.
  Report the gap the same way `ac-review` reports it (missing reviewer dimension, open
  `qa-blocker`, or unresolved decision bead) — never proceed past a `NEEDS_DECISION` verdict.

Mark ledger task 4 `completed`; `TaskUpdate` task 5 `in_progress`.

---

## Act 3 — Commit the Batch Report (feedback pending-write + review-mark advance)

### Feedback write-back — PHASE 1 (pending, not final)

**Two-phase model** — full spec, error-handling policy, unit test cases:
**`../ac-merge/references/feedback-writeback-hook.md`**. Batch-close marks rows **PENDING**
here; the final `status='fixed'` + `fixed_in_build` stamp — the transition that actually fires
the client's "fixed in build N" notification (`features/feedback/lib/loopback.ts:190`,
`isNowFixed = row.status === 'fixed'`) — is deferred to `ac-publish` at mint (bd-pwt44.6).
**Do not write `status='fixed'` here.** Batch-close has no build number to attach to it, and
writing the literal string `'fixed'` would notify the user weeks early with a null build.

```bash
br list --json | jq '[.issues[] | select((.labels // []) | (index("triage") and index("feedback"))) | select(.status == "closed")]'
```

For each matching bead, resolve `linked_bead` (parsed from the bead description's
`Source: public.feedback_reports / id=<uuid>` line) and call `runFeedbackPendingWriteHook`
(`body-compass-app/lib/pipeline/merge-feedback-writeback.ts`) to write
`status='fixed_pending_release'` (no `fixed_in_build`) back to the row via the service-role
client. If a bead's `linked_bead` is unset or the row isn't found: log a warning and continue —
**never abort the batch-close for a write-back failure.** There is no web/native or
build-number branch here (that distinction only matters at publish, once a real build number
exists).

Log in the batch report:

```
Feedback pending-write: <N> rows marked fixed_pending_release
  <N> warnings (missing linked_bead or row not found — see log)
```

### Commit the batch report

Write `.claude/reviews/batch/YYYY-MM-DD-HHMM-batch-close.md` — the batch-close summary,
distinct from `ac-review`'s own findings report already committed in Act 2.

**Single source of truth for the shared sections:** `ac-review/references/report-template.md`.
The **Summary**, **Beads Completed**, **Changes**, **Test Coverage**, **Known post-merge tails**,
and **Also carried** sections are that template's — do NOT re-specify their contents here (a
second hand-rolled copy is exactly the drift bug ac-vgt filed). Fill them per the template's
field descriptions; `$BATCH_RANGE` is the range those sections' `git diff`/`git log` commands
key on. Batch-close's own addition beyond the template is a short **Feedback write-back** line
(the pending-write count logged above) — there is no Deploy section anymore (deploy
verification moved to `ac-publish`).

```bash
export AGENT_NAME=<minted-name>   # re-assert inline (Phase-0 mint) — this commit is the operative review-mark; attribute it to the minted identity, not FoggyCreek
git add ".claude/reviews/batch/YYYY-MM-DD-HHMM-batch-close.md"
# Pathspec-on-commit (bd-kskxg field-test): the trailing `-- <report path>` scopes the commit to
# ONLY this file, so pre-staged foreign WIP in the shared checkout cannot be swept into the
# batch-report commit (happened live; a soft-reset recovered it). The `git add` above is still
# needed because the report is a brand-new untracked file.
git commit -m "batch-close: ${ANCHOR:0:8}..$(git rev-parse --short HEAD) — {N} beads, {commit count} commits" -- ".claude/reviews/batch/YYYY-MM-DD-HHMM-batch-close.md"
git push origin main || { git pull --rebase origin main && git push origin main; }
```

**Why this commit (not `ac-review`'s Act 2 commit) is the operative review-mark:**
`git log -1 -- .claude/reviews/batch/` (both `ac-review`'s and `ac-loop`'s scope-detection use
this) picks the **latest** commit touching that path. Since this commit lands after the Tier 1
CI dispatch and the light review, it naturally supersedes `ac-review`'s earlier commit as the
mark — folding the administrative tail of the ceremony into THIS batch's reviewed range instead
of leaking it into the next batch's diff. No special git trick needed; ordering does the work.

**This must be the LAST commit of the ceremony.** If a fix-forward round is still needed after
this point, that means Act 1 (or Act 2) isn't actually done — re-run from there and redo this
commit last, again. Nothing pushes after the batch report.

Mark ledger task 5 `completed`; `TaskUpdate` task 6 `in_progress`.

---

## Beads-closed gate

`ac-merge` never invoked `beads-closed-gate.sh` directly — only `ac-loop` does, as its own
pre-merge gate, upstream of whichever closing skill it calls. Nothing to retarget here: the
gate stays `ac-loop`'s responsibility (its assignee-scoping rewrite is a sibling bead and needs
no change in this skill).

## Documented technique — the union allocator pattern (for the record)

`_shared/scripts/allocate-wave-branch.sh` is deleted alongside this skill's creation —
trunk-direct has no numbered wave branches to allocate. Its collision-guard pattern is worth
remembering for **any future numbered-artifact allocation**: compute NEXT from the union of
live refs ∪ main-log merge/commit messages ∪ tags — never refs alone (`git fetch --prune` drops
merged refs, so a refs-only scan can reuse a shipped number). Re-derive this pattern fresh if a
future skill needs to allocate a numbered artifact; don't resurrect the deleted script.

---

## Report + Slack + Finalize

### Report

```markdown
## Batch Closed: {ANCHOR short-sha}..{HEAD short-sha}

**Batch report:** `.claude/reviews/batch/YYYY-MM-DD-HHMM-batch-close.md`
**Beads completed:** {count}
**Commits:** {count}

### Light Review
**VERDICT:** APPROVED — {N} auto-fixed, {M} decisions resolved

### Tier 1 CI
{run URL} — {green | fixed after N rounds}

### Feedback write-back
{N} rows marked fixed_pending_release ({M} warnings)

### What Shipped
{1-3 bullet summary}
```

No Deploy section — deploy verification is `ac-publish`'s job now, not this ceremony's.

### Slack Notify

```bash
slack-send --channel sofi --card \
  --title "Batch closed" \
  --body "Batch closed — ${ANCHOR:0:8}..$(git rev-parse --short HEAD), ${N} beads, ${COMMIT_COUNT} commits. CI: ${RUN_URL}. Review: APPROVED."
```

### Release the build slot

```
release_build_slot(key="batch-close:main")   # release even on an aborted run
```

### Self-deregister the Tier-1 identity (Layer 1)

As the ceremony's true last act — after the build slot is released — deregister the name
minted in the Session Identity step so the registry doesn't accumulate a zombie identity per
batch-close (doctrine: `_shared/agent-identity.md` Deregistration, Layer 1; by name —
`registration_token` optional). Do this even on an aborted run:

```
mcp__mcp-agent-mail__deregister_agent(
  project_key: CANONICAL_PROJECT_KEY,
  agent_name: AGENT_NAME
)
```

### Next Step

```
AskUserQuestion(
  questions: [{
    question: "Batch closed. What's next?",
    header: "Next step",
    multiSelect: false,
    options: [
      { label: "Start new feature (Recommended)", description: "Run /ac-plan-init — begin planning the next batch" },
      { label: "Hygiene pass", description: "Run /ac-hygiene — codebase health check after the batch" },
      { label: "Publish", description: "Run /ac-publish — mint a release, prove it, ship web + native" },
      { label: "Done", description: "Nothing more to do right now" }
    ]
  }]
)
```

(Skipped entirely when the delegation prompt says so — e.g. an autonomous loop invocation says
"no 'what's next?' after batch-close.")

### Finalize

Mark the run ledger's final task `completed`. Clean up only on the clean "Done" path — if a
follow-up was chosen or a CI/review step flagged an error, leave `$ARTIFACTS_DIR` for
investigation.

```bash
rm -rf "$ARTIFACTS_DIR"   # ONLY on the clean "Done" path
```

---

## Remember

- **This is the single batch-closing ceremony for trunk-direct `main`** — run once per batch,
  not per commit; `ac-merge` is unchanged and still owns the PR path for legacy branches.
- **Batch = review-mark range, not a branch** — the anchor is the last commit touching
  `.claude/reviews/batch/` (bootstrap: last `v*` tag). Same computation `ac-review` uses.
- **Thin, on purpose.** No version bump, no tag, no deploy verification, no 6-dim review panel
  live in this skill anymore — all four moved to `ac-publish`. This ceremony's ONLY outputs are
  a light `VERDICT`, a green Tier 1 CI dispatch, and a committed batch-report/review-mark.
- **Light review gates everything downstream** — a single reviewer's `VERDICT: APPROVED`, not
  the full panel; `NEEDS_DECISION` stops the ceremony cold.
- **Tier 1 CI dispatch is the batch's ONE CI confirmation** — fire once, poll in the
  foreground, fix-forward, never per-commit, never a backgrounded poller that outlives the
  session.
- **Feedback write-back here is PENDING, not final** — `status='fixed_pending_release'`, no
  build stamp; the notification-firing `status='fixed'` + `fixed_in_build` transition happens
  at `ac-publish`.
- **The build slot is advisory, not a lock** — `acquire_build_slot` always grants; check
  `conflicts` yourself and back off on a genuine overlap.
- **Act 3's commit must be the LAST commit of the ceremony** — nothing pushes after it. A
  fix-forward round found after this point means re-running from Act 1 and redoing Act 3 last,
  again.
- **Abort is always an option** — if Tier 1 CI keeps failing or review returns
  `NEEDS_DECISION`, surface it and let the user decide; never claim "closed" over an unresolved
  gate.

---

_Trunk-direct batch closing: gate through a light review, dispatch CI once, commit the thin
batch report, advance the review-mark. Version/tag/deploy/heavy-review: `/ac-publish`. For
legacy branches: `/ac-merge`. For next feature: `/ac-plan-init`._
