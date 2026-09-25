#!/usr/bin/env bash
# project-key-guard.test.sh — Layer-2 must use the AGENTS.md project key, never cwd.
#
# A grep-for-/Users/ assertion already passes and proves nothing (bd-8kdjl). This
# guard extracts the key resolver ac-land publishes and runs it against a fixture
# AGENTS.md and the live repo.
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

# The spine may delegate the pin detail to references/teardown.md (the diet's home
# for it); either location naming the pin source counts.
expect "$( { grep -q 'Agent Mail project key' "$AC_LAND" || grep -q 'Agent Mail project key' "$SCRIPT_DIR/../references/teardown.md"; } && echo 1 || echo 0 )" \
  "ac-land names the AGENTS.md project-key line as the key source"

# Must not assign cwd / git root / PROJECT_ROOT as the key (prose forbidding that is fine).
if grep -nE 'project_key: *(\$PROJECT_ROOT|\$\(git rev-parse|\$\(pwd)|human_key: *(\$PROJECT_ROOT|\$\(git rev-parse|\$\(pwd)' "$AC_LAND" >/dev/null; then
  expect 0 "ac-land must not assign cwd/git-root as project_key"
else
  expect 1 "ac-land must not assign cwd/git-root as project_key"
fi

# Extract the resolver ac-land publishes and run it against a fixture pin.
FIXTURE=$(mktemp -d /tmp/project-key-guard-XXXXXX)
printf '# x\n\nAgent Mail project key: `example-app`\n' > "$FIXTURE/AGENTS.md"
# The resolver is the sed one-liner published in ac-land — extract it, don't rewrite it.
# The diet moved the teardown block (and the resolver with it) to references/teardown.md;
# read the spine first, fall back to the indirection it names.
RESOLVER=$(awk '/PINNED_KEY=\$\(sed/{flag=1} flag{print} /head -1/{if(flag) exit}' "$AC_LAND")
if [ -z "$RESOLVER" ]; then
  RESOLVER=$(awk '/PINNED_KEY=\$\(sed/{flag=1} flag{print} /head -1/{if(flag) exit}' "$SCRIPT_DIR/../references/teardown.md")
fi
if [ -z "$RESOLVER" ]; then
  expect 0 "ac-land publishes a PINNED_KEY=sed resolver"
else
  expect 1 "ac-land publishes a PINNED_KEY=sed resolver"
  GOT=$(cd "$FIXTURE" && eval "$RESOLVER" && printf '%s' "$PINNED_KEY")
  if [ "$GOT" = "example-app" ]; then
    expect 1 "resolver against fixture AGENTS.md returns example-app"
  else
    expect 0 "resolver against fixture AGENTS.md returns example-app (got: $GOT)"
  fi
fi
rm -rf "$FIXTURE"

# Live check: the repo this test runs in resolves a slash-free key that is its own name.
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/AGENTS.md" ] && [ -n "$RESOLVER" ]; then
  GOT=$(cd "$REPO_ROOT" && eval "$RESOLVER" && printf '%s' "$PINNED_KEY")
  if [ "$GOT" = "$(basename "$REPO_ROOT")" ]; then
    expect 1 "live key equals the repo name ($GOT)"
  else
    expect 0 "live key equals the repo name (got: $GOT)"
  fi
else
  echo "  SKIP  live key check (no AGENTS.md at the git root)"
fi

echo ""
echo "project-key-guard.test: ${CASES} cases, ${FAILURES} failures"
[ "$FAILURES" -eq 0 ]
