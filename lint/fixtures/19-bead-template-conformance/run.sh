#!/usr/bin/env bash
# run.sh — the RED case for lint/checks/19-bead-template-conformance.py. The
# check imports the runtime guard from <root>/hooks/bead-capture-guard.py, so
# the fixture copies the guard into a scratch tree. The VACUOUS guard (>= 20
# scanned templates) needs a populated tree, so it ships 20 conformant
# templates plus one missing the origin:<skill> provenance label. Exits 0
# only when the real check went RED as required.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CHECK="$ROOT/lint/checks/19-bead-template-conformance.py"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/hooks" "$W/skills/bad"
cp "$ROOT/hooks/bead-capture-guard.py" "$W/hooks/"
{
  for n in $(seq 1 20); do
    printf '%s\n' '`br create -t task --labels "origin:ac-hygiene,unrefined" --title "fixture-do-not-file '"$n"'"`'
  done
  printf '%s\n' '`br create -t bug --title "a template with no provenance label"`'
} > "$W/skills/bad/SKILL.md"
out="$(python3 "$CHECK" "$W" 2>&1)"; rc=$?
echo "$out" | sed 's/^/  | /'
if [ "$rc" -ne 1 ]; then echo "fixture: expected RED (exit 1), got $rc"; exit 1; fi
printf '%s' "$out" | grep -q "no origin:<skill> label" || { echo "fixture: wrong violation"; exit 1; }
exit 0
