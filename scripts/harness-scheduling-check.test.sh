#!/usr/bin/env bash
# harness-scheduling-check.test.sh — proof harness for scripts/harness-scheduling-check.sh
# (ac-on0y.1) and, transitively, for lint.sh's harness-scheduling check.
#
# WHY fixtures: the check's whole value is catching a runner whose discovery has been
# narrowed so a harness stops being executed. That state cannot be produced in the live
# repo without breaking it, so each case builds a throwaway tree under $TMPDIR with its
# own runner, workflow, and harnesses. The final case runs the check against the REAL
# repo, so the fixtures can never drift into proving something the repo does not do.
#
# Exit 0 = all cases pass.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$SCRIPT_DIR/harness-scheduling-check.sh"
AC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CASES=0
FAILURES=0

WORK="$(mktemp -d "${TMPDIR:-/tmp}/harness-sched.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

expect() { # $1 = 1 if the case held   $2 = label
  CASES=$((CASES + 1))
  if [ "$1" = 1 ]; then
    printf '  PASS  %s\n' "$2"
  else
    printf '  FAIL  %s\n' "$2"
    FAILURES=$((FAILURES + 1))
  fi
}

# build_fixture <name> <listed-harnesses...> — a tree with 3 real harnesses on disk and
# a runner that CLAIMS to run exactly the ones named. Returns the root on stdout.
build_fixture() {
  local name="$1"; shift
  local root="$WORK/$name"
  mkdir -p "$root/scripts" "$root/.github/workflows" \
           "$root/skills/alpha/scripts" "$root/skills/beta" "$root/hooks"

  printf '#!/usr/bin/env bash\nexit 0\n' > "$root/skills/alpha/scripts/one.test.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$root/skills/beta/two.test.sh"
  printf 'import sys\nsys.exit(0)\n'      > "$root/hooks/three.test.py"

  printf 'name: CI\njobs:\n  harnesses:\n    steps:\n      - run: bash scripts/run-all-harnesses.sh\n' \
    > "$root/.github/workflows/ci.yml"

  {
    printf '#!/usr/bin/env bash\n'
    printf 'if [ "${1:-}" = "--list" ]; then\n'
    local h
    for h in "$@"; do printf '  echo "%s"\n' "$h"; done
    printf '  exit 0\nfi\nexit 0\n'
  } > "$root/scripts/run-all-harnesses.sh"
  chmod +x "$root/scripts/run-all-harnesses.sh"

  printf '%s' "$root"
}

ALL="skills/alpha/scripts/one.test.sh skills/beta/two.test.sh hooks/three.test.py"

echo "--- the check's own contract ---"

# GREEN: the runner lists every harness on disk.
# shellcheck disable=SC2086
G=$(build_fixture green $ALL)
bash "$CHECK" "$G" >/dev/null 2>&1
expect "$( [ $? -eq 0 ] && echo 1 || echo 0 )" "complete runner inventory -> PASSES"

# RED 1 — the real defect: a harness exists that the runner would not run.
R1=$(build_fixture narrowed "skills/alpha/scripts/one.test.sh" "skills/beta/two.test.sh")
out=$(bash "$CHECK" "$R1" 2>&1); rc=$?
expect "$( [ $rc -ne 0 ] && echo 1 || echo 0 )" "runner glob narrowed (harness unscheduled) -> FAILS"
expect "$(printf '%s' "$out" | grep -q 'hooks/three.test.py' && echo 1 || echo 0)" \
  "  ...and NAMES the unscheduled harness"

# RED 2 — no workflow invokes the runner: the suite exists but nothing schedules it.
# shellcheck disable=SC2086
R2=$(build_fixture unscheduled $ALL)
printf 'name: CI\njobs:\n  lint:\n    steps:\n      - run: bash lint.sh\n' > "$R2/.github/workflows/ci.yml"
out=$(bash "$CHECK" "$R2" 2>&1); rc=$?
expect "$( [ $rc -ne 0 ] && echo 1 || echo 0 )" "no workflow references the runner -> FAILS"
expect "$(printf '%s' "$out" | grep -q 'unscheduled' && echo 1 || echo 0)" \
  "  ...and says the suite is unscheduled"

# RED 3 — the runner itself is gone.
# shellcheck disable=SC2086
R3=$(build_fixture no-runner $ALL)
rm -f "$R3/scripts/run-all-harnesses.sh"
bash "$CHECK" "$R3" >/dev/null 2>&1
expect "$( [ $? -ne 0 ] && echo 1 || echo 0 )" "runner missing entirely -> FAILS"

# RED 4 — nothing to check must never read as a pass (the NOT-GATED case).
R4=$(build_fixture empty)
rm -f "$R4/skills/alpha/scripts/one.test.sh" "$R4/skills/beta/two.test.sh" "$R4/hooks/three.test.py"
out=$(bash "$CHECK" "$R4" 2>&1); rc=$?
expect "$( [ $rc -ne 0 ] && echo 1 || echo 0 )" "zero harnesses found -> FAILS (verified nothing)"
expect "$(printf '%s' "$out" | grep -q 'NOT-GATED' && echo 1 || echo 0)" \
  "  ...and says NOT-GATED"

echo "--- against the live repo ---"
# Ties the fixtures to reality: the same check, the real runner, the real inventory.
bash "$CHECK" "$AC_ROOT" >/dev/null 2>&1
expect "$( [ $? -eq 0 ] && echo 1 || echo 0 )" "every harness in THIS repo is scheduled"

echo ""
echo "harness-scheduling-check.test: ${CASES} cases, ${FAILURES} failures"
[ "$FAILURES" -eq 0 ]
