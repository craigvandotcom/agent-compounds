#!/usr/bin/env bash
#
# lint.sh — registry self-lint for agent-compounds. The front door every caller
# runs (ruled 2026-09-06: redesigned, never deleted).
#
# Mechanizes the 2026-06-11 audit's checkable invariants.
#
# Check 14 (no-net-growth) is ported to lint/checks/14-no-net-growth.py; this
# file hosts no copy of it. ec5fa64 removed the `net-growth-ok` escape hatch —
# growth is bought with deletion, never a prose stamp — and the port keeps it
# removed (pinned by scripts/lint-net-growth.test.sh).
#
# Usage:  ./lint.sh                 full scan: every un-ported bash block, then
#                                   the v2 runner (lint/run.py) over lint/checks/
#         ./lint.sh --check <id>    ONLY the named v2 check (repeatable)
#         ./lint.sh --changed       only v2 checks whose scope touches the diff
#         ./lint.sh --changed --staged  scope to the staged index (what a commit contains)
#                                   — the pre-commit lane's mode; a dirty sibling file or
#                                   ledger does not drag another writer's scope in
#         ./lint.sh --json          v2 results as JSON
#         ./lint.sh --help
#
# Flags select the RUNNER ONLY — they skip the un-ported bash blocks, so a
# scoped run stays scoped (and a probe on --check <id> cannot be forged by a
# sibling's uncommitted edit elsewhere in the shared tree). A bare invocation
# runs everything: the full bash suite first, then the runner.
#
# Exit 0  all executed checks pass
# Exit 1  one or more checks failed (each reported as FAIL: ...)
# Exit 2  NOT-GATED — a check scanned zero files (verified nothing), or the
#         interpreter is below Python 3.12. Never a pass.
#
# Style-matched to deploy.sh (same repo).

set -uo pipefail

AC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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

# --- front-door flag parsing -------------------------------------------------
RUNNER_ARGS=()
RUNNER_MODE=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)  usage; exit 0 ;;
    --changed|--json|--staged) RUNNER_ARGS+=("$1"); RUNNER_MODE=1; shift ;;
    --check)    [ $# -ge 2 ] || { echo "lint.sh: --check requires an id" >&2; exit 2; }
                RUNNER_ARGS+=("$1" "$2"); RUNNER_MODE=1; shift 2 ;;
    --check=*)  RUNNER_ARGS+=("--check" "${1#--check=}"); RUNNER_MODE=1; shift ;;
    *)          echo "lint.sh: unknown argument '$1' (usage: ./lint.sh --help)" >&2; exit 2 ;;
  esac
done

require_py312

# Repo-root check: the front door resolves its own checkout, and the runner the
# exec hands to must exist there — a partial checkout would silently scan nothing.
if [ ! -f "$AC_ROOT/lint/run.py" ]; then
  echo "NOT-GATED: $AC_ROOT/lint/run.py missing — this checkout is incomplete; the v2 runner cannot verify anything" >&2
  if [ "$RUNNER_MODE" = 1 ]; then exit 2; fi
fi

if [ "$RUNNER_MODE" = 1 ]; then
  exec python3 "$AC_ROOT/lint/run.py" "${RUNNER_ARGS[@]}" --root "$AC_ROOT"
fi

FAILURES=0
CHECKS=0

# Emit a FAIL line and increment counters.
fail() {
  echo "FAIL: $*"
  FAILURES=$(( FAILURES + 1 ))
}

# Increment check counter.
check() {
  CHECKS=$(( CHECKS + 1 ))
}

# ---------------------------------------------------------------------------
# Check 25 — is_test_shaped single-definition sensor (ac-b62c)
# ---------------------------------------------------------------------------
echo "--- Check 25: is_test_shaped drift sensor ---"
check
# flight-check WRITES the verification scope that close-gate READS. is_test_shaped is the
# contract both sides of that handshake interpret; if a second definition appears, the scope
# one records is not the scope the other interprets and the temporal proof silently rests on
# two different contracts. Exactly ONE definition site — close-gate.sh — enforced here, so a
# re-duplication fails instead of drifting.
ITS_SITES=$(grep -rl 'is_test_shaped()' skills/ac-implement/scripts/ 2>/dev/null || true)
ITS_N=$(printf '%s' "$ITS_SITES" | grep -c . || true)
if [ "$ITS_N" -eq 1 ] && printf '%s\n' "$ITS_SITES" | grep -q 'close-gate.sh'; then
  echo "  ok: is_test_shaped() defined once, in close-gate.sh"
else
  fail "Check 25: is_test_shaped() has $ITS_N definition site(s) ($(printf '%s' "$ITS_SITES" | tr '\n' ' ')) — the contract must live in exactly one place, close-gate.sh (ac-b62c drift sensor)"
fi
grep -q 'is_test_shaped' skills/ac-implement/scripts/flight-check.sh \
  && fail "Check 25: flight-check.sh mentions is_test_shaped — it must carry no copy that could drift from close-gate.sh's definition (ac-b62c)"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "lint: ${CHECKS} checks, ${FAILURES} failures (un-ported bash blocks)"

# A failing un-ported block ends the run here — a red suite is not a green run.
if [ "$FAILURES" -gt 0 ]; then
  exit 1
fi

# The v2 runner runs AFTER the un-ported blocks and ITS exit becomes the final
# exit. If the runner is absent (mid-port checkout) the legacy verdict stands.
if [ -f "$AC_ROOT/lint/run.py" ]; then
  exec python3 "$AC_ROOT/lint/run.py" --root "$AC_ROOT"
fi

[ "$FAILURES" -eq 0 ]
