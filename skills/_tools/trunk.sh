#!/usr/bin/env bash
#
# trunk.sh — resolve the repository's remote trunk name.
#
# ASSURANCE
#   PROBE:      bash skills/_tools/trunk.test.sh
#   SCHEDULE:   every ship path and branch guard (callers are switched by sibling beads)
#   MODE:       blocking
#   ON-FAILURE: closed
#
# A checkout's DECLARED trunk wins: `git config ac2.trunk`, the repo-local key the commit
# lane's foreign-branch guard reads on the agnostic-version line.  The remote's default
# branch is a hosting setting, not a statement of where work lands: easy-mode's
# origin/HEAD is main while its trunk is dev, so origin/HEAD only answers for a checkout
# that declares nothing.  A declaration is verified, never trusted: a declared name with
# no origin/<name> tracking ref is refused (exit 2), not replaced by origin/HEAD, because
# that fallback is exactly the guess the declaration exists to prevent.
#
# Undeclared: the remote's symbolic HEAD is authoritative.  If a clone has lost that
# record, repair it from the remote; if the repair cannot reach the remote, fall back to
# the first local origin/main or origin/master tracking ref and say why the fallback was
# used.
set -uo pipefail

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "trunk.sh: cannot resolve trunk; not inside a git work tree" >&2
  exit 2
}
cd "$ROOT" || {
  echo "trunk.sh: cannot enter repository root '$ROOT'" >&2
  exit 2
}

read_origin_head() {
  local ref
  ref=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null) || return 1
  case "$ref" in
    origin/?*) printf '%s\n' "${ref#origin/}" ;;
    *) return 1 ;;
  esac
}

read_tracking_fallback() {
  local branch
  for branch in main master; do
    if git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
      printf '%s\n' "$branch"
      return 0
    fi
  done
  return 1
}

declared=$(git config --get ac2.trunk 2>/dev/null) || declared=""
if [ -n "$declared" ]; then
  if git show-ref --verify --quiet "refs/remotes/origin/$declared"; then
    printf '%s\n' "$declared"
    exit 0
  fi
  echo "trunk.sh: git config ac2.trunk declares '$declared', but origin/$declared does not exist; fetch it or correct the declaration" >&2
  exit 2
fi

trunk=$(read_origin_head) || trunk=""

if [ -z "$trunk" ]; then
  if git remote get-url origin >/dev/null 2>&1 \
     && git remote set-head origin -a >/dev/null 2>&1; then
    trunk=$(read_origin_head) || trunk=""
    if [ -z "$trunk" ]; then
      echo "trunk.sh: origin/HEAD remained unset after repair; falling back to origin/main, origin/master" >&2
    fi
  else
    echo "trunk.sh: origin/HEAD repair unavailable; falling back to origin/main, origin/master" >&2
  fi
fi

if [ -z "$trunk" ]; then
  trunk=$(read_tracking_fallback) || {
    echo "trunk.sh: cannot resolve trunk; tried origin/HEAD, origin/main, origin/master" >&2
    exit 2
  }
fi

printf '%s\n' "$trunk"
