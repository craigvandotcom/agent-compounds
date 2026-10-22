#!/usr/bin/env bash
# defer-to-project.sh <hook-file> [args] — run one of this registry's hooks, unless the
# session's project carries and wires its own, different copy of it: a file at
# <project>/hooks/<hook-file> that <project>/.claude/settings.json names. That copy then
# speaks and this one stays silent, so a hook wired machine-wide and by the project runs
# once. Every {HOOKS} command in engine/hooks.wiring.json runs through here.
#
# A .md payload is printed; a script is exec'd with stdin and args, its exit code intact.
# When in doubt (no project, no copy, copy not wired, same file) the hook runs.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
name="${1:?usage: defer-to-project.sh <hook-file> [args]}"
shift
hook="$here/$name"
proj="${CLAUDE_PROJECT_DIR:-}"

if [ -n "$proj" ] && [ -f "$proj/hooks/$name" ] \
  && [ "$(realpath "$proj/hooks/$name")" != "$(realpath "$hook")" ] \
  && grep -qF "hooks/$name" "$proj/.claude/settings.json" 2>/dev/null; then
  exit 0
fi

case "$name" in
  *.md) exec cat "$hook" ;;
  *) exec "$hook" "$@" ;;
esac
