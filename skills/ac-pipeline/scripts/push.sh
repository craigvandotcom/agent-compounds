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
# once they are clean.
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
#
# NO DISPATCH HERE: the full quality-gate proof (quality-gate.yml's `reason=prove` leg)
# is dispatched exactly once, at publish, by ac-prove (bd-fugib.8). Dispatching it per
# push burned ~25 minutes of self-hosted runner on every batch commit for a verdict
# ac-prove re-checks for freshness anyway.
#
# Usage: push.sh [--branch <name>] [--remote <name>]
#   --branch       branch to push (default: main)
#   --remote       remote to push to (default: origin)
#
# Exit codes:
#   0  pushed
#   1  REFUSED — a whole-tree check failed, a merge left conflicts, or the push itself was
#      rejected: nothing pushed. NEXT: fix-forward — fix the named failure and re-run; this
#      is never a blind retry.
#   2  usage, or NOT-GATED — this script could not verify (not inside a git repo, etc.)
#   3  REFUSED [dirty-tree] — a tracked file is uncommitted, named on stderr
#
set -uo pipefail

BRANCH="main"
REMOTE="origin"

while [ $# -gt 0 ]; do
  case "$1" in
    --branch)      BRANCH="${2:-}"; shift 2 ;;
    --remote)      REMOTE="${2:-}"; shift 2 ;;
    -h|--help)     sed -n '2,45p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *)             echo "push.sh: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) \
  || { echo "NOT-GATED: not inside a git repository" >&2; exit 2; }
cd "$ROOT" || { echo "NOT-GATED: cannot enter repo root '$ROOT'" >&2; exit 2; }

# --- 1. REFUSE a dirty tree, naming the file --------------------------------------------
# Untracked files owe nothing to a push gate (the same axis touchers.sh already reads for
# a Delivers path): only TRACKED, uncommitted changes block it. `.beads/` is EXEMPT
# unconditionally — the bead ledger has its OWN committer lane (a conductor, never every
# session) and is routinely dirty mid-batch; refusing on it deadlocks every push against a
# normal, expected mid-run state (measured: wiring this script into an app's own pre-push
# hook refused every push while any session held ledger edits). A repo declares FURTHER
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
if [ -n "$DIRTY_RAW" ]; then
  while IFS= read -r _status_line; do
    [ -n "$_status_line" ] || continue
    # porcelain v1: two status chars, a space, then the path (a rename's " -> " tail is
    # part of the same line and is never itself a prefix match target).
    _status_path="${_status_line:3}"
    _dirty_path_exempt "$_status_path" || DIRTY="$DIRTY
$_status_line"
  done <<DIRTYEOF
$DIRTY_RAW
DIRTYEOF
  DIRTY="${DIRTY#$'\n'}"
fi
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

exit 0
