#!/usr/bin/env bash
# run-start.sh — record the human's starting branch before a swarm spawns.
#
# Usage: run-start.sh --run <run-id>
# Record: <git-common-dir>/ac-flight/<run-id>/branch
#
# ASSURANCE
#   PROBE:      skills/ac-implement/scripts/run-start.test.sh
#   SCHEDULE:   ac-implement Phase 0, once before any worker spawn; every CI proof run
#   MODE:       blocking
#   ON-FAILURE: closed — a detached or unrecordable start never falls back to a guessed branch
#
# Exit: 0 recorded · 1 detached HEAD · 2 usage / repository / write failure.
set -uo pipefail

RUN=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --run) RUN="${2:-}"; shift 2 ;;
    -h|--help)
      printf 'usage: %s --run <run-id>\n' "$0"
      exit 0
      ;;
    *) printf 'run-start: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done
[ -n "$RUN" ] || { printf 'run-start: --run <run-id> is required\n' >&2; exit 2; }
[ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = true ] \
  || { printf 'run-start: not inside a git work tree; no branch record written\n' >&2; exit 2; }

BRANCH="$(git symbolic-ref --short -q HEAD)" || {
  printf 'run-start: REFUSED %s — HEAD is detached; no branch record written\n' "$RUN" >&2
  exit 1
}

COMMON="$(git rev-parse --git-common-dir 2>/dev/null)" \
  || { printf 'run-start: cannot resolve git common dir; no branch record written\n' >&2; exit 2; }
COMMON="$(cd "$COMMON" 2>/dev/null && pwd -P)" \
  || { printf 'run-start: cannot enter git common dir %s; no branch record written\n' "$COMMON" >&2; exit 2; }
RECORD_DIR="$COMMON/ac-flight/$RUN"
RECORD="$RECORD_DIR/branch"
mkdir -p "$RECORD_DIR" \
  || { printf 'run-start: cannot create %s; no branch record written\n' "$RECORD_DIR" >&2; exit 2; }
printf '%s\n' "$BRANCH" >"$RECORD" \
  || { printf 'run-start: cannot write %s; no branch record written\n' "$RECORD" >&2; exit 2; }

printf 'run-start: recorded %s on %s\n' "$RUN" "$BRANCH"
if ! git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
  printf 'this run will publish %s to origin\n' "$BRANCH"
fi
