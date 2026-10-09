#!/usr/bin/env bash
#
# autopilot.sh — the one reader of a project's .claude/factory.json "autopilot" block.
#
# ASSURANCE
#   PROBE:      bash skills/_tools/autopilot.test.sh
#   SCHEDULE:   every unattended pick, commit-lane check and gate (callers are switched by sibling beads)
#   MODE:       blocking
#   ON-FAILURE: closed
#
# Verbs
#   active                exit 0 only when AC2_AUTOPILOT=1 and the block has enabled:true.
#                         Exit 1 otherwise; a missing block or an unset switch is inactive.
#   get <key>             print autopilot.<key> raw; exit 1 when the key is absent.
#   protected <path>...   print each path the block's protect ERE matches; exit 0 if any matched,
#                         exit 1 if none.  One engine: grep -E.  Reads the declared list whether or
#                         not the switch is set or the block is enabled.
#                         .beads/issues.jsonl is never protected: the ledger commit shares the lane.
#
# Exit codes: 0 yes/match · 1 no/inactive · 2 NOT-GATED · 64 usage.
#
# NOT-GATED (exit 2, fail closed): AC2_AUTOPILOT=1 and the file is unreadable or not JSON, the
# block is not an object, enabled is not a boolean, max_priority is not a non-negative integer,
# or protect is missing, empty, an invalid ERE (grep exit 2) or an ERE that matches the empty
# string (it would match every path).  An empty `grep -E ''` matches everything, so an empty
# list is refused rather than read as "protect all" or "protect nothing".
set -uo pipefail

LEDGER=.beads/issues.jsonl

notgated() {
  printf 'NOT-GATED: autopilot.sh — %s\n' "$*" >&2
  exit 2
}

usage() {
  printf 'usage: autopilot.sh active | get <key> | protected <path>...\n' >&2
  exit 64
}

verb=${1:-}
[ -n "$verb" ] || usage
shift
case "$verb" in
  active) [ "$#" -eq 0 ] || usage ;;
  get) [ "$#" -eq 1 ] && [ -n "$1" ] || usage ;;
  protected) [ "$#" -ge 1 ] || usage ;;
  *) usage ;;
esac

# `active` never reads the file unless the switch is on.
SWITCH=0
[ "${AC2_AUTOPILOT:-}" = 1 ] && SWITCH=1
if [ "$verb" = active ] && [ "$SWITCH" -eq 0 ]; then
  exit 1
fi

# Project root: the repository the caller stands in, else the cwd.
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || ROOT=$PWD
FILE="$ROOT/.claude/factory.json"

# A project that cannot be read is NOT-GATED when the switch is on, plain inactive otherwise.
unreadable() {
  if [ "$SWITCH" -eq 1 ]; then notgated "$1"; fi
  exit 1
}

command -v jq >/dev/null 2>&1 || unreadable "jq not found"
[ -r "$FILE" ] || unreadable "cannot read $FILE"
jq -e . "$FILE" >/dev/null 2>&1 || unreadable "$FILE is not valid JSON"

# Missing block → inactive / nothing protected.
jq -e 'type == "object" and has("autopilot")' "$FILE" >/dev/null 2>&1 || exit 1
jq -e '.autopilot | type == "object"' "$FILE" >/dev/null 2>&1 \
  || notgated "autopilot in $FILE is not an object"

ENABLED=$(jq -r '.autopilot.enabled // false | if type == "boolean" then tostring else "invalid" end' "$FILE")
[ "$ENABLED" != invalid ] || notgated "autopilot.enabled in $FILE is not a boolean"

# A disabled block asks nothing of its other keys.
if [ "$verb" = active ] && [ "$ENABLED" = false ]; then
  exit 1
fi

jq -e '.autopilot.max_priority | type == "number" and . >= 0 and . == floor' "$FILE" >/dev/null 2>&1 \
  || notgated "autopilot.max_priority in $FILE is missing or not a non-negative integer"

PROTECT=$(jq -r '.autopilot.protect | if type == "string" then . else "" end' "$FILE")
[ -n "$PROTECT" ] || notgated "autopilot.protect in $FILE is missing or empty"

# Compile the ERE once against empty input: grep exit 2 is a malformed pattern.
printf '' | grep -E -- "$PROTECT" >/dev/null 2>&1
[ "$?" -ne 2 ] || notgated "autopilot.protect in $FILE is not a valid ERE"
printf '\n' | grep -qE -- "$PROTECT" \
  && notgated "autopilot.protect in $FILE matches the empty string, so it would match every path"

case "$verb" in
  active)
    exit 0
    ;;
  get)
    VAL=$(jq -r --arg k "$1" 'if (.autopilot | has($k)) and .autopilot[$k] != null
      then .autopilot[$k] | if type == "string" then . else tojson end
      else empty end' "$FILE")
    [ -n "$VAL" ] || exit 1
    printf '%s\n' "$VAL"
    exit 0
    ;;
  protected)
    HIT=1
    for p in "$@"; do
      norm=$p
      while [ "${norm#./}" != "$norm" ]; do norm=${norm#./}; done
      [ "$norm" = "$LEDGER" ] && continue
      printf '%s\n' "$norm" | grep -qE -- "$PROTECT"
      case $? in
        0) printf '%s\n' "$p"; HIT=0 ;;
        1) ;;
        *) notgated "grep failed on autopilot.protect in $FILE" ;;
      esac
    done
    exit "$HIT"
    ;;
esac
