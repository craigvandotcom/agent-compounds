#!/usr/bin/env bash
# RED fixture for lint/checks/12-deployed-app-conformance: builds a consumer
# tree whose workflow-reminder.md and app-root AGENTS.md still carry dead
# pipeline names, points LINT_CONSUMER_BASE at it, and runs the REAL check.
# Exits 0 only when the check went RED naming both C1 and C3 (the run.sh
# contract is inverted: 0 = the required RED was demonstrated).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
STATE="$(mktemp -d)"
trap 'rm -rf "$STATE"' EXIT

mkdir -p "$STATE/.claude/hooks" "$STATE/infrastructure"
: > "$STATE/infrastructure/ac-deploy-targets.list"
printf 'Claim beads with /ac/bead-work.\n' > "$STATE/.claude/hooks/workflow-reminder.md"
printf 'Stages: bead-work then wave-merge.\n' > "$STATE/AGENTS.md"

out="$(LINT_CONSUMER_BASE="$STATE" python3 "$REPO/lint/checks/12-deployed-app-conformance.py" 2>&1)"
rc=$?
if [ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'C1:' && printf '%s\n' "$out" | grep -q 'C3:'; then
  exit 0
fi
echo "fixture: check did NOT go RED naming C1+C3 (exit $rc):" >&2
printf '%s\n' "$out" >&2
exit 1
