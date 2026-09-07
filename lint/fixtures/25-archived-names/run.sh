#!/usr/bin/env bash
#
# run.sh — the RED fixture for lint/checks/25-archived-names.py.
#
# 00-meta's contract (inverted): exit 0 when the check went RED as required,
# 1 when the check passed its RED case, >=2 when the fixture could not build.
#
# Builds a minimal tree: one archived skill dir, one live skill whose SKILL.md
# carries the retired name, NO allowlist. The check must fail (exit 1) naming
# the carrier — an archived name standing in live text is exactly the defect.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/../../checks/25-archived-names.py"
[ -f "$CHECK" ] || { echo "fixture cannot build: $CHECK missing"; exit 2; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/_archive/skills/ac-loop" "$work/skills/live-skill"
printf '# archived: this skill was retired\n' > "$work/_archive/skills/ac-loop/SKILL.md"
printf '%s\n' \
  '# live-skill' \
  '' \
  'Workflow: run ac-loop first, then close the batch.' > "$work/skills/live-skill/SKILL.md"

out="$(python3 "$CHECK" "$work" 2>&1)"
rc=$?
printf '%s\n' "$out" | sed 's/^/  fixture: /'

if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -q "skills/live-skill/SKILL.md"; then
  echo "fixture: RED demonstrated — the carrier was named"
  exit 0
fi
if [ "$rc" -eq 1 ]; then
  echo "fixture: check went RED but did not name the carrier"
  exit 1
fi
echo "fixture: check did NOT go RED (exit $rc) — the check passed its own RED case"
exit 1
