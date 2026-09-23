#!/usr/bin/env bash
# ---
# id: 20-harness-scheduling
# prevents: a proof-test harness that no workflow runs — coverage that exists as a file but never
#   executes
# scope: HARNESSES
# severity: fail
# fixture: lint/fixtures/20-harness-scheduling
# ---
#
# 20-harness-scheduling.sh — every proof-test harness is scheduled.
#
# Check 18 proves a guard CAN fire; this proves a proof test IS RUN. Because
# scripts/run-all-proofs.sh discovers harnesses by glob and a workflow runs
# that ONE script, no harness is named in a workflow individually — so this
# check recomputes the harness inventory INDEPENDENTLY (its own git ls-files
# / find, its own excludes) and compares it against what the runner claims via
# `--list`. Two implementations of the same question; when they disagree,
# coverage has silently shrunk. It also proves some workflow actually invokes
# the runner — a runner nobody calls is the same defect one level up.
#
# Usage: 20-harness-scheduling.sh [<repo root>]     (default: this checkout)
#   Exit 0   every harness is scheduled
#   Exit 1   a harness is unscheduled, the two inventories disagree, no
#            workflow invokes the runner, or the runner is not executable
#   Exit 2   NOT-GATED — the runner is missing entirely, or zero proof-test
#            harnesses exist to audit; an empty scan is never read as a pass
set -uo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
RUNNER_REL="scripts/run-all-proofs.sh"
RUNNER="$ROOT/$RUNNER_REL"
CHECK_ID="20-harness-scheduling"
FAILURES=0

hs_fail() { echo "FAIL: $*"; FAILURES=$(( FAILURES + 1 )); }

# 1 — the runner exists. Without it nothing runs any harness: NOT-GATED, not a finding.
if [ ! -f "$RUNNER" ]; then
  echo "$CHECK_ID NOT-GATED: $RUNNER_REL missing — nothing runs the proof-test harnesses" >&2
  exit 2
fi
[ -x "$RUNNER" ] || hs_fail "$RUNNER_REL is not executable"

# 2 — some workflow actually invokes it.
if ! grep -lq "run-all-proofs" "$ROOT"/.github/workflows/*.yml 2>/dev/null; then
  hs_fail "no .github/workflows/*.yml references run-all-proofs.sh — the harness suite is unscheduled"
fi

# 3 — independent inventory vs the runner's claimed inventory.
# Tracked plus untracked-not-ignored inside a checkout; the walk outside one.
EXPECTED=$(
  if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$ROOT" ls-files --cached --others --exclude-standard -- '*.test.sh' '*.test.py' \
      | while IFS= read -r f; do [ -f "$ROOT/$f" ] && printf '%s\n' "$f"; done
  else
    find "$ROOT" -type d \( -name node_modules -o -name _archive -o -name .git \) -prune -o \
      -type f \( -name '*.test.sh' -o -name '*.test.py' \) -print 2>/dev/null | sed "s#^$ROOT/##"
  fi | LC_ALL=C sort -u
)
ACTUAL=$(bash "$RUNNER" --list 2>/dev/null | LC_ALL=C sort)

if [ -z "$EXPECTED" ]; then
  echo "$CHECK_ID NOT-GATED: found ZERO proof-test harnesses — verified nothing" >&2
  exit 2
fi

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

if [ "$FAILURES" -eq 0 ]; then
  echo "  ok: $CHECK_ID — $(printf '%s\n' "$EXPECTED" | grep -c .) harness(es), all scheduled via $RUNNER_REL"
  exit 0
fi
echo "FAIL $CHECK_ID: ${FAILURES} unscheduled proof-test harness issue(s) — see above"
exit 1
