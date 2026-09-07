#!/usr/bin/env bash
# 20-harness-scheduling.test.sh — the fixture proving Check 20's contract.
#
#   PROBE: a harness tree with no workflow invoking the harness runner is RED
#           naming the unscheduled suite; a tree whose workflow invokes the
#           runner and whose inventory matches is GREEN; a tree missing the
#           judge script is NOT-GATED (exit 2); the real registry is GREEN.
#
# ASSURANCE
#   PROBE:    bash lint/checks/20-harness-scheduling.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/20-harness-scheduling.py"
ROOT="$(cd "$HERE/../.." && pwd)"
REG="$ROOT/scripts/harness-scheduling-check.sh"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

build_tree() { # <root> <with-workflow-ref:yes|no>
  local w="$1" ref="$2"
  mkdir -p "$w/scripts" "$w/.github/workflows" "$w/lint/checks"
  cp "$REG" "$w/scripts/"
  cp "$ROOT/scripts/run-all-harnesses.sh" "$w/scripts/"
  chmod +x "$w/scripts/"*.sh
  printf '#!/usr/bin/env bash\n# demo proof harness\nexit 0\n' > "$w/lint/checks/demo.test.sh"
  chmod +x "$w/lint/checks/demo.test.sh"
  if [ "$ref" = yes ]; then
    printf 'name: ci\non: [push]\njobs:\n  t:\n    runs-on: ubuntu-latest\n    steps:\n      - run: bash scripts/run-all-harnesses.sh\n' > "$w/.github/workflows/ci.yml"
  else
    printf 'name: ci\non: [push]\njobs:\n  t:\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo hi\n' > "$w/.github/workflows/ci.yml"
  fi
}

# --- RED: harnesses exist, no workflow runs them -------------------------------
w="$(mktemp -d)"
build_tree "$w" no
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "no .github/workflows/\*.yml references run-all-harnesses.sh"; then
  ok "RED: unscheduled suite -> exit 1 naming the missing workflow reference"
else
  bad "RED case: expected 1 naming the unscheduled suite, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- GREEN: workflow runs the runner, inventories agree -------------------------
w="$(mktemp -d)"
build_tree "$w" yes
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q "every proof-test harness is scheduled"; then
  ok "GREEN: scheduled suite -> exit 0"
else
  bad "GREEN case: expected 0, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- NOT-GATED: the judge script is missing from the audited tree ---------------
w="$(mktemp -d)"
mkdir -p "$w/lint/checks"
printf 'x\n' > "$w/lint/checks/demo.test.sh"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q "NOT-CHECKED"; then
  ok "NOT-GATED: missing judge -> exit 2, verified nothing"
else
  bad "NOT-GATED case: expected 2, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- the real registry is green -------------------------------------------------
out="$(python3 "$CHECK" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  ok "GREEN: the real registry's harness suite is scheduled"
else
  bad "real-tree case: expected 0, got $rc"; printf '%s\n' "$out"
fi

echo "20-harness-scheduling.test.sh: ${fails} failure(s)"
[ "$fails" -eq 0 ]
