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

# --- front-door flag parsing: every flag passes straight through to the runner ---
RUNNER_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)  usage; exit 0 ;;
    --json|--staged) RUNNER_ARGS+=("$1"); shift ;;
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

exec python3 "$AC_ROOT/lint/run.py" "${RUNNER_ARGS[@]}" --root "$AC_ROOT"
