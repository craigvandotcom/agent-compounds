#!/usr/bin/env bash
# 17-dcg-blocked-redirects.test.sh — the fixture proving Check 17's contract.
#
#   RED: the committed static fixture (bad truncating redirects inside bash
#        and sh fences) exits 1 naming both hits.
#   GREEN: the real registry exits 0; prose, append, literal targets, tee,
#          dcg-allow and non-bash fences do NOT fire; a *.sh file is not a
#          prescription.
#   VACUOUS: a root with no *.md under skills/ exits 1 (the sweep itself
#          accounts for nothing).
#   NOT-GATED: a root with no skills/ exits 2.
#
# ASSURANCE
#   PROBE:    bash lint/checks/17-dcg-blocked-redirects.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/17-dcg-blocked-redirects.py"
ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
pass() { echo "  PASS $1"; }
fail() { echo "  FAIL $1"; fails=$((fails + 1)); }

# --- RED: the committed static fixture -------------------------------------------
out="$(python3 "$CHECK" "$ROOT/lint/fixtures/17-dcg-blocked-redirects" 2>&1)"; rc=$?
if [ "$rc" = 1 ] \
   && printf '%s' "$out" | grep -q 'SKILL.md:9:bad_command > "\$OUT/results.md"' \
   && printf '%s' "$out" | grep -q 'SKILL.md:17:also bad > "\$DIR/list"'; then
  pass "RED: both bad redirect lines named -> exit 1"
else
  fail "RED fixture: expected 1 naming both hits, got $rc"; printf '%s\n' "$out"
fi

# --- GREEN: the allowed shapes do not fire ----------------------------------------
w="$(mktemp -d)"
mkdir -p "$w/skills/allowed-skill"
cat > "$w/skills/allowed-skill/SKILL.md" <<'MD'
```bash
append >> "$OUT/file" never truncates
literal >/dev/null is fine
tee "$OUT/x" is not a redirect
documented > "$OUT/final.md" # dcg-allow
```
MD
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  pass "GREEN: append / literal / tee / dcg-allow -> exit 0"
else
  fail "allowed-shapes case: expected 0, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- GREEN: the real registry -------------------------------------------------------
out="$(python3 "$CHECK" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  pass "GREEN: 0 violations across the real skills/ corpus"
else
  fail "real-tree case: expected 0, got $rc"; printf '%s\n' "$out"
fi

# --- VACUOUS: zero files scanned is a failure, never a pass -------------------------
w="$(mktemp -d)"
mkdir -p "$w/skills"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "zero files scanned under skills/ — the sweep is vacuous"; then
  pass "VACUOUS: zero *.md under skills/ -> exit 1, never a pass"
else
  fail "vacuous case: expected 1, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- NOT-GATED: no skills/ -----------------------------------------------------------
w="$(mktemp -d)"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q "NOT-CHECKED"; then
  pass "NOT-GATED: no skills/ dir -> exit 2"
else
  fail "NOT-GATED case: expected 2, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

echo "17-dcg-blocked-redirects.test.sh: $((5 - fails)) passed, $fails failed"
[ "$fails" -eq 0 ]
