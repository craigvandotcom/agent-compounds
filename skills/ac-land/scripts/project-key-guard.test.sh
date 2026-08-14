#!/usr/bin/env bash
# project-key-guard.test.sh — Layer-2 must use the pinned session-start key, never cwd.
#
# A grep-for-/Users/ assertion already passes and proves nothing (bd-8kdjl). This
# guard extracts the key ac-land instructs the agent to use and compares it to the
# pinned human_key in session-start.md.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AC_LAND="$SCRIPT_DIR/../SKILL.md"
FAILURES=0
CASES=0

expect() {
  CASES=$((CASES + 1))
  if [ "$1" = 1 ]; then
    printf '  PASS  %s\n' "$2"
  else
    printf '  FAIL  %s\n' "$2"
    FAILURES=$((FAILURES + 1))
  fi
}

echo "--- ac-land Layer-2 project-key resolution ---"

expect "$(grep -c 'session-start.md' "$AC_LAND" | awk '{print ($1>=1)?1:0}')" \
  "ac-land names .claude/hooks/session-start.md as the pin source"

# Must not assign cwd / git root / PROJECT_ROOT as the key (prose forbidding that is fine).
if grep -nE 'project_key: *(\$PROJECT_ROOT|\$\(git rev-parse|\$\(pwd)|human_key: *(\$PROJECT_ROOT|\$\(git rev-parse|\$\(pwd)' "$AC_LAND" >/dev/null; then
  expect 0 "ac-land must not assign cwd/git-root as project_key"
else
  expect 1 "ac-land must not assign cwd/git-root as project_key"
fi

# Extract the resolver ac-land publishes and run it against a fixture pin.
FIXTURE=$(mktemp -d /tmp/project-key-guard-XXXXXX)
mkdir -p "$FIXTURE/.claude/hooks"
printf '%s\n' '  human_key: "neometa/body-compass-app",' > "$FIXTURE/.claude/hooks/session-start.md"
# The resolver is the sed one-liner published in ac-land — extract it, don't rewrite it.
RESOLVER=$(awk '/PINNED_KEY=\$\(sed/{flag=1} flag{print} /head -1/{if(flag) exit}' "$AC_LAND")
if [ -z "$RESOLVER" ]; then
  expect 0 "ac-land publishes a PINNED_KEY=sed resolver"
else
  expect 1 "ac-land publishes a PINNED_KEY=sed resolver"
  GOT=$(cd "$FIXTURE" && eval "$RESOLVER" && printf '%s' "$PINNED_KEY")
  if [ "$GOT" = "neometa/body-compass-app" ]; then
    expect 1 "resolver against fixture pin returns neometa/body-compass-app"
  else
    expect 0 "resolver against fixture pin returns neometa/body-compass-app (got: $GOT)"
  fi
fi
rm -rf "$FIXTURE"

# Live compare when this checkout (or a sibling app) has a session-start pin.
# Walk up from cwd looking for .claude/hooks/session-start.md — works when the
# test is invoked from body-compass-app or any neoMeta app.
PIN_FILE=""
d=$(pwd)
while [ "$d" != / ]; do
  if [ -f "$d/.claude/hooks/session-start.md" ]; then
    PIN_FILE="$d/.claude/hooks/session-start.md"
    break
  fi
  d=$(dirname "$d")
done
if [ -z "$PIN_FILE" ] && [ -f /Users/craigvanheerden/Repos/neometa/software/body-compass-app/.claude/hooks/session-start.md ]; then
  PIN_FILE=/Users/craigvanheerden/Repos/neometa/software/body-compass-app/.claude/hooks/session-start.md
fi

if [ -n "$PIN_FILE" ]; then
  PINNED=$(sed -n 's/.*human_key: *"\(neometa\/[^"]*\)".*/\1/p' "$PIN_FILE" | head -1)
  REPO_ROOT=$(cd "$(dirname "$PIN_FILE")/../.." && pwd)
  GOT=$(cd "$REPO_ROOT" && eval "$RESOLVER" && printf '%s' "$PINNED_KEY")
  if [ -n "$PINNED" ] && [ "$GOT" = "$PINNED" ]; then
    expect 1 "live resolver key equals pinned human_key ($PINNED)"
  else
    expect 0 "live resolver key equals pinned human_key (pinned=$PINNED got=$GOT)"
  fi
else
  echo "  SKIP  live pin compare (no session-start.md in cwd ancestry)"
fi

echo ""
echo "project-key-guard.test: ${CASES} cases, ${FAILURES} failures"
[ "$FAILURES" -eq 0 ]
