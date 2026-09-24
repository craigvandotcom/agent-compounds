#!/usr/bin/env bash
# 21-assurance-declarations.test.sh — proof harness for lint/checks/21-assurance-declarations.sh:
# the four-field schema, fail-open-only-for-advisory, the BACKSTOP escape (PENDING-DECISION was
# cut — no users, and it resolved against a gitignored board), orphan detection over hooks/, and
# the NOT-GATED (exit 2) paths.
#
# Every case builds a throwaway root under $TMPDIR with its own engine/hooks.wiring.json and its
# own hooks/ executables. The final case runs the check against the REAL repo so the fixtures
# cannot drift into proving something it does not do.
#
# ASSURANCE
#   PROBE:    bash lint/checks/21-assurance-declarations.test.sh
#   SCHEDULE: scripts/run-all-proofs.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/21-assurance-declarations.sh"
ROOT="$(cd "$HERE/../.." && pwd)"
CASES=0
FAILURES=0

WORK="$(mktemp -d "${TMPDIR:-/tmp}/assurance-decl.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

GOOD='{"PROBE":"p","SCHEDULE":"s","MODE":"advisory","ON-FAILURE":"open"}'

# fixture <assurance-json-or-empty> [extra-hook-file-content] -> root path on stdout
# Builds a root whose single wiring entry runs hooks/wired.sh with the given declaration.
# `mktemp -d`, never a shared counter: `$(fixture ...)` command substitution runs in a
# SUBSHELL, so a counter incremented there never propagates back — every call would
# collide on the same path (proven: two sequential `X="$(fixture ...)"` calls both
# resolved to "f1"), silently layering one case's files onto the next's directory.
fixture() {
  local decl="$1" extra="${2:-}"
  local root; root="$(mktemp -d "$WORK/f.XXXXXX")"
  mkdir -p "$root/hooks" "$root/engine"

  printf '#!/bin/bash\nexit 0\n' > "$root/hooks/wired.sh"

  if [ -n "$decl" ]; then
    jq -n --argjson a "$decl" \
      '{_doc:"fixture", wiring:[{id:"wired", event:"PreToolUse", command:"{HOOKS}/wired.sh", harnesses:["claude"], scope:["org"], assurance:$a}]}' \
      > "$root/engine/hooks.wiring.json"
  else
    jq -n '{_doc:"fixture", wiring:[{id:"wired", event:"PreToolUse", command:"{HOOKS}/wired.sh", harnesses:["claude"], scope:["org"]}]}' \
      > "$root/engine/hooks.wiring.json"
  fi

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

run_check_grep() { # <expected exit> <needle> <label> <root>
  local want="$1" needle="$2" label="$3" root="$4" out rc
  CASES=$((CASES + 1))
  out=$(bash "$CHECK" "$root" 2>&1); rc=$?
  if [ "$rc" = "$want" ] && printf '%s' "$out" | grep -q "$needle"; then
    printf '  PASS  %s\n' "$label"
  else
    printf '  FAIL  %s (wanted exit %s carrying %q, got %s)\n' "$label" "$want" "$needle" "$rc"
    printf '%s\n' "$out" | sed 's/^/          | /'
    FAILURES=$((FAILURES + 1))
  fi
}

echo "--- the four-field schema ---"
run_check 0 "conforming declaration -> PASSES" "$(fixture "$GOOD")"
run_check_grep 1 "wiring 'wired' carries no assurance declaration" \
  "wiring entry with NO declaration -> FAILS naming the entry" "$(fixture "")"
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
run_check_grep 1 "MODE: blocking with ON-FAILURE: open and no escape" \
  "blocking + fail-open with NO escape -> FAILS" \
  "$(fixture '{"PROBE":"p","SCHEDULE":"s","MODE":"blocking","ON-FAILURE":"open"}')"

echo "--- PENDING-DECISION is cut: no escape but BACKSTOP remains ---"
run_check_grep 1 "MODE: blocking with ON-FAILURE: open and no escape" \
  "a PENDING-DECISION field is no longer an escape -> FAILS same as no escape at all" \
  "$(fixture '{"PROBE":"p","SCHEDULE":"s","MODE":"blocking","ON-FAILURE":"open","PENDING-DECISION":"bd-open-dec"}')"

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
run_check 1 "declared role 'orphan' -> FAILS (the escape was cut; wire it or delete it)" \
  "$(fixture "$GOOD" '#!/bin/bash
# ASSURANCE-ROLE: orphan
exit 0')"
run_check 1 "unknown ASSURANCE-ROLE -> FAILS" \
  "$(fixture "$GOOD" '#!/bin/bash
# ASSURANCE-ROLE: vibes
exit 0')"

echo "--- lean-script header declarations (moved from the retired Check 23's leg 5) ---"
LEAN="$(fixture "$GOOD")"
mkdir -p "$LEAN/skills/ac-plan/scripts"
printf '#!/usr/bin/env bash\necho hi\n' > "$LEAN/skills/ac-plan/scripts/undeclared.sh"
run_check_grep 1 "skills/ac-plan/scripts/undeclared.sh declares no" \
  "lean script with no PROBE/SCHEDULE/MODE/ON-FAILURE header -> FAILS, named" "$LEAN"

DECLARED="$(fixture "$GOOD")"
mkdir -p "$DECLARED/skills/ac-polish/scripts"
cat > "$DECLARED/skills/ac-polish/scripts/demo.sh" <<'EOF'
#!/usr/bin/env bash
# PROBE:      demo.test.sh
# SCHEDULE:   every polish round
# MODE:       blocking
# ON-FAILURE: closed
EOF
run_check 0 "lean script WITH a conforming header -> PASSES" "$DECLARED"

NOSCRIPTS="$(fixture "$GOOD")"
mkdir -p "$NOSCRIPTS/skills/ac-plan"
run_check_grep 1 "NOT-GATED — the lean-script discovery set resolved to zero scripts" \
  "skills/ present but the lean-script discovery set is empty -> FAILS (not silently gated green)" "$NOSCRIPTS"

echo "--- NOT-GATED: verified nothing is never a pass (exit 2) ---"
NOJSON="$WORK/no-hooks-json"; mkdir -p "$NOJSON/hooks" "$NOJSON/.beads"
run_check_grep 2 "NOT-GATED" \
  "engine/hooks.wiring.json missing entirely -> exit 2, verified nothing" "$NOJSON"

EMPTY="$(fixture "$GOOD")"
jq -n '{_doc:"fixture", wiring:[]}' > "$EMPTY/engine/hooks.wiring.json"
run_check_grep 2 "NOT-GATED" \
  "zero wiring entries -> exit 2, verified nothing" "$EMPTY"

echo "--- against the live repo ---"
run_check 0 "every wiring entry + hooks/ executable in THIS repo is declared" "$ROOT"

echo ""
echo "21-assurance-declarations.test.sh: ${CASES} cases, ${FAILURES} failures"
[ "$FAILURES" -eq 0 ]
