#!/usr/bin/env bash
# board.sh — the whole ac-board render in one call (read-only).
#
# Runs every board read concurrently, then hands the results to render.py, which renders the
# board deterministically: counts come from code, never from a model bucketing raw JSON.
#
# Scan E (scheduled-CI health) and docket-health EXECUTE the fenced blocks in
# ac-pipeline/references/board-scan.md — the text ci-gate-health.test.sh proves. Never copy
# a scan in here.
#
# Usage:  board.sh [--compact] [--json]  (from inside the project; --compact = the verdict
#                                   line only, the org-wide one-line-per-repo view; --json
#                                   prints model.build()'s dict instead of rendering — the
#                                   combinable machine-readable form)
#         board.sh --watch [secs]  the terminal dashboard (tui.py): redraws every secs
#                                  (default 15); network reads refresh every CACHE_S
#         board.sh --others       one other beads repo this machine deploys to per line
#                                  (tui.py's footer source; not a board render)
# Env:    AC_BOARD_FETCH_TIMEOUT (default 5s) bounds `git fetch`; past it, waves count the
#         refs of the last fetch and the flags line says so.
# Exit:   0 rendered (a failed read renders `?` and is named in the flags line);
#         2 not inside a git repo.

COMPACT=0; JSON=0; WATCH=0; SECS=15
for a in "$@"; do
  case "$a" in
    --compact) COMPACT=1 ;;
    --json) JSON=1 ;;
    --watch) WATCH=1 ;;
    [0-9]*) SECS=$a ;;
  esac
done

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "board: not a git repo"; exit 2; }
export PROJECT_ROOT
SELF=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
SKILLS=$(cd "$SELF/../.." && pwd)

others() {  # every other beads repo this machine deploys to, plus the registry itself
  { "$SKILLS/../engine/machine.sh" --targets 2>/dev/null | cut -f1; (cd "$SKILLS/.." && pwd); } |
    sort -u | while read -r p; do [ "$p" != "$PROJECT_ROOT" ] && [ -d "$p/.beads" ] && echo "$p"; done
}
[ "${1:-}" = --others ] && { others; exit 0; }

if [ "$WATCH" = 1 ]; then
  STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ac-board/$(basename "$PROJECT_ROOT")"
  mkdir -p "$STATE_DIR/cache"
  export AC_BOARD_CACHE="$STATE_DIR/cache"
  exec python3 "$SELF/tui.py" "$SECS"
fi

DOC="$SKILLS/ac-pipeline/references/board-scan.md"
BR_CALL="$SKILLS/_tools/br-call.sh"
CACHE_S=300
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cd "$PROJECT_ROOT" || exit 2

block() {  # block <heading-regex> — the first ```bash fence under that heading in board-scan.md
  local src
  src=$(awk -v h="$1" '$0 ~ h {s=1} s&&/^```bash$/{f=1;next} f&&/^```$/{exit} f' "$DOC")
  [ -n "$src" ] && printf '%s' "$src" || printf 'echo "board-scan.md: no bash fence under %s" >&2; exit 2' "$1"
}

job() {  # job <name> <seconds> <bash-source> — run in the background; .out/.err/.rc land in $T
  local name=$1 secs=$2 src=$3
  ( timeout "$secs" bash -c ". '$BR_CALL'; $src" >"$T/$name.out" 2>"$T/$name.err"
    echo $? >"$T/$name.rc" ) &
}

slow() {  # slow <job args> — a network read; the watch dashboard reuses an answer under CACHE_S
  local c="${AC_BOARD_CACHE:-}/$1"
  if [ -n "${AC_BOARD_CACHE:-}" ] && [ -f "$c.rc" ] && [ "$(( $(date +%s) - $(stat -c %Y "$c.rc") ))" -lt "$CACHE_S" ]; then
    cp -p "$c.out" "$c.err" "$c.rc" "$T/"; return
  fi
  job "$@"
}

job beads  20 'br_call list --limit 0 --json'
job ready  20 'br_call ready --limit 0 --json'
if [ "$COMPACT" = 0 ]; then
  job docket 20 "$(block '^### Docket health')"
  slow ci     60 "ARTIFACTS_DIR='$T/ci'; $(block '^## Scan E')"
  job truth  30 "'$SKILLS/ac-pipeline/scripts/board-truth.sh'"
  slow waves  "$(( ${AC_BOARD_FETCH_TIMEOUT:-5} + 5 ))" \
    "timeout ${AC_BOARD_FETCH_TIMEOUT:-5} git fetch --prune --quiet || echo 'git fetch failed — waves as of last fetch' >&2
     git branch -r --list '*wave/*'"
  slow prs    15 'gh pr list --state open --json number,title,createdAt,isDraft,statusCheckRollup'
fi
job triage  5 "'$SKILLS/ac-triage/scripts/triage-gate.sh' --status"
job roster 15 "python3 '$SELF/agent-roster.py'"   # compact too: the verdict needs live agents
wait

if [ -n "${AC_BOARD_CACHE:-}" ]; then  # keep fresh network answers; a failure is never cached
  for n in ci waves prs; do
    [ "$(cat "$T/$n.rc" 2>/dev/null)" = 0 ] && [ "$T/$n.rc" -nt "$AC_BOARD_CACHE/$n.rc" ] &&
      cp "$T/$n.out" "$T/$n.err" "$T/$n.rc" "$AC_BOARD_CACHE/"
  done
fi

if [ "$JSON" = 1 ]; then
  python3 "$SELF/model.py" "$T" "$PROJECT_ROOT" "$COMPACT"
else
  python3 "$SELF/render.py" "$T" "$PROJECT_ROOT" "$COMPACT"
fi
