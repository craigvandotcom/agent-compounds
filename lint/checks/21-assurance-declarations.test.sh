#!/usr/bin/env bash
# 21-assurance-declarations.test.sh — the fixture proving Check 21's contract.
#
#   PROBE: a wiring entry with no assurance object is RED naming the entry; a
#           conforming blocking+closed declaration is GREEN; blocking+fail-open
#           with no escape is RED; a tree missing the judge is NOT-GATED
#           (exit 2); the real registry is GREEN.
#
# ASSURANCE
#   PROBE:    bash lint/checks/21-assurance-declarations.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/21-assurance-declarations.py"
ROOT="$(cd "$HERE/../.." && pwd)"
REG="$ROOT/scripts/assurance-declarations-check.sh"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

build_tree() { # <root> <hooks-json-text>
  local w="$1" body="$2"
  mkdir -p "$w/scripts" "$w/hooks"
  cp "$REG" "$w/scripts/"
  chmod +x "$w/scripts/"*.sh
  printf '%s' "$body" > "$w/hooks/hooks.json"
}

DECL='{"PROBE":"run the test harness","SCHEDULE":"CI lint job","MODE":"blocking","ON-FAILURE":"closed"}'

# --- RED: wiring entry carries no assurance declaration ------------------------
w="$(mktemp -d)"
build_tree "$w" '{"wiring":[{"id":"demo","command":"echo hi"}]}'
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "wiring 'demo' carries no assurance declaration"; then
  ok "RED: undeclared wiring -> exit 1 naming the entry"
else
  bad "RED case: expected 1 naming 'demo', got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- RED: blocking + fail-open with no escape -----------------------------------
w="$(mktemp -d)"
build_tree "$w" '{"wiring":[{"id":"demo","command":"echo hi","assurance":{"PROBE":"p","SCHEDULE":"s","MODE":"blocking","ON-FAILURE":"open"}}]}'
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "MODE: blocking with ON-FAILURE: open and no escape"; then
  ok "RED: blocking fail-open with no escape -> exit 1"
else
  bad "RED fail-open case: expected 1, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- GREEN: conforming blocking + closed declaration ----------------------------
w="$(mktemp -d)"
build_tree "$w" "{\"wiring\":[{\"id\":\"demo\",\"command\":\"echo hi\",\"assurance\":$DECL}]}"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q "all declared"; then
  ok "GREEN: conforming declaration -> exit 0"
else
  bad "GREEN case: expected 0, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- NOT-GATED: the judge script is missing from the audited tree ---------------
w="$(mktemp -d)"
mkdir -p "$w/hooks"
printf '{"wiring":[]}\n' > "$w/hooks/hooks.json"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q "NOT-CHECKED"; then
  ok "NOT-GATED: missing judge -> exit 2, verified nothing"
else
  bad "NOT-GATED case: expected 2, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- the real registry is green -------------------------------------------------
out="$(python3 "$CHECK" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  ok "GREEN: the real registry's wiring is fully declared"
else
  bad "real-tree case: expected 0, got $rc"; printf '%s\n' "$out"
fi

echo "21-assurance-declarations.test.sh: ${fails} failure(s)"
[ "$fails" -eq 0 ]
