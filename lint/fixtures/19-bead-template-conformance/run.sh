#!/usr/bin/env bash
# run.sh — the RED case for lint/checks/19-bead-template-conformance.py. A
# template's conformance is judged by scripts/bead-template-lint.py, which
# computes its ROOT from its own location and imports the runtime guard — so
# the fixture copies the real script and guard into a scratch tree and ships
# one template missing the origin:<skill> provenance label. Exits 0 only when
# the real check went RED as required.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CHECK="$ROOT/lint/checks/19-bead-template-conformance.py"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/scripts" "$W/hooks" "$W/skills/bad"
cp "$ROOT/scripts/bead-template-lint.py" "$W/scripts/"
cp "$ROOT/hooks/bead-capture-guard.py" "$W/hooks/"
cat > "$W/skills/bad/SKILL.md" <<'MD'
`br create -t bug --title "a template with no provenance label"`
MD
out="$(python3 "$CHECK" "$W" 2>&1)"; rc=$?
echo "$out" | sed 's/^/  | /'
if [ "$rc" -ne 1 ]; then echo "fixture: expected RED (exit 1), got $rc"; exit 1; fi
printf '%s' "$out" | grep -q "non-conforming bead template(s)" || { echo "fixture: wrong violation"; exit 1; }
exit 0
