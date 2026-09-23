#!/usr/bin/env bash
# run.sh — the RED case for lint/checks/21-assurance-declarations.sh: a hooks
# manifest whose wiring entry carries no assurance declaration. Exits 0 only
# when the real check reports exactly that.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CHECK="$ROOT/lint/checks/21-assurance-declarations.sh"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT

mkdir -p "$W/hooks" "$W/engine"
printf '{"wiring":[{"id":"demo","command":"echo hi"}]}\n' > "$W/engine/hooks.wiring.json"

out="$(bash "$CHECK" "$W" 2>&1)"; rc=$?
echo "$out" | sed 's/^/  | /'
if [ "$rc" -ne 1 ]; then echo "fixture: expected RED (exit 1) for a wiring entry with no assurance declaration, got $rc"; exit "$rc"; fi
printf '%s' "$out" | grep -q "wiring 'demo' carries no assurance declaration" \
  || { echo "fixture: the undeclared-wiring violation was not the report"; exit 1; }
exit 0
