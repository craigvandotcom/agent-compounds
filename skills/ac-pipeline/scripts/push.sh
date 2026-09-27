#!/usr/bin/env bash
#
# push.sh — the one push step that gates the whole committed tree (ac-ftfz.7).
#
# WHY: commit and push used to be one act — every commit in a batch pushed immediately,
# so the whole-tree verdict arrived only after origin already had it, and a red test once
# reached origin before anyone found it. This is the other layer of the two-layer split:
# commit often, with fast scoped checks (swarm-commit.sh); push once per batch through
# ONE whole-tree step that refuses a dirty tree, brings origin's history in without
# discarding a single existing commit, runs the repo's own whole-tree checks, pushes only
# once they are clean, then dispatches the full quality gate against the SHA just pushed.
#
# THE STEPS, in order:
#   1. REFUSE while any tracked file is uncommitted — naming the file. A partial push of a
#      half-finished tree defeats the whole point of a whole-tree gate.
#   2. Bring origin's history in with a MERGE. History already pushed by anyone else is
#      never discarded or replayed onto a new base — a merge either fast-forwards or adds
#      one merge commit; either way every existing commit keeps its own identity.
#   3. Run this repo's own whole-tree checks (./lint.sh, scripts/run-all-proofs.sh — each
#      run only when present, so this script stays usable in a repo that has neither yet).
#      A failure pushes nothing.
#   4. Push. A rejected push is reported and left for a human to reconcile by hand — this
#      script never re-tries with a history-discarding remedy of its own.
#   5. Dispatch the full quality gate (quality-gate.yml's `reason=prove` leg, pinned to the
#      SHA just pushed — never the OTHER reason that workflow defines, the Tier-1
#      affected-only leg, which would silently prove the wrong range) and print its run URL.
#
# Usage: push.sh [--branch <name>] [--remote <name>] [--no-dispatch]
#   --branch       branch to push (default: main)
#   --remote       remote to push to (default: origin)
#   --no-dispatch  push only; skip the quality-gate dispatch (used by push.test.sh, which
#                  has no real GitHub remote to dispatch against)
#
# Exit codes:
#   0  pushed (dispatch attempted too, unless --no-dispatch or the workflow file is absent)
#   1  REFUSED — a whole-tree check failed, a merge left conflicts, or the push itself was
#      rejected: nothing pushed. NEXT: fix-forward — fix the named failure and re-run; this
#      is never a blind retry.
#   2  usage, or NOT-GATED — this script could not verify (not inside a git repo, etc.)
#   3  REFUSED [dirty-tree] — a tracked file is uncommitted, named on stderr
#
set -uo pipefail

BRANCH="main"
REMOTE="origin"
DISPATCH=1

while [ $# -gt 0 ]; do
  case "$1" in
    --branch)      BRANCH="${2:-}"; shift 2 ;;
    --remote)      REMOTE="${2:-}"; shift 2 ;;
    --no-dispatch) DISPATCH=0; shift ;;
    -h|--help)     sed -n '2,45p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *)             echo "push.sh: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) \
  || { echo "NOT-GATED: not inside a git repository" >&2; exit 2; }
cd "$ROOT" || { echo "NOT-GATED: cannot enter repo root '$ROOT'" >&2; exit 2; }

# --- 1. REFUSE a dirty tree, naming the file --------------------------------------------
# Untracked files owe nothing to a push gate (the same axis touchers.sh already reads for
# a Delivers path): only TRACKED, uncommitted changes block it.
DIRTY=$(git status --porcelain --untracked-files=no 2>/dev/null)
if [ -n "$DIRTY" ]; then
  echo "REFUSED [dirty-tree]: tracked source is not fully committed — push gates the WHOLE tree, never a partial one. Uncommitted:" >&2
  echo "$DIRTY" | sed 's/^/  /' >&2
  exit 3
fi

# --- 2. bring origin's history in — a merge, always; a rewrite of history, never --------
git fetch "$REMOTE" "$BRANCH" >/dev/null 2>&1 \
  || echo "push.sh: warn — fetch failed; comparing against the last-known $REMOTE/$BRANCH" >&2
LOCAL_SHA=$(git rev-parse "$BRANCH" 2>/dev/null)
REMOTE_SHA=$(git rev-parse "$REMOTE/$BRANCH" 2>/dev/null || true)
if [ -n "$REMOTE_SHA" ] && [ "$LOCAL_SHA" != "$REMOTE_SHA" ] \
   && ! git merge-base --is-ancestor "$REMOTE_SHA" "$LOCAL_SHA" 2>/dev/null; then
  echo "push.sh: $REMOTE/$BRANCH has commits this branch does not — bringing them in with a merge (every existing commit keeps its own identity)"
  if ! git merge --no-edit "$REMOTE/$BRANCH"; then
    echo "REFUSED [merge-conflict]: bringing in $REMOTE/$BRANCH left conflicts; resolve them by hand, then re-run push.sh. NEXT: fix-forward — this is a fix, never a retry-as-is." >&2
    exit 1
  fi
fi

# --- 3. this repo's own whole-tree checks — only the ones that exist -------------------
CHECKS_FAILED=0
if [ -x ./lint.sh ]; then
  echo "push.sh: running ./lint.sh"
  ./lint.sh || CHECKS_FAILED=1
fi
if [ "$CHECKS_FAILED" -eq 0 ] && [ -x scripts/run-all-proofs.sh ]; then
  echo "push.sh: running scripts/run-all-proofs.sh"
  scripts/run-all-proofs.sh || CHECKS_FAILED=1
fi

if [ "$CHECKS_FAILED" -ne 0 ]; then
  echo "REFUSED [red-check]: a whole-tree check failed; nothing was pushed. NEXT: fix-forward — fix the failure and commit it, then re-run push.sh." >&2
  exit 1
fi

# --- 4. push -----------------------------------------------------------------------------
if ! git push "$REMOTE" "$BRANCH"; then
  echo "REFUSED [push-rejected]: git push to $REMOTE/$BRANCH was rejected; the commit is safe locally. NEXT: fix-forward — reconcile by hand (never discard history), then re-run push.sh." >&2
  exit 1
fi

SHA=$(git rev-parse HEAD)
echo "push.sh: pushed $SHA to $REMOTE/$BRANCH"

# --- 5. dispatch the full quality gate against the SHA just pushed ----------------------
if [ "$DISPATCH" -eq 0 ]; then
  exit 0
fi
if ! command -v gh >/dev/null 2>&1; then
  echo "push.sh: NOT-GATED — the gh CLI is unavailable; the full quality gate could not be dispatched for $SHA" >&2
  exit 0
fi
if [ ! -f .github/workflows/quality-gate.yml ]; then
  echo "push.sh: quality-gate.yml absent in this repo; nothing dispatched"
  exit 0
fi

if gh workflow run quality-gate.yml -f reason=prove -f ref="$SHA"; then
  sleep 3
  RUN_URL=$(gh run list --workflow=quality-gate.yml --limit 1 --json url --jq '.[0].url' 2>/dev/null || true)
  if [ -n "$RUN_URL" ]; then
    echo "push.sh: dispatched the full quality gate (reason=prove, ref=$SHA): $RUN_URL"
  else
    echo "push.sh: dispatched the full quality gate (reason=prove, ref=$SHA); run URL not yet available — check: gh run list --workflow=quality-gate.yml"
  fi
else
  echo "push.sh: NOT-GATED — dispatching the full quality gate (reason=prove) failed for $SHA; the push itself already succeeded" >&2
fi
exit 0
