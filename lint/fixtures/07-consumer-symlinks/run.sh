#!/usr/bin/env bash
# RED fixture for lint/checks/07-consumer-symlinks: builds a consumer tree with
# one dangling symlink, points LINT_CONSUMER_BASE at it, and runs the REAL
# check. Exits 0 only when the check went RED naming the link (the run.sh
# contract is inverted: 0 = the required RED was demonstrated).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
STATE="$(mktemp -d)"
trap 'rm -rf "$STATE"' EXIT

mkdir -p "$STATE/.claude/skills/real-skill" "$STATE/infrastructure"
: > "$STATE/infrastructure/ac-deploy-targets.list"
printf '# real-skill\n' > "$STATE/.claude/skills/real-skill/SKILL.md"
ln -s "$STATE/.claude/skills/gone-skill" "$STATE/.claude/skills/dangling-link"

out="$(LINT_CONSUMER_BASE="$STATE" python3 "$REPO/lint/checks/07-consumer-symlinks.py" 2>&1)"
rc=$?
if [ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'broken symlink: .*dangling-link'; then
  exit 0
fi
echo "fixture: check did NOT go RED naming the dangling link (exit $rc):" >&2
printf '%s\n' "$out" >&2
exit 1
