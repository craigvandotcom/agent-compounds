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
  bead ac-legacy  open   task  "retired-lifecycle-marker"
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
  bead ac-canon   open   task  "refined,skill-improvement,human-ratified,origin:ac-land,skill:ac-tidy"
  bead ac-cockpit open   task  "refined,cockpit"
  bead ac-htask   open   task          "refined,human-gate" "" "HUMAN: rotate the key"
  bead ac-hdec    open   decision      "refined,human-gate" "" "HUMAN: pick a vendor"
  bead ac-hinv    open   investigation "refined" "" "HUMAN: look into it"
  bead ac-qdec    open   question      "refined" "" "DECISION: which way"
  bead ac-blk-live   blocked task "refined"
  bead ac-blk-none   blocked task "refined"
  bead ac-blk-closed blocked task "refined"
} | jq -s '.' >"$BOARD"
jq -c '.[]' "$BOARD" | jq -c 'if .id == "ac-e1" then .dependencies = [{issue_id:"ac-e1",depends_on_id:"EPA",type:"blocks"}]
  elif .id == "ac-e2" then .dependencies = [{issue_id:"ac-e2",depends_on_id:"EPA",type:"blocks"}]
  elif .id == "ac-cc1" then .dependencies = [{issue_id:"ac-cc1",depends_on_id:"EPC",type:"blocks"}]
  elif .id == "ac-blk-live" then .dependencies = [{issue_id:"ac-blk-live",depends_on_id:"ac-keep",type:"blocks"}]
  elif .id == "ac-blk-closed" then .dependencies = [{issue_id:"ac-blk-closed",depends_on_id:"ac-strip",type:"blocks"}]
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
# Plan age is its last COMMIT, not its mtime: a NIGHTLY worktree checkout stamps every
# file "now". Commit each aged plan backdated; the stale draft keeps a fresh mtime.
aged() {  # aged <file> <status> <age>
  printf -- '---\nstatus: %s\n---\n' "$2" >"$R/_plans/$1"
  git -C "$R" add -- "_plans/$1"
  GIT_COMMITTER_DATE="$(date -d "$3" -R)" git -C "$R" -c user.email=t@t -c user.name=t \
    commit -qm "$1" --date="$(date -d "$3" -R)" -- "_plans/$1"
}
aged stale-draft.md  draft    '15 days ago'
aged fresh-draft.md  draft    '13 days ago'
aged old-approved.md approved '30 days ago'
touch "$R/_plans/stale-draft.md"
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
[ "$(cell draft-stale _plans/stale-draft.md)" = review ] && pass "draft committed 15d ago, fresh mtime → draft-stale flagged" || fail "stale-draft: $(cell draft-stale _plans/stale-draft.md)"
[ -z "$(cell draft-stale _plans/fresh-draft.md)" ] && pass "13-day draft → not flagged" || fail "fresh-draft flagged"
[ -z "$(cell draft-stale _plans/old-approved.md)" ] && pass "30-day approved plan → not flagged" || fail "old-approved flagged"

[ -n "$(cell strip-unrefined ac-strip)" ] && pass "closed + unrefined → strip" || fail "strip missed"
[ -z "$(cell strip-unrefined ac-keep)" ]  && pass "open + unrefined → no strip" || fail "open stripped"
[ -n "$(cell add-unrefined ac-bare)" ]    && pass "open, no lifecycle label → add unrefined" || fail "bare missed"
[ -n "$(cell add-unrefined ac-legacy)" ]  && pass "a retired lifecycle-label token no longer counts → add-unrefined" || fail "legacy label counted"
[ -z "$(cell add-unrefined ac-epicb)" ]   && pass "epic never stamped unrefined" || fail "epic stamped"

[ "$(cell label-review zzz-odd)" = review ] && pass "unnamed label → review, never remove" || fail "zzz-odd: $(cell label-review zzz-odd)"
[ -z "$(cell label-review origin:manual)" ] && pass "origin:<family> label named → none" || fail "origin family flagged"
[ -z "$(cell label-review skill-improvement)$(cell label-review human-ratified)" ] \
  && pass "skill-improvement + human-ratified (declared) → no label-review row" || fail "declared canon flagged"
[ -z "$(cell label-review origin:ac-land)$(cell label-review skill:ac-tidy)" ] \
  && pass "declared prefix families (origin:*, skill:*) → none" || fail "family flagged"
[ "$(cell label-review cockpit)" = review ] \
  && pass "bare cockpit label: a prose path mention (infrastructure/services/cockpit/...) never declares it" || fail "cockpit: $(cell label-review cockpit)"
! printf '%s\n' "$OUT" | awk -F'\t' '$1 == "label-review" && $2 ~ /\// {print}' | grep -q . \
  && ! printf '%s\n' "$OUT" | awk -F'\t' '$1 == "label-review" && ($2 == "infrastructure" || $2 == "services")' | grep -q . \
  && pass "path-shaped canon creates no truncated label token" || fail "truncated path token in label-review"
! printf '%s\n' "$OUT" | awk -F'\t' '$3 ~ /remove/ && $1 == "label-review"' | grep -q . \
  && pass "no label-review row ever removes" || fail "label-review proposes removal"

[ "$(cell type-review ac-dtask)" = review ] && pass "DECISION: typed task → type-review" || fail "ac-dtask: $(cell type-review ac-dtask)"
[ "$(cell type-review ac-aact)" = review ]  && pass "ACTION: typed decision → type-review" || fail "ac-aact missed"
[ -z "$(cell type-review ac-dok)$(cell type-review ac-dshut)" ] \
  && pass "matching type, or closed → no type-review" || fail "type-review over-flags"
[ -z "$(cell type-review ac-htask)" ] && pass "task titled HUMAN: (canonical human-action shape) → none" || fail "HUMAN: task flagged"
[ -z "$(cell type-review ac-hdec)" ]  && pass "decision titled HUMAN: → none" || fail "HUMAN: decision flagged"
[ "$(cell type-review ac-hinv)" = review ] && pass "investigation titled HUMAN: → type-review" || fail "ac-hinv missed"
[ "$(cell type-review ac-qdec)" = review ] && pass "question titled DECISION: → type-review" || fail "ac-qdec missed"

[ "$(cell finding-i2-edge 'ac-e1→EPA')" = "suppressed ac-ruled" ] && pass "I2 edge a closed ac-tidy finding named → suppressed" || fail "e1: $(cell finding-i2-edge 'ac-e1→EPA')"
[ "$(cell finding-i2-edge 'ac-e2→EPA')" = file ] && pass "I2 edge named only by a non-tidy closed bead → file" || fail "e2: $(cell finding-i2-edge 'ac-e2→EPA')"
! has "ac-cc1→EPC" && pass "closed–closed I2 edge → none" || fail "closed edge reported"
[ "$(cell finding-post-merge-tail ac-pm)" = "skip-open ac-owner" ] && pass "post-merge tail an open gate names → skip-open" || fail "pm: $(cell finding-post-merge-tail ac-pm)"
[ "$(cell finding-epic-idle EPIDLE)" = file ] && pass "open epic, no open children → finding" || fail "epic-idle missed"
[ "$(cell finding-epic-idle EPD)" = file ] && pass "epic with a Probe: line, zero open children → finding too" || fail "EPD missed (bd-26br6 class)"
[ -z "$(cell finding-epic-idle EPA)" ] && pass "epic with a Probe: line but an open child → no finding" || fail "EPA flagged"

# reopen-blocked (ac-m9y4.12): the edge is read through bead.py.
[ -z "$(cell reopen-blocked ac-blk-live)" ]   && pass "blocked, an open blocks edge → none" || fail "blk-live flagged"
[ -n "$(cell reopen-blocked ac-blk-none)" ]   && pass "blocked, no blocks edge at all → reopen-blocked" || fail "blk-none missed"
[ -n "$(cell reopen-blocked ac-blk-closed)" ] && pass "blocked, its only blocker closed → reopen-blocked" || fail "blk-closed missed"
[ -z "$(cell reopen-blocked ac-keep)" ]       && pass "open (not blocked) → never reopen-blocked" || fail "ac-keep flagged"

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
