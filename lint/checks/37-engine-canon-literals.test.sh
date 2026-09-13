#!/usr/bin/env bash
# 37-engine-canon-literals.test.sh — the fixture proving Check 37's contract.
#
#   PROBE: the committed static fixture is RED on both a code line and a wiring
#          command, while its prose comment and `_doc` — which quote the very
#          literals the check forbids — stay GREEN; the real registry is GREEN;
#          a root with no engine/ is NOT-GATED (2).
#
# ASSURANCE
#   PROBE:    bash lint/checks/37-engine-canon-literals.test.sh
#   SCHEDULE: scripts/run-all-proofs.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/37-engine-canon-literals.py"
ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

# --- RED: the static fixture, code line ------------------------------------------
out="$(python3 "$CHECK" "$ROOT/lint/fixtures/37-engine-canon-literals" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "engine/sync.sh:7: home-anchored"; then
  ok "RED: fixture code line -> exit 1 naming the line"
else
  bad "fixture code line: expected 1 naming sync.sh:7, got $rc"; printf '%s\n' "$out"
fi

# --- RED: the wiring manifest's command field ------------------------------------
if printf '%s' "$out" | grep -q "wiring 'dirty' command carries"; then
  ok "RED: wiring command -> flagged by id"
else
  bad "wiring command: expected the 'dirty' entry flagged"; printf '%s\n' "$out"
fi

# --- GREEN: prose is out of scope, and this is the leg that keeps the check alive --
# The fixture's comment and its `_doc` both spell the forbidden literals verbatim. A
# check that reddened on its own explanation would be deleted within a week.
if printf '%s' "$out" | grep -q "sync.sh:3\|sync.sh:4\|_doc"; then
  bad "prose leaked into findings — comments and _doc must be out of scope"
  printf '%s\n' "$out"
else
  ok "GREEN: prose comment and _doc ignored"
fi

# --- GREEN: the clean wiring entry is not flagged ---------------------------------
if printf '%s' "$out" | grep -q "wiring 'clean'"; then
  bad "the {INFRA} placeholder entry was flagged — placeholders are the fix, not the defect"
else
  ok "GREEN: {INFRA} placeholder entry not flagged"
fi

# --- GREEN: the real registry ------------------------------------------------------
out="$(python3 "$CHECK" "$ROOT" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  ok "GREEN: the real engine/ derives its paths"
else
  bad "real registry: expected 0, got $rc"; printf '%s\n' "$out"
fi

# --- NOT-GATED: no engine/ under root ---------------------------------------------
w="$(mktemp -d)"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q "NOT-CHECKED"; then
  ok "NOT-GATED: no engine/ -> exit 2, never a pass"
else
  bad "no-engine case: expected 2 NOT-CHECKED, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

if [ "$fails" -gt 0 ]; then
  echo "37-engine-canon-literals: $fails case(s) FAILED"
  exit 1
fi
echo "37-engine-canon-literals: all cases passed"
