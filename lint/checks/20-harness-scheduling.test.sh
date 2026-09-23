#!/usr/bin/env bash
# 20-harness-scheduling.test.sh — the proof harness for lint/checks/20-harness-scheduling.sh.
#
#   PROBE: a harness tree with no workflow invoking the runner is RED naming the
#          unscheduled suite; a harness the runner's inventory omits is RED naming it;
#          a tree missing the runner, or with zero harnesses, is NOT-GATED (exit 2); a
#          complete tree is GREEN; the real registry is GREEN.
#
# ASSURANCE
#   PROBE:    bash lint/checks/20-harness-scheduling.test.sh
#   SCHEDULE: scripts/run-all-proofs.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/20-harness-scheduling.sh"
ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# build_tree <dir> <with-workflow-ref:yes|no> — a real run-all-proofs.sh + one demo
# harness; toggles whether the CI workflow actually invokes the runner.
build_tree() {
  local w="$1" ref="$2"
  mkdir -p "$w/scripts" "$w/.github/workflows" "$w/lint/checks"
  cp "$ROOT/scripts/run-all-proofs.sh" "$w/scripts/"
  chmod +x "$w/scripts/"*.sh
  printf '#!/usr/bin/env bash\n# demo proof harness\nexit 0\n' > "$w/lint/checks/demo.test.sh"
  chmod +x "$w/lint/checks/demo.test.sh"
  if [ "$ref" = yes ]; then
    printf 'name: ci\non: [push]\njobs:\n  t:\n    runs-on: ubuntu-latest\n    steps:\n      - run: bash scripts/run-all-proofs.sh\n' > "$w/.github/workflows/ci.yml"
  else
    printf 'name: ci\non: [push]\njobs:\n  t:\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo hi\n' > "$w/.github/workflows/ci.yml"
  fi
}

# build_fixture <dir> <listed-harnesses...> — 3 real harnesses on disk (two shapes,
# .test.sh and .test.py) and a stub runner that CLAIMS to run exactly the ones named,
# so a narrowed claim (fewer args than files on disk) is producible without touching
# the real runner's own logic.
build_fixture() {
  local w="$1"; shift
  mkdir -p "$w/scripts" "$w/.github/workflows" \
           "$w/skills/alpha/scripts" "$w/skills/beta" "$w/hooks"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$w/skills/alpha/scripts/one.test.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$w/skills/beta/two.test.sh"
  printf 'import sys\nsys.exit(0)\n' > "$w/hooks/three.test.py"
  printf 'name: CI\njobs:\n  harnesses:\n    steps:\n      - run: bash scripts/run-all-proofs.sh\n' \
    > "$w/.github/workflows/ci.yml"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'if [ "${1:-}" = "--list" ]; then\n'
    local h
    for h in "$@"; do printf '  echo "%s"\n' "$h"; done
    printf '  exit 0\nfi\nexit 0\n'
  } > "$w/scripts/run-all-proofs.sh"
  chmod +x "$w/scripts/run-all-proofs.sh"
}

ALL="skills/alpha/scripts/one.test.sh skills/beta/two.test.sh hooks/three.test.py"

# --- RED: harnesses exist, no workflow runs them ---------------------------------
w="$WORK/no-workflow-ref"; mkdir -p "$w"
build_tree "$w" no
out="$(bash "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "no .github/workflows/\*.yml references run-all-proofs.sh"; then
  ok "RED: unscheduled suite -> exit 1 naming the missing workflow reference"
else
  bad "RED (no workflow ref): expected 1 naming the unscheduled suite, got $rc"; printf '%s\n' "$out"
fi

# --- RED: a harness on disk that the runner's claimed inventory omits ------------
w="$WORK/narrowed"; mkdir -p "$w"
build_fixture "$w" "skills/alpha/scripts/one.test.sh" "skills/beta/two.test.sh"
out="$(bash "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "hooks/three.test.py"; then
  ok "RED: runner inventory narrowed -> exit 1 naming the unscheduled harness"
else
  bad "RED (narrowed): expected 1 naming hooks/three.test.py, got $rc"; printf '%s\n' "$out"
fi

# --- GREEN: workflow runs the runner, inventories agree --------------------------
w="$WORK/scheduled"; mkdir -p "$w"
build_tree "$w" yes
out="$(bash "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q "scheduled"; then
  ok "GREEN: scheduled suite -> exit 0"
else
  bad "GREEN case: expected 0, got $rc"; printf '%s\n' "$out"
fi

# --- GREEN: runner lists every harness on disk (real-runner build_fixture shape) -
w="$WORK/complete"; mkdir -p "$w"
build_fixture "$w" $ALL
out="$(bash "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  ok "GREEN: complete runner inventory -> exit 0"
else
  bad "GREEN (complete): expected 0, got $rc"; printf '%s\n' "$out"
fi

# --- NOT-GATED: the runner script is missing entirely -----------------------------
w="$WORK/no-runner"; mkdir -p "$w/lint/checks"
printf 'x\n' > "$w/lint/checks/demo.test.sh"
out="$(bash "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q "NOT-GATED"; then
  ok "NOT-GATED: missing runner -> exit 2, verified nothing"
else
  bad "NOT-GATED (no runner): expected 2, got $rc"; printf '%s\n' "$out"
fi

# --- NOT-GATED: zero proof-test harnesses exist -----------------------------------
w="$WORK/empty"; mkdir -p "$w/scripts" "$w/.github/workflows"
printf '#!/usr/bin/env bash\nif [ "${1:-}" = "--list" ]; then exit 0; fi\nexit 0\n' > "$w/scripts/run-all-proofs.sh"
chmod +x "$w/scripts/run-all-proofs.sh"
printf 'name: CI\njobs:\n  harnesses:\n    steps:\n      - run: bash scripts/run-all-proofs.sh\n' > "$w/.github/workflows/ci.yml"
out="$(bash "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q "NOT-GATED"; then
  ok "NOT-GATED: zero harnesses found -> exit 2, verified nothing"
else
  bad "NOT-GATED (empty): expected 2, got $rc"; printf '%s\n' "$out"
fi

# --- the real registry is green ----------------------------------------------------
out="$(bash "$CHECK" "$ROOT" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  ok "GREEN: the real registry's harness suite is scheduled"
else
  bad "real-tree case: expected 0, got $rc"; printf '%s\n' "$out"
fi

echo "20-harness-scheduling.test.sh: ${fails} failure(s)"
[ "$fails" -eq 0 ]
