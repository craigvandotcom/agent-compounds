---
name: ac-merge
description: Merge a wave branch to main — PR creation, CI/agent feedback triage, version + build bump, land. Triggers: 'merge the wave', 'wave merge', 'ship the branch', 'merge to main'.
---


**You are the conductor closing a feature wave.** Create the PR, wait for CI and agent feedback, triage and fix issues, merge when clean.

Run after both `/ac-land` and `/ac-review` have completed for the wave (their order is flexible). This is per-wave (not per-session like bead-land).

---

## I/O Contract

|                  |                                                                                            |
| ---------------- | ------------------------------------------------------------------------------------------ |
| **Input**        | Wave branch with all beads complete, pushed (post `/ac-land` and `/ac-review`)           |
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
ARTIFACTS_DIR=/tmp/wave-merge-$(date +%Y%m%d-%H%M%S)
mkdir -p "$ARTIFACTS_DIR"
```

### Verify Wave Branch

```bash
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"
```

**If not on a `wave/*` branch:** STOP. "You must be on a wave branch. Current: {CURRENT_BRANCH}"

### Verify All Beads Closed

```bash
br list --json
```

Check for any open/in-progress beads. **If open beads remain:**

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

### Quality Gate

```bash
# Run project quality gate (see AGENTS.md > Project Commands > Quality gate)
```

**If any fail:** Fix before proceeding. Do not create a PR with failing local checks.

### Rebase on Main

```bash
git fetch origin main
git rebase origin/main
```

**If conflicts:** Resolve them, run quality gate again, then continue.

### Native Sim QA Smoke Gate (conditional)

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
br list --json | jq '[.[] | select(.labels // [] | index("qa-blocker")) | select(.status != "closed")] | length'
```

Open `qa-blocker` beads are unresolved user-facing breaks filed by QA runs —
treat exactly like failing required checks: STOP and ask (fix first vs merge
anyway with explicit override). The two valid resolutions: fix the bug, or —
if the behavior is intended — update the journey doc and close the bead.

### Version Bump

Scan the wave's commits for conventional-commit prefixes and suggest the next semver bump. The version-bump commit lands on the wave branch BEFORE the push, so the PR shows it as part of the merge unit.

```bash
BASE_BRANCH=main
COMMIT_LOG=$(git log "$BASE_BRANCH"..HEAD --format="%s%n%b")

# Detect any breaking change footer or `!:` in subject
if printf '%s' "$COMMIT_LOG" | grep -qE "^[a-zA-Z]+(\([^)]+\))?!:|BREAKING[ -]CHANGE"; then
    SUGGESTED_BUMP=major
elif printf '%s' "$COMMIT_LOG" | grep -qE "^feat(\([^)]+\))?:"; then
    SUGGESTED_BUMP=minor
else
    SUGGESTED_BUMP=patch
fi

CURRENT_VERSION=$(node -p "require('./package.json').version")
echo "Current version: $CURRENT_VERSION → suggested bump: $SUGGESTED_BUMP"
```

Confirm with the user (suggested bump as the recommended option):

```
AskUserQuestion(
  questions: [{
    question: "Wave commits suggest {SUGGESTED_BUMP} bump from v{CURRENT_VERSION}. Apply?",
    header: "Version bump",
    multiSelect: false,
    options: [
      { label: "{SUGGESTED_BUMP} (Recommended)", description: "Derived from commit prefixes (feat→minor, fix-only→patch, !→major)" },
      { label: "patch", description: "Force patch — bug fixes / non-feature changes only" },
      { label: "minor", description: "Force minor — new features (backward compatible)" },
      { label: "major", description: "Force major — breaking changes" },
      { label: "skip — no bump this wave", description: "Don't touch package.json (rare; use when shipping a doc-only or experiment-only wave)" }
    ]
  }]
)
```

Apply the chosen bump (unless skipped):

```bash
pnpm version "$CHOSEN_BUMP" --no-git-tag-version
NEW_VERSION=$(node -p "require('./package.json').version")
```

#### Propagate the version to native build surfaces

`package.json` alone doesn't reach the App Store binary. Propagate to the native build surfaces (iOS pbxproj `MARKETING_VERSION` ×4 + monotonic `CURRENT_PROJECT_VERSION`; Android `build.gradle` when added; the JS `NEXT_PUBLIC_APP_VERSION` is auto-derived, no script) following **`references/version-bump.md`**. Web-only projects skip this.

#### Commit the bump

```bash
git add package.json pnpm-lock.yaml ios/App/App.xcodeproj/project.pbxproj 2>/dev/null
git commit -m "chore(release): v${NEW_VERSION} (iOS build ${NEW_BUILD})"
```

The tag is created on the merge commit in Phase 3 (after merge to main), not here — that way `v$NEW_VERSION` points at the actual shipped state.

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

Save as `WAIT_FOR_FEEDBACK` (true/false).

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

Save the PR number and URL.

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

### Cleanup

```bash
rm -rf "$ARTIFACTS_DIR"
```

---

## Remember

- **This is per-wave, not per-session** — run once when all beads are done, not after each bead-work session
- **Wave = release unit, not feature unit** — a wave can carry mixed work from multiple epics. The PR title is derived from version + content summary; the branch name (`wave/NNN`) is opaque.
- **Version bump scans commits** — feat→minor, fix-only→patch, `!:` or BREAKING CHANGE→major. User confirms before the bump commit lands; tag is created on the merge commit after merge.
- **Both pre-merge gates required** — `ac-land` (session closure) and `ac-review` (branch review) must both complete before running this; their order relative to each other is flexible.
- **Merge commit preserves per-bead history** — don't squash, the flywheel's atomic commits are valuable
- **The wait-triage-fix loop is the core value** — PR creation is trivial, feedback handling is not
- **Bot-agnostic** — works with any CI/agent setup (Claude Code Review, CodeRabbit, Vercel, custom)
- **Sim smoke gate is conditional** — only for native-touching waves on a Mac; never blocks from Linux, but the report must flag the skipped gate
- **Auto-fix obvious issues, ask about the rest** — same triage philosophy as the review commands
- **Re-poll is short** — 5 minutes max after pushing fixes, don't loop forever
- **Abort is always an option** — if checks keep failing, let the user decide

---

_Wave merge: create PR, triage feedback, fix, ship. For session closure: `/ac-land`. For next feature: `/ac-plan-init`._
