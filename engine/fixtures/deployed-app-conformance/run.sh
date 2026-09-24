#!/usr/bin/env bash
# RED fixture for engine/checks/deployed-app-conformance.py: builds a configured
# machine whose org root carries a workflow-reminder.md and an app-root AGENTS.md
# with dead pipeline names, points the reader's AC_MACHINE_FILE at it, and runs
# the REAL check. Exits 0 only when the check went RED naming both C1 and C3 (the
# run.sh contract is inverted: 0 = the required RED was demonstrated).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
STATE="$(mktemp -d)"
trap 'rm -rf "$STATE"' EXIT

# The consumer union comes from engine/machine.sh, so the fixture supplies a machine
# file: one existing target, and an org root whose every-prompt files carry dead names.
mkdir -p "$STATE/.claude/hooks" "$STATE/app-target"
printf '{"org_root": "%s", "targets": [{"path": "%s/app-target", "public": false}]}\n' \
  "$STATE" "$STATE" > "$STATE/machine.json"
printf 'Claim beads with /ac/bead-work.\n' > "$STATE/.claude/hooks/workflow-reminder.md"
printf 'Stages: bead-work then wave-merge.\n' > "$STATE/AGENTS.md"

out="$(AC_MACHINE_FILE="$STATE/machine.json" python3 "$REPO/engine/checks/deployed-app-conformance.py" 2>&1)"
rc=$?
if [ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'C1:' && printf '%s\n' "$out" | grep -q 'C3:'; then
  exit 0
fi
echo "fixture: check did NOT go RED naming C1+C3 (exit $rc):" >&2
printf '%s\n' "$out" >&2
exit 1
