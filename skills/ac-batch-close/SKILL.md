---
name: ac-batch-close
description: 'Trunk-direct batch closing ceremony — CI dispatch + review + version bump + tag + deploy checks + review-mark advance. Triggers: ''batch close'', ''close the batch'', ''ac-batch-close'', ''ship the batch''.'
---


**You are the conductor closing out a batch of trunk-direct commits on `main`.** Agents commit
directly to `main` — no wave branch, no PR. This is the periodic (or on-demand) closing
ceremony: gate the batch through `ac-review`, bump the version, dispatch Tier 1 CI, verify the
deploy, and advance the review-mark. Fired once per batch, not per commit.

This skill is a retarget of `ac-merge` (`skills/ac-merge/SKILL.md`) for the trunk-direct flow.
`ac-merge` is **unchanged** and remains the PR-merge path for legacy branches (dependabot,
human feature branches — `.claude/legacy-branches.txt`). Nothing from `ac-merge` is silently
dropped: the PR ceremony below is removed with cause; everything else is retargeted to the
batch anchor instead of a branch/PR base.

## Removed from ac-merge (PR ceremony — `ac-merge` still owns this path)

There is no branch and no PR on trunk-direct, so these have nothing to attach to:

- `gh pr create`, PR body assembly (`ac-merge/references/pr-body-template.md`), `gh pr merge`,
  `--delete-branch`, local branch deletion, branch-rebase-onto-main.
- The interactive "Does this project have GitHub CI checks…" `AskUserQuestion` — Tier 1 CI
  dispatch (Phase 3) is now a fixed mechanism, not a per-project optional wait; the only
  remaining conditional is a file-existence check (does `quality-gate.yml` exist at all).

Everything else below is the same mechanism, retargeted anchor and audience.

---

## I/O Contract

|                  |                                                                                            |
| ---------------- | ------------------------------------------------------------------------------------------ |
| **Input**        | `main`, with implementation commits already pushed directly since the last batch anchor (no branch, no PR) |
| **Output**       | Batch reviewed (`ac-review` APPROVED), versioned, tagged, Tier 1 CI confirmed, deploy verified, review-mark advanced |
| **Artifacts**    | Batch-close summary in `.claude/reviews/batch/`, scratch in `$ARTIFACTS_DIR`                |
| **Verification** | `ac-review` VERDICT: APPROVED; Tier 1 CI dispatch green for the final SHA; Vercel/native deploy checks pass |

## Prerequisites

- On `main` (trunk-direct — no branch-name check; if invoked on a branch, that's `ac-merge`'s job, not this skill's)
- `gh` CLI authenticated
- Implementation commits already landed directly on `main` (from `ac-implement`, trunk-direct — no wave branch to check out)
- A `quality-gate.yml` workflow with `workflow_dispatch` inputs `reason` + `batch_anchor`
  (added by the sibling bead bd-u2lo1.10). If the workflow doesn't exist yet, Tier 1 CI
  dispatch (Phase 3) is skipped silently — same escape hatch `ac-merge`'s CI-config question
  offered, now inferred from file presence instead of asked.

---

## Phase 0: Pre-flight

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

### Declare the Run Ledger

Same rationale as `ac-merge`: this ceremony spans a 10-min CI poll where a session can drop.
One task per major section, so a resumed run re-enters at the exact section instead of
re-polling from scratch:

```
TaskCreate (one per section, in run order):
  1.  Determine batch anchor + scope + quality gate       in_progress
  2.  QA smoke gate (conditional)                          pending
  3.  ac-review gate (VERDICT required)                    pending
  4.  Version bump + native propagation + write-back       pending
  5.  Tier 1 CI dispatch + fix-forward                      pending
  6.  Tag + deploy verification                            pending
  7.  Final Act — commit + push batch report               pending
  8.  Report + Slack + finalize                             pending
```

`TaskUpdate` each to `in_progress`/`completed` as you go. Persist `ANCHOR`, `NEW_VERSION`,
`DISPATCH_RUN_ID` to `$STATE` as you capture them (`echo "ANCHOR=$ANCHOR" >> "$STATE"`) so a
dropped session reloads instead of re-deriving.

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
  # Bootstrap fallback: no batch review-mark exists yet
  ANCHOR=$(git describe --tags --match 'v*' --abbrev=0)
fi
BATCH_RANGE="$ANCHOR..HEAD"
echo "ANCHOR=$ANCHOR" >> "$STATE"
```

Deterministic `$ARTIFACTS_DIR` per `_shared/run-id.md` (prefix `batch-close`) — trunk-direct
has no wave branch to key on, so the key is the anchor SHA instead of a branch slug:

```bash
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

No PR body is constructed. This context feeds the Phase 4 batch-close report only.

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

**If any fail:** fix before proceeding — same rule as `ac-merge`: never dispatch Tier 1 CI or
invoke `ac-review` with failing local checks.

Mark ledger task 1 `completed`; `TaskUpdate` task 2 `in_progress`.

### QA Smoke Gate (conditional — safety net)

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

---

## Phase 1: ac-review Gate

There is no PR to attach a review to, so `ac-review` runs directly on `main` and its `VERDICT`
gates this ceremony proceeding — the same severity bar `ac-merge` enforced at PR-merge, moved
here since there's no PR-merge choke point left on trunk-direct.

Delegate `ac-review` (do not inline its work — `ac-review/SKILL.md` is a full skill, not a
sub-step of this one):

> "Run ac-review on main (trunk-direct mode). report_dest=.claude/reviews/batch/"

`ac-review`'s own Phase 6 commits its findings report to that destination and pushes — this
provisionally advances the review-mark; Phase 5's Final Act below supersedes it (see that
section's note on why).

**Read the returned summary for `VERDICT:`.**

- **`VERDICT: APPROVED`** → proceed to Phase 2.
- **`VERDICT: NEEDS_DECISION`** → STOP. Do not version-bump, tag, or dispatch CI. Report the
  gap the same way `ac-review` reports it (missing reviewer dimension, open `qa-blocker`, or
  unresolved decision bead) — never proceed past a `NEEDS_DECISION` verdict.

Mark ledger task 3 `completed`; `TaskUpdate` task 4 `in_progress`.

---

## Phase 2: Version Bump + Feedback Write-back

**Every batch-close bumps `patch` by default** — same policy as `ac-merge`: these app versions
are a build/marketing number, not a published-library API contract, so neither a feature batch
nor a chore pass auto-escalates to minor. `minor`/`major` remain deliberate, explicitly-chosen
human bumps, never derived from commit prefixes. The bump commit lands directly on `main` (no
branch to hold it on) — it's pushed immediately, then Tier 1 CI (Phase 3) confirms it.

**Default path is non-interactive:** apply `patch` automatically, without asking — the normal
case for autonomous/delegated runs.

```bash
CHOSEN_BUMP=patch
COMMIT_LOG=$(git log $BATCH_RANGE --format="%s%n%b")
if printf '%s' "$COMMIT_LOG" | grep -qE "^[a-zA-Z]+(\([^)]+\))?!:|BREAKING[ -]CHANGE"; then
    echo "NOTE: batch carries a breaking-change marker — pick 'major' explicitly only if truly warranted."
fi
CURRENT_VERSION=$(node -p "require('./package.json').version")
```

**The only thing that stops the patch bump is an explicit skip/freeze directive** (e.g.
`MERGE_SKIP_BUMP=1`, or a standing version-freeze such as an App Store submission in review —
the app-version-pin rule). No other "skip" path exists.

**Interactive human-run only:** if a human is running this skill directly and wants to override
the default, offer the choice per `ac-merge/references/version-bump-interactive.md` (verbatim
`AskUserQuestion` spec — read it only in interactive mode).

Apply the chosen bump (unless frozen/skipped):

```bash
pnpm version "$CHOSEN_BUMP" --no-git-tag-version
NEW_VERSION=$(node -p "require('./package.json').version")
echo "NEW_VERSION=$NEW_VERSION" >> "$STATE"
```

### Propagate to native build surfaces

Same propagation `ac-merge` uses — iOS `MARKETING_VERSION` ×4 + monotonic
`CURRENT_PROJECT_VERSION`, Android `build.gradle` when added, `NEXT_PUBLIC_APP_VERSION`
auto-derived. Follow **`../ac-merge/references/version-bump.md`** verbatim (it remains the
sole-owner reference for this counter regardless of which skill calls it). Web-only projects
skip the native steps.

### Commit and push the bump

```bash
git add package.json pnpm-lock.yaml ios/App/App.xcodeproj/project.pbxproj 2>/dev/null
git commit -m "chore(release): v${NEW_VERSION} (iOS build ${NEW_BUILD})"
git push origin main || { git pull --rebase origin main && git push origin main; }
```

The tag is created in Phase 4, after Tier 1 CI + deploy checks confirm this commit — not here
(same reasoning `ac-merge` applies: the tag should point at a confirmed-good state).

### Feedback write-back (post-build-bump, unchanged mechanics)

Run immediately after the bump commit. Full spec, error-handling policy, unit test cases:
**`../ac-merge/references/feedback-writeback-hook.md`** — hook site is now "ac-batch-close
Phase 2, immediately after the bump commit" (same mechanics, different calling skill).

```bash
br list --json | jq '[.issues[] | select((.labels // []) | (index("triage") and index("feedback"))) | select(.status == "closed")]'
```

For each matching bead, resolve `linked_bead` and write `status='fixed'`,
`fixed_in_build=<NEW_BUILD>` back to `public.feedback_reports` via the service-role client. If
a bead's `linked_bead` is unset or the row isn't found: log a warning and continue — **never
abort the batch-close for a write-back failure.** Web-only batches with no native build bump:
use `NEW_VERSION` (semver string) as the build identifier.

Mark ledger task 4 `completed`; `TaskUpdate` task 5 `in_progress`.

---

## Phase 3: Tier 1 CI Dispatch + Fix-Forward

Trunk-direct has no PR-triggered CI to wait on. Instead, batch-close explicitly fires **one**
Tier 1 CI run for the whole batch (`ac-loop`'s pipeline diagram calls this "1 CI run for the
whole batch") — the workflow-dispatch leg a sibling bead (bd-u2lo1.10) adds to
`quality-gate.yml`.

### Fire the dispatch

```bash
gh workflow run quality-gate.yml -f reason=batch-close -f batch_anchor="$ANCHOR"
```

If `quality-gate.yml` has no `workflow_dispatch` trigger yet (pre-bd-u2lo1.10), skip this
phase silently and note the gap in the Phase 6 report — do not block the batch on
infrastructure another bead is landing.

### Poll for the dispatched run against the bump commit

Same bounded-wait discipline as `ac-merge`'s PR-checks poll (`_shared/delegation-contract.md`:
hard-capped, timeout-terminal — a stalled CI run is a reportable outcome, not a pause):

```bash
BUMP_SHA=$(git rev-parse HEAD)
for i in $(seq 1 20); do
    sleep 30
    RUN_JSON=$(gh run list --workflow=quality-gate.yml --branch main \
      --json databaseId,status,conclusion,headSha,url --limit 10 2>/dev/null)
    MATCH=$(echo "$RUN_JSON" | jq -r --arg sha "$BUMP_SHA" '[.[] | select(.headSha == $sha)][0]')
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
run's failed jobs (`gh run view <id> --log-failed`) — not PR comments/agent reviews (those
came from `ac-review` in Phase 1 and are already applied). Same classification `ac-merge` uses:

- **Auto-fix:** obvious CI failures (lint/type/format), clear single-fix issues.
- **Conductor decides:** high-severity items with clear fixes, easy improvements.
- **Present to user:** architectural/debatable items (Exhaust Rule applies if headless —
  `br create -t bug --labels review-finding` rather than blocking silently).

Apply fixes, commit, push directly to `main`, re-dispatch, re-poll (5-minute cap, same as
`ac-merge`'s re-poll). **If checks still fail after fixes:** present failures and ask abort vs
proceed-anyway (interactive), or file a `qa-blocker` bead + STOP (autonomous/headless).

Mark ledger task 5 `completed`; `TaskUpdate` task 6 `in_progress`.

---

## Phase 4: Tag + Deploy Verification

### Tag the batch

```bash
NEW_VERSION=$(node -p "require('./package.json').version")
git tag "v$NEW_VERSION" -m "Release v$NEW_VERSION"
git push origin "v$NEW_VERSION"
```

Skip if the version was frozen/skipped in Phase 2. The tag marks the **last shippable commit**
of the batch (the confirmed-green bump commit) — not the Phase 5 batch-report commit, which is
administrative and comes after, un-tagged (see Phase 5's note).

### Database migrations — a SEPARATE, human-approved push (unchanged from ac-merge)

If the batch includes a `supabase/migrations/*.sql` file, none of the above pushed it to
production — the prod `db push` is a deliberate, human-approved, collision-aware step, run
after the local-validate gate (`ac-implement` Phase 1c). Shared-project apps: `supabase
migration fetch` → review diff → `db push` → verify — never blind-repair. Surface the pending
prod migration in the Phase 6 report so it isn't silently forgotten.

**Apply-timing gate (expand/contract — `rule-migrations-expand-contract`).** Trunk-direct
deploys to prod when code lands, which is BEFORE this ceremony even runs — so the timing risk
is sharper here than on ac-merge's PR path:

- **EXPAND (additive) migration the already-live code depends on:** it must be applied
  **before or at this batch-close.** If still unpushed — interactive: ask push-now / proceed
  with the dependent path flag-gated off / hold. Headless: hold and file a `human-gate`
  decision bead (Exhaust Rule).
- **CONTRACT (drop/rename/narrow/NOT NULL-no-default):** never applied here — merges as a
  *held* migration, applied later via `ac-publish`'s migration gate.

### Verify the Deploy Actually Shipped (widened — closes bd-vqy0d)

```bash
sleep 90
vercel ls <project> 2>/dev/null | head -5     # final SHA: ● Ready or ● Error?
```

Two checks, not one:

1. **Final-SHA check (as ac-merge):** `● Error` on the tagged commit → the batch-close push
   did NOT reach production. Surface loudly, investigate (`next build` locally — missing deps
   on lazily-compiled routes is the classic cause). Do not close claiming "shipped."
2. **Served-version check (new — closes bd-vqy0d):** a Ready deployment can still be serving a
   *stale* build if the platform served a cached/previous artifact. Assert the LIVE site's
   `NEXT_PUBLIC_APP_VERSION` actually equals `$NEW_VERSION` (fetch the deployed page/API and
   grep the injected version string) — Ready ≠ serving-what-we-think.
3. **Intermediate-commit scan (new):** a final-SHA-only check misses a commit *inside* the
   batch range that broke the build before self-healing on the next push. Scan the Vercel
   deployment list for every commit in `$BATCH_RANGE` and flag any `● Error` entry, even if the
   final SHA is Ready — a broken interim deploy briefly served bad prod and is worth knowing
   about even after the fact.

No Vercel project → skip silently. Full incident provenance (447-day simil8 freeze):
`../ac-merge/references/incidents.md`.

### Native (iOS) build check

Same HEAD-anchored, blocking check as `ac-merge` — `pnpm archive:watch-head` (or the app's
named command in `CORE/distribution.md`), fired after THIS ceremony's push. Two deadlines
(archive must APPEAR, must COMPLETE). Produced ≠ uploaded — if the merge-triggered build is an
archive-only health check (BCA's Xcode Cloud pattern), report exactly that wording, never
implying a shippable build exists (`../ac-merge/references/incidents.md`, BCA 2026-07-02).

### Confirm the Tier 1 CI run — silence ≠ pass

This reads the **same dispatch run** polled in Phase 3 — there is no separate "main CI"
confirmation on trunk-direct; the dispatch *is* the confirmation.

- Terminal + green → report the run URL.
- Terminal + failed → surface loudly; this shouldn't happen post-fix-forward — treat as a
  regression, file a bead, do not claim shipped.
- **Still pending >1hr** (rare, if Phase 3's poll already timed out and the run is still
  queued behind other work): compute elapsed from `createdAt`, don't treat pending as stuck
  per se, but do not close silently — Slack it:

```bash
slack-send --channel sofi --card \
  --title "Batch-close CI still pending >1hr" \
  --body "Tier 1 CI dispatch <RUN_URL> for batch-close (anchor <ANCHOR_SHA_SHORT>, bump v<NEW_VERSION>) has been queued/running over an hour. Watch it land — batch-close isn't done until this resolves green."
```

Mark ledger task 6 `completed`; `TaskUpdate` task 7 `in_progress`.

---

## Phase 5: Final Act — Commit the Batch Report

Write `.claude/reviews/batch/YYYY-MM-DD-HHMM-batch-close.md` — the batch-close summary,
distinct from `ac-review`'s own findings report already committed in Phase 1:

```markdown
## Summary
{1-3 sentences: what this batch shipped}

## Beads Completed
{claim-set beads with IDs and titles from br list}

## Changes
{diff stats over $BATCH_RANGE}

## Test Coverage
{quality gate results + Tier 1 CI dispatch run link}

## Deploy
{Vercel served-version check + intermediate-commit scan result; native archive-watch-head result}

## Known post-merge tails
{beads labeled post-merge, still open — same convention as ac-merge's PR body}

## Also carried (beyond the claim set)
{any commit in $BATCH_RANGE not tied to a tracked bead — a concurrent agent's fix, a
scheduled ops commit. Trunk-direct means multiple sessions can commit to main inside one
batch window; name them here so nothing ships unseen (pipeline-builder Invariant 8).}
```

```bash
git add ".claude/reviews/batch/YYYY-MM-DD-HHMM-batch-close.md"
git commit -m "batch-close: v${NEW_VERSION} — {N} beads, {commit count} commits"
git push origin main || { git pull --rebase origin main && git push origin main; }
```

**Why this commit (not `ac-review`'s Phase 6 commit) is the operative review-mark:**
`git log -1 -- .claude/reviews/batch/` (both `ac-review`'s and `ac-loop`'s scope-detection use
this) picks the **latest** commit touching that path. Since this commit lands after the version
bump, Tier 1 CI dispatch, and deploy checks, it naturally supersedes `ac-review`'s earlier
commit as the mark — folding the administrative tail of the ceremony into THIS batch's
reviewed range instead of leaking it into the next batch's diff. No special git trick needed;
ordering does the work.

**This must be the LAST commit of the ceremony.** If a fix-forward round is still needed after
this point, that means Phase 3 (or later) isn't actually done — re-run from there and redo this
commit last, again. Nothing pushes after the batch report.

Mark ledger task 7 `completed`; `TaskUpdate` task 8 `in_progress`.

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

## Phase 6: Report + Slack + Finalize

### Report

```markdown
## Batch Closed: v{NEW_VERSION}

**Anchor:** {ANCHOR short-sha} → **HEAD:** {current short-sha}
**Batch report:** `.claude/reviews/batch/YYYY-MM-DD-HHMM-batch-close.md`
**Beads completed:** {count}
**Commits:** {count}

### ac-review
**VERDICT:** APPROVED — {N} auto-fixed, {M} decisions resolved

### Tier 1 CI
{run URL} — {green | fixed after N rounds}

### Deploy
- Vercel: {Ready, version confirmed | Error — investigate}
- Native: {archive succeeded | health-check only | N/A}

### What Shipped
{1-3 bullet summary}
```

### Slack Notify — "batch shipped" (retargeted from ac-loop's "wave shipped"/"plan wave shipped")

```bash
slack-send --channel sofi --card \
  --title "🚀 Batch shipped" \
  --body "Batch closed — v${NEW_VERSION}, ${N} beads, ${COMMIT_COUNT} commits since ${ANCHOR:0:8}. CI: ${RUN_URL}. Deploy: ${DEPLOY_STATUS}."
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
      { label: "Done", description: "Shipped — nothing more to do" }
    ]
  }]
)
```

(Skipped entirely when the delegation prompt says so — e.g. an autonomous loop invocation says
"no 'what's next?' after batch-close.")

### Finalize

Mark the run ledger's final task `completed`. Clean up only on the clean "Done" path — if a
follow-up was chosen or a deploy-verify step flagged an error, leave `$ARTIFACTS_DIR` for
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
- **`ac-review`'s `VERDICT: APPROVED` gates everything downstream** — the same severity bar
  `ac-merge` applied at PR-merge, moved here since there's no PR-merge choke point on trunk-direct.
- **Every batch-close bumps `patch` by default** — unchanged policy from `ac-merge`; minor/major
  remain explicit human choices.
- **Tier 1 CI dispatch is the batch's ONE CI confirmation** — fire once, poll, fix-forward,
  never per-commit; it doubles as the "silence ≠ pass" main-CI confirmation.
- **The tag marks the last SHIPPABLE commit** (the version bump); the Final Act's batch report
  is the true review-mark and comes after, un-tagged.
- **The Final Act must be the LAST commit of the ceremony** — nothing pushes after it. A
  fix-forward round found after this point means re-running from Phase 3 and redoing it last, again.
- **Abort is always an option** — if Tier 1 CI keeps failing or a deploy check errors, surface
  it and let the user decide; never claim "shipped" on an unverified deploy.

---

_Trunk-direct batch closing: gate through ac-review, bump, dispatch CI, verify deploy, advance
the review-mark. For legacy branches: `/ac-merge`. For next feature: `/ac-plan-init`._
