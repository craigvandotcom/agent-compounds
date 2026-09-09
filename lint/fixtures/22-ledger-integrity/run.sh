#!/usr/bin/env bash
# run.sh — the RED cases for lint/checks/22-ledger-integrity.py: (1) a ledger whose
# entry cites a receipt but no control (and is not tagged untreated), and (2) the
# folded-in --strict class — an entry with an ordinal outside the schema's canonical
# set is a named NOT-SCORABLE finding. Exits 0 only when the real check reports exactly
# those findings.
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

# --- sub-case: an unscorable ordinal is a named NOT-SCORABLE finding -----------------
W2="$(mktemp -d)"; trap 'rm -rf "$W" "$W2"' EXIT
mkdir -p "$W2/scripts" "$W2/skills/skill-builder/scripts" "$W2/skills/ac-pipeline"
cp "$ROOT/scripts/ac-ledger-integrity.sh" "$W2/scripts/"
cp "$ROOT/skills/skill-builder/scripts/friction-rollup.py" "$W2/skills/skill-builder/scripts/"
cp "$ROOT/skills/ac-pipeline/SKILL.md" "$W2/skills/ac-pipeline/"
chmod +x "$W2/scripts/"*.sh
{
  printf -- '---\nskill: ac-pipeline\ncreated: 2026-09-07\nlast_pass: never\nentries: 1\n---\n\n# fixture ledger\n\n## fixture-friction\n'
  printf -- '- skills: [ac-pipeline]\n- impact: M\n- frequency: sometimes\n- perceptibility: silent\n- recurrence: 3\n'
  printf -- '- first_seen: 2026-09-01\n- last_seen: 2026-08-01\n- status: open\n- receipt: somewhere (fixture)\n'
  printf -- '- control: untreated\n'
} > "$W2/skills/ac-pipeline/FRICTIONS.md"

out2="$(python3 "$CHECK" "$W2" 2>&1)"; rc2=$?
echo "$out2" | sed 's/^/  | /'
if [ "$rc2" -ne 1 ]; then echo "fixture: expected RED (exit 1) for the unscorable ordinal, got $rc2"; exit "$rc2"; fi
printf '%s' "$out2" | grep -q "NOT-SCORABLE: fixture-friction" \
  || { echo "fixture: the NOT-SCORABLE violation was not the report"; exit 1; }
exit 0
