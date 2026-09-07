#!/usr/bin/env bash
#
# run.sh — the RED fixture for lint/checks/29-stage-conformance.py.
#
# 00-meta's contract (inverted): exit 0 when the check went RED as required,
# 1 when the check passed its RED case, >=2 when the fixture could not build.
#
# Builds a minimal registry: a two-stage table, a skill declaring a legal
# hand-off, and one declaring a hand-off to a stage the table lacks. The
# check must fail (exit 1) naming the offender.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/../../checks/29-stage-conformance.py"
[ -f "$CHECK" ] || { echo "fixture cannot build: $CHECK missing"; exit 2; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/skills/ac-pipeline/references" "$work/skills/ac-green" "$work/skills/ac-red"
cat > "$work/skills/ac-pipeline/references/stage-table.md" <<'TBL'
| Stage | Owner skill | Trigger | Human gate | Artifact | Non-ac skills loaded |
|---|---|---|---|---|---|
| One | `ac-one` | on demand | none | report | — |
| Two | `ac-two` | after One | none | artifact | — |
TBL
printf '%s\n' '# ac-green' 'Hands off to ac-two.' > "$work/skills/ac-green/SKILL.md"
printf '%s\n' '# ac-red' 'Hands off to ac-three — a stage the table lacks.' > "$work/skills/ac-red/SKILL.md"

out="$(python3 "$CHECK" "$work" 2>&1)"
rc=$?
printf '%s\n' "$out" | sed 's/^/  fixture: /'

if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -q "ac-red/SKILL.md"; then
  echo "fixture: RED demonstrated — the non-conforming hand-off was named"
  exit 0
fi
echo "fixture: check did NOT go RED as required (exit $rc)"
exit 1
