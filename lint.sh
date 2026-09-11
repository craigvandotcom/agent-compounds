#!/usr/bin/env bash
#
# lint.sh — registry self-lint for agent-compounds. The front door every caller
# runs (ruled 2026-09-06: redesigned, never deleted).
#
# Mechanizes the 2026-06-11 audit's checkable invariants.
#
# Every check lives under lint/checks/, run by the v2 runner (lint/run.py);
# this file hosts no check logic of its own (the last un-ported bash block —
# the is_test_shaped single-definition sensor, legacy "Check 25" — was ported
# to lint/checks/34-is-test-shaped-single-def.py on 2026-09-12: its id
# collided with the unrelated lint/checks/25-archived-names.py, and living
# inline made it invisible to 00-meta.py's header contract and to
# --check/--changed scoping). Check 14 (no-net-growth)'s `net-growth-ok`
# escape hatch stays removed (ec5fa64) — growth is bought with deletion,
# never a prose stamp — pinned by scripts/lint-net-growth.test.sh.
#
# Usage:  ./lint.sh                 every check under lint/checks/
#         ./lint.sh --check <id>    ONLY the named check (repeatable)
#         ./lint.sh --changed       only checks whose scope touches the diff
#         ./lint.sh --changed --staged  scope to the staged index (what a commit contains)
#                                   — the pre-commit lane's mode; a dirty sibling file or
#                                   ledger does not drag another writer's scope in
#         ./lint.sh --json          results as JSON
#         ./lint.sh --help
#
# This file is a thin dispatcher: it validates the interpreter, resolves the
# checkout, and hands every invocation to lint/run.py unchanged.
#
# Exit 0  all executed checks pass
# Exit 1  one or more checks failed (each reported as FAIL: ...)
# Exit 2  NOT-GATED — a check scanned zero files (verified nothing), the
#         checkout is incomplete, or the interpreter is below Python 3.12.
#         Never a pass.
#
# Style-matched to deploy.sh (same repo).

set -uo pipefail

AC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  sed -n '2,28p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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
    --changed|--json|--staged) RUNNER_ARGS+=("$1"); shift ;;
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
