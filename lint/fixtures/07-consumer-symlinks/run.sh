#!/usr/bin/env bash
# RED fixture for lint/checks/07-consumer-symlinks: builds a configured machine whose
# org root carries one dangling symlink, points the reader's AC_MACHINE_FILE at it, and
# runs the REAL check. Exits 0 only when the check went RED naming the link (the run.sh
# contract is inverted: 0 = the required RED was demonstrated).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
STATE="$(mktemp -d)"
trap 'rm -rf "$STATE"' EXIT

# The consumer union comes from engine/machine.sh, so the fixture supplies a machine
# file: one existing target, and an org root that carries the dangling link.
mkdir -p "$STATE/.claude/skills/real-skill" "$STATE/app-target"
printf '{"org_root": "%s", "targets": [{"path": "%s/app-target", "public": false}]}\n' \
  "$STATE" "$STATE" > "$STATE/machine.json"
printf '# real-skill\n' > "$STATE/.claude/skills/real-skill/SKILL.md"
ln -s "$STATE/.claude/skills/gone-skill" "$STATE/.claude/skills/dangling-link"

out="$(AC_MACHINE_FILE="$STATE/machine.json" python3 "$REPO/lint/checks/07-consumer-symlinks.py" 2>&1)"
rc=$?
if [ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'broken symlink: .*dangling-link'; then
  exit 0
fi
echo "fixture: check did NOT go RED naming the dangling link (exit $rc):" >&2
printf '%s\n' "$out" >&2
exit 1
