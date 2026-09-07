#!/usr/bin/env bash
# run.sh — the RED case for lint/checks/13-skill-registry.py: a registry whose
# skill carries a description over the 1024-char cap. Exits 0 only when the
# real check reports exactly that.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CHECK="$ROOT/lint/checks/13-skill-registry.py"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT

mkdir -p "$W/skills/skill-builder/scripts" "$W/skills/overlong"
cp "$ROOT/skills/skill-builder/scripts/validate-skill.sh" "$W/skills/skill-builder/scripts/"
chmod +x "$W/skills/skill-builder/scripts/"*.sh
{
  printf -- '---\nname: overlong\ndescription: "'
  for i in $(seq 1 140); do printf 'trigger word %d ' "$i"; done
  printf '"\n---\n\n# overlong\n'
} > "$W/skills/overlong/SKILL.md"

out="$(python3 "$CHECK" "$W" 2>&1)"; rc=$?
echo "$out" | sed 's/^/  | /'
if [ "$rc" -ne 1 ]; then echo "fixture: expected RED (exit 1) for an over-cap description, got $rc"; exit "$rc"; fi
printf '%s' "$out" | grep -q "skill-registry validation" \
  || { echo "fixture: the registry-validation violation was not the report"; exit 1; }
exit 0
