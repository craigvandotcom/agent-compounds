#!/usr/bin/env bash
# assurance-declarations-check.test.sh — proof harness for the assurance-triad declaration
# check and its orphan detection (ac-on0y.4), and so for lint.sh Check 21.
#
# Every case builds a throwaway root under $TMPDIR with its own hooks/hooks.json, its own
# hooks/ executables, and its own .beads/issues.jsonl. Fixture beads are synthetic jsonl
# lines fed to the parser — NEVER live board mutations. The final case runs the check
# against the REAL repo so the fixtures cannot drift into proving something it does not do.
#
# Exit 0 = all cases pass.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$SCRIPT_DIR/assurance-declarations-check.sh"
AC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CASES=0
FAILURES=0

WORK="$(mktemp -d "${TMPDIR:-/tmp}/assurance-decl.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

N=0
GOOD='{"PROBE":"p","SCHEDULE":"s","MODE":"advisory","ON-FAILURE":"open"}'

# fixture <assurance-json-or-empty> [extra-hook-file-content] -> root path on stdout
# Builds a root whose single wiring entry runs hooks/wired.sh with the given declaration.
fixture() {
  local decl="$1" extra="${2:-}"
  N=$((N + 1))
  local root="$WORK/f$N"
  mkdir -p "$root/hooks" "$root/.beads"

  printf '#!/bin/bash\nexit 0\n' > "$root/hooks/wired.sh"

  if [ -n "$decl" ]; then
    jq -n --argjson a "$decl" \
      '{_doc:"fixture", wiring:[{id:"wired", event:"PreToolUse", command:"{HOOKS}/wired.sh", harnesses:["claude"], scope:["org"], assurance:$a}]}' \
      > "$root/hooks/hooks.json"
  else
    jq -n '{_doc:"fixture", wiring:[{id:"wired", event:"PreToolUse", command:"{HOOKS}/wired.sh", harnesses:["claude"], scope:["org"]}]}' \
      > "$root/hooks/hooks.json"
  fi

  # A synthetic board: one OPEN decision, one CLOSED decision, one OPEN task.
  {
    printf '%s\n' '{"id":"bd-open-dec","issue_type":"decision","status":"open"}'
    printf '%s\n' '{"id":"bd-closed-dec","issue_type":"decision","status":"closed"}'
    printf '%s\n' '{"id":"bd-open-task","issue_type":"task","status":"open"}'
  } > "$root/.beads/issues.jsonl"

  [ -n "$extra" ] && printf '%s\n' "$extra" > "$root/hooks/loose.sh"
  printf '%s' "$root"
}

run_check() { # <expected exit> <label> <root>
  local want="$1" label="$2" root="$3" out rc
  CASES=$((CASES + 1))
  out=$(bash "$CHECK" "$root" 2>&1); rc=$?
  if [ "$rc" = "$want" ]; then
    printf '  PASS  %s\n' "$label"
  else
    printf '  FAIL  %s (wanted exit %s, got %s)\n' "$label" "$want" "$rc"
    printf '%s\n' "$out" | sed 's/^/          | /'
    FAILURES=$((FAILURES + 1))
  fi
}

echo "--- the four-field schema ---"
run_check 0 "conforming declaration -> PASSES" "$(fixture "$GOOD")"
run_check 1 "wiring entry with NO declaration -> FAILS" "$(fixture "")"
run_check 1 "declaration missing PROBE -> FAILS" \
  "$(fixture '{"SCHEDULE":"s","MODE":"advisory","ON-FAILURE":"open"}')"
run_check 1 "declaration missing SCHEDULE -> FAILS" \
  "$(fixture '{"PROBE":"p","MODE":"advisory","ON-FAILURE":"open"}')"
run_check 1 "declaration missing MODE -> FAILS" \
  "$(fixture '{"PROBE":"p","SCHEDULE":"s","ON-FAILURE":"open"}')"
run_check 1 "declaration missing ON-FAILURE -> FAILS" \
  "$(fixture '{"PROBE":"p","SCHEDULE":"s","MODE":"advisory"}')"
run_check 1 "MODE outside blocking|advisory -> FAILS" \
  "$(fixture '{"PROBE":"p","SCHEDULE":"s","MODE":"sometimes","ON-FAILURE":"open"}')"

echo "--- fail-open is legal only for advisory ---"
run_check 0 "blocking + ON-FAILURE: closed -> PASSES" \
  "$(fixture '{"PROBE":"p","SCHEDULE":"s","MODE":"blocking","ON-FAILURE":"closed"}')"
run_check 1 "blocking + fail-open with NO escape -> FAILS" \
  "$(fixture '{"PROBE":"p","SCHEDULE":"s","MODE":"blocking","ON-FAILURE":"open"}')"

echo "--- PENDING-DECISION is self-expiring ---"
run_check 0 "escape citing an OPEN DECISION bead -> PASSES" \
  "$(fixture '{"PROBE":"p","SCHEDULE":"s","MODE":"blocking","ON-FAILURE":"open","PENDING-DECISION":"bd-open-dec"}')"
run_check 1 "escape citing a CLOSED decision bead -> FAILS (a ruling must be executed)" \
  "$(fixture '{"PROBE":"p","SCHEDULE":"s","MODE":"blocking","ON-FAILURE":"open","PENDING-DECISION":"bd-closed-dec"}')"
run_check 1 "escape citing an OPEN NON-decision bead -> FAILS" \
  "$(fixture '{"PROBE":"p","SCHEDULE":"s","MODE":"blocking","ON-FAILURE":"open","PENDING-DECISION":"bd-open-task"}')"
run_check 1 "escape citing a NONEXISTENT id -> FAILS" \
  "$(fixture '{"PROBE":"p","SCHEDULE":"s","MODE":"blocking","ON-FAILURE":"open","PENDING-DECISION":"bd-nope"}')"

echo "--- BACKSTOP: a ruled fail-open, not a pending one ---"
run_check 0 "BACKSTOP naming an EXISTING path -> PASSES" \
  "$(fixture '{"PROBE":"p","SCHEDULE":"s","MODE":"blocking","ON-FAILURE":"open","BACKSTOP":"hooks/wired.sh catches the rest"}')"
run_check 1 "BACKSTOP naming a MISSING path -> FAILS" \
  "$(fixture '{"PROBE":"p","SCHEDULE":"s","MODE":"blocking","ON-FAILURE":"open","BACKSTOP":"hooks/gone.sh catches the rest"}')"

echo "--- orphan detection ---"
run_check 1 "unwired, undeclared executable in hooks/ -> FAILS" \
  "$(fixture "$GOOD" '#!/bin/bash
exit 0')"
run_check 0 "declared utility naming a CALLER -> PASSES" \
  "$(fixture "$GOOD" '#!/bin/bash
# ASSURANCE-ROLE: utility
# CALLER: harness-sync.sh
exit 0')"
run_check 1 "declared utility with NO CALLER -> FAILS" \
  "$(fixture "$GOOD" '#!/bin/bash
# ASSURANCE-ROLE: utility
exit 0')"
run_check 0 "declared orphan citing an OPEN decision -> PASSES" \
  "$(fixture "$GOOD" '#!/bin/bash
# ASSURANCE-ROLE: orphan
# PENDING-DECISION: bd-open-dec
exit 0')"
run_check 1 "declared orphan citing a CLOSED decision -> FAILS" \
  "$(fixture "$GOOD" '#!/bin/bash
# ASSURANCE-ROLE: orphan
# PENDING-DECISION: bd-closed-dec
exit 0')"
run_check 1 "unknown ASSURANCE-ROLE -> FAILS" \
  "$(fixture "$GOOD" '#!/bin/bash
# ASSURANCE-ROLE: vibes
exit 0')"

echo "--- a check that verified nothing is never a pass ---"
EMPTY="$(fixture "$GOOD")"
jq -n '{_doc:"fixture", wiring:[]}' > "$EMPTY/hooks/hooks.json"
run_check 1 "zero wiring entries -> FAILS (NOT-GATED)" "$EMPTY"

echo "--- against the live repo ---"
run_check 0 "every wiring entry + hooks/ executable in THIS repo is declared" "$AC_ROOT"

echo ""
echo "assurance-declarations-check.test: ${CASES} cases, ${FAILURES} failures"
[ "$FAILURES" -eq 0 ]
