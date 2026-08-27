#!/usr/bin/env bash
# stamp-refined-fixpoint.test.sh — the ac2 fixpoint-receipt gate inside stamp-refined.sh.
#
# `refined` is what the worker loop selects on, and stamp-refined.sh is its only sanctioned
# writer. For an ac2-origin bead the stamp is legal only against a fixpoint receipt — so the
# gate lives in the WRITER, not in ac2-polish's procedure: a check a caller can route around
# is not a gate.
#
# THE SEAM IS EXECUTED, NOT COPIED: the accept case RUNS skills/_tools/polish-fixpoint.sh to
# produce a real receipt and feeds THAT through the mocked `br` into the stamp. A hand-copied
# fixture string stays green when either side of the seam drifts, which is the untested seam
# rather than coverage — Case 7 mutates the producer's token to prove the coupling.
#
# Run directly:  bash skills/ac-bead-refine/scripts/stamp-refined-fixpoint.test.sh
# Discovered automatically by scripts/run-all-harnesses.sh (glob over *.test.sh).
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
STAMP="$DIR/stamp-refined.sh"
FIXPOINT="$ROOT/skills/_tools/polish-fixpoint.sh"

FAILURES=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

# --- the mocked board: `show --json`, `comments add -f`, and a call log -----------------
MOCK="$WORK/bin"; mkdir -p "$MOCK"
BR_LOG="$WORK/br.log"
FIXTURE_BEADS="$WORK/beads.json"; export FIXTURE_BEADS BR_LOG
cat >"$MOCK/br" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$BR_LOG"
case "$1" in
  show)
    shift; ids=()
    while [ $# -gt 0 ]; do case "$1" in --json) shift ;; *) ids+=("$1"); shift ;; esac; done
    want=$(printf '%s\n' "${ids[@]}" | jq -R . | jq -s .)
    out=$(jq --argjson want "$want" '[ .[] | select(.id as $i | $want | index($i)) ]' "$FIXTURE_BEADS")
    [ "$(printf '%s' "$out" | jq 'length')" -gt 0 ] && { printf '%s\n' "$out"; exit 0; }
    echo '{"error":{"code":"ISSUE_NOT_FOUND"}}'; exit 1 ;;
  comments)
    # `comments add <id> -f <file>` — append the file's text as a real comment, so the
    # receipt the producer wrote is the one the reader reads.
    if [ "${2:-}" = add ]; then
      id="$3"; file=""
      shift 3
      while [ $# -gt 0 ]; do case "$1" in -f) file="$2"; shift 2 ;; *) shift ;; esac; done
      text=$(cat "$file")
      tmp=$(mktemp)
      jq --arg id "$id" --arg t "$text" \
         '[ .[] | if .id == $id then .comments = ((.comments // []) + [{text:$t}]) else . end ]' \
         "$FIXTURE_BEADS" >"$tmp" && mv "$tmp" "$FIXTURE_BEADS"
    fi
    exit 0 ;;
esac
exit 0
EOF
chmod +x "$MOCK/br"

# An ac2-schema description: four sections, every AC naming an executable probe. element4-check
# accepts this shape (ac-4y92), so anything refused below is refused by the RECEIPT gate.
AC2_DESC='## Intent
Why this matters, with no line numbers.

## Acceptance Criteria
- The gate ships as an executable script.
  Probe: `test -x skills/ac2-implement/scripts/close-gate.sh` — tier: none

## Delivers
- gate: skills/ac2-implement/scripts/close-gate.sh

## Consumes
- none
'
LEGACY_DESC='## Declared RED
Test `x` must FAIL before the fix; assert exit 1.
'

write_board() {
  jq -n --arg ac2 "$AC2_DESC" --arg leg "$LEGACY_DESC" '[
    {id:"bd-ac2-noreceipt", issue_type:"task", labels:["origin:ac2-beadify"], description:$ac2, comments:[]},
    {id:"bd-ac2-receipt",   issue_type:"task", labels:["origin:ac2-beadify"], description:$ac2, comments:[]},
    {id:"bd-ac2-malformed", issue_type:"task", labels:["origin:ac2-beadify"], description:$ac2,
     comments:[{text:"POLISH-FIXPOINT:"}]},
    {id:"bd-ac2-round1",    issue_type:"task", labels:["origin:ac2-beadify"], description:$ac2,
     comments:[{text:"POLISH-FIXPOINT: mode=bead rounds=1 sha256=deadbeefdeadbeef at=2026-08-27T00:00:00Z engine=polish-fixpoint.sh"}]},
    {id:"bd-ac2-direct",    issue_type:"task", labels:["origin:ac2-beadify"], description:$ac2, comments:[]},
    {id:"bd-legacy",        issue_type:"task", labels:["origin:ac-beadify"],  description:$leg, comments:[]}
  ]' >"$FIXTURE_BEADS"
}
write_board

stamped_count() { grep -c "label add $1 refined" "$BR_LOG"; }

# --- Case 1: ac2-origin bead with NO receipt -> REFUSED, and no label is written -------
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-ac2-noreceipt 2>&1); RC=$?
if [ "$RC" -ne 0 ] && [ "$(stamped_count bd-ac2-noreceipt)" -eq 0 ] \
   && echo "$OUT" | grep -qi "fixpoint"; then
  pass "Case 1: an ac2-origin bead with no fixpoint receipt is REFUSED, no label written"
else
  fail "Case 1: expected refusal with no label write, rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

# --- Case 2: THE SEAM — a receipt produced by polish-fixpoint.sh itself lets it stamp --
: >"$BR_LOG"
STATE="$WORK/state"; ART="$WORK/artifact.md"
printf 'round zero\n' >"$ART"
PRE0=$(shasum -a 256 "$ART" | awk '{print $1}')
PATH="$MOCK:$PATH" bash "$FIXPOINT" --mode bead --target bd-ac2-receipt --artifact "$ART" \
  --state "$STATE" --round 1 --pre "deadbeef" >/dev/null 2>&1   # round 1: CONTINUE, records the sha
FP_OUT=$(PATH="$MOCK:$PATH" bash "$FIXPOINT" --mode bead --target bd-ac2-receipt --artifact "$ART" \
  --state "$STATE" --round 2 --pre "$PRE0" 2>&1); FP_RC=$?
if [ "$FP_RC" -eq 0 ] && grep -q "POLISH-FIXPOINT:" "$STATE/receipt.txt"; then
  pass "Case 2a: polish-fixpoint.sh reached a fixpoint and wrote a real receipt"
else
  fail "Case 2a: producer did not stamp, rc=$FP_RC. Output: $FP_OUT"
fi
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-ac2-receipt 2>&1); RC=$?
if [ "$RC" -eq 0 ] && [ "$(stamped_count bd-ac2-receipt)" -eq 1 ]; then
  pass "Case 2b: with the PRODUCER'S OWN receipt on the bead, the stamp is written once"
else
  fail "Case 2b: expected exit 0 and one label write, rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

# --- Case 3: an ac-*-origin bead is NOT subject to the requirement ---------------------
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-legacy 2>&1); RC=$?
if [ "$RC" -eq 0 ] && [ "$(stamped_count bd-legacy)" -eq 1 ]; then
  pass "Case 3: a legacy ac-*-origin bead still stamps with no receipt (additive, not a regression)"
else
  fail "Case 3: expected the legacy path untouched, rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

# --- Case 4: a receipt header with no rounds/sha is ABSENT, not satisfied --------------
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-ac2-malformed 2>&1); RC=$?
if [ "$RC" -ne 0 ] && [ "$(stamped_count bd-ac2-malformed)" -eq 0 ]; then
  pass "Case 4: a receipt header carrying no measurement is treated as ABSENT"
else
  fail "Case 4: expected refusal, rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

# --- Case 5: rounds=1 is not a fixpoint — a clean first round proves nothing -----------
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-ac2-round1 2>&1); RC=$?
if [ "$RC" -ne 0 ] && [ "$(stamped_count bd-ac2-round1)" -eq 0 ]; then
  pass "Case 5: a rounds=1 receipt is REFUSED (a fixpoint needs a clean round >= 2)"
else
  fail "Case 5: expected refusal, rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

# --- Case 6: the refusal comes from the SCRIPT, with no caller involved ----------------
# Sourced-and-called, the other entry point: the gate must not live in a wrapper.
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash -c ". '$STAMP'; stamp_refined bd-ac2-direct" 2>&1); RC=$?
if [ "$RC" -ne 0 ] && [ "$(stamped_count bd-ac2-direct)" -eq 0 ]; then
  pass "Case 6: the sourced function refuses too — the gate is in the writer, not a caller"
else
  fail "Case 6: expected refusal from the function itself, rc=$RC. Output: $OUT"
fi

# --- Case 7: NEGATIVE CONTROL on the seam — drift either side and this goes RED --------
# Rewrite the produced receipt's token as a drifted producer would, feed it in, demand a refusal.
: >"$BR_LOG"
DRIFTED=$(sed 's/^POLISH-FIXPOINT:/POLISH-FIXPOINT-V2:/' "$STATE/receipt.txt")
tmp=$(mktemp)
jq --arg t "$DRIFTED" '[ .[] | if .id == "bd-ac2-noreceipt" then .comments = [{text:$t}] else . end ]' \
   "$FIXTURE_BEADS" >"$tmp" && mv "$tmp" "$FIXTURE_BEADS"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-ac2-noreceipt 2>&1); RC=$?
if [ "$RC" -ne 0 ] && [ "$(stamped_count bd-ac2-noreceipt)" -eq 0 ]; then
  pass "Case 7: NEGATIVE CONTROL — a drifted receipt token no longer satisfies the gate"
else
  fail "Case 7: a drifted receipt was accepted — the matcher is not coupled to the producer"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All stamp-refined fixpoint-receipt tests passed."
  exit 0
else
  echo "$FAILURES fixture test(s) FAILED."
  exit 1
fi
