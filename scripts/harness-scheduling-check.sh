#!/usr/bin/env bash
#
# harness-scheduling-check.sh — assert no proof-test harness is unscheduled.
#
# Born from ac-on0y.1. lint.sh Check 18 proves a guard CAN fire; this proves a proof
# test IS RUN. Both exist because a mechanism nobody executes reads as coverage.
#
# Usage:  harness-scheduling-check.sh [<repo root>]     (default: this script's repo)
# Exit 0  every harness is scheduled
# Exit 1  at least one is not (each reported as FAIL: ...)
#
# THE ASSERTION, and why it is not circular: scripts/run-all-harnesses.sh discovers
# harnesses by glob and a workflow runs that ONE script, so no harness is named in a
# workflow individually. This check therefore recomputes the inventory INDEPENDENTLY —
# its own find, its own excludes — and compares it against what the runner claims via
# `--list`. Two implementations of the same question; when they disagree, coverage has
# silently shrunk (someone narrowed the runner's glob) and this fails. Identical logic
# in one place would be decoration.
#
set -uo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
RUNNER_REL="scripts/run-all-harnesses.sh"
RUNNER="$ROOT/$RUNNER_REL"
FAILURES=0

hs_fail() { echo "FAIL: $*"; FAILURES=$(( FAILURES + 1 )); }

# 1 — the runner exists and is executable.
if [ ! -f "$RUNNER" ]; then
  hs_fail "$RUNNER_REL missing — nothing runs the proof-test harnesses"
  echo "harness-scheduling: ${FAILURES} failure(s)"
  exit 1
fi
[ -x "$RUNNER" ] || hs_fail "$RUNNER_REL is not executable"

# 2 — some workflow actually invokes it. A runner nobody calls is the same defect
#     one level up: the thing that runs the proof tests must itself be scheduled.
if ! grep -lq "run-all-harnesses" "$ROOT"/.github/workflows/*.yml 2>/dev/null; then
  hs_fail "no .github/workflows/*.yml references run-all-harnesses.sh — the harness suite is unscheduled"
fi

# 3 — independent inventory vs the runner's claimed inventory.
EXPECTED=$(
  find "$ROOT" \
    -type d \( -name node_modules -o -name _archive -o -name .git \) -prune -o \
    -type f \( -name '*.test.sh' -o -name '*.test.py' \) -print 2>/dev/null \
    | sed "s#^$ROOT/##" \
    | LC_ALL=C sort
)
ACTUAL=$(bash "$RUNNER" --list 2>/dev/null | LC_ALL=C sort)

if [ -z "$EXPECTED" ]; then
  hs_fail "found ZERO proof-test harnesses — this check verified nothing (NOT-GATED)"
else
  MISSING=$(comm -23 <(printf '%s\n' "$EXPECTED") <(printf '%s\n' "$ACTUAL"))
  EXTRA=$(comm -13 <(printf '%s\n' "$EXPECTED") <(printf '%s\n' "$ACTUAL"))
  if [ -n "$MISSING" ]; then
    hs_fail "harness(es) exist that $RUNNER_REL would NOT run — a new harness cannot silently join the unscheduled pile:"
    printf '  - %s\n' $MISSING
  fi
  if [ -n "$EXTRA" ]; then
    hs_fail "$RUNNER_REL claims harness(es) this check cannot find — the two inventories disagree:"
    printf '  - %s\n' $EXTRA
  fi
fi

if [ "$FAILURES" -eq 0 ]; then
  echo "harness-scheduling: $(printf '%s\n' "$EXPECTED" | grep -c .) harness(es), all scheduled via $RUNNER_REL"
fi
echo "harness-scheduling: ${FAILURES} failure(s)"
[ "$FAILURES" -eq 0 ]
