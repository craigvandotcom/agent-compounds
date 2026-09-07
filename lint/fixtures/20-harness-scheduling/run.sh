#!/usr/bin/env bash
# run.sh — the RED case for lint/checks/20-harness-scheduling.py: a tree whose
# harnesses (and their runner) exist but no workflow invokes the runner, so the
# suite is unscheduled. Exits 0 only when the real check reports exactly that.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CHECK="$ROOT/lint/checks/20-harness-scheduling.py"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT

mkdir -p "$W/scripts" "$W/.github/workflows" "$W/lint/checks"
cp "$ROOT/scripts/harness-scheduling-check.sh" "$W/scripts/"
cp "$ROOT/scripts/run-all-harnesses.sh" "$W/scripts/"
chmod +x "$W/scripts/"*.sh
printf '#!/usr/bin/env bash\n# demo proof harness\nexit 0\n' > "$W/lint/checks/demo.test.sh"
chmod +x "$W/lint/checks/demo.test.sh"
# A workflow that runs tests but never the harness runner — the defect itself.
printf 'name: ci\non: [push]\njobs:\n  t:\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo hi\n' > "$W/.github/workflows/ci.yml"

out="$(python3 "$CHECK" "$W" 2>&1)"; rc=$?
echo "$out" | sed 's/^/  | /'
if [ "$rc" -ne 1 ]; then echo "fixture: expected RED (exit 1) for an unscheduled harness suite, got $rc"; exit "$rc"; fi
printf '%s' "$out" | grep -q "no .github/workflows/\*.yml references run-all-harnesses.sh" \
  || { echo "fixture: the unscheduled-workflow violation was not the report"; exit 1; }
exit 0
