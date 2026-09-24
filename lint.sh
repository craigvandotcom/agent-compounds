#!/usr/bin/env bash
#
# lint.sh — registry self-lint for agent-compounds. Docs: lint/README.md.
#
# Usage:  ./lint.sh                 every check under lint/checks/
#         ./lint.sh --check <id>    ONLY the named check (repeatable)
#         ./lint.sh --staged        the whole suite against the staged index
#                                   (what a commit would contain) — the
#                                   pre-commit lane's mode
#         ./lint.sh --json          results as JSON
#         ./lint.sh --help
#
# Exit 0 pass · 1 fail (FAIL: ... lines) · 2 NOT-GATED — verified nothing.
# Full contract (lanes, exit codes, header fields, allowlists): lint/README.md.
#
# This file is a thin dispatcher: it validates the interpreter, resolves the
# checkout, and hands every invocation to lint/run.py unchanged.

set -uo pipefail

AC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

require_py312() {
  if ! command -v python3 >/dev/null 2>&1; then
    echo "NOT-GATED: python3 not found — the lint runner cannot run, so nothing can be verified" >&2
    exit 2
  fi
  if ! python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 12) else 1)' 2>/dev/null; then
    echo "NOT-GATED: python3 3.12+ required (found $(python3 -V 2>&1)) — the lint runner refuses to run on an older interpreter" >&2
    exit 2
  fi
}

# `--staged` git calls: honour LINT_CALLER_GIT_INDEX_FILE (a pathspec-scoped
# `git commit -F msg -- path`'s temporary index — see run.py's
# _resolve_caller_index() docstring for why) the same way run.py does —
# validated (must exist) before it overrides the ambient index.
_staged_git() {
  if [ -n "${LINT_CALLER_GIT_INDEX_FILE:-}" ] && [ -f "$LINT_CALLER_GIT_INDEX_FILE" ]; then
    GIT_INDEX_FILE="$LINT_CALLER_GIT_INDEX_FILE" git -C "$AC_ROOT" "$@"
  else
    git -C "$AC_ROOT" "$@"
  fi
}

# The first hop of a `--staged` run: `lint.sh` execs the WORKING TREE's
# lint/run.py, and a Python interpreter that cannot PARSE that file (a
# literal top-level SyntaxError, e.g. mid-refactor) never reaches any
# in-file delegation logic — no fix living inside run.py can rescue that
# (see run.py's staged-lane comment + run.test.sh case 14, which proves the
# equivalent property for code that DOES parse). This hop never parses
# run.py itself: it is bash, using only git, so it survives a broken
# working-tree run.py.
#
# It extracts the INDEX's lint/run.py + tracked lint/lib/* + tracked
# lint/checks/* — what a commit will actually contain — into a fresh scratch
# dir and runs THAT copy. lint/checks/* is included alongside run.py/lib
# because run.py's own discover() (lib/scope.py's CHECKS population, an
# os.listdir() of a `lint/checks` sitting beside wherever run.py itself
# lives) runs BEFORE the staged-delegation branch even starts — an empty or
# missing lint/checks there trips run.py's own "no check files discovered"
# NOT-GATED exit before delegation is ever reached, for a plain `--staged`
# run with no --check filter at all, not just a --check id that happens not
# to resolve. That extracted run.py is what decides everything from here:
# with LINT_STAGED_RUNNER unset, it takes its normal --staged path
# (materialise the full staged snapshot, then delegate to that snapshot's
# own run.py with LINT_STAGED_RUNNER=1) exactly as it always has — this hop
# only gets a parseable run.py off the ground, nothing else changes.
#
# On any extraction failure (dir creation, checkout-index, or a missing
# lint/run.py in the result) this falls back to the working tree's own
# run.py with a NOTICE, rather than silently verifying nothing.
staged_first_hop() {
  local scratch_base="${XDG_CACHE_HOME:-$HOME/.cache}/ac-lint"
  if ! mkdir -p "$scratch_base" 2>/dev/null; then
    echo "NOTICE: staged first-hop scratch dir ($scratch_base) could not be created — falling back to the working tree's lint/run.py" >&2
    return 1
  fi
  local dir
  dir="$(mktemp -d "$scratch_base/ac-lint-hop-XXXXXX" 2>/dev/null)" || {
    echo "NOTICE: staged first-hop scratch dir creation failed — falling back to the working tree's lint/run.py" >&2
    return 1
  }

  local -a extra_files=()
  while IFS= read -r -d '' f; do
    extra_files+=("$f")
  done < <(_staged_git ls-files -z -- lint/lib lint/checks 2>/dev/null)

  if ! _staged_git checkout-index --prefix="$dir/" -- lint/run.py "${extra_files[@]}" >/dev/null 2>&1 \
     || [ ! -f "$dir/lint/run.py" ]; then
    echo "NOTICE: staged first-hop extraction (git checkout-index of the INDEX's lint/run.py + lint/lib + lint/checks) failed — falling back to the working tree's lint/run.py" >&2
    rm -rf "$dir"
    return 1
  fi

  python3 "$dir/lint/run.py" "${RUNNER_ARGS[@]}" --root "$AC_ROOT"
  local rc=$?
  rm -rf "$dir"
  exit "$rc"
}

# --- front-door flag parsing: every flag passes straight through to the runner ---
RUNNER_ARGS=()
STAGED=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)  usage; exit 0 ;;
    --json)     RUNNER_ARGS+=("$1"); shift ;;
    --staged)   RUNNER_ARGS+=("$1"); STAGED=1; shift ;;
    --check)    [ $# -ge 2 ] || { echo "lint.sh: --check requires an id" >&2; exit 2; }
                RUNNER_ARGS+=("$1" "$2"); shift 2 ;;
    --check=*)  RUNNER_ARGS+=("--check" "${1#--check=}"); shift ;;
    *)          echo "lint.sh: unknown argument '$1' (usage: ./lint.sh --help)" >&2; exit 2 ;;
  esac
done

require_py312

# Repo-root check: the front door resolves its own checkout, and the runner the
# exec hands to must exist there — a partial checkout would silently scan nothing.
if [ ! -f "$AC_ROOT/lint/run.py" ]; then
  echo "NOT-GATED: $AC_ROOT/lint/run.py missing — this checkout is incomplete; nothing can be verified" >&2
  exit 2
fi

# A `--staged` request takes the bash-only first hop (never parses the
# working-tree run.py) unless this process IS already that hop's own child
# (LINT_STAGED_RUNNER set) — see staged_first_hop() above.
if [ "$STAGED" = 1 ] && [ -z "${LINT_STAGED_RUNNER:-}" ]; then
  staged_first_hop
  # staged_first_hop only returns (rather than exiting) on failure — fall
  # through to the working tree's own runner, same as before this hop existed.
fi

exec python3 "$AC_ROOT/lint/run.py" "${RUNNER_ARGS[@]}" --root "$AC_ROOT"
