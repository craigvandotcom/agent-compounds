#!/usr/bin/env bash
# stamp-refined-ruling.test.sh — the ruling-staleness leg inside stamp-refined.sh (ac-2h8w).
#
# Measured in a consuming app (bd-i01pk): a human ruled "DELETE the dead buffer; the
# alternative is rejected" and recorded it as a `DECISION (<human>): …` comment on a bead
# that already held `refined` from a polish receipt written the day before. The title and
# ACs still asked for the rejected option — no eligibility filter reads comments — and a
# worker built the rejected option. This harness pins the gate: a `refined` bead whose
# newest `DECISION (…):` comment is newer than its newest `POLISH-FIXPOINT:` receipt comment
# is refused and downgraded; a receipt newer than the ruling passes; a ruling with no
# receipt at all is refused too; a bead with no DECISION comment is unaffected.
#
# "Newer" is comment ARRAY ORDER, the same axis the existing fixpoint-receipt leg already
# trusts (it picks the receipt via `tail -1`, not a timestamp field) — `br show --json`
# returns comments in the order they were written, and this fixture's mocked `comments add`
# appends in call order, so index order IS chronological order here exactly as it is on the
# real board.
#
# Run directly:  bash skills/_tools/stamp-refined-ruling.test.sh
# Discovered automatically by scripts/run-all-proofs.sh (glob over *.test.sh).
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
STAMP="$DIR/stamp-refined.sh"

FAILURES=0
PASSES=0
pass() { echo "  PASS: $1"; PASSES=$((PASSES + 1)); }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

# A fixture repo so the TOUCHERS LEG derives from a tree the harness controls. lib/lonely.ts
# is tracked and referenced by nothing, so every fixture below owes no touchers line — the
# same shape stamp-refined-fixpoint.test.sh uses for its "referenced by nothing" case. This
# harness is about the ruling leg, not the touchers leg, so every fixture is built to clear
# every OTHER leg cleanly.
FIXREPO="$WORK/repo"; mkdir -p "$FIXREPO/lib"
printf 'export const lonely = 1\n' >"$FIXREPO/lib/lonely.ts"
(cd "$FIXREPO" && git init -q && git add lib/lonely.ts)
cd "$FIXREPO" || { echo "HARNESS FAIL: cannot enter fixture repo"; exit 1; }

# --- the mocked board: `show --json`, `label add/remove`, `comments add -f` -------------
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
  label)
    if [ "${2:-}" = add ] || [ "${2:-}" = remove ]; then
      op="$2"; id="$3"; name="$4"
      tmp=$(mktemp)
      jq --arg id "$id" --arg name "$name" --arg op "$op" '
        [ .[] | if .id == $id then
          if $op == "add" then .labels = ((.labels // []) + [$name] | unique)
          else .labels = ((.labels // []) - [$name]) end
        else . end ]' "$FIXTURE_BEADS" >"$tmp" && mv "$tmp" "$FIXTURE_BEADS"
    fi
    exit 0 ;;
  comments)
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

# A probed, non-family-origin, task-shaped description whose only Delivers path is the
# unreferenced fixture file above — clears element4, probe-presence, prod-write, task-Delivers
# and touchers cleanly on every fixture, so any refusal below comes from the ruling leg alone.
DESC='## Declared RED
Test `x` must FAIL before the fix; assert exit 1.

## Acceptance Criteria
- The fix lands.
  Probe: `grep -q "the fix" src/x.ts && true` — tier: none

## Delivers
- lib/lonely.ts
'

RECEIPT1='POLISH-FIXPOINT: mode=bead rounds=2 sha256=deadbeefdeadbeef00000000000000000000000000000000000000000000 at=2026-09-24T21:29:36Z engine=polish-fixpoint.sh'
RECEIPT2='POLISH-FIXPOINT: mode=bead rounds=2 sha256=cafebabecafebabe00000000000000000000000000000000000000000000 at=2026-09-27T13:57:26Z engine=polish-fixpoint.sh'
RULING1='DECISION (reviewer): DELETE the dead buffer; the alternative is rejected'
RULING2='DECISION (reviewer): confirmed — DELETE stands'

jq -n --arg desc "$DESC" \
      --arg r1 "$RECEIPT1" --arg r2 "$RECEIPT2" \
      --arg d1 "$RULING1" --arg d2 "$RULING2" '[
  # Case 1 — the measured timeline: receipt, then ruling, then claim. Still holds `refined`.
  {id:"bd-receipt-then-ruling", issue_type:"task", labels:["origin:ac-triage","refined","refine-full"],
   description:$desc, comments:[{text:$r1},{text:$d1}]},
  # Case 2 — ruling, then a fresh receipt: the receipt is newer, so the ruling was polished in.
  {id:"bd-ruling-then-receipt", issue_type:"task", labels:["origin:ac-triage"],
   description:$desc, comments:[{text:$d1},{text:$r1}]},
  # Case 3 — a ruling with no receipt at all: never polished into the text.
  {id:"bd-ruling-no-receipt", issue_type:"task", labels:["origin:ac-triage"],
   description:$desc, comments:[{text:$d1}]},
  # Case 4 — no DECISION comment at all: this leg must not touch it. Carries the receipt
  # every origin now owes (ac-m9y4.7) so it still reaches a real STAMP.
  {id:"bd-no-decision", issue_type:"task", labels:["origin:ac-triage"],
   description:$desc, comments:[{text:$r1}]},
  # Case 5 — two receipts either side of one ruling: the NEWEST receipt is after the ruling.
  {id:"bd-newest-receipt-after-ruling", issue_type:"task", labels:["origin:ac-triage"],
   description:$desc, comments:[{text:$r1},{text:$d1},{text:$r2}]},
  # Case 6 — two rulings either side of a receipt, second ruling after: the NEWEST ruling
  # wins even with an earlier receipt present. Still holds `refined`.
  {id:"bd-newest-ruling-after-receipt", issue_type:"task", labels:["origin:ac-triage","refined","refine-full"],
   description:$desc, comments:[{text:$r1},{text:$d1},{text:$r2},{text:$d2}]}
]' >"$FIXTURE_BEADS"

stamped_count() { grep -c "label add $1 refined" "$BR_LOG"; }
stripped_count() { grep -c "label remove $1 refined" "$BR_LOG"; }
unrefined_count() { grep -c "label add $1 unrefined" "$BR_LOG"; }

# --- Case 1: receipt, then ruling, then claim — REFUSED + DOWNGRADED ------------------
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-receipt-then-ruling 2>&1); RC=$?
if [ "$RC" -ne 0 ] && [ "$(stamped_count bd-receipt-then-ruling)" -eq 0 ] \
   && [ "$(stripped_count bd-receipt-then-ruling)" -eq 1 ] \
   && [ "$(unrefined_count bd-receipt-then-ruling)" -eq 1 ] \
   && echo "$OUT" | grep -qi "ruling"; then
  pass "Case 1: a DECISION ruling newer than the last receipt is REFUSED and the stale stamp is DOWNGRADED"
else
  fail "Case 1: expected refusal + downgrade, rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

# --- Case 2: a receipt newer than the ruling PASSES ------------------------------------
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-ruling-then-receipt 2>&1); RC=$?
if [ "$RC" -eq 0 ] && [ "$(stamped_count bd-ruling-then-receipt)" -eq 1 ]; then
  pass "Case 2: a fresh receipt written after the ruling stamps cleanly"
else
  fail "Case 2: expected rc 0 + one stamp, rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

# --- Case 3: a ruling with NO receipt at all is REFUSED --------------------------------
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-ruling-no-receipt 2>&1); RC=$?
if [ "$RC" -ne 0 ] && [ "$(stamped_count bd-ruling-no-receipt)" -eq 0 ] \
   && echo "$OUT" | grep -qi "ruling"; then
  pass "Case 3: a ruling with no receipt at all is REFUSED — the ruling was never polished in"
else
  fail "Case 3: expected refusal, rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

# --- Case 4: no DECISION comment at all — unaffected, normal stamp proceeds ------------
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-no-decision 2>&1); RC=$?
if [ "$RC" -eq 0 ] && [ "$(stamped_count bd-no-decision)" -eq 1 ]; then
  pass "Case 4: a bead with no DECISION comment is unaffected by the ruling leg"
else
  fail "Case 4: expected rc 0 + one stamp, rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

# --- Case 5: the NEWEST receipt (not the first) decides — after the ruling, PASSES -----
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-newest-receipt-after-ruling 2>&1); RC=$?
if [ "$RC" -eq 0 ] && [ "$(stamped_count bd-newest-receipt-after-ruling)" -eq 1 ]; then
  pass "Case 5: the newest receipt (not the first) is what is compared — a later one clears an earlier ruling"
else
  fail "Case 5: expected rc 0 + one stamp, rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

# --- Case 6: the NEWEST ruling (not the first) decides — after the receipt, REFUSED ----
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-newest-ruling-after-receipt 2>&1); RC=$?
if [ "$RC" -ne 0 ] && [ "$(stripped_count bd-newest-ruling-after-receipt)" -eq 1 ] \
   && [ "$(unrefined_count bd-newest-ruling-after-receipt)" -eq 1 ] \
   && echo "$OUT" | grep -qi "ruling"; then
  pass "Case 6: the newest ruling (not the first) is what is compared — a later one stales an earlier receipt"
else
  fail "Case 6: expected refusal + downgrade, rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "$PASSES passed, $FAILURES failed — all stamp-refined ruling-staleness tests passed."
  exit 0
else
  echo "$FAILURES fixture test(s) FAILED."
  exit 1
fi
