#!/usr/bin/env bash
#
# assurance-declarations-check.sh — every mechanism DECLARES its failure semantics,
# and no executable hides in hooks/ undeclared (ac-on0y.4).
#
# lint.sh Check 18 proves a guard CAN fire. Check 20 proves a proof test IS RUN. This
# proves a mechanism SAYS WHAT IT DOES WHEN IT BREAKS — because "wired" and "working"
# are different claims, and hooks/ contained a guard that had been fail-open against an
# empty store for months plus an executable with no wiring at all.
#
# Usage:  assurance-declarations-check.sh [<repo root>]
# Exit 0  every wiring entry and hooks/ executable carries a conforming declaration
# Exit 1  at least one does not (each reported as FAIL: ...)
#
# THE SCHEMA — four fields on each hooks.json wiring entry's `assurance` object:
#   PROBE       how you would show it is alive
#   SCHEDULE    what triggers it
#   MODE        blocking | advisory   (DECLARED, never inferred: hooks.json's event/matcher
#               shape cannot distinguish advisory skill-edit-guard from blocking
#               bead-capture-guard — they are both PreToolUse)
#   ON-FAILURE  open | closed
#
# FAIL-OPEN IS LEGAL ONLY FOR ADVISORY. A blocking mechanism declaring ON-FAILURE: open
# needs exactly one of two escapes, and both are self-expiring or verifiable:
#   PENDING-DECISION: <bead-id>  the fail-open is an UNRESOLVED fork. Valid only while the
#       cited bead is issue_type=="decision" AND status=="open", resolved by parsing the
#       committed .beads/issues.jsonl directly — NO br dependency, because br is a locally
#       installed binary absent from CI runners and lint.sh runs on ubuntu-latest. Citing a
#       closed, missing, or non-decision bead FAILS: a ruled decision must be executed, not
#       squatted on, and a stray open task cannot host the escape.
#   BACKSTOP: <named mechanism>  the fail-open is a RULED design with something else
#       catching what slips through. Added because bead-capture-guard is blocking and
#       deliberately fails open on unparseable shell (a guard must not wedge an unattended
#       3am loop) with the ac-bead-refine stamp-gate as its backstop — a real, decided case
#       that is not a pending decision. When the value names a path, that path must EXIST,
#       so a backstop cannot be a comforting sentence about a file nobody kept.
#
# ORPHAN DETECTION: an executable in hooks/ with neither a wiring entry nor a declared
# role is a failure. Roles: `ASSURANCE-ROLE: utility|test-harness` + `CALLER:` naming its
# real caller, or `ASSURANCE-ROLE: orphan` + the same PENDING-DECISION escape.
#
set -uo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
HOOKS_JSON="$ROOT/hooks/hooks.json"
BOARD="$ROOT/.beads/issues.jsonl"
FAILURES=0

ad_fail() { echo "FAIL: $*"; FAILURES=$(( FAILURES + 1 )); }

if [ ! -r "$HOOKS_JSON" ]; then
  ad_fail "hooks/hooks.json missing — wiring and its declarations unverifiable"
  echo "assurance-declarations: ${FAILURES} failure(s)"
  exit 1
fi

# resolve_pending <bead-id> -> 0 if it is an OPEN DECISION bead, else 1 with a reason
resolve_pending() {
  local id="$1" line
  if [ ! -r "$BOARD" ]; then
    echo "board .beads/issues.jsonl unreadable — cannot resolve PENDING-DECISION"
    return 1
  fi
  line=$(jq -c --arg id "$id" 'select(.id == $id)' "$BOARD" 2>/dev/null | head -1)
  if [ -z "$line" ]; then
    echo "cites '$id', which does not exist on the board"
    return 1
  fi
  local t s
  t=$(printf '%s' "$line" | jq -r '.issue_type // ""')
  s=$(printf '%s' "$line" | jq -r '.status // ""')
  if [ "$t" != "decision" ]; then
    echo "cites '$id', whose issue_type is '$t' — only a decision bead may host this escape"
    return 1
  fi
  if [ "$s" != "open" ]; then
    echo "cites '$id', which is '$s' — a ruled decision must be EXECUTED, not squatted on"
    return 1
  fi
  return 0
}

COUNT=$(jq '.wiring | length' "$HOOKS_JSON" 2>/dev/null || echo 0)
if [ "$COUNT" -eq 0 ]; then
  ad_fail "hooks.json declares ZERO wiring entries — this check verified nothing (NOT-GATED)"
  echo "assurance-declarations: ${FAILURES} failure(s)"
  exit 1
fi

i=0
while [ "$i" -lt "$COUNT" ]; do
  entry=$(jq -c ".wiring[$i]" "$HOOKS_JSON")
  hid=$(printf '%s' "$entry" | jq -r '.id // "<no id>"')

  if [ "$(printf '%s' "$entry" | jq -r 'has("assurance")')" != "true" ]; then
    ad_fail "wiring '$hid' carries no assurance declaration (needs PROBE, SCHEDULE, MODE, ON-FAILURE)"
    i=$(( i + 1 )); continue
  fi

  for f in PROBE SCHEDULE MODE ON-FAILURE; do
    v=$(printf '%s' "$entry" | jq -r --arg f "$f" '.assurance[$f] // ""')
    [ -n "$v" ] || ad_fail "wiring '$hid' declaration is missing field '$f'"
  done

  mode=$(printf '%s' "$entry" | jq -r '.assurance.MODE // ""')
  onf=$(printf '%s'  "$entry" | jq -r '.assurance["ON-FAILURE"] // ""')
  case "$mode" in blocking|advisory|"") ;; *) ad_fail "wiring '$hid' MODE '$mode' is not blocking|advisory" ;; esac
  case "$onf"  in open|closed|"")       ;; *) ad_fail "wiring '$hid' ON-FAILURE '$onf' is not open|closed" ;; esac

  if [ "$mode" = "blocking" ] && [ "$onf" = "open" ]; then
    pend=$(printf '%s' "$entry" | jq -r '.assurance["PENDING-DECISION"] // ""')
    back=$(printf '%s' "$entry" | jq -r '.assurance.BACKSTOP // ""')
    if [ -n "$pend" ]; then
      if ! why=$(resolve_pending "$pend"); then
        ad_fail "wiring '$hid' is blocking + fail-open and its PENDING-DECISION $why"
      fi
    elif [ -n "$back" ]; then
      # A backstop naming a path must name one that exists.
      bpath=$(printf '%s' "$back" | grep -oE '^[A-Za-z0-9_][A-Za-z0-9_./-]*\.[A-Za-z0-9]+' | head -1)
      if [ -n "$bpath" ] && [ ! -e "$ROOT/$bpath" ]; then
        ad_fail "wiring '$hid' BACKSTOP names '$bpath', which does not exist — a backstop nobody kept is not a backstop"
      fi
    else
      ad_fail "wiring '$hid' is MODE: blocking with ON-FAILURE: open and no escape — declare PENDING-DECISION: <open decision bead> or BACKSTOP: <named mechanism>"
    fi
  fi
  i=$(( i + 1 ))
done

# --- orphan detection ------------------------------------------------------
for f in "$ROOT"/hooks/*.py "$ROOT"/hooks/*.sh; do
  [ -e "$f" ] || continue
  base="${f##*/}"
  # Wired? The manifest references hooks by filename inside its command strings.
  if jq -e --arg b "$base" '[.wiring[] | select((.command // "") | contains($b))] | length > 0' \
       "$HOOKS_JSON" >/dev/null 2>&1; then
    continue
  fi
  role=$(grep -oE 'ASSURANCE-ROLE:[[:space:]]*[a-z-]+' "$f" 2>/dev/null | head -1 | sed -E 's/.*:[[:space:]]*//')
  case "$role" in
    utility|test-harness)
      grep -qE 'CALLER:[[:space:]]*[^[:space:]]' "$f" \
        || ad_fail "hooks/$base declares role '$role' but names no CALLER — an unnamed caller cannot be checked"
      ;;
    orphan)
      pend=$(grep -oE 'PENDING-DECISION:[[:space:]]*[A-Za-z0-9_.-]+' "$f" | head -1 | sed -E 's/.*:[[:space:]]*//')
      if [ -z "$pend" ]; then
        ad_fail "hooks/$base declares role 'orphan' with no PENDING-DECISION — wire it or delete it"
      elif ! why=$(resolve_pending "$pend"); then
        ad_fail "hooks/$base is a declared orphan whose PENDING-DECISION $why"
      fi
      ;;
    "")
      ad_fail "hooks/$base has NO hooks.json wiring and NO ASSURANCE-ROLE — an undeclared executable reads as coverage"
      ;;
    *)
      ad_fail "hooks/$base declares unknown ASSURANCE-ROLE '$role' (expected utility|test-harness|orphan)"
      ;;
  esac
done

if [ "$FAILURES" -eq 0 ]; then
  echo "assurance-declarations: $COUNT wiring entries + hooks/ executables all declared"
fi
echo "assurance-declarations: ${FAILURES} failure(s)"
[ "$FAILURES" -eq 0 ]
