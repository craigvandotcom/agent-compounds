#!/usr/bin/env bash
# consensus.test.sh — fixture-based tests for consensus.py's location matching (ac-ewgr.4).
#
# Sibling-test convention: skills/ac-pipeline/scripts/ hosts six committed *.test.sh
# harnesses; this is the same shape for skills/ac-review/scripts/. No shell-test framework
# exists in this repo (no bats/shellspec/shunit) — self-contained assert harness.
#
# Every fixture uses `severity: medium` ON PURPOSE. At high/critical the auto-fix cascade
# fires on severity alone (`reason=severity:high`) and MASKS every location behaviour these
# cases exist to pin — an implementer who picks `high` as a "natural" demo severity will
# conclude there is no bug.
#
# Cases:
#   AC1 RED->GREEN  one defect, adjacent lines 17/19, overlapping prose  -> consensus
#   AC2 distance    two different defects, lines 17/60                   -> stay separate
#   AC3 same-dist   two DIFFERENT defects, lines 17/19, disjoint prose   -> stay separate
#   AC4 exact-line  one location :17, two categories                     -> AUTO_FIX (2)
#
# Run: bash skills/ac-review/scripts/consensus.test.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONSENSUS="$SCRIPT_DIR/consensus.py"

FAILURES=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

# make_case <name> <correctness-findings-json> <contracts-findings-json> -> echoes the dir
make_case() {
  local d="$WORKDIR/$1"
  mkdir -p "$d"
  printf '%s' '{"round": 1, "spawned": ["correctness", "contracts"]}' >"$d/panel-round-1.json"
  printf '%s' "{\"findings\":[$2]}" >"$d/round-1-correctness.json"
  printf '%s' "{\"findings\":[$3]}" >"$d/round-1-contracts.json"
  echo "$d"
}

run_case() { python3 "$CONSENSUS" --artifacts-dir "$1" --round 1 2>&1; }

# --- AC1: ONE defect anchored at adjacent lines 17 / 19 (the bug) -----------------
D=$(make_case ac1 \
  '{"title":"unchecked null deref in handler","severity":"medium","file":"src/handler.ts","line":17,"category":"correctness","fix":"guard the null","auto_fixable":true}' \
  '{"title":"handler may deref null on the same path","severity":"medium","file":"src/handler.ts","line":19,"category":"contracts","fix":"guard the null","auto_fixable":true}')
OUT=$(run_case "$D")
if echo "$OUT" | grep -q '^AUTO_FIX (2):' && echo "$OUT" | grep -q 'near-location-consensus' \
   && echo "$OUT" | grep -q '^DEFERRED (0)'; then
  pass "AC1: same defect at adjacent lines 17/19 reaches near-location consensus"
else
  fail "AC1: expected AUTO_FIX (2) with near-location-consensus, DEFERRED (0). Output:
$OUT"
fi

# --- AC2: two different defects, far apart (17 vs 60) — bounds the window ---------
D=$(make_case ac2 \
  '{"title":"off-by-one in loop bound","severity":"medium","file":"src/handler.ts","line":17,"category":"correctness","fix":"clamp the loop bound","auto_fixable":true}' \
  '{"title":"response type omits the error branch","severity":"medium","file":"src/handler.ts","line":60,"category":"contracts","fix":"add the error branch to the response type","auto_fixable":true}')
OUT=$(run_case "$D")
if echo "$OUT" | grep -q '^AUTO_FIX (0):' && echo "$OUT" | grep -q '^DEFERRED (2)'; then
  pass "AC2: different defects 43 lines apart stay two DEFERRED entries"
else
  fail "AC2: expected AUTO_FIX (0) / DEFERRED (2). Output:
$OUT"
fi

# --- AC3: two GENUINELY DIFFERENT defects at the SAME distance (17/19) ------------
# Byte-identical to AC1 in every field norm_key reads (file, line, category) — they
# differ only in title/fix prose. This is why the near-location pass reads that prose:
# a location-only rule provably merges this pair too.
D=$(make_case ac3 \
  '{"title":"off-by-one in loop bound","severity":"medium","file":"src/handler.ts","line":17,"category":"correctness","fix":"clamp the loop bound","auto_fixable":true}' \
  '{"title":"response type omits the error branch","severity":"medium","file":"src/handler.ts","line":19,"category":"contracts","fix":"add the error branch to the response type","auto_fixable":true}')
OUT=$(run_case "$D")
if echo "$OUT" | grep -q '^AUTO_FIX (0):' && echo "$OUT" | grep -q '^DEFERRED (2)'; then
  pass "AC3: different defects at adjacent lines 17/19 are NOT merged (text gate holds)"
else
  fail "AC3: expected AUTO_FIX (0) / DEFERRED (2). Output:
$OUT"
fi

# --- AC4: exact-line, two categories — pre-existing behaviour must survive ---------
D=$(make_case ac4 \
  '{"title":"unchecked null deref in handler","severity":"medium","file":"src/handler.ts","line":17,"category":"correctness","fix":"guard the null","auto_fixable":true}' \
  '{"title":"handler contract allows a null here","severity":"medium","file":"src/handler.ts","line":17,"category":"contracts","fix":"tighten the contract","auto_fixable":true}')
OUT=$(run_case "$D")
if echo "$OUT" | grep -q '^AUTO_FIX (2):' && echo "$OUT" | grep -q 'same-location-consensus'; then
  pass "AC4: exact-line any-category consensus preserved (same-location-consensus)"
else
  fail "AC4: expected AUTO_FIX (2) with same-location-consensus. Output:
$OUT"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All consensus.py fixture tests passed."
  exit 0
else
  echo "$FAILURES fixture test(s) FAILED."
  exit 1
fi
