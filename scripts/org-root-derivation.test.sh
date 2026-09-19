#!/usr/bin/env bash
# org-root-derivation.test.sh — proof harness for engine/org-root.sh.
#
# WHY this exists: ORG_ROOT anchors every rendered path that is not under AC_ROOT. A
# wrong value does not fail — it writes plausible-looking garbage into every harness on
# the machine and is discovered weeks later by a 404. The old derivation (AC_ROOT's
# THIRD parent, copied into engine/sync.sh, engine/exceptions.sh, and as "five parents
# up" into lint/lib/consumers.py) was such a value on any layout where agent-compounds
# is not two directories deep: on ~/code/agent-compounds it yielded /Users, and the
# engine rendered `$HOME/Users/infrastructure/tools/src/lib/activity_logger.py` into a
# deploy target's PostToolUse hook — an absolute path resolving nowhere, firing on every
# tool call. `cd /Users` succeeded, so nothing downstream ever checked. lint checks 07
# and 12 went NOT-CHECKED from the same cause while reporting it as an empty machine.
#
# WHY fixtures: the layouts being proven cannot coexist on one machine, and the one that
# regressed (flat) is the one this machine actually has. Each case builds a throwaway
# tree under $TMPDIR and asks the REAL canon — sourced from engine/org-root.sh, never
# copied — what it resolves to.
#
# Exit 0 = all cases pass · 77 = self-skip (reported loudly, never a silent green).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CANON="$REPO_ROOT/engine/org-root.sh"
CASES=0
FAILURES=0
SKIPS=0

# cd/pwd, not the raw mktemp path: $TMPDIR carries a trailing slash on macOS, and the
# resulting `//` compares unequal against the same path after the canon normalizes it.
WORK="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/org-root.XXXXXX")" && pwd)"
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

skip() { SKIPS=$((SKIPS + 1)); printf '  SKIP  %s — %s\n' "$1" "$2"; }

[ -f "$CANON" ] || { echo "SKIP: $CANON missing"; exit 77; }
command -v jq >/dev/null || { echo "SKIP: jq not installed"; exit 77; }

# resolve <ac-root> [org_root-json-value] — run the real canon against a fixture.
# Echoes its stdout; returns its exit status.
resolve() {
  local ac="$1"
  local org="${2-}"
  local layout="$ac/harness.config.json"
  mkdir -p "$ac"
  if [ -n "$org" ]; then
    printf '{"targets":["../*"],"harnesses":{},"org_root":"%s"}\n' "$org" > "$layout"
  else
    printf '{"targets":["../*"],"harnesses":{}}\n' > "$layout"
  fi
  AC_ROOT="$ac" LAYOUT="$layout" CANON="$CANON" bash -c '
    set -uo pipefail
    . "$CANON"
    resolve_org_root
  '
}

# layout <path-under-WORK> <infra-parent-under-WORK> — build a fixture, echo its AC_ROOT
layout() {
  local ac="$WORK/$1" infra="$WORK/$2"
  mkdir -p "$ac" "$infra/infrastructure"
  echo "$ac"
}

echo "== org-root derivation"

# --- 1. flat layout: THE REGRESSION -------------------------------------------------
AC="$(layout flat/code/agent-compounds flat)"
got="$(resolve "$AC")"
expect "$([ "$got" = "$WORK/flat" ] && echo 1 || echo 0)" \
  "flat ~/code/agent-compounds -> org root (got: ${got:-<empty>})"

# and prove the OLD derivation would have been wrong here, so this case keeps
# documenting the defect it guards rather than becoming an opaque equality check.
old="$(cd "$AC/../../.." && pwd)"
expect "$([ "$old" != "$WORK/flat" ] && echo 1 || echo 0)" \
  "flat layout defeats the old third-parent derivation (it gives: $old)"

# --- 2. three-repo layout ------------------------------------------------------------
AC="$(layout three/mission/software/agent-compounds three)"
got="$(resolve "$AC")"
expect "$([ "$got" = "$WORK/three" ] && echo 1 || echo 0)" \
  "three-repo ~/mission/software/agent-compounds -> ~ (got: ${got:-<empty>})"

# --- 3. Mac monorepo layout ----------------------------------------------------------
AC="$(layout mono/Repos/org/software/agent-compounds mono/Repos)"
got="$(resolve "$AC")"
expect "$([ "$got" = "$WORK/mono/Repos" ] && echo 1 || echo 0)" \
  "Mac monorepo ~/Repos/<org>/software/agent-compounds -> ~/Repos (got: ${got:-<empty>})"

# --- 4. nearest marker wins ----------------------------------------------------------
# Two infrastructure/ dirs on the path; the walk must stop at the first one up, not the
# furthest. A walk that ran to the top would silently pick the wrong org on a nested org.
AC="$(layout near/code/agent-compounds near)"
mkdir -p "$WORK/near/code/infrastructure"
got="$(resolve "$AC")"
expect "$([ "$got" = "$WORK/near/code" ] && echo 1 || echo 0)" \
  "nearest infrastructure/ wins over a further one (got: ${got:-<empty>})"

# --- 5. explicit org_root overrides the walk -----------------------------------------
AC="$(layout override/code/agent-compounds override)"
mkdir -p "$WORK/elsewhere"
got="$(resolve "$AC" "$WORK/elsewhere")"
expect "$([ "$got" = "$WORK/elsewhere" ] && echo 1 || echo 0)" \
  "org_root key beats the marker walk (got: ${got:-<empty>})"

# --- 6. explicit org_root that is not a directory is FATAL ---------------------------
AC="$(layout badoverride/code/agent-compounds badoverride)"
got="$(resolve "$AC" "$WORK/does-not-exist" 2>/dev/null)"; rc=$?
expect "$([ "$rc" = 2 ] && echo 1 || echo 0)" \
  "org_root pointing at a non-directory exits 2 (got rc=$rc)"
expect "$([ -z "$got" ] && echo 1 || echo 0)" \
  "...and prints no path on stdout that a caller could mistake for success"

# --- 7. unresolvable is FATAL, never a guess -----------------------------------------
# Only meaningful when no REAL ancestor of $WORK happens to carry infrastructure/.
probe="$(dirname "$WORK")"; contaminated=0
while [ "$probe" != "/" ]; do
  [ -d "$probe/infrastructure" ] && { contaminated=1; break; }
  probe="$(dirname "$probe")"
done
[ -d "/infrastructure" ] && contaminated=1
if [ "$contaminated" = 1 ]; then
  skip "unresolvable layout exits 2" "a real ancestor of $WORK carries infrastructure/"
else
  mkdir -p "$WORK/orphan/code/agent-compounds"
  got="$(resolve "$WORK/orphan/code/agent-compounds" 2>/dev/null)"; rc=$?
  expect "$([ "$rc" = 2 ] && echo 1 || echo 0)" \
    "no infrastructure/ anywhere exits 2 rather than guessing (got rc=$rc)"
  expect "$([ -z "$got" ] && echo 1 || echo 0)" \
    "...and emits no ORG_ROOT on stdout"
fi

# --- 8. the live repo resolves ------------------------------------------------------
# Fixtures can prove a function the real checkout never exercises. This case keeps them
# honest: whatever layout this machine has, the shipped canon must resolve on it.
live="$(AC_ROOT="$REPO_ROOT" LAYOUT="$REPO_ROOT/harness.config.json" CANON="$CANON" bash -c '
  set -uo pipefail
  . "$CANON"
  resolve_org_root
')"; rc=$?
expect "$([ "$rc" = 0 ] && [ -d "${live:-/nonexistent}" ] && echo 1 || echo 0)" \
  "the live checkout resolves to an existing directory (got: ${live:-<empty>}, rc=$rc)"

# --- 9. the Python twin agrees ------------------------------------------------------
# lint/lib/consumers.py cannot source the shell canon, so it carries the same walk.
# Two implementations that silently disagree is how checks 07 and 12 went NOT-CHECKED
# while the engine was happily rendering paths — so assert they agree, here.
PY=""
for cand in python3 /opt/homebrew/bin/python3 /usr/bin/python3; do
  command -v "$cand" >/dev/null 2>&1 && { PY="$cand"; break; }
done
if [ -z "$PY" ]; then
  skip "python twin agrees with the shell canon" "no python3 on PATH"
elif [ ! -f "$REPO_ROOT/lint/lib/consumers.py" ]; then
  skip "python twin agrees with the shell canon" "lint/lib/consumers.py absent"
else
  pygot="$(cd "$REPO_ROOT" && env -u LINT_CONSUMER_BASE "$PY" -c '
import sys
sys.path.insert(0, "lint/lib")
import consumers
print(consumers.base())
' 2>/dev/null)"
  expect "$([ -n "$pygot" ] && [ "$pygot" = "$live" ] && echo 1 || echo 0)" \
    "lint/lib/consumers.py agrees with engine/org-root.sh (py: ${pygot:-<empty>}, sh: ${live:-<empty>})"
fi

# --- 10. nothing counts parents any more --------------------------------------------
# The defect's signature is `../../..` standing in for the org root. Guard against it
# coming back into the engine by copy-paste; fixtures under lint/ resolve to their own
# repo root and are a different thing, so only engine/ is in scope.
strays="$(grep -rn '\.\./\.\./\.\.' "$REPO_ROOT/engine" 2>/dev/null | grep -v '^\s*#' | grep -vi 'hooks.d\|60-ac-lint' || true)"
expect "$([ -z "$strays" ] && echo 1 || echo 0)" \
  "no engine/ file derives a root by counting parents${strays:+ (found: $strays)}"

echo
if [ "$CASES" = 0 ]; then
  echo "FAIL: no cases ran — the harness verified nothing" >&2
  exit 1
fi
printf 'cases=%d failures=%d skips=%d\n' "$CASES" "$FAILURES" "$SKIPS"
[ "$FAILURES" = 0 ] || exit 1
exit 0
