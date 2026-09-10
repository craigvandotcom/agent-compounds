#!/usr/bin/env bash
# stamp-refined-fixpoint.test.sh — the lean fixpoint-receipt gate inside stamp-refined.sh.
#
# `refined` is what the worker loop selects on, and stamp-refined.sh is its only sanctioned
# writer. For an ac-origin bead the stamp is legal only against a fixpoint receipt — so the
# gate lives in the WRITER, not in ac-polish's procedure: a check a caller can route around
# is not a gate.
#
# THE SEAM IS EXECUTED, NOT COPIED: the accept case RUNS skills/_tools/polish-fixpoint.sh to
# produce a real receipt and feeds THAT through the mocked `br` into the stamp. A hand-copied
# fixture string stays green when either side of the seam drifts, which is the untested seam
# rather than coverage — Case 7 mutates the producer's token to prove the coupling.
#
# Run directly:  bash skills/_tools/stamp-refined-fixpoint.test.sh
# Discovered automatically by scripts/run-all-harnesses.sh (glob over *.test.sh).
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
STAMP="$DIR/stamp-refined.sh"
FIXPOINT="$ROOT/skills/_tools/polish-fixpoint.sh"

FAILURES=0
PASSES=0
pass() { echo "  PASS: $1"; PASSES=$((PASSES + 1)); }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

# Every case runs INSIDE a fixture repo, so the TOUCHERS LEG (2026-09-03) derives from a tree
# the harness controls. The older fixtures' Delivers paths do not exist here, so they are new
# artifacts and owe nothing — those cases keep their meaning unchanged. Cases 12–16 build on:
#   lib/db/foods.ts   referenced by lib/api.ts  -> a touchers line is owed
#   lib/lonely.ts     referenced by nothing     -> nothing owed
FIXREPO="$WORK/repo"; mkdir -p "$FIXREPO/lib/db"
printf 'export function updateFood() {}\n' >"$FIXREPO/lib/db/foods.ts"
printf 'import { updateFood } from "../db/foods"\n' >"$FIXREPO/lib/api.ts"
printf 'export const lonely = 1\n' >"$FIXREPO/lib/lonely.ts"
(cd "$FIXREPO" && git init -q)
cd "$FIXREPO" || { echo "HARNESS FAIL: cannot enter fixture repo"; exit 1; }

# --- the mocked board: `show --json`, `comments add -f`, and a call log -----------------
MOCK="$WORK/bin"; mkdir -p "$MOCK"
BR_LOG="$WORK/br.log"
BR_SHOW_COUNT="$WORK/br-show-count"; : >"$BR_SHOW_COUNT"
FIXTURE_BEADS="$WORK/beads.json"; export FIXTURE_BEADS BR_LOG BR_SHOW_COUNT
cat >"$MOCK/br" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$BR_LOG"
case "$1" in
  show)
    shift; ids=()
    while [ $# -gt 0 ]; do case "$1" in --json) shift ;; *) ids+=("$1"); shift ;; esac; done
    # BR_SHOW_BUDGET=N serves the first N show reads, then dies — the switch that
    # drives the dead-read cases (23–24) at a specific point in the flow.
    if [ -n "${BR_SHOW_BUDGET:-}" ]; then
      n=$(cat "$BR_SHOW_COUNT" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" >"$BR_SHOW_COUNT"
      [ "$n" -le "$BR_SHOW_BUDGET" ] || { echo '{"error":{"code":"BR_DEAD","message":"mock dead read"}}'; exit 1; }
    fi
    want=$(printf '%s\n' "${ids[@]}" | jq -R . | jq -s .)
    out=$(jq --argjson want "$want" '[ .[] | select(.id as $i | $want | index($i)) ]' "$FIXTURE_BEADS")
    # BR_SHOW_OBJECT=1 reproduces the shape the real `br` intermittently answers with under
    # concurrent readers: the bare OBJECT instead of a one-element array (Case 18).
    if [ "$(printf '%s' "$out" | jq 'length')" -eq 1 ] && [ "${BR_SHOW_OBJECT:-0}" = 1 ]; then
      printf '%s\n' "$out" | jq '.[0]'; exit 0
    fi
    [ "$(printf '%s' "$out" | jq 'length')" -gt 0 ] && { printf '%s\n' "$out"; exit 0; }
    echo '{"error":{"code":"ISSUE_NOT_FOUND"}}'; exit 1 ;;
  label)
    # `label add <id> <name>` / `label remove <id> <name>` — MUTATE the fixture board
    # so the read-back leg (D1, ac-heyt.7) sees what was written. BR_LABEL_FAIL=1
    # rejects the write without touching the board — the failed-write case.
    if [ "${2:-}" = add ] || [ "${2:-}" = remove ]; then
      op="$2"; id="$3"; name="$4"
      if [ "${BR_LABEL_FAIL:-0}" = 1 ]; then exit 1; fi
      tmp=$(mktemp)
      jq --arg id "$id" --arg name "$name" --arg op "$op" '
        [ .[] | if .id == $id then
          if $op == "add" then .labels = ((.labels // []) + [$name] | unique)
          else .labels = ((.labels // []) - [$name]) end
        else . end ]' "$FIXTURE_BEADS" >"$tmp" && mv "$tmp" "$FIXTURE_BEADS"
    fi
    exit 0 ;;
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

# An ac-schema description: four sections, every AC naming an executable probe. element4-check
# accepts this shape (ac-4y92), so anything refused below is refused by the RECEIPT gate.
SCHEMA_DESC='## Intent
Why this matters, with no line numbers.

## Acceptance Criteria
- The gate ships as an executable script.
  Probe: `test -x skills/ac-implement/scripts/close-gate.sh` — tier: none

## Delivers
- gate: skills/ac-implement/scripts/close-gate.sh

## Consumes
- none
'
LEGACY_DESC='## Declared RED
Test `x` must FAIL before the fix; assert exit 1.
'
LEGACY_PROBED_DESC='## Declared RED
Test `x` must FAIL before the fix; assert exit 1.

## Acceptance Criteria
- The fix lands.
  Probe: `grep -q "the fix" src/x.ts` — tier: none
'

write_board() {
  jq -n --arg schema_desc "$SCHEMA_DESC" --arg leg "$LEGACY_DESC" --arg legp "$LEGACY_PROBED_DESC" '[
    {id:"bd-ac-noreceipt", issue_type:"task", labels:["origin:ac-beadify"], description:$schema_desc, comments:[]},
    {id:"bd-ac-receipt",   issue_type:"task", labels:["origin:ac-beadify"], description:$schema_desc, comments:[]},
    {id:"bd-ac-malformed", issue_type:"task", labels:["origin:ac-beadify"], description:$schema_desc,
     comments:[{text:"POLISH-FIXPOINT:"}]},
    {id:"bd-ac-round1",    issue_type:"task", labels:["origin:ac-beadify"], description:$schema_desc,
     comments:[{text:"POLISH-FIXPOINT: mode=bead rounds=1 sha256=deadbeefdeadbeef at=2026-08-27T00:00:00Z engine=polish-fixpoint.sh"}]},
    {id:"bd-ac-direct",    issue_type:"task", labels:["origin:ac-beadify"], description:$schema_desc, comments:[]},
    {id:"bd-legacy",        issue_type:"task", labels:["origin:ac-beadify"],  description:$leg, comments:[]},
    {id:"bd-legacy-probed", issue_type:"task", labels:["origin:ac-beadify"],  description:$legp, comments:[]},
    {id:"bd-external-probed", issue_type:"task", labels:["origin:ac-triage"], description:$legp, comments:[]},
    {id:"bd-legacy-stale",  issue_type:"task", labels:["refined","refine-full"], description:$leg, comments:[]},
    {id:"bd-ac-stale-receipt", issue_type:"task", labels:["origin:ac-beadify","refined"], description:$schema_desc, comments:[]},
    {id:"bd-external-already", issue_type:"task", labels:["refined","refine-full"], description:$legp, comments:[]},
    {id:"bd-clean",        issue_type:"task", labels:["origin:ac-triage"], description:$legp, comments:[]}
  ]' >"$FIXTURE_BEADS"
}
write_board

stamped_count() { grep -c "label add $1 refined" "$BR_LOG"; }
stripped_count() { grep -c "label remove $1 refined" "$BR_LOG"; }
unrefined_count() { grep -c "label add $1 unrefined" "$BR_LOG"; }

# --- Case 1: ac-origin bead with NO receipt -> REFUSED, and no label is written -------
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-ac-noreceipt 2>&1); RC=$?
if [ "$RC" -ne 0 ] && [ "$(stamped_count bd-ac-noreceipt)" -eq 0 ] \
   && echo "$OUT" | grep -qi "fixpoint"; then
  pass "Case 1: an ac-origin bead with no fixpoint receipt is REFUSED, no label written"
else
  fail "Case 1: expected refusal with no label write, rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

# --- Case 2: THE SEAM — a receipt produced by polish-fixpoint.sh itself lets it stamp --
: >"$BR_LOG"
STATE="$WORK/state"; ART="$WORK/artifact.md"
printf 'round zero\n' >"$ART"
PRE0=$(shasum -a 256 "$ART" | awk '{print $1}')
PATH="$MOCK:$PATH" bash "$FIXPOINT" --mode bead --target bd-ac-receipt --artifact "$ART" \
  --state "$STATE" --round 1 --pre "deadbeef" >/dev/null 2>&1   # round 1: CONTINUE, records the sha
FP_OUT=$(PATH="$MOCK:$PATH" bash "$FIXPOINT" --mode bead --target bd-ac-receipt --artifact "$ART" \
  --state "$STATE" --round 2 --pre "$PRE0" --findings 0 2>&1); FP_RC=$?
if [ "$FP_RC" -eq 0 ] && grep -q "POLISH-FIXPOINT:" "$STATE/receipt.txt"; then
  pass "Case 2a: polish-fixpoint.sh reached a fixpoint and wrote a real receipt"
else
  fail "Case 2a: producer did not stamp, rc=$FP_RC. Output: $FP_OUT"
fi
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-ac-receipt 2>&1); RC=$?
if [ "$RC" -eq 0 ] && [ "$(stamped_count bd-ac-receipt)" -eq 1 ]; then
  pass "Case 2b: with the PRODUCER'S OWN receipt on the bead, the stamp is written once"
else
  fail "Case 2b: expected exit 0 and one label write, rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

# --- Case 3: a probe-LESS description is refused on EITHER origin (2026-08-29 floor) -----
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-legacy 2>&1); RC=$?
if [ "$RC" -ne 0 ] && [ "$(stamped_count bd-legacy)" -eq 0 ] \
   && echo "$OUT" | grep -qi "probe"; then
  pass "Case 3: a probe-less legacy bead is REFUSED — a Declared RED alone no longer stamps"
else
  fail "Case 3: expected probe-refusal with no label write, rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

# --- Case 3b: a PROBED family bead with no receipt is REFUSED (one pipeline: every ------
# --- family origin owes the receipt; the old ac2-only scoping is gone with the rename) --
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-legacy-probed 2>&1); RC=$?
if [ "$RC" -ne 0 ] && [ "$(stamped_count bd-legacy-probed)" -eq 0 ] \
   && echo "$OUT" | grep -qi "fixpoint"; then
  pass "Case 3b: a probed family-origin bead with no receipt is REFUSED — the receipt gate covers every family origin"
else
  fail "Case 3b: expected receipt refusal, rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

# --- Case 3c: a probed bead from OUTSIDE the family stamps with no receipt --------------
# --- (the receipt gate is scoped to family origins, not the whole board) ----------------
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-external-probed 2>&1); RC=$?
if [ "$RC" -eq 0 ] && [ "$(stamped_count bd-external-probed)" -eq 1 ]; then
  pass "Case 3c: a probed non-family-origin bead still stamps with no receipt (the receipt gate stays family-scoped)"
else
  fail "Case 3c: expected the non-family probed bead to stamp, rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

# --- Case 4: a receipt header with no rounds/sha is ABSENT, not satisfied --------------
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-ac-malformed 2>&1); RC=$?
if [ "$RC" -ne 0 ] && [ "$(stamped_count bd-ac-malformed)" -eq 0 ]; then
  pass "Case 4: a receipt header carrying no measurement is treated as ABSENT"
else
  fail "Case 4: expected refusal, rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

# --- Case 5: rounds=1 is not a fixpoint — a clean first round proves nothing -----------
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-ac-round1 2>&1); RC=$?
if [ "$RC" -ne 0 ] && [ "$(stamped_count bd-ac-round1)" -eq 0 ]; then
  pass "Case 5: a rounds=1 receipt is REFUSED (a fixpoint needs a clean round >= 2)"
else
  fail "Case 5: expected refusal, rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

# --- Case 6: the refusal comes from the SCRIPT, with no caller involved ----------------
# Sourced-and-called, the other entry point: the gate must not live in a wrapper.
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash -c ". '$STAMP'; stamp_refined bd-ac-direct" 2>&1); RC=$?
if [ "$RC" -ne 0 ] && [ "$(stamped_count bd-ac-direct)" -eq 0 ]; then
  pass "Case 6: the sourced function refuses too — the gate is in the writer, not a caller"
else
  fail "Case 6: expected refusal from the function itself, rc=$RC. Output: $OUT"
fi

# --- Case 7: NEGATIVE CONTROL on the seam — drift either side and this goes RED --------
# Rewrite the produced receipt's token as a drifted producer would, feed it in, demand a refusal.
: >"$BR_LOG"
DRIFTED=$(sed 's/^POLISH-FIXPOINT:/POLISH-FIXPOINT-V2:/' "$STATE/receipt.txt")
tmp=$(mktemp)
jq --arg t "$DRIFTED" '[ .[] | if .id == "bd-ac-noreceipt" then .comments = [{text:$t}] else . end ]' \
   "$FIXTURE_BEADS" >"$tmp" && mv "$tmp" "$FIXTURE_BEADS"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-ac-noreceipt 2>&1); RC=$?
if [ "$RC" -ne 0 ] && [ "$(stamped_count bd-ac-noreceipt)" -eq 0 ]; then
  pass "Case 7: NEGATIVE CONTROL — a drifted receipt token no longer satisfies the gate"
else
  fail "Case 7: a drifted receipt was accepted — the matcher is not coupled to the producer"
fi

# --- Case 8: DOWNGRADE — a bead still HOLDING `refined` that no longer qualifies -------
# The 2026-08-31 measured failure: pre-floor stamps survived every later pass because a
# refusal only declined to ADD the label — it never REMOVED the stale one. "Restamped on
# sight, never grandfathered" must be bidirectional: refusal + currently holds = strip.
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-legacy-stale 2>&1); RC=$?
if [ "$RC" -ne 0 ] && [ "$(stamped_count bd-legacy-stale)" -eq 0 ] \
   && [ "$(stripped_count bd-legacy-stale)" -eq 1 ] \
   && [ "$(unrefined_count bd-legacy-stale)" -eq 1 ] \
   && echo "$OUT" | grep -qi "DOWNGRADED"; then
  pass "Case 8: a stale refined stamp is STRIPPED (refined removed, unrefined added) on refusal"
else
  fail "Case 8: expected refusal + downgrade, rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

# --- Case 9: an UNUSABLE gate mutates NOTHING — never strip on cannot-check -----------
# (the executed wrapper preserves the rc class — 0 stamped · 1 refused · 2 cannot-check —
# so a cannot-check mutates no label; the assertion that matters is the LABEL LOG)
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-absent-from-board 2>&1); RC=$?
if [ "$RC" -ne 0 ] && [ -z "$(grep -E 'label (add|remove) bd-absent-from-board' "$BR_LOG")" ]; then
  pass "Case 9: a cannot-check refusal writes no label change — stripping only on a content verdict"
else
  fail "Case 9: expected non-zero rc with zero label ops, rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

# --- Case 10: a family bead HOLDING refined with no receipt is also downgraded ---------
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-ac-stale-receipt 2>&1); RC=$?
if [ "$RC" -ne 0 ] && [ "$(stripped_count bd-ac-stale-receipt)" -eq 1 ] \
   && [ "$(unrefined_count bd-ac-stale-receipt)" -eq 1 ]; then
  pass "Case 10: a pre-receipt family stamp is downgraded too (never grandfathered applies to the receipt gate)"
else
  fail "Case 10: expected refusal + downgrade, rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

# --- Case 11: RE-STAMP is idempotent — a conforming bead already holding refined -------
# --- stays stamped (label add once) and is never stripped ------------------------------
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-external-already 2>&1); RC=$?
if [ "$RC" -eq 0 ] && [ "$(stamped_count bd-external-already)" -eq 1 ] \
   && [ "$(stripped_count bd-external-already)" -eq 0 ]; then
  pass "Case 11: a conforming bead already holding refined re-stamps cleanly, never stripped"
else
  fail "Case 11: expected rc 0, one stamp, zero strips, rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

# --- Cases 12–16: the TOUCHERS LEG (2026-09-03) — the trigger is derived from the tree ----
# Non-family origin (no receipt owed) with a probe, so every verdict below is the touchers
# leg's alone. The commands inside the touchers lines run in the fixture repo.
T_NONE='## Intent
Guard updateFood against zero-row updates.

## Acceptance Criteria
- The guard lands.
  Probe: `grep -q count lib/db/foods.ts` — tier: none

## Delivers
- `lib/db/foods.ts` — updateFood row-count guard

## Consumes
- none
'
T_OK='## Intent
Guard updateFood against zero-row updates.

## Acceptance Criteria
- The guard lands.
  Probe: `grep -q count lib/db/foods.ts` — tier: none

## Delivers
- `lib/db/foods.ts` — updateFood row-count guard
  touchers: `rg -l -F "db/foods" lib -g "!lib/db/foods.ts"` → 1 · owned by: bd-api-caller

## Consumes
- none
'
T_STALE=${T_OK/→ 1 · owned by/→ 3 · owned by}
T_MALFORMED=${T_OK/ · owned by: bd-api-caller/}
T_LONELY=${T_NONE/lib\/db\/foods.ts\` — updateFood row-count guard/lib\/lonely.ts\` — lonely constant}
T_NEW=${T_NONE/lib\/db\/foods.ts\` — updateFood row-count guard/lib\/new-module.ts\` — a file that does not exist yet}
tmp=$(mktemp)
jq --arg none "$T_NONE" --arg ok "$T_OK" --arg stale "$T_STALE" --arg mal "$T_MALFORMED" --arg lonely "$T_LONELY" --arg new "$T_NEW" '. + [
  {id:"bd-t-none",   issue_type:"task", labels:["origin:ac-triage"], description:$none,   comments:[]},
  {id:"bd-t-ok",     issue_type:"task", labels:["origin:ac-triage"], description:$ok,     comments:[]},
  {id:"bd-t-stale",  issue_type:"task", labels:["origin:ac-triage","refined"], description:$stale, comments:[]},
  {id:"bd-t-mal",    issue_type:"task", labels:["origin:ac-triage"], description:$mal,    comments:[]},
  {id:"bd-t-lonely", issue_type:"task", labels:["origin:ac-triage"], description:$lonely, comments:[]},
  {id:"bd-t-new",    issue_type:"task", labels:["origin:ac-triage"], description:$new,    comments:[]}
]' "$FIXTURE_BEADS" >"$tmp" && mv "$tmp" "$FIXTURE_BEADS"

: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-t-none 2>&1); RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "unowned-touchers" && echo "$OUT" | grep -q "referenced by 1 file" \
   && [ "$(stamped_count bd-t-none)" -eq 0 ]; then
  pass "Case 12: a referenced Delivers path with no touchers line is REFUSED [unowned-touchers], naming the derived count"
else
  fail "Case 12: expected rc 1 + unowned-touchers, rc=$RC. Output: $OUT"
fi

: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-t-ok 2>&1); RC=$?
if [ "$RC" -eq 0 ] && [ "$(stamped_count bd-t-ok)" -eq 1 ]; then
  pass "Case 13: a touchers line whose command reproduces its count STAMPS"
else
  fail "Case 13: expected rc 0 + one stamp, rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-t-stale 2>&1); RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "declare → 3 but the command reproduces 1" \
   && [ "$(stripped_count bd-t-stale)" -eq 1 ] && [ "$(stamped_count bd-t-stale)" -eq 0 ]; then
  pass "Case 14: a STALE touchers count is refused with both numbers, and a held stamp is DOWNGRADED"
else
  fail "Case 14: expected rc 1 + stale refusal + downgrade, rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-t-mal 2>&1); RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "malformed"; then
  pass "Case 15: a touchers line with no owned-by / out-of-scope is refused as malformed"
else
  fail "Case 15: expected rc 1 + malformed, rc=$RC. Output: $OUT"
fi

: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-t-lonely 2>&1); RC=$?
OUT2=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-t-new 2>&1); RC2=$?
if [ "$RC" -eq 0 ] && [ "$RC2" -eq 0 ] && [ "$(stamped_count bd-t-lonely)" -eq 1 ] && [ "$(stamped_count bd-t-new)" -eq 1 ]; then
  pass "Case 16: an unreferenced file and a not-yet-existing file owe no touchers line — both STAMP"
else
  fail "Case 16: expected both to stamp, rc=$RC/$RC2. Output: $OUT / $OUT2"
fi

# Case 17 — NEGATIVE CONTROL on the tool itself: the bead that STAMPS in Case 13 must be
# REFUSED, not stamped, when rg cannot run. A missing/broken rg reads as "zero references"
# only if the writer forgets to look at rg's exit code — that is the silent pass this case
# pins shut. The shim sits in its own dir so Cases 12–16 keep the real rg.
NORG="$WORK/norg"; mkdir -p "$NORG"
printf '#!/usr/bin/env bash\nexit 127\n' >"$NORG/rg"; chmod +x "$NORG/rg"
: >"$BR_LOG"
OUT=$(PATH="$NORG:$MOCK:$PATH" bash "$STAMP" bd-t-ok 2>&1); RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "rg exited 127" && [ "$(stamped_count bd-t-ok)" -eq 0 ]; then
  pass "Case 17: NEGATIVE CONTROL — when rg cannot run, a referenced Delivers path is REFUSED, never read as zero references"
else
  fail "Case 17: expected a refusal naming rg's exit code and no stamp, rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

# --- Case 18: `br show --json` answering with a bare OBJECT still stamps ----------------
# Measured flake: under concurrent readers br sometimes answers with the object rather than
# a one-element array. Every filter in stamp-refined.sh is `.[0]`, which dies "Cannot index
# object with number" on that shape — and a dead filter reads as "no labels, no description",
# so the bead is refused for a defect the READER invented, not one the bead has.
# element4-check.sh is STUBBED here on purpose: it maps a non-array to `[]` and exits 2
# (its own NOT-GATED leg), so without the stub this case would measure that gate instead of
# this script's meta reader. The verdict below is the normaliser's alone.
E4STUB="$WORK/e4-pass.sh"; printf '#!/usr/bin/env bash\nexit 0\n' >"$E4STUB"; chmod +x "$E4STUB"
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" BR_SHOW_OBJECT=1 ELEMENT4_CHECK="$E4STUB" bash "$STAMP" bd-external-probed 2>&1); RC=$?
if [ "$RC" -eq 0 ] && [ "$(stamped_count bd-external-probed)" -eq 1 ]; then
  pass "Case 18a: an object-shaped 'br show --json' answer is normalised — the bead still stamps"
else
  fail "Case 18a: expected rc 0 + one stamp on the object shape, rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

# --- Case 18b: NEGATIVE CONTROL — strip the normaliser and the same input must NOT stamp -
MUTDIR="$WORK/mutant-shape"; mkdir -p "$MUTDIR"
sed 's/if type=="array" then . else \[.\] end/./' "$STAMP" >"$MUTDIR/stamp-refined.sh"
if ! grep -q 'if type=="array"' "$MUTDIR/stamp-refined.sh" && grep -q "jq '\.'" "$MUTDIR/stamp-refined.sh"; then
  pass "Case 18b-i: the negative-control mutation applied (the shape normaliser is gone)"
else
  fail "Case 18b-i: mutation did not apply — the normaliser moved; Case 18b-ii is vacuous"
fi
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" BR_SHOW_OBJECT=1 ELEMENT4_CHECK="$E4STUB" TOUCHERS_TOOL="$DIR/touchers.sh" \
      bash "$MUTDIR/stamp-refined.sh" bd-external-probed 2>&1); RC=$?
if [ "$RC" -ne 0 ] && [ "$(stamped_count bd-external-probed)" -eq 0 ]; then
  pass "Case 18b-ii: NEGATIVE CONTROL — without the normaliser the object shape refuses a conforming bead"
else
  fail "Case 18b-ii: the un-normalised reader accepted the object shape — Case 18a proves nothing, rc=$RC. Output: $OUT"
fi

# --- Cases 19–21: obligations are derived from Delivers BULLETS only (ac-l7xt) ---------
# A path named ONLY inside a touchers line's own command or clause is a disposition, not a
# delivery — extracting it invented obligations no bullet could satisfy (measured 2026-09-05:
# one group refused 9 of 12 beads for clause-mentioned paths). And a touchers line binds to
# its OWN bullet only: the first line in the section must never answer for a later bullet.
B_CLAUSE='## Intent
Guard updateFood against zero-row updates.

## Acceptance Criteria
- The guard lands.
  Probe: `grep -q count lib/db/foods.ts` — tier: none

## Delivers
- `lib/db/foods.ts` — updateFood row-count guard
  touchers: `rg -l -F "db/foods" lib -g "!lib/db/foods.ts"` → 1 · owned by: bd-api-caller | out-of-scope: lib/api.ts is the caller and ships in this bead

## Consumes
- none
'
# Case 20: a STALE touchers line in an EARLIER bullet must not answer for the real bullet.
B_CLAUSE_FIRST='## Intent
Guard updateFood against zero-row updates.

## Acceptance Criteria
- The guard lands.
  Probe: `grep -q count lib/db/foods.ts` — tier: none

## Delivers
- scope note: the consumer set is tracked by the line beneath
  touchers: `rg -l -F "db/foods" lib -g "!lib/db/foods.ts"` → 9 · owned by: bd-scope-note | out-of-scope: lib/db/foods.ts is delivered by the bullet beneath
- `lib/db/foods.ts` — updateFood row-count guard
  touchers: `rg -l -F "db/foods" lib -g "!lib/db/foods.ts"` → 1 · owned by: bd-api-caller

## Consumes
- none
'
# Case 21: a touchers line whose ONLY path mention is its own command owes nothing.
B_OWN_CMD='## Intent
Guard updateFood against zero-row updates.

## Acceptance Criteria
- The guard lands.
  Probe: `grep -q count lib/db/foods.ts` — tier: none

## Delivers
- caller-inventory note
  touchers: `rg -l -F "db/foods" lib -g "!lib/db/foods.ts"` → 1 · owned by: bd-api-caller
- `lib/db/foods.ts` — updateFood row-count guard
  touchers: `rg -l -F "db/foods" lib -g "!lib/db/foods.ts"` → 1 · owned by: bd-api-caller

## Consumes
- none
'
tmp=$(mktemp)
jq --arg clause "$B_CLAUSE" --arg first "$B_CLAUSE_FIRST" --arg own "$B_OWN_CMD" '. + [
  {id:"bd-b-clause",  issue_type:"task", labels:["origin:ac-triage"], description:$clause, comments:[]},
  {id:"bd-b-first",   issue_type:"task", labels:["origin:ac-triage"], description:$first,  comments:[]},
  {id:"bd-b-own-cmd", issue_type:"task", labels:["origin:ac-triage"], description:$own,    comments:[]}
]' "$FIXTURE_BEADS" >"$tmp" && mv "$tmp" "$FIXTURE_BEADS"

: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-b-clause 2>&1); RC=$?
if [ "$RC" -eq 0 ] && [ "$(stamped_count bd-b-clause)" -eq 1 ]; then
  pass "Case 19: a path named ONLY inside a touchers clause owes nothing — the bead stamps"
else
  fail "Case 19: expected rc 0 + stamp, rc=$RC. Output: $OUT"
fi

: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-b-first 2>&1); RC=$?
if [ "$RC" -eq 0 ] && [ "$(stamped_count bd-b-first)" -eq 1 ]; then
  pass "Case 20: a clause mention in an EARLIER bullet binds nothing — the real bullet's own line answers, and it is correct"
else
  fail "Case 20: expected rc 0 + stamp (the earlier stale line must not answer for the later bullet), rc=$RC. Output: $OUT"
fi

: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-b-own-cmd 2>&1); RC=$?
if [ "$RC" -eq 0 ] && [ "$(stamped_count bd-b-own-cmd)" -eq 1 ]; then
  pass "Case 21: a touchers line whose only path mention is its own command owes nothing"
else
  fail "Case 21: expected rc 0 + stamp, rc=$RC. Output: $OUT"
fi

# --- Cases 22–24: the WRITE READ-BACK (D1) — a write the board did not accept ------
# --- (or a board that cannot be re-read) is WRITE-FAILED, never a silent STAMPED -----
# The stamp leg and the downgrade leg each RE-READ the board after writing and assert
# the label set they meant to produce. Exit codes are never trusted: the sensor is the
# read-back. bd-external-probed is the clean-stamp bead (Case 3c/18a); its flow makes
# two show reads before the read-back (element4 + the meta read).

# Case 22: a FAILED `br label add` — the board is not updated, the read-back refuses.
# bd-clean is a never-stamped bead, so the read-back cannot find an earlier refined.
: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" BR_LABEL_FAIL=1 bash "$STAMP" bd-clean 2>&1); RC=$?
if [ "$RC" -eq 2 ] && echo "$OUT" | grep -q "WRITE-FAILED bd-clean" \
   && ! echo "$OUT" | grep -q "STAMPED"; then
  pass "Case 22: a rejected label write is WRITE-FAILED (rc 2), never a STAMPED"
else
  fail "Case 22: expected rc 2 + WRITE-FAILED and no STAMPED, rc=$RC. Output: $OUT"
fi

# Case 23: a DEAD READ after the write — the read-back cannot verify the stamp.
: >"$BR_LOG"
: >"$BR_SHOW_COUNT"
OUT=$(PATH="$MOCK:$PATH" BR_SHOW_BUDGET=2 bash "$STAMP" bd-clean 2>&1); RC=$?
if [ "$RC" -eq 2 ] && echo "$OUT" | grep -q "WRITE-FAILED bd-clean"; then
  pass "Case 23: a dead read after the write is WRITE-FAILED — the stamp is not trusted on exit codes"
else
  fail "Case 23: expected rc 2 + WRITE-FAILED, rc=$RC. Output: $OUT"
fi

# Case 24: a DEAD READ during the downgrade — a cannot-check, never "no stale stamp held".
: >"$BR_LOG"
: >"$BR_SHOW_COUNT"
OUT=$(PATH="$MOCK:$PATH" BR_SHOW_BUDGET=2 bash "$STAMP" bd-legacy-stale 2>&1); RC=$?
if [ "$RC" -eq 2 ] && echo "$OUT" | grep -q "WRITE-FAILED bd-legacy-stale"; then
  pass "Case 24: a dead read during the downgrade is WRITE-FAILED (rc 2), never 'no stale stamp held'"
else
  fail "Case 24: expected rc 2 + WRITE-FAILED, rc=$RC. Output: $OUT"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "$PASSES passed, $FAILURES failed — all stamp-refined fixpoint-receipt tests passed."
  exit 0
else
  echo "$FAILURES fixture test(s) FAILED."
  exit 1
fi
