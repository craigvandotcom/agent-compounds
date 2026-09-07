#!/usr/bin/env bash
# run.sh — the RED case for lint/checks/22-ledger-integrity.py: a ledger whose
# entry cites a receipt but no control (and is not tagged untreated). Exits 0
# only when the real check reports exactly that.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CHECK="$ROOT/lint/checks/22-ledger-integrity.py"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT

mkdir -p "$W/scripts" "$W/skills/skill-builder/scripts" "$W/skills/ac-pipeline"
cp "$ROOT/scripts/ac-ledger-integrity.sh" "$W/scripts/"
cp "$ROOT/skills/skill-builder/scripts/friction-rollup.py" "$W/skills/skill-builder/scripts/"
cp "$ROOT/skills/ac-pipeline/SKILL.md" "$W/skills/ac-pipeline/"
chmod +x "$W/scripts/"*.sh
{
  printf -- '---\nskill: ac-pipeline\ncreated: 2026-09-07\nlast_pass: never\nentries: 1\n---\n\n# fixture ledger\n\n## fixture-friction\n'
  printf -- '- skills: [ac-pipeline]\n- impact: M\n- frequency: every-run\n- perceptibility: silent\n- recurrence: 3\n'
  printf -- '- first_seen: 2026-09-01\n- last_seen: 2026-09-02\n- status: open\n- receipt: nowhere (fixture)\n'
  printf -- '- control: I99\n- control_landed: 2026-08-01\n'
} > "$W/skills/ac-pipeline/FRICTIONS.md"

out="$(python3 "$CHECK" "$W" 2>&1)"; rc=$?
echo "$out" | sed 's/^/  | /'
if [ "$rc" -ne 1 ]; then echo "fixture: expected RED (exit 1) for a control the constitution does not define, got $rc"; exit "$rc"; fi
printf '%s' "$out" | grep -q "cites control 'I99', which the constitution does not define" \
  || { echo "fixture: the unresolvable-control violation was not the report"; exit 1; }
exit 0
