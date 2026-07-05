---
name: ac-merge
description: 'Merge a wave branch to main — PR creation, CI/agent feedback triage, version + build bump, land. Triggers: ''merge the wave'', ''wave merge'', ''ship the branch'', ''merge to main''.'
---


**You are the conductor closing a feature wave.** Create the PR, wait for CI and agent feedback, triage and fix issues, merge when clean.

Run after `/ac-review` has completed for the wave — review is the sole pre-merge gate. `/ac-land` runs AFTER this merge, as session closure. This is per-wave (not per-session like bead-land).

---

## I/O Contract

|                  |                                                                                            |
| ---------------- | ------------------------------------------------------------------------------------------ |
| **Input**        | Wave branch with all beads complete, pushed, post `/ac-review` (the sole pre-merge gate)  |
| **Output**       | PR merged to main, wave branch deleted, feature shipped                                    |
| **Artifacts**    | PR on GitHub, feedback triage in `$ARTIFACTS_DIR/`                                         |
| **Verification** | All CI checks green, PR merged, on main branch                                            |

## Prerequisites

- On a `wave/*` branch
- All beads closed (`br list --json` — none open)
- Branch pushed and up-to-date with remote
- `gh` CLI authenticated

---

## Phase 0: Pre-flight

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
WAVE=$(git branch --show-current)
# Stable per-wave artifacts dir → a session dropped during a 10-min CI poll finds the SAME dir
# on resume (a fresh timestamped dir would orphan the prior state). ac-land sweeps /tmp/wave-merge-*.
ARTIFACTS_DIR="/tmp/wave-merge-${WAVE//\//-}"
mkdir -p "$ARTIFACTS_DIR"
STATE="$ARTIFACTS_DIR/state.env"      # durable resume anchor: PR_NUMBER, NEW_VERSION, WAIT_FOR_FEEDBACK
[ -f "$STATE" ] && . "$STATE"         # on resume, reload instead of re-asking
```

### Declare the Run Ledger

ac-merge spans 10-min CI polls where a session can drop. Declare a run ledger so a resumed
run re-enters at the right phase instead of re-polling from scratch or re-asking PR#/version:

```
TaskCreate (one per phase):
  1. Pre-flight — branch, beads, QA, rebase, version bump   in_progress
  2. Create PR                                               pending
  3. Wait for PR feedback + triage                           pending
  4. Merge + tag + verify deploy shipped                     pending
  5. Report + finalize                                       pending
```

`TaskUpdate` at each phase boundary. As you capture `PR_NUMBER`, `NEW_VERSION`, and
`WAIT_FOR_FEEDBACK`, append them to `$STATE` (e.g. `echo "PR_NUMBER=$PR_NUMBER" >> "$STATE"`)
so a dropped session reloads them on resume. The ledger tracks the RUN; beads stay the work atom.

### Verify Wave Branch

```bash
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"
```

**If not on a `wave/*` branch:** STOP. "You must be on a wave branch. Current: {CURRENT_BRANCH}"

### Verify Review Verdict (standalone-mode gate)

`ac-loop` already enforces "review before merge" as part of its own chain (it reads
`VERDICT:` straight from `ac-review`'s Phase 8 output and only chains to merge on
`APPROVED`). This step closes the hole where `/ac-merge` is invoked **standalone** by a
human, with no loop in front of it to guarantee review actually ran first — read the
verdict mechanically off disk instead of trusting memory of "I think review passed."

```bash
LATEST_REVIEW=$(ls -t .claude/reviews/*.md 2>/dev/null | head -1)
```

- **Missing** (no file in `.claude/reviews/`) → STOP. "No review found in
  `.claude/reviews/` — run `/ac-review` on this branch before merging."
- **Stale** (the review file's mtime/commit predates the branch's last non-review
  commit — i.e. code changed after the review ran):
  ```bash
  git log -1 --format=%ct -- . ':!.claude/reviews' > /tmp/last-code-commit-ts
  ```
  compare against `LATEST_REVIEW`'s modification time → if the last code commit is
  newer, STOP. "Latest review (`$LATEST_REVIEW`) predates the newest code commit on
  this branch — re-run `/ac-review`."
- **Present and fresh but not `VERDICT: APPROVED`** (e.g. `VERDICT: NEEDS_DECISION`, or
  no `VERDICT:` line at all):
  ```bash
  grep -m1 "^\*\*VERDICT:\*\*\|^VERDICT:" "$LATEST_REVIEW"
  ```
  → STOP. Surface the verdict line (or "no VERDICT line found") and the review file
  path; do not proceed to the Quality Gate.
- **`VERDICT: APPROVED`** and fresher than the last code commit → proceed.

### Verify All Beads Closed

```bash
br list --json
```

Beads labeled `post-merge` are **excluded** from this gate — they're deliberately
un-closeable until after the code they track has shipped and gone live (prod
verification, follow-up monitoring, a check that only makes sense once the merge
commit is running in production). Blocking the merge on them would be circular: the
bead can't close until the merge happens, so it can never close. Instead of blocking,
they're carried forward as known tails, listed explicitly in the PR body (see
`references/pr-body-template.md` § Known post-merge tails) so they're never silently
dropped — the gate below narrows to beads that genuinely should be closed pre-merge:

```bash
br list --json --limit 1000 | jq '[.issues[]
  | select(.status != "closed")
  | select((.labels // []) | index("post-merge") | not)]'
```

Check for any open/in-progress beads in that filtered set. **If open beads remain:**

```
AskUserQuestion(
  questions: [{
    question: "{N} beads still open. Merge anyway?",
    header: "Open beads",
    multiSelect: false,
    options: [
      { label: "Stop — close beads first", description: "Run /ac-implement to finish remaining beads" },
      { label: "Merge anyway", description: "Open beads will remain for a future wave" }
    ]
  }]
)
```

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
# Run project quality gate (see AGENTS.md > Project Commands > Quality gate)
```

**If any fail:** Fix before proceeding. Do not create a PR with failing local checks.

### QA Smoke Gate (conditional — safety net)

This is the **post-rebase smoke net**: it re-proves the exact state that merges, using
the **same classifier as `_shared/verification-gate.md`** (the diff-class greps below are
that gate's `native` / `webui` classes). The Verify stage in `ac-pipeline`/`ac-loop`
already ran the gate-selected passes at full depth pre-land; this net re-checks at
**smoke** depth because a rebase can change what merges. If a fresh gate-selected PASS
exists for the current `HEAD` SHA, note-and-skip; otherwise run the smoke pass below.

> Selection/depth logic is single-sourced in `_shared/verification-gate.md` — keep these
> greps in sync with it (or, when editing, lift the classification there and reference it).
> Note: this net covers the **QA twins** only; `ac-ui-polish` is a Verify-stage pass, not
> re-run at merge.

Hybrid/native apps only. Runs the post-rebase state — the thing that actually merges.
Three conditions, all must hold; otherwise skip silently:

```bash
# 1. Project has a native app at all
[ -d ios ] || SKIP_SIM_SMOKE=1

# 2. The wave touched native-adjacent surface
git diff main...HEAD --name-only | grep -qE '^ios/|capacitor\.config|cap-build|@capacitor' \
  || git diff main...HEAD -- package.json | grep -qE '@capacitor|capacitor' \
  || SKIP_SIM_SMOKE=1

# 3. We're on a Mac (simulators need Xcode)
[ "$(uname)" = "Darwin" ] || SKIP_SIM_SMOKE=mac-needed
```

- **All hold** → load **`ac-qa-device/SKILL.md`** and run a **smoke** pass
  (build via the app's own build command, launch, auth, primary journey —
  facts in the app's `CORE/journeys/native.md`). ~2–3 min on a warm sim.
- **Smoke FAILS** → STOP before creating the PR. Report the `QA_VALIDATION`
  block (`platform: ios-simulator`) and ask: abort (fix first) vs merge anyway
  (not recommended).
- **`SKIP_SIM_SMOKE=mac-needed`** (native-touching wave, but not on a Mac) →
  do NOT block the merge; surface a loud note in the Phase 4 report:
  "native-touching wave merged without device QA — run `ac-qa-device` smoke
  from a Mac session before the next TestFlight push."

**Web-shell smoke (the browser twin, any OS):** if the wave touched web UI
(`git diff main...HEAD --name-only | grep -qE '\.(tsx|jsx|css)$|app/|components/'`)
load **`ac-qa-browser/SKILL.md`** and run a **smoke** pass against the dev server.
A FAIL reports the `QA_VALIDATION` block (`platform: browser-local`) and STOPs the
same way. This branch needs no Mac, so it has no `mac-needed` escape.

The user can also trigger a smoke/full pass on either twin manually at any time,
independent of this gate ("run a device QA smoke", "run a browser QA smoke").

**QA-blocker check (beads projects, runs regardless of platform):**

```bash
br list --json --limit 1000 | jq '[.issues[] | select(.labels // [] | index("qa-blocker")) | select(.status != "closed")] | length'
```

Open `qa-blocker` beads are unresolved user-facing breaks filed by QA runs —
treat exactly like failing required checks: STOP and ask (fix first vs merge
anyway with explicit override). The two valid resolutions: fix the bug, or —
if the behavior is intended — update the journey doc and close the bead.

### Version Bump

**The default bump is ALWAYS `patch`.** These app versions are a build / marketing
number, not a published-library API contract — so a feature wave does NOT auto-escalate
to minor. `minor` and `major` are **deliberate, explicitly-chosen** bumps that a human
directs for a milestone or an announced breaking release; they are NEVER auto-derived from
commit prefixes. The version-bump commit lands on the wave branch BEFORE the push, so the
PR shows it as part of the merge unit.

```bash
BASE_BRANCH=main
COMMIT_LOG=$(git log "$BASE_BRANCH"..HEAD --format="%s%n%b")

# DEFAULT IS PATCH for every wave — features included.
SUGGESTED_BUMP=patch

# Signal only: surface a breaking-change marker so a human can CHOOSE major.
# Do NOT auto-escalate the default off patch.
if printf '%s' "$COMMIT_LOG" | grep -qE "^[a-zA-Z]+(\([^)]+\))?!:|BREAKING[ -]CHANGE"; then
    echo "NOTE: wave carries a breaking-change marker — pick 'major' explicitly only if truly warranted."
fi

CURRENT_VERSION=$(node -p "require('./package.json').version")
echo "Current version: $CURRENT_VERSION → default bump: patch"
```

**Autonomous / loop mode (ac-loop): always take `patch`** — never auto-select minor/major
without an explicit human instruction passed in the loop directive.

Confirm with the user (patch is the recommended default):

```
AskUserQuestion(
  questions: [{
    question: "Bump v{CURRENT_VERSION} → patch (default)? Choose minor/major only for a deliberate milestone.",
    header: "Version bump",
    multiSelect: false,
    options: [
      { label: "patch (Recommended)", description: "Default for EVERY wave — fixes and features alike. App version is a build number, not a library API contract." },
      { label: "minor", description: "Explicit opt-in only — a deliberate feature-milestone release you are choosing now." },
      { label: "major", description: "Explicit opt-in only — a deliberate, announced breaking/milestone release." },
      { label: "skip — no bump this wave", description: "Don't touch package.json (rare; doc-only or experiment-only wave)." }
    ]
  }]
)
```

Apply the chosen bump (unless skipped):

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

### Push

```bash
git push --force-with-lease
```

### Ask About CI/Agent Reviews

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

Save as `WAIT_FOR_FEEDBACK` (true/false), and persist for resume: `echo "WAIT_FOR_FEEDBACK=$WAIT_FOR_FEEDBACK" >> "$STATE"`. Mark ledger task 1 `completed`.

---

## Phase 1: Create PR

### Gather PR Context

```bash
# Bead summary
br list --json > "$ARTIFACTS_DIR/beads.json"

# Commit history on this wave
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

### Create PR

The wave branch name (e.g. `wave/042`) is just an identifier — it doesn't describe content. Derive the PR title from the version bump + a 4-7 word summary of what actually changed, scanned from commit subjects + the bead list.

```bash
gh pr create --title "v{NEW_VERSION}: {short summary derived from commits}" --body "$(cat <<'EOF'
{constructed PR body — include the version bump as the first line}
EOF
)"
```

Save the PR number and URL, and persist for resume: `echo "PR_NUMBER=$PR_NUMBER" >> "$STATE"`. Mark ledger task 2 `completed`.

**If `WAIT_FOR_FEEDBACK` is false:** Skip to Phase 3 (Merge).

---

## Phase 2: Wait for PR Feedback

### Poll for Checks and Comments

Wait for CI checks and agent reviews to complete. Poll every 30 seconds, timeout after 10 minutes.

```bash
PR_NUMBER={from Phase 1}

# Poll loop (up to 10 minutes)
for i in $(seq 1 20); do
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

Tag the merge commit with the version that was bumped in Phase 0. Skip this step if the user chose "skip — no bump this wave".

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
git branch -d "$WAVE" 2>/dev/null || true   # Clean local wave branch
```

### Database migrations are a SEPARATE, human-approved push — not part of merge

If the wave includes a `supabase/migrations/*.sql` file, merging to main does **NOT**
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
  at this merge**. If still unpushed, ask (headless loop → Slack buttons): *"Wave depends on
  unpushed expand migration `<file>` — Push to prod now / Merge anyway (dependent code path is
  flag-gated OFF) / Hold the wave."* Do not merge live-dependent code over an unpushed schema.
- **CONTRACT (drop/rename/narrow/NOT NULL-no-default):** never apply at merge. It merges as a
  *held* migration and is applied later via `ac-publish`'s migration gate, after old native
  builds age out. If a wave bundles contract DDL into an expand migration, split it first.

### Verify the Deploy Actually Shipped

If the project deploys on push to main (Vercel: `vercel.json` present or a known Vercel
project — simil8, cv-site, neometa-app, move-free-app, art-still-app marketing):

```bash
sleep 90   # give the build a head start
vercel ls <project> 2>/dev/null | head -5   # latest deployment: ● Ready or ● Error?
```

- `● Error` → the merge did NOT reach production. Surface it loudly and investigate
  (run `next build` locally — missing deps on lazily-compiled routes are the classic
  cause). Do not close the session claiming "shipped."
- No Vercel project → skip silently.

> Why: a broken main build fails silently on Vercel — prod just keeps serving the last
> good build, with no alert. simil8's prod was frozen for ~447 days this way
> (react-virtuoso never added to package.json; every build since March 2025 failed;
> nobody knew). Evidence: simil8/memory/auto/simil8-vercel-production-frontend.md.

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
  build exists (the wording that cost BCA an evening, 2026-07-02).
- No native-build-on-merge → skip silently.

---

## Phase 4: Report + Handoff

### Report

```markdown
## Wave Merged: {wave name}

**PR:** {URL}
**Branch:** wave/{name} → main
**Beads completed:** {count}
**Commits:** {count}
**Files changed:** {count}

### PR Feedback

- **CI checks:** {all passed | N fixed}
- **Agent review findings:** {count} ({auto-fixed} auto-fixed, {user-decided} user-decided, {skipped} skipped)

### What Shipped

{1-3 bullet summary of the feature}
```

### Next Step

```
AskUserQuestion(
  questions: [{
    question: "Wave merged to main. What's next?",
    header: "Next step",
    multiSelect: false,
    options: [
      { label: "Start new feature (Recommended)", description: "Run /ac-plan-init — begin planning the next wave" },
      { label: "Hygiene pass", description: "Run /ac-hygiene — codebase health check after the merge" },
      { label: "Done", description: "Feature shipped — nothing more to do" }
    ]
  }]
)
```

### Finalize

Mark the run ledger's final task `completed`. Then clean up — but only on the clean "Done"
path. If the user chose a follow-up (new feature / hygiene) or the Phase-3 deploy-verify
flagged an error, **leave `$ARTIFACTS_DIR`** — the report points at it for investigation, and
`ac-land`'s teardown sweeps `/tmp/wave-merge-*` later anyway. Don't delete state a follow-up
still needs.

```bash
rm -rf "$ARTIFACTS_DIR"   # ONLY on the clean "Done" path
```

---

## Remember

- **This is per-wave, not per-session** — run once when all beads are done, not after each bead-work session
- **Wave = release unit, not feature unit** — a wave can carry mixed work from multiple epics. The PR title is derived from version + content summary; the branch name (`wave/NNN`) is opaque.
- **The default bump is ALWAYS `patch`** — minor/major are explicit, deliberate human choices, never derived from commit prefixes. User confirms before the bump commit lands; tag is created on the merge commit after merge.
- **`ac-review` is the sole pre-merge gate** — branch review must complete before running this. `ac-land` is NOT a pre-merge gate; it runs after this merge as session closure.
- **Merge commit preserves per-bead history** — don't squash, the flywheel's atomic commits are valuable
- **The wait-triage-fix loop is the core value** — PR creation is trivial, feedback handling is not
- **Bot-agnostic** — works with any CI/agent setup (Claude Code Review, CodeRabbit, Vercel, custom)
- **Sim smoke gate is conditional** — only for native-touching waves on a Mac; never blocks from Linux, but the report must flag the skipped gate
- **Auto-fix obvious issues, ask about the rest** — same triage philosophy as the review commands
- **Re-poll is short** — 5 minutes max after pushing fixes, don't loop forever
- **Abort is always an option** — if checks keep failing, let the user decide

---

_Wave merge: create PR, triage feedback, fix, ship. For session closure: `/ac-land`. For next feature: `/ac-plan-init`._
