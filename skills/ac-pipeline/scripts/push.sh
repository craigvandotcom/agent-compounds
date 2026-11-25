#!/usr/bin/env bash
#
# push.sh — the one push step that gates the whole committed tree (ac-ftfz.7).
#
# WHY: commit and push used to be one act — every commit in a batch pushed immediately,
# so the whole-tree verdict arrived only after origin already had it, and a red test once
# reached origin before anyone found it. This is the other layer of the two-layer split:
# commit often, with fast scoped checks (swarm-commit.sh); push once per batch through
# ONE whole-tree step that checks exactly the commits it pushes, brings origin's history in
# without discarding a single existing commit, runs the repo's own whole-tree checks, pushes
# only once they are clean.
#
# THE STEPS, in order:
#   1. NOTE any tracked file that is uncommitted — it is never pushed, and no longer blocks
#      the push. The whole-tree checks need a tree that IS the commits being pushed, so when
#      the working tree is dirty step 3 runs them in a clean `git worktree` export of HEAD
#      (removed afterwards) instead of in the shared checkout. A dirty file that an unpushed
#      commit also touches is named in the output; the commit is pushed as committed.
#   2. Bring origin's history in with a MERGE. History already pushed by anyone else is
#      never discarded or replayed onto a new base — a merge either fast-forwards or adds
#      one merge commit; either way every existing commit keeps its own identity.
#   3. Run this repo's own whole-tree checks (./lint.sh, scripts/run-all-proofs.sh — each
#      run only when present, so this script stays usable in a repo that has neither yet)
#      against the committed tree: in place when the tree is clean, in the clean export when
#      it is dirty. A failure pushes nothing.
#   4. Push. A rejected push is reported and left for a human to reconcile by hand — this
#      script never re-tries with a history-discarding remedy of its own.
#
# NO DISPATCH HERE: the full quality-gate proof (quality-gate.yml's `reason=prove` leg)
# is dispatched exactly once, at publish, by ac-publish's prove step (bd-fugib.8). Dispatching it per
# push burned ~25 minutes of self-hosted runner on every batch commit for a verdict
# the prove step re-checks for freshness anyway.
#
# CHECKS-ONLY MODE (--check-only): a pre-push hook calls push.sh this way. Steps 1 and 3
# run (dirty-tree note, whole-tree checks); no fetch, no merge, no push. The outer
# `git push` that fired the hook does the one transfer — a hook that ran step 4 would land
# the push inside push.sh, and the outer push would then fail on a stale expected SHA
# (`cannot lock ref`). Origin ahead surfaces as the outer push's own non-fast-forward
# rejection; a hook never rewrites local history mid-push.
#
# Usage: push.sh [--branch <name>] [--remote <name>] [--check-only]
#   --branch       branch to push (default: main); from a detached HEAD, HEAD is pushed to it
#   --remote       remote to push to (default: origin)
#   --check-only   run the gate (steps 1 and 3) and exit; never fetch, merge or push
#
# Exit codes:
#   0  pushed (with --check-only: gate passed, nothing pushed — the caller pushes)
#   1  REFUSED — a whole-tree check failed, a merge left conflicts, or the push itself was
#      rejected: nothing pushed. NEXT: fix-forward — fix the named failure and re-run; this
#      is never a blind retry.
#   2  usage, or NOT-GATED — this script could not verify (not inside a git repo, no clean export, etc.)
#   3  retired — a dirty tracked file used to refuse here; it is now only noted (step 1).
#      Never returned; kept in this table so an old caller's `3` branch is read as dead.
#
set -uo pipefail

BRANCH="main"
REMOTE="origin"
CHECK_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --branch)      BRANCH="${2:-}"; shift 2 ;;
    --remote)      REMOTE="${2:-}"; shift 2 ;;
    --check-only)  CHECK_ONLY=1; shift ;;
    -h|--help)     sed -n '2,53p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *)             echo "push.sh: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) \
  || { echo "NOT-GATED: not inside a git repository" >&2; exit 2; }
cd "$ROOT" || { echo "NOT-GATED: cannot enter repo root '$ROOT'" >&2; exit 2; }

# --- 1. NOTE a dirty tree — it does not block the push ----------------------------------
# The step-3 checks read a working tree, so a dirty file would make their verdict describe
# a tree nobody committed. The answer is to check a clean export of HEAD (step 3), never to
# hold committed work local for an unrelated edit: the dirty file is reported, not pushed.
# Untracked files owe nothing to a push gate (the same axis touchers.sh already reads for
# a Delivers path): only TRACKED, uncommitted changes count as dirty. `.beads/` is EXEMPT
# unconditionally — the bead ledger has its OWN committer lane (a conductor, never every
# session) and is routinely dirty mid-batch; it never triggers the export. A repo declares FURTHER
# live-state exemptions the SAME way a consuming app's own prod-serve dirty gate already
# might — `PUSH_DIRTY_ALLOW` (space-separated path PREFIXES) — or a
# `.push-dirty-allow` file at the repo root (one prefix per line; blank lines and `#`
# comments ignored). Neither widens past ledger/coordination-shaped paths on its own:
# CODE PATHS are never exempt by this script's own choice, only by what a repo declares.
DIRTY_ALLOW=".beads/"
if [ -f .push-dirty-allow ]; then
  while IFS= read -r _dirty_allow_line; do
    _dirty_allow_line="${_dirty_allow_line%%#*}"
    # shellcheck disable=SC2086 # word-splitting trims surrounding whitespace on purpose
    _dirty_allow_line=$(echo $_dirty_allow_line)
    [ -n "$_dirty_allow_line" ] && DIRTY_ALLOW="$DIRTY_ALLOW $_dirty_allow_line"
  done <.push-dirty-allow
fi
DIRTY_ALLOW="$DIRTY_ALLOW ${PUSH_DIRTY_ALLOW:-}"

_dirty_path_exempt() {
  for _prefix in $DIRTY_ALLOW; do
    case "$1" in
      "$_prefix"*) return 0 ;;
    esac
  done
  return 1
}

DIRTY_RAW=$(git status --porcelain --untracked-files=no 2>/dev/null)
DIRTY=""
DIRTY_PATHS=""
if [ -n "$DIRTY_RAW" ]; then
  while IFS= read -r _status_line; do
    [ -n "$_status_line" ] || continue
    # porcelain v1: two status chars, a space, then the path (a rename's " -> " tail is
    # part of the same line and is never itself a prefix match target).
    _status_path="${_status_line:3}"
    if ! _dirty_path_exempt "$_status_path"; then
      DIRTY="$DIRTY
$_status_line"
      DIRTY_PATHS="$DIRTY_PATHS
${_status_path##* -> }"
    fi
  done <<DIRTYEOF
$DIRTY_RAW
DIRTYEOF
  DIRTY="${DIRTY#$'\n'}"
  DIRTY_PATHS="${DIRTY_PATHS#$'\n'}"
fi

# --- 2. bring origin's history in — a merge, always; a rewrite of history, never --------
if [ "$CHECK_ONLY" -eq 0 ]; then
  git fetch "$REMOTE" "$BRANCH" >/dev/null 2>&1 \
    || echo "push.sh: warn — fetch failed; comparing against the last-known $REMOTE/$BRANCH" >&2
  # A detached HEAD (a worktree checked out at a commit) is what the caller holds: the
  # branch name there is the LIVE checkout's ref, shared across worktrees, never this tree's
  # work. Compare and push HEAD; the local branch ref is left untouched.
  if git symbolic-ref -q HEAD >/dev/null 2>&1; then PUSH_SRC="$BRANCH"; else PUSH_SRC="HEAD"; fi
  LOCAL_SHA=$(git rev-parse "$PUSH_SRC" 2>/dev/null)
  REMOTE_SHA=$(git rev-parse "$REMOTE/$BRANCH" 2>/dev/null || true)
fi
if [ "$CHECK_ONLY" -eq 0 ] && [ -n "$REMOTE_SHA" ] && [ "$LOCAL_SHA" != "$REMOTE_SHA" ] \
   && ! git merge-base --is-ancestor "$REMOTE_SHA" "$LOCAL_SHA" 2>/dev/null; then
  echo "push.sh: $REMOTE/$BRANCH has commits this branch does not — bringing them in with a merge (every existing commit keeps its own identity)"
  if ! git merge --no-edit "$REMOTE/$BRANCH"; then
    echo "REFUSED [merge-conflict]: bringing in $REMOTE/$BRANCH left conflicts, or would overwrite a modified file in the working tree; resolve or commit it by hand, then re-run push.sh. NEXT: fix-forward — this is a fix, never a retry-as-is." >&2
    exit 1
  fi
fi

# --- 3. this repo's own whole-tree checks — only the ones that exist -------------------
# The checks run against the COMMITTED tree. A clean tree is checked in place. A dirty tree is
# not what gets pushed, so it is not what gets checked: the checks run in a throwaway detached
# worktree of HEAD (git hooks off — an export, not a checkout anyone works in), removed on
# every exit path. A dirty file an unpushed commit also touches is named; the commit still goes.
CHECK_ROOT="$ROOT"
if [ -n "$DIRTY" ]; then
  echo "push.sh: tracked file(s) modified in the working tree are NOT part of this push; the whole-tree checks run against a clean export of HEAD:"
  echo "$DIRTY" | sed 's/^/  /'
  _base=$(git rev-parse --verify -q "$REMOTE/$BRANCH^{commit}" 2>/dev/null || true)
  if [ -n "$_base" ]; then
    _overlap=$(comm -12 <(printf '%s\n' "$DIRTY_PATHS" | sort -u) \
                        <(git log --format= --name-only "$_base..HEAD" 2>/dev/null | sort -u))
    if [ -n "$_overlap" ]; then
      echo "push.sh: also touched by an unpushed commit — the commit is pushed as committed, the working-tree edit stays local:"
      echo "$_overlap" | sed 's/^/  /'
    fi
  fi
  EXPORT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/push-sh-export.XXXXXX") \
    || { echo "NOT-GATED: cannot create a scratch directory for the clean export" >&2; exit 2; }
  _export_cleanup() {
    git worktree remove --force "$EXPORT_DIR" >/dev/null 2>&1 || rm -rf "$EXPORT_DIR"
    git worktree prune >/dev/null 2>&1 || true
  }
  trap _export_cleanup EXIT
  git -c core.hooksPath=/dev/null worktree add -q --detach "$EXPORT_DIR" HEAD >/dev/null 2>&1 \
    || { echo "NOT-GATED: cannot export HEAD to a clean worktree — the checks cannot run against the committed tree" >&2; exit 2; }
  CHECK_ROOT="$EXPORT_DIR"
fi
CHECKS_FAILED=0
if [ -x "$CHECK_ROOT/lint.sh" ]; then
  echo "push.sh: running ./lint.sh"
  (cd "$CHECK_ROOT" && ./lint.sh) || CHECKS_FAILED=1
fi
if [ "$CHECKS_FAILED" -eq 0 ] && [ -x "$CHECK_ROOT/scripts/run-all-proofs.sh" ]; then
  echo "push.sh: running scripts/run-all-proofs.sh"
  (cd "$CHECK_ROOT" && scripts/run-all-proofs.sh) || CHECKS_FAILED=1
fi

if [ "$CHECKS_FAILED" -ne 0 ]; then
  echo "REFUSED [red-check]: a whole-tree check failed; nothing was pushed. NEXT: fix-forward — fix the failure and commit it, then re-run push.sh." >&2
  exit 1
fi

# --- 4. push — never in --check-only: the calling push is the one transfer ---------------
if [ "$CHECK_ONLY" -eq 1 ]; then
  echo "push.sh: whole-tree gate passed (--check-only); nothing pushed here — the calling push transfers"
  exit 0
fi
if ! git push "$REMOTE" "$PUSH_SRC:refs/heads/$BRANCH"; then
  echo "REFUSED [push-rejected]: git push to $REMOTE/$BRANCH was rejected; the commit is safe locally. NEXT: fix-forward — reconcile by hand (never discard history), then re-run push.sh." >&2
  exit 1
fi

SHA=$(git rev-parse HEAD)
echo "push.sh: pushed $SHA to $REMOTE/$BRANCH"

exit 0
