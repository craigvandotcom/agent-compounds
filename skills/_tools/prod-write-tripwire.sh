#!/usr/bin/env bash
# prod-write-tripwire.sh — one sourceable home for the prod-write signal classifier.
#
# The predicate itself is judgment (beads-standards/reference/bead-conventions.md
# § The prod-write gate predicate). This tripwire is the mechanical backstop: when a
# description matches a prod-write SIGNAL, it must carry either the reader's recorded
# negative verdict or the board's sensitive-prod + DECISION blocks gate pair. The tool
# never writes a label or an edge; it only returns PASS / REFUSED / NOT-GATED.
#
# Usage:
#   . <path>/prod-write-tripwire.sh
#   prod_write_tripwire_check <description-file> <comma-labels> <decision-block-count> [label]
#   bash <path>/prod-write-tripwire.sh <description-file> <comma-labels> <decision-block-count> [label]
#
# Exit codes:
#   0  PASS       — no signal, or a recorded negative/gate verdict covers the signal
#   1  REFUSED    — a signal has neither recorded verdict
#   2  NOT-GATED  — inputs could not be checked; never read as zero or PASS
#
# ASSURANCE (ac-pipeline/references/assurance-declarations.md):
#   PROBE:      skills/_tools/prod-write-tripwire.test.sh
#   SCHEDULE:   every refined stamp through stamp-refined.sh; every CI proof run
#   MODE:       blocking
#   ON-FAILURE: closed — a signal without a recorded verdict refuses the stamp
#
# Deliberately no `set -u` / `set -e` / `pipefail`: this file is sourced into
# stamp-refined.sh and must not leak shell options into its caller.

if [ -n "${ZSH_VERSION:-}" ]; then
  _PROD_WRITE_TRIPWIRE_SELF="$0"
else
  _PROD_WRITE_TRIPWIRE_SELF="${BASH_SOURCE[0]}"
fi

_prod_write_signal() { # <description-file> -> "<class>\t<matched line>" or exit 1
  local file="$1" match
  if match=$(grep -Em1 -- \
    'execute|supabase[[:space:]]+db[[:space:]]+push|--linked|--project-ref|[.]supabase[.]co|psql' \
    "$file"); then
    printf 'mechanism\t%s\n' "$match"
    return 0
  fi
  if match=$(grep -Em1 -- \
    'UPDATE[[:space:]]+[A-Za-z_][A-Za-z0-9_.]*[[:space:]]+SET|INSERT[[:space:]]+INTO|DELETE[[:space:]]+FROM|TRUNCATE' \
    "$file"); then
    printf 'SQL write\t%s\n' "$match"
    return 0
  fi
  if match=$(grep -Eim1 -- \
    'backfill|data[ -]fix|one-off.{0,80}(write|update|fix|script)|prod(uction)?[[:space:][:punct:]]+(rows?|data|table|database|db)' \
    "$file"); then
    printf 'data-state\t%s\n' "$match"
    return 0
  fi
  return 1
}

prod_write_tripwire_check() { # <description-file> <labels> <decision-count> [message-label]
  local file="${1:-}" labels="${2:-}" decisions="${3:-}" label="${4:-${file:-description}}"
  local signal signal_rc class match negative

  if [ -z "$file" ] || [ ! -f "$file" ] || [ ! -r "$file" ]; then
    printf 'prod-write: NOT-GATED %s — no readable description file at "%s"; nothing was checked.\n' \
      "$label" "${file:-<none>}" >&2
    return 2
  fi
  if ! printf '%s' "$decisions" | grep -Eq '^[0-9]+$'; then
    printf 'prod-write: NOT-GATED %s — DECISION blocks count must be a non-negative integer, got "%s"; nothing was checked.\n' \
      "$label" "$decisions" >&2
    return 2
  fi

  negative=$(grep -Em1 -- \
    '^prod-write:[[:space:]]+none[[:space:]]+—[[:space:]]+[^[:space:]].*$' "$file" || true)
  if [ -n "$negative" ]; then
    printf 'prod-write: OK %s — recorded negative verdict: %s\n' "$label" "$negative"
    return 0
  fi

  signal=$(_prod_write_signal "$file"); signal_rc=$?
  if [ "$signal_rc" -ne 0 ]; then
    printf 'prod-write: OK %s — no prod-write signal matched.\n' "$label"
    return 0
  fi
  class=${signal%%$'\t'*}
  match=${signal#*$'\t'}

  case ",$labels," in
    *,sensitive-prod,*)
      if [ "$decisions" -gt 0 ]; then
        printf 'prod-write: OK %s — gate pair present: sensitive-prod + %s DECISION blocks edge(s).\n' \
          "$label" "$decisions"
        return 0
      fi
      ;;
  esac

  printf 'prod-write: REFUSED %s — [%s] matched "%s", but the bead has a missing recorded gate pair: add a non-empty `prod-write: none — <reason>` verdict or wire sensitive-prod + a DECISION blocks edge.\n' \
    "$label" "$class" "$match" >&2
  return 1
}

_PROD_WRITE_TRIPWIRE_DIRECT=0
if [ -n "${ZSH_VERSION:-}" ]; then
  [ "${zsh_eval_context[-1]-}" = toplevel ] && _PROD_WRITE_TRIPWIRE_DIRECT=1
else
  [ "${BASH_SOURCE[0]-}" = "${0}" ] && _PROD_WRITE_TRIPWIRE_DIRECT=1
fi

if [ "$_PROD_WRITE_TRIPWIRE_DIRECT" = 1 ]; then
  if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
    printf 'usage: %s <description-file> <comma-labels> <decision-block-count> [label]\n' "$0" >&2
    exit 2
  fi
  prod_write_tripwire_check "$@"
  exit $?
fi
