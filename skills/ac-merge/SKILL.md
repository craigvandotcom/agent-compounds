---
name: ac-merge
description: 'The single merge-to-main path for ANY branch — feature wave or chore/hygiene. PR creation, CI/agent feedback triage + fix-forward, always-patch version bump, tag, land. Triggers: ''merge the wave'', ''ship the branch'', ''merge to main'', ''merge this branch''.'
---


**You are the conductor closing out a branch — feature wave or chore/hygiene.** Create the PR, wait for CI and agent feedback, triage and fix, merge when clean.

Feature waves run after `/ac-review` (the pre-merge gate for waves); chore/hygiene branches are self-reviewed and skip it. `/ac-land` runs AFTER this merge, as session closure. Per-branch, not per-session (contrast: bead-land).

**Trunk-direct migration:** agents committing directly to `main` no longer open PRs — that
closing ceremony is **`ac-batch-close`** (`skills/ac-batch-close/SKILL.md`). This skill
(`ac-merge`) is unchanged and remains the PR-merge path for legacy branches (dependabot,
human feature branches — see `.claude/legacy-branches.txt`).

---

## I/O Contract

|                  |                                                                                            |
| ---------------- | ------------------------------------------------------------------------------------------ |
| **Input**        | The current branch (wave or chore/hygiene), pushed. For a wave, post `/ac-review` (the pre-merge gate); hygiene/chore branches are self-reviewed and skip that gate. |
| **Output**       | PR merged to main, branch deleted, work shipped                                    |
| **Artifacts**    | PR on GitHub, feedback triage in `$ARTIFACTS_DIR/`                                         |
| **Verification** | All CI checks green, PR merged, on main branch                                            |

## Prerequisites

- Branch pushed and up-to-date with remote
- `gh` CLI authenticated
- Works on any branch — feature wave (`wave/*`) or chore/hygiene (`hygiene/*`); no branch-name check is performed

---

## Phase 0: Pre-flight

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
WAVE=$(git branch --show-current)   # variable name kept for both wave and chore/hygiene branches
# Stable per-branch artifacts dir → a session dropped during a 10-min CI poll finds the SAME dir
# on resume (a fresh timestamped dir would orphan the prior state). ac-land sweeps /tmp/wave-merge-*
# (the artifacts-dir prefix is unchanged regardless of branch kind — ac-land's glob depends on it).
ARTIFACTS_DIR="/tmp/wave-merge-${WAVE//\//-}"
mkdir -p "$ARTIFACTS_DIR"
STATE="$ARTIFACTS_DIR/state.env"      # durable resume anchor: PR_NUMBER, NEW_VERSION, WAIT_FOR_FEEDBACK
[ -f "$STATE" ] && . "$STATE"         # on resume, reload instead of re-asking
```

### Register Session Identity (Tier 1)

<!-- net-growth-ok: ac-1oq — ac-merge edited code and pushed with NO minted identity (commits misattributed to the Tier-2 chore identity while doing Tier-1 work); this seals the protocol gap via the shared canon -->

ac-merge edits product code (quality-gate + feedback fixes) and commits + pushes in the
shared checkout — a **Tier-1 session** (bead ac-1oq; `_shared/agent-identity.md` § Tier 1).
**Run the mint + token/export discipline per `_shared/agent-mail.md` (§ Mint, § Export)**;
reserve the files of each fix round at the work grain before editing (§ Reserve), and
release + self-deregister at Finalize (§ Release).

### Declare the Run Ledger

ac-merge spans long CI polls where a session can drop. Declare the run ledger per
`_shared/run-ledger.md` (pattern + resume doctrine there — one task per section,
advance as you go, persist captured facts to `$STATE`). This ceremony's table:

```
TaskCreate (one per section, in run order):
  1.  Rebase on main + quality gate                    in_progress
  2.  QA smoke gate (conditional)                      pending
  3.  Version bump + native propagation                pending
  4.  Feedback write-back                              pending
  5.  Push + confirm CI/agent-review config            pending
  6.  Create PR                                        pending
  7.  Wait for PR feedback + triage + fix              pending
  8.  Merge + tag                                      pending
  9.  Verify deploy shipped                            pending
  10. Report + finalize                                pending
```

State vars this run persists to `$STATE`: `PR_NUMBER`, `NEW_VERSION`, `WAIT_FOR_FEEDBACK`.

### Rebase on Main (first — post-rebase truth)

Rebase BEFORE the quality gate: `main` is what actually merges, so the gate must run on the
rebased state, not the pre-rebase branch (through-thread: post-rebase truth).

```bash
git fetch origin main
git rebase origin/main
```

**If conflicts:** Resolve them, then run the quality gate below.

### Quality Gate (post-rebase)

```bash
# Run project quality gate (see AGENTS.md > Project Commands > Quality gate).
# Order MIRRORS CI: format FIRST + auto-fix, then type-check, lint, tests.
#   format (auto-fix, e.g. `pnpm format` = prettier --write .)   <- pre-empts CI's `prettier --check .`
# mirror: _shared/verification-gate.md §Format-first
#   + type-check + lint + tests
# Tests = the AGGREGATED affected run, pinned to the merge base:
#   VITEST_AFFECTED_REF=origin/main pnpm test
# Post-rebase this selects everything the WHOLE branch changed vs the exact state
# that merges — per-commit affected runs during implementation never saw current
# main (semantic-conflict class) nor the final tree (review fixups, conflict
# resolutions). Pin the ref: the config default 'main' is the LOCAL branch, which
# can be stale even right after `git fetch origin main` — origin/main is truth.
```

**Format is the first step and it AUTO-FIXES** — CI runs `prettier --check .` repo-wide as
its *first* step, so any unformatted file (even one already red on `main`) fails the whole
gate; if `pnpm format` rewrites pre-existing files, commit the formatting (you're repairing
a gate CI was already failing). **Commit without `--no-verify`** — the pre-commit
`lint-staged` hook auto-formats staged files; only the *push* uses `--no-verify` (to skip
the heavy pre-push build). Never let CI catch a formatting miss.
<!-- mirror: _shared/verification-gate.md §Format-first — edit there first -->

**If any fail:** Fix before proceeding. Do not create a PR with failing local checks.

Mark ledger task 1 `completed`; `TaskUpdate` task 2 `in_progress`.

### QA Smoke Gate (conditional — safety net)

**Run the ceremony smoke net per `_shared/verification-gate.md` § Ceremony smoke net**
with `<RANGE>` = `main...HEAD` — the post-rebase state, the thing that actually merges
(device-twin conditions, browser twin, FAIL escalation, `mac-needed` note, and the
qa-blocker STOP all live there; a smoke FAIL here means STOP before creating the PR).
The Verify stage already ran the gate-selected passes at full depth pre-land; this net
re-checks at smoke because the rebase above can change the diff.

Mark ledger task 2 `completed`; `TaskUpdate` task 3 `in_progress`.

### Version Bump

**Every merge bumps `patch` by default — waves AND hygiene/chores alike.** These app
versions are a build / marketing number, not a published-library API contract — so
neither a feature wave nor a chore pass auto-escalates to minor. `minor` and `major` are
**deliberate, explicitly-chosen** bumps that a human directs for a milestone or an
announced breaking release; they are NEVER auto-derived from commit prefixes. The
version-bump commit lands on the branch BEFORE the push, so the PR shows it as part of
the merge unit.

**The default path is non-interactive: apply `patch` automatically, without asking.**
This is the normal case — autonomous/delegated runs (`ac-loop`, `ac-hygiene`) and any
other invocation that doesn't explicitly ask for interactive control all take the patch
bump silently.

```bash
BASE_BRANCH=main
COMMIT_LOG=$(git log "$BASE_BRANCH"..HEAD --format="%s%n%b")

# DEFAULT IS PATCH — every merge, features and chores alike.
CHOSEN_BUMP=patch

# Signal only: surface a breaking-change marker so a human can CHOOSE major later.
# Never auto-escalate the default off patch.
if printf '%s' "$COMMIT_LOG" | grep -qE "^[a-zA-Z]+(\([^)]+\))?!:|BREAKING[ -]CHANGE"; then
    echo "NOTE: branch carries a breaking-change marker — pick 'major' explicitly only if truly warranted."
fi

CURRENT_VERSION=$(node -p "require('./package.json').version")
echo "Current version: $CURRENT_VERSION → bump: patch"
```

**The only thing that stops the patch bump is an explicit skip/freeze directive.** If
the caller passes a freeze/skip directive (e.g. `MERGE_SKIP_BUMP=1`, or a standing
version-freeze such as an App Store submission in review — see the app-version-pin
rule), do NOT bump; carry the current version forward unchanged. There is no other
"skip" path — every non-frozen merge bumps patch.

**Verify the freeze fact before honoring it — never trust its prose alone.** A
freeze/pin memory fact (e.g. `app-version-pinned-*`) goes stale silently: it can outlive
the situation that created it and wrongly suppress a bump for days. Before you skip the
bump on the strength of such a fact, check BOTH ground truths, in this order:
1. **The cited gating bead's LIVE status** — the fact MUST name the bead whose closure
   retires it; run `br show <id>` and confirm it is still open. A closed gating bead means
   the freeze is over — the fact is stale; do NOT honor it (and flag it for retirement —
   see the bead-close checklist in `ac-implement`).
2. **`package.json` ground truth** — read the current version. If it already moved past
   the pinned version, the pin is contradicted by reality; do NOT honor the fact.
Only when the gating bead is still open AND `package.json` still sits at the pinned
version do you carry the version forward. (Incident: a 1.2.0 App Store pin outlived its
bead's close by 7 days and would have wrongly skipped a bump — caught only by this
double-check. Memory: `app-version-pinned-*`.)

**Interactive human-run merge only:** if a human is running this skill directly
(not via `ac-loop` / `ac-hygiene` delegation) and wants to override the default,
offer the choice explicitly — otherwise skip straight to applying `patch`. The exact
`AskUserQuestion` spec (verbatim option set — do not paraphrase it):
`references/version-bump-interactive.md`. Read it in interactive mode only — when
NOT running under a delegation prompt that pre-answers the bump.

Apply the chosen bump (unless frozen/skipped):

```bash
pnpm version "$CHOSEN_BUMP" --no-git-tag-version
NEW_VERSION=$(node -p "require('./package.json').version")
echo "NEW_VERSION=$NEW_VERSION" >> "$STATE"   # persist so a dropped session doesn't re-ask the bump
```

#### Propagate the version to native build surfaces

`package.json` alone doesn't reach the App Store binary. Propagate to the native build surfaces (iOS pbxproj `MARKETING_VERSION` ×4 + monotonic `CURRENT_PROJECT_VERSION`; Android `build.gradle` when added; the JS `NEXT_PUBLIC_APP_VERSION` is auto-derived, no script) following **`references/version-bump.md`**. Web-only projects skip this.

#### Commit the bump

```bash
git add package.json pnpm-lock.yaml ios/App/App.xcodeproj/project.pbxproj 2>/dev/null
git commit -m "chore(release): v${NEW_VERSION} (iOS build ${NEW_BUILD})"
```

The tag is created on the merge commit in Phase 3 (after merge to main), not here — that way `v$NEW_VERSION` points at the actual shipped state.

Mark ledger task 3 `completed`; `TaskUpdate` task 4 `in_progress`.

### Feedback write-back (post-build-bump)

**Run immediately after the bump commit, before the push.** This step requires `NEW_BUILD`
(set in Version Bump above) — if the bump was skipped, use the current build number from
the pbxproj; `fixed_in_build` must never be empty.

Scan the wave's merged beads for any with the `triage,feedback` label:

```bash
br list --json | jq '[.issues[] | select((.labels // []) | (index("triage") and index("feedback"))) | select(.status == "closed")]'
```

For each matching bead, resolve its `linked_bead` field (the source `public.feedback_reports`
row id) and write back via the service-role client:

```sql
UPDATE public.feedback_reports
SET status        = 'fixed',
    fixed_in_build = '<NEW_BUILD>'
WHERE id          = '<linked_bead>'
  AND linked_bead IS NOT NULL   -- only update claimed rows (safety guard)
```

- `NEW_BUILD` = the integer incremented in Version Bump (iOS `CURRENT_PROJECT_VERSION`).
  Web-only waves with no native build bump: use `NEW_VERSION` (semver string) as the
  build identifier — `fixed_in_build` is `text`, not `int`.
- If a bead's `linked_bead` field is unset or the row is not found, log a warning and
  continue — do NOT abort the merge for a write-back failure.
- If no `triage,feedback` beads are in this wave, skip silently.

Full spec, error-handling policy, and unit test cases: `references/feedback-writeback-hook.md`.

Mark ledger task 4 `completed`; `TaskUpdate` task 5 `in_progress`.

### Push

```bash
git push --force-with-lease
```

### Ask About CI/Agent Reviews

**Delegation reception:** when the delegation prompt supplies a cached CI config (e.g. `ac-loop` passes "CI config for this project: <cached-answer>"), skip the question below and use the supplied answer as `WAIT_FOR_FEEDBACK`.

```
AskUserQuestion(
  questions: [{
    question: "Does this project have GitHub CI checks or agent reviews (e.g., Claude Code Review, CodeRabbit) that run on PRs?",
    header: "PR feedback",
    multiSelect: false,
    options: [
      { label: "Yes — wait for feedback", description: "Wait up to 10 minutes for checks and agent reviews, then triage" },
      { label: "No — merge directly", description: "No CI/agents configured, skip waiting" }
    ]
  }]
)
```

Save as `WAIT_FOR_FEEDBACK` (true/false), and persist for resume: `echo "WAIT_FOR_FEEDBACK=$WAIT_FOR_FEEDBACK" >> "$STATE"`. Mark ledger task 5 `completed`.

---

## Phase 1: Create PR

`TaskUpdate` task 6 `in_progress`.

### Gather PR Context

```bash
# Bead summary. NB: dcg blocks a redirect whose target path is variable-built (11 such writes in this skill) — if blocked do NOT bypass; use tee or the Write tool per _shared/shell-guardrails.md
br list --json > "$ARTIFACTS_DIR/beads.json"

# Commit history on this branch
BASE_BRANCH=main
git log "$BASE_BRANCH"..HEAD --oneline > "$ARTIFACTS_DIR/commits.txt"

# Diff stats
git diff "$BASE_BRANCH"...HEAD --stat > "$ARTIFACTS_DIR/diff-stats.txt"

# Review report (if exists)
ls .claude/reviews/*.md 2>/dev/null | tail -1
```

Also read the plan file (`_plans/*.md`) if it exists for the original intent.

### Build PR Body

Construct a structured PR body from the gathered context using the template in **`references/pr-body-template.md`** (Summary, Beads Completed, Changes, Test Coverage, Review).

Beads labeled `post-merge` are deliberately un-closeable pre-merge (prod verification,
follow-up monitoring — checks that only make sense once the merge commit is live). List
them explicitly as **known post-merge tails** (`references/pr-body-template.md` § Known
post-merge tails) rather than treating them as blockers — closure of genuinely open beads
is checked upstream of this skill (by `ac-loop`, for a wave) before it invokes ac-merge.

**The branch is the merge unit — include by default, gate on the full diff, surface the extras**
(pipeline-builder Invariant 8). This branch may carry commits you didn't author — a
concurrent session's fix, a scheduled triage/ops commit landed on the checked-out branch. Do
**not** drop them because they're "not yours": the merge validates the *entire* branch diff as a
unit (CI + review + gitleaks are the gate, not authorship). Before writing the body, diff the
whole branch against main (`git diff --stat main...HEAD`) and **name any change beyond this
branch's headline scope** — an `.env`/secret edit, a migration, a foreign commit — in a
**"Also carried"** line of the PR body, so a human sees what actually shipped. Exclude a change
only on a real signal (`WIP`/`DO-NOT-MERGE` marker, CI failure, gitleaks hit, explicit scope
conflict), and when you do, **say so in the PR body** — never a silent drop.

### Create PR

The branch name (e.g. `wave/042` or `hygiene/20260707`) is just an identifier — it doesn't describe content. Derive the PR title from the version bump + a 4-7 word summary of what actually changed, scanned from commit subjects + the bead list.

```bash
gh pr create --title "v{NEW_VERSION}: {short summary derived from commits}" --body "$(cat <<'EOF'
{constructed PR body — include the version bump as the first line}
EOF
)"
```

Save the PR number and URL, and persist for resume: `echo "PR_NUMBER=$PR_NUMBER" >> "$STATE"`. Mark ledger task 6 `completed`; `TaskUpdate` task 7 `in_progress`.

**If `WAIT_FOR_FEEDBACK` is false:** Mark ledger task 7 `completed` (skipped — no feedback to wait for) and skip to Phase 3 (Merge).

---

## Phase 2: Wait for PR Feedback

> **Bounded wait only** (`_shared/delegation-contract.md`): the poll below is hard-capped
> and timeout-terminal on purpose — never swap it for an open-ended "monitor" and assume it
> wakes you. A stalled CI/agent run is a reportable outcome, not a pause.

### Poll for Checks and Comments

<!-- net-growth-ok: ac-j6v — 10-min cap timed out mid-run on full-suite-fallback batches (run 29243312437); cap + rationale aligned with ac-batch-close's evidence-stamped block -->
Wait for CI checks and agent reviews to complete. Poll every 30 seconds, timeout after ~25
minutes — a diff touching `scripts/` or CI config correctly defeats `vitest-affected` selection
and runs the FULL suite (~19 min observed, run 29243312437); a 10-min cap times out mid-run on
any full-suite-fallback batch (same evidence as `ac-batch-close`'s cap; bead ac-j6v).

```bash
PR_NUMBER={from Phase 1}

# Poll loop (up to ~25 minutes)
for i in $(seq 1 50); do
    sleep 30

    # Check CI status
    CHECKS=$(gh pr checks "$PR_NUMBER" 2>/dev/null)
    echo "$CHECKS"

    # Check if all checks have completed (none pending)
    PENDING=$(echo "$CHECKS" | grep -c "pending\|queued\|in_progress" || true)

    if [ "$PENDING" -eq 0 ]; then
        echo "All checks completed."
        break
    fi

    echo "Waiting... ($i/20, ${PENDING} checks still running)"
done
```

### Collect All Feedback

After checks complete (or timeout):

```bash
# CI check results
gh pr checks "$PR_NUMBER" > "$ARTIFACTS_DIR/ci-checks.txt"

# PR comments (agent reviews, bot feedback)
gh api repos/{owner}/{repo}/pulls/$PR_NUMBER/comments --paginate > "$ARTIFACTS_DIR/pr-comments.json"

# PR review comments (review-level feedback)
gh api repos/{owner}/{repo}/pulls/$PR_NUMBER/reviews --paginate > "$ARTIFACTS_DIR/pr-reviews.json"

# Issue comments on the PR
gh pr view "$PR_NUMBER" --comments > "$ARTIFACTS_DIR/pr-discussion.txt"
```

### Assess Feedback

Read all collected feedback. Categorize:

```
IF all checks pass AND no review comments -> Skip to Phase 3 (clean PR)
IF any checks fail OR review comments exist -> Proceed to triage
```

### Triage Feedback

**THIS IS YOUR CORE WORK. Do not delegate triage.**

Parse all PR comments and failed checks into a findings list. For each finding, classify:

**Auto-fix (apply immediately):**
- CI failures with obvious fixes (lint errors, type errors, formatting)
- Agent review items marked as critical or security-related
- Clear, unambiguous single-fix issues (the reviewer told you exactly what to change)

**Conductor decides (apply without asking user):**
- High-severity items with clear fixes
- Easy improvements that don't change architecture
- Items that align with project conventions in AGENTS.md

**Present to user (uncertain items):**
- Architectural suggestions or trade-offs
- Items where the right fix is debatable
- Suggestions that would significantly change the implementation
- Anything the conductor isn't confident about

### Apply Fixes

For auto-fix and conductor-decided items:

```bash
# Apply fixes directly using Edit tool
# After all fixes:
git add <specific files>
git commit -m "$(cat <<'EOF'
fix: address PR feedback

{list of fixes applied}

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
git push
```

### Present Uncertain Items to User

**Exhaust rule (see `skills/_shared/bead-conventions.md`):** review feedback
that won't be acted on in this merge leaves as a typed bead, not a skipped
list item — `-t bug`/`-t investigation` with `--labels review-finding`, or
`-t decision --labels human-gate` (pre-staged memo) for taste/product forks
when running autonomously. Don't block the merge on non-blocking exhaust.
<!-- mirror: _shared/bead-conventions.md — edit there first -->

**If uncertain items remain:**

```
AskUserQuestion(
  questions: [{
    question: "Applied {N} fixes from PR feedback. {M} items need your decision:",
    header: "PR feedback",
    multiSelect: true,
    options: [
      { label: "Fix A: <title>", description: "{reviewer}: {file} — <one-line summary>" },
      { label: "Fix B: <title>", description: "{reviewer}: {file} — <one-line summary>" }
    ]
  }]
)
```

**If more than 4 items:** Split across multiple `AskUserQuestion` calls.

Apply user-approved fixes, commit, push.

### Re-poll (Short)

If fixes were pushed, CI/agents will re-run. Brief re-poll — 5 minutes max:

```bash
for i in $(seq 1 10); do
    sleep 30
    CHECKS=$(gh pr checks "$PR_NUMBER" 2>/dev/null)
    PENDING=$(echo "$CHECKS" | grep -c "pending\|queued\|in_progress" || true)
    FAILED=$(echo "$CHECKS" | grep -c "fail" || true)

    if [ "$PENDING" -eq 0 ]; then
        if [ "$FAILED" -gt 0 ]; then
            echo "WARNING: ${FAILED} checks still failing after fixes."
        else
            echo "All checks passing."
        fi
        break
    fi
done
```

**If checks still fail after fixes:** Present failures to user and ask whether to merge anyway or abort.

Mark ledger task 7 `completed`; `TaskUpdate` task 8 `in_progress`.

---

## Phase 3: Merge

### Confirm All Checks

```bash
gh pr checks "$PR_NUMBER"
```

**If any required checks are failing:**

```
AskUserQuestion(
  questions: [{
    question: "{N} required checks still failing. How to proceed?",
    header: "Checks",
    multiSelect: false,
    options: [
      { label: "Abort — fix first", description: "Don't merge. Address failures manually." },
      { label: "Merge anyway", description: "Override failing checks (not recommended)" }
    ]
  }]
)
```

### Merge

```bash
gh pr merge "$PR_NUMBER" --merge --delete-branch
```

Uses merge commit to preserve per-bead commit history.

### Switch to Main + Tag the Release

```bash
git checkout main
git pull
```

Tag the merge commit with the version that was bumped in Phase 0. Skip this step if the version was frozen/skipped (see Version Bump above).

```bash
# NEW_VERSION captured in Phase 0; if not in scope, re-read from package.json on main
NEW_VERSION=$(node -p "require('./package.json').version")
git tag "v$NEW_VERSION" -m "Release v$NEW_VERSION"
git push origin "v$NEW_VERSION"
```

### Verify

```bash
git log --oneline -5            # Confirm merge commit visible
git tag --points-at HEAD        # Confirm v$NEW_VERSION on the merge commit
git branch -d "$WAVE" 2>/dev/null || true   # Clean local branch (wave or hygiene/chore)
```

### Database migrations are a SEPARATE, human-approved push — not part of merge

If the branch includes a `supabase/migrations/*.sql` file, merging to main does **NOT**
apply it to production. The prod `db push` is a deliberate, human-approved, collision-aware
step (the `supabase` skill gates `db push` as ASK-USER-FIRST), run AFTER the local-validate
gate passed pre-merge (ac-implement Phase 1c). For apps on a **shared** Supabase project,
push collision-aware: `supabase migration fetch` → review the diff → `db push` → verify —
**never blind-repair** (multiple apps push to one prod). Surface the pending prod migration
in the merge summary so it isn't silently forgotten; do not claim the schema change "shipped"
until the push is done and verified.

**Apply-timing gate (expand/contract — `rule-migrations-expand-contract`).** Web deploys to
prod AT merge, so code that *depends* on a migration must not go live before its schema does:

- **EXPAND (additive) migration that merged code depends on:** it must be applied **before or
  at this merge**. If still unpushed — interactive: ask *"Branch depends on unpushed expand
  migration `<file>` — Push to prod now / Merge anyway (dependent code path is flag-gated OFF)
  / Hold the merge."* Headless: hold the merge and file a `human-gate` decision bead carrying
  those options (Exhaust Rule). Do not merge live-dependent code over an unpushed schema.
- **CONTRACT (drop/rename/narrow/NOT NULL-no-default):** never apply at merge. It merges as a
  *held* migration and is applied later via `ac-publish`'s migration gate, after old native
  builds age out. If a branch bundles contract DDL into an expand migration, split it first.

Mark ledger task 8 `completed`; `TaskUpdate` task 9 `in_progress`.

### Verify the Deploy Actually Shipped

If the project deploys on push to main (Vercel: `vercel.json` present or a known Vercel
project — simil8, cv-site, neometa-app, move-free-app, art-still-app marketing):

```bash
# Poll — a bare foreground `sleep 90` is BLOCKED by the harness; the sleep must sit in a loop.
for i in $(seq 1 12); do
    sleep 10
    vercel ls <project> 2>/dev/null | head -5 | command grep -qE '● (Ready|Error)' && break
done
vercel ls <project> 2>/dev/null | head -5   # latest deployment: ● Ready or ● Error?
```

- `● Error` → the merge did NOT reach production. Surface it loudly and investigate
  (run `next build` locally — missing deps on lazily-compiled routes are the classic
  cause). Do not close the session claiming "shipped."
- No Vercel project → skip silently.

> Why: a broken main build fails silently on Vercel — no alert, prod just keeps serving
> the last good build (simil8's prod was frozen ~447 days this way — full incident:
> `references/incidents.md`).

**Native (iOS) build — the same boundary, the same check.** If the app's merge to main ALSO
triggers a native build (Xcode Cloud archive on push, or a self-hosted-runner release lane),
verify it here too — it's the iOS twin of the Vercel check, because the build is *triggered by
the merge*. This is `ac-merge`'s job, NOT `ac-distribute`'s: merge proves the build was
**produced**; distribute proves it's **ready to submit** (its own preflight). The app's
`CORE/distribution.md` names a **HEAD-anchored, blocking** check command (BCA:
`pnpm archive:watch-head`). It MUST key on the merge commit — "the latest build SUCCEEDED" is
the silent-failure trap (a *stale prior* build passes while your commit never built). It blocks
until terminal with **two deadlines so an autonomous loop can't hang**: the archive must APPEAR
(else it never triggered — a silent stop: pending PLA / compute quota / SCM grant / disabled
workflow) and must COMPLETE (else assume failed).

- exit ≠ 0 → the merge did NOT produce a shippable build. Surface loudly; do NOT advance the
  pipeline to `ac-distribute` on a build that doesn't exist. The check prints which failure it
  is (never-triggered vs failed vs timed-out).
- **Produced ≠ uploaded.** The merge-triggered build may be an archive-only HEALTH CHECK that
  never reaches TestFlight (BCA's Xcode Cloud archive is exactly this). CORE/distribution.md
  must say which it is; when it's health-check-only, report "archive health-check green — no
  TestFlight build produced; ship via the app's release lane" instead of implying a shippable
  build exists — a wrong wording here caused the BCA 2026-07-02 incident (`references/incidents.md`).
- No native-build-on-merge → skip silently.

### Confirm the main-branch CI run — silence ≠ pass

The merge triggers the repo's CI (e.g. `Quality Gate`) on `main`. On a **single
self-hosted runner** that queue can sit hours behind a dependabot backlog — so "no failure
seen" is NOT "passed": the loop can land its last commits with **zero CI confirmation** and
only the fix-forward convention as cover (2026-07-03 incident: main Quality Gate queued 2+
hrs behind dependabot; the session closed blind). Never treat poll-timeout silence as green.

```bash
# The run triggered by THE MERGE COMMIT (not "latest" — a stale prior run is the trap)
MERGE_SHA=$(git rev-parse HEAD)
RUN_JSON=$(gh run list --branch main --commit "$MERGE_SHA" \
  --json databaseId,status,conclusion,url,createdAt --limit 5 2>/dev/null)
echo "$RUN_JSON"                       # RECORD the run ID + URL in the report — always
```

- Terminal + green → report the run URL as the confirmation.
- Terminal + failed → surface loudly; fix-forward or file a bead. Do not claim shipped.
- **Still `queued`/`in_progress`** → compute elapsed from `createdAt` (per
  `ci-in-progress-not-stuck-compute-elapsed` — status alone is not "stuck"). If a **main**
  run is still pending **>1hr**, do NOT close silently: surface it in the report AND
  `slack-send` the run URL so a human can watch it land. The merge is done; the *proof* is
  outstanding — say so explicitly rather than implying green.

Mark ledger task 9 `completed`; `TaskUpdate` task 10 `in_progress`.

---

## Phase 4: Report + Handoff

### Report

```markdown
## Branch Merged: {branch name}

**PR:** {URL}
**Branch:** {branch} → main
**Beads completed:** {count}
**Commits:** {count}
**Files changed:** {count}

### PR Feedback

- **CI checks:** {all passed | N fixed}
- **Agent review findings:** {count} ({auto-fixed} auto-fixed, {user-decided} user-decided, {skipped} skipped)

### What Shipped

{1-3 bullet summary of what merged — feature or chore/hygiene fixes}
```

### Next Step

```
AskUserQuestion(
  questions: [{
    question: "Branch merged to main. What's next?",
    header: "Next step",
    multiSelect: false,
    options: [
      { label: "Start new feature (Recommended)", description: "Run /ac-plan-init — begin planning the next wave" },
      { label: "Hygiene pass", description: "Run /ac-hygiene — codebase health check after the merge" },
      { label: "Done", description: "Shipped — nothing more to do" }
    ]
  }]
)
```

(Skipped entirely when this delegation prompt says so — e.g. `ac-loop` and `ac-hygiene` both say "no 'what's next?' after merge".)

### Finalize

Release any file reservations still held and self-deregister the Phase-0 identity per
`_shared/agent-mail.md` § Release (bead ac-1oq). Then mark the run ledger's final task
`completed`. Then clean up — but only on the clean "Done"
path. If the user chose a follow-up (new feature / hygiene) or the Phase-3 deploy-verify
flagged an error, **leave `$ARTIFACTS_DIR`** — the report points at it for investigation, and
`ac-land`'s teardown sweeps `/tmp/wave-merge-*` later anyway. Don't delete state a follow-up
still needs.

```bash
rm -rf "$ARTIFACTS_DIR"   # ONLY on the clean "Done" path
```

---

## Remember

<!-- diet: restated bullets deleted (ac-gcj.5 Remember diet, Craig ruling 2) — cut bullets have live body twins (grep-verified); Remember-only rules survive below -->

- **Wave = release unit, not feature unit** — a wave can carry mixed work from multiple epics; the PR title derives from version + content summary, the branch name (`wave/NNN` / `hygiene/YYYYMMDD`) is opaque
- **Merge commit preserves per-bead history** — don't squash; the flywheel's atomic commits are valuable
- **Bot-agnostic** — works with any CI/agent setup (Claude Code Review, CodeRabbit, Vercel, custom)

---

_Universal merge: create PR, triage feedback, fix, ship — wave or chore/hygiene. For session closure: `/ac-land`. For next feature: `/ac-plan-init`._
