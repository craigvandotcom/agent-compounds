#!/usr/bin/env bash
# 03-frontmatter-conformance.test.sh — the fixture proving Check 3's contract.
#
#   PROBE: a name that does not match its directory is RED; prose inside the
#           frontmatter block is RED; an agent carrying `model:` is RED; the
#           real registry is GREEN; a root with nothing to scan is NOT-GATED (2).
#
# ASSURANCE
#   PROBE:    bash lint/checks/03-frontmatter-conformance.test.sh
#   SCHEDULE: scripts/run-all-proofs.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/03-frontmatter-conformance.py"
ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

# --- RED: the committed static fixture fires on all three legs -------------------
out="$(python3 "$CHECK" "$ROOT/lint/fixtures/03-frontmatter-conformance" 2>&1)"; rc=$?
if [ "$rc" = 1 ] \
   && printf '%s' "$out" | grep -q "name 'something-else' != dir name 'badname'" \
   && printf '%s' "$out" | grep -q "line 4 is not a YAML mapping entry" \
   && printf '%s' "$out" | grep -q "'model:' is forbidden"; then
  ok "RED: static fixture -> exit 1 naming all three violation classes"
else
  bad "RED case: expected 1 naming three classes, got $rc"; printf '%s\n' "$out"
fi

# --- GREEN: the real registry ----------------------------------------------------
out="$(python3 "$CHECK" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  ok "GREEN: the real registry's frontmatter conforms"
else
  bad "real-tree case: expected 0, got $rc"; printf '%s\n' "$out"
fi

# --- NOT-GATED: a root with no skills or agents -----------------------------------
w="$(mktemp -d)"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q "NOT-CHECKED"; then
  ok "NOT-GATED: empty root -> exit 2, verified nothing"
else
  bad "NOT-GATED case: expected 2, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- RED: unclosed frontmatter block ---------------------------------------------
w="$(mktemp -d)"
mkdir -p "$w/skills/unclosed"
printf -- '---\nname: unclosed\ndescription: "never closed"\n' > "$w/skills/unclosed/SKILL.md"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "never closed by a '---'"; then
  ok "RED: unclosed frontmatter block -> exit 1"
else
  bad "unclosed case: expected 1, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

echo "03-frontmatter-conformance.test.sh: ${fails} failure(s)"
[ "$fails" -eq 0 ]
