#!/usr/bin/env bash
# tidy-scan.test.sh — proof harness for tidy-scan.sh: every rule positive and negative, the
# finding dedupe, NOT-GATED on a dead read, and the read-only invariant. No real board.
# Run: bash skills/ac-tidy/scripts/tidy-scan.test.sh   (exit 0 = all cases pass)

SELF=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]:-$0}")")" && pwd)
SCRIPT="$SELF/tidy-scan.sh"
CASES=0; FAILURES=0
pass() { CASES=$((CASES+1)); echo "ok   $*"; }
fail() { CASES=$((CASES+1)); FAILURES=$((FAILURES+1)); echo "FAIL $*"; }

W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
R="$W/repo"; mkdir -p "$R/_backlog/pool" "$R/_backlog/_done" "$R/_plans" "$R/.beads" "$W/bin"
git -C "$R" init -q

# Stub br: every list returns the whole fixture board; show returns one row; STUB_FAIL refuses.
cat >"$W/bin/br" <<'STUB'
#!/usr/bin/env bash
[ -n "${STUB_FAIL:-}" ] && { echo '{"error":{"message":"stub refused"}}'; exit 1; }
case "$1" in
  list) jq -c '{issues: .}' "$BOARD" ;;
  show) jq -c --arg id "$2" '[.[] | select(.id == $id) | .dependencies = []]' "$BOARD" ;;
esac
STUB
chmod +x "$W/bin/br"
export AC2_BR_CMD="$W/bin/br" BOARD="$W/board.json"

bead() {  # bead <id> <status> <type> <labels-csv> [description] [title]
  jq -nc --arg id "$1" --arg st "$2" --arg ty "$3" --arg l "$4" --arg d "${5:-}" --arg t "${6:-t $1}" \
    '{id:$id,status:$st,issue_type:$ty,title:$t,description:$d,
      created_at:"2026-09-01T00:00:00Z",labels:($l|split(",")|map(select(. != "")))}'
}
{
  bead ac-strip   closed task  "unrefined"
  bead ac-keep    open   task  "unrefined"
  bead ac-bare    open   task  "origin:manual"
  bead ac-ratif   open   task  "human-ratified"
  bead ac-epicb   open   epic  ""                  "Probe: x"
  bead ac-odd     open   task  "refined,zzz-odd"
  bead EPA        open   epic  "refined"           "Probe: x"
  bead EPA.1      open   task  "refined"
  bead ac-e1      open   task  "refined"
  bead ac-e2      open   task  "refined"
  bead ac-cc1     closed task  "refined"
  bead EPC        closed epic  "refined"
  bead ac-ruled   closed decision "origin:ac-tidy,human-gate" "I2: ac-e1 blocks EPA"
  bead ac-noise   closed task  "ci"                "mentions ac-e2 and EPA"
  bead ac-pm      open   task  "refined,post-merge"
  bead ac-owner   open   decision "human-gate"     "owns ac-pm"
  bead EPIDLE     open   epic  "refined"
  bead EPD        open   epic  "refined"           "Probe: y"
  bead EPD.1      closed task  "refined"
  bead ac-dtask   open   task     "refined" "" "DECISION: pick one"
  bead ac-aact    open   decision "refined" "" "ACTION: rotate the key"
  bead ac-dok     open   decision "refined" "" "DECISION: fine as typed"
  bead ac-dshut   closed task     "refined" "" "DECISION: closed, ignored"
} | jq -s '.' >"$BOARD"
jq -c '.[]' "$BOARD" | jq -c 'if .id == "ac-e1" then .dependencies = [{issue_id:"ac-e1",depends_on_id:"EPA",type:"blocks"}]
  elif .id == "ac-e2" then .dependencies = [{issue_id:"ac-e2",depends_on_id:"EPA",type:"blocks"}]
  elif .id == "ac-cc1" then .dependencies = [{issue_id:"ac-cc1",depends_on_id:"EPC",type:"blocks"}]
  else . end' >"$R/.beads/issues.jsonl"

printf -- '---\nstatus: complete\n---\n# a\n' >"$R/_backlog/pool/complete.md"
printf -- '---\nstatus: captured\n---\n- [x] one\n- [X] two\n' >"$R/_backlog/pool/checked.md"
printf -- '---\nstatus: captured\n---\n- [x] one\n- [ ] two\n' >"$R/_backlog/pool/partial.md"
printf -- '---\nstatus: captured\n---\nprose only\n' >"$R/_backlog/pool/prose.md"
printf -- '---\nstatus: complete\n---\n' >"$R/_backlog/_done/old.md"
printf -- '---\nstatus: beadified\nbeadified: EPD\n---\n' >"$R/_plans/deliverable.md"
printf -- '---\nstatus: beadified\nbeadified: EPA\n---\n' >"$R/_plans/open-kids.md"
printf -- '---\nstatus: beadified\nbeadified: EPC\ndelivered: 2026-09-01T00:00:00Z\n---\n' >"$R/_plans/stamped.md"
printf -- '---\nstatus: draft\n---\n' >"$R/_plans/draft.md"
git -C "$R" add -A && git -C "$R" -c user.email=t@t -c user.name=t commit -qm fixture

OUT=$(cd "$R" && "$SCRIPT"); RC=$?
has()  { printf '%s\n' "$OUT" | grep -qF "$1"; }
cell() { printf '%s\n' "$OUT" | awk -F'\t' -v r="$1" -v t="$2" '$1==r && $2==t {print $3}'; }
[ "$RC" -eq 0 ] && pass "scan exits 0" || fail "scan rc=$RC: $OUT"

[ -n "$(cell backlog-archive _backlog/pool/complete.md)" ] && pass "backlog status: complete → archive" || fail "complete not archived"
[ -n "$(cell backlog-archive _backlog/pool/checked.md)" ]  && pass "backlog all tasks checked → archive" || fail "all-checked not archived"
[ -z "$(cell backlog-archive _backlog/pool/partial.md)" ]  && pass "backlog with an unchecked task → none" || fail "partial archived"
[ -z "$(cell backlog-archive _backlog/pool/prose.md)" ]    && pass "prose-captured backlog (no boxes) → none" || fail "prose archived"
! has "_backlog/_done/old.md" && pass "_done/ backlog skipped" || fail "_done scanned"

[ -n "$(cell plan-deliver _plans/deliverable.md)" ] && pass "plan with every child closed → plan-deliver" || fail "deliverable missed"
[ -z "$(cell plan-deliver _plans/open-kids.md)" ]   && pass "plan with open children → none" || fail "open-kids delivered"
[ -n "$(cell plan-move _plans/stamped.md)" ]        && pass "live plan already delivered: → plan-move" || fail "stamped not moved"
! has "_plans/draft.md" && pass "draft plan → none" || fail "draft proposed"

[ -n "$(cell strip-unrefined ac-strip)" ] && pass "closed + unrefined → strip" || fail "strip missed"
[ -z "$(cell strip-unrefined ac-keep)" ]  && pass "open + unrefined → no strip" || fail "open stripped"
[ -n "$(cell add-unrefined ac-bare)" ]    && pass "open, no lifecycle label → add unrefined" || fail "bare missed"
[ -z "$(cell add-unrefined ac-ratif)" ]   && pass "human-ratified counts as lifecycle → none" || fail "ratified stamped"
[ -z "$(cell add-unrefined ac-epicb)" ]   && pass "epic never stamped unrefined" || fail "epic stamped"

[ "$(cell label-review zzz-odd)" = review ] && pass "unnamed label → review, never remove" || fail "zzz-odd: $(cell label-review zzz-odd)"
[ -z "$(cell label-review origin:manual)" ] && pass "origin:<family> label named → none" || fail "origin family flagged"
! printf '%s\n' "$OUT" | awk -F'\t' '$3 ~ /remove/ && $1 == "label-review"' | grep -q . \
  && pass "no label-review row ever removes" || fail "label-review proposes removal"

[ "$(cell type-review ac-dtask)" = review ] && pass "DECISION: typed task → type-review" || fail "ac-dtask: $(cell type-review ac-dtask)"
[ "$(cell type-review ac-aact)" = review ]  && pass "ACTION: typed decision → type-review" || fail "ac-aact missed"
[ -z "$(cell type-review ac-dok)$(cell type-review ac-dshut)" ] \
  && pass "matching type, or closed → no type-review" || fail "type-review over-flags"

[ "$(cell finding-i2-edge 'ac-e1→EPA')" = "suppressed ac-ruled" ] && pass "I2 edge a closed ac-tidy finding named → suppressed" || fail "e1: $(cell finding-i2-edge 'ac-e1→EPA')"
[ "$(cell finding-i2-edge 'ac-e2→EPA')" = file ] && pass "I2 edge named only by a non-tidy closed bead → file" || fail "e2: $(cell finding-i2-edge 'ac-e2→EPA')"
! has "ac-cc1→EPC" && pass "closed–closed I2 edge → none" || fail "closed edge reported"
[ "$(cell finding-post-merge-tail ac-pm)" = "skip-open ac-owner" ] && pass "post-merge tail an open gate names → skip-open" || fail "pm: $(cell finding-post-merge-tail ac-pm)"
[ "$(cell finding-epic-idle EPIDLE)" = file ] && pass "open epic, no open children, no Probe → finding" || fail "epic-idle missed"
[ -z "$(cell finding-epic-idle EPD)" ] && pass "epic with a Probe: line → no finding" || fail "EPD flagged"

[ -z "$(git -C "$R" status --porcelain)" ] && pass "read-only: fixture tree unchanged" || fail "tree changed: $(git -C "$R" status --porcelain)"

OUT=$(cd "$R" && STUB_FAIL=1 "$SCRIPT" 2>/dev/null); RC=$?
[ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q '^tidy-scan: ?' && ! printf '%s' "$OUT" | grep -q $'\t' \
  && pass "br refused → exit 2, '?', no rows" || fail "br failure rc=$RC out=$OUT"

mv "$R/.beads/issues.jsonl" "$W/j"
OUT=$(cd "$R" && "$SCRIPT"); RC=$?
[ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q 'issues.jsonl unreadable' \
  && pass "missing issues.jsonl → exit 2" || fail "jsonl missing rc=$RC out=$OUT"

echo "tidy-scan.test: $CASES cases, $FAILURES failures"
[ "$FAILURES" -eq 0 ]
