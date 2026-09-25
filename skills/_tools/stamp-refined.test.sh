#!/usr/bin/env bash
# stamp-refined.test.sh — the prod-write and Delivers legs at their integration seam.
#
# element4 and touchers are stubbed PASS so every verdict below belongs to the two new legs.
# The mocked board mutates labels, which makes the downgrade and read-back behaviour real.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$DIR/stamp-refined.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
MOCK="$WORK/bin"
mkdir -p "$MOCK"
BOARD="$WORK/beads.json"
BR_LOG="$WORK/br.log"
export BR_LOG BOARD

cat >"$MOCK/br" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$BR_LOG"
case "${1:-}" in
  show)
    id="${3:-}"
    jq --arg id "$id" '[.[] | select(.id == $id)]' "$BOARD"
    ;;
  label)
    op="${2:-}"; id="${3:-}"; name="${4:-}"
    tmp=$(mktemp)
    jq --arg id "$id" --arg name "$name" --arg op "$op" '
      [.[] | if .id == $id then
        if $op == "add" then .labels = ((.labels // []) + [$name] | unique)
        else .labels = ((.labels // []) - [$name]) end
      else . end]' "$BOARD" >"$tmp" && mv "$tmp" "$BOARD"
    ;;
esac
exit 0
EOF
chmod +x "$MOCK/br"

cat >"$WORK/e4-pass.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$WORK/touchers-pass.sh" <<'EOF'
#!/usr/bin/env bash
touchers_check() { printf 'touchers: OK test stub\n'; return 0; }
EOF
chmod +x "$WORK/e4-pass.sh"

BASE='## Intent
Guard a local parser.

## Acceptance Criteria
- The guard lands.
  Probe: `bash skills/_tools/stamp-refined.test.sh` — tier: standing-harness

## Delivers
- lib/parser.sh

## Consumes
- none
'
SIGNAL="${BASE}"$'\n'"The repair is a one-off data fix for the affected production database rows."
NEGATIVE="${SIGNAL}"$'\n'"prod-write: none — the repair is confined to the sanitized test fixture."
NO_DELIVERS='## Intent
Document a local outcome.

## Acceptance Criteria
- The outcome is recorded.
  Probe: `bash skills/_tools/stamp-refined.test.sh` — tier: standing-harness

## Consumes
- none
'
PROSE_DELIVERS='## Intent
Document a local outcome.

## Acceptance Criteria
- The outcome is recorded.
  Probe: `bash skills/_tools/stamp-refined.test.sh` — tier: standing-harness

## Delivers
- a documented outcome with no artifact path

## Consumes
- none
'

jq -n \
  --arg base "$BASE" --arg signal "$SIGNAL" --arg negative "$NEGATIVE" \
  --arg none "$NO_DELIVERS" --arg prose "$PROSE_DELIVERS" '[
  {id:"bd-prod-unmarked", issue_type:"task", title:"escaped fix", labels:["origin:test","refined"],
   description:$signal, dependencies:[]},
  {id:"bd-prod-negative", issue_type:"task", title:"recorded negative", labels:["origin:test"],
   description:$negative, dependencies:[]},
  {id:"bd-prod-gated", issue_type:"task", title:"gated fix", labels:["origin:test","sensitive-prod"],
   description:$signal, dependencies:[{id:"dec-1", title:"DECISION: approve repair", status:"closed", dependency_type:"blocks"}]},
  {id:"bd-prod-label-only", issue_type:"task", title:"label without edge", labels:["origin:test","sensitive-prod"],
   description:$signal, dependencies:[]},
  {id:"bd-prod-plain", issue_type:"task", title:"plain code", labels:["origin:test"],
   description:$base, dependencies:[]},
  {id:"bd-task-no-delivers", issue_type:"task", title:"task without artifacts", labels:["origin:test"],
   description:$none, dependencies:[]},
  {id:"bd-feature-prose", issue_type:"feature", title:"feature without artifacts", labels:["origin:test"],
   description:$prose, dependencies:[]},
  {id:"bd-bug-prose", issue_type:"bug", title:"bug outside Delivers scope", labels:["origin:test"],
   description:$prose, dependencies:[]}
]' >"$BOARD"

PASSES=0
FAILURES=0
pass() { echo "  PASS: $1"; PASSES=$((PASSES + 1)); }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }
run_stamp() {
  : >"$BR_LOG"
  STAMP_OUT=$(PATH="$MOCK:$PATH" ELEMENT4_CHECK="$WORK/e4-pass.sh" TOUCHERS_TOOL="$WORK/touchers-pass.sh" \
    bash "$STAMP" "$1" 2>&1)
  STAMP_RC=$?
}
label_count() { grep -c "label $1 $2 $3" "$BR_LOG" || true; }

run_stamp bd-prod-unmarked
if [ "$STAMP_RC" -eq 1 ] && printf '%s\n' "$STAMP_OUT" | grep -q "\[data-state\]" \
    && [ "$(label_count add bd-prod-unmarked refined)" -eq 0 ] \
    && [ "$(label_count remove bd-prod-unmarked refined)" -eq 1 ] \
    && [ "$(label_count add bd-prod-unmarked unrefined)" -eq 1 ] \
    && ! grep -q "sensitive-prod" "$BR_LOG"; then
  pass "signal without a recorded verdict is refused, downgraded, and never labelled"
else
  fail "unmarked prod-write signal" "rc=$STAMP_RC: $STAMP_OUT / log: $(cat "$BR_LOG")"
fi

run_stamp bd-prod-negative
if [ "$STAMP_RC" -eq 0 ] && [ "$(label_count add bd-prod-negative refined)" -eq 1 ]; then
  pass "a non-empty prod-write: none verdict passes"
else
  fail "negative prod-write verdict" "rc=$STAMP_RC: $STAMP_OUT / log: $(cat "$BR_LOG")"
fi

run_stamp bd-prod-gated
if [ "$STAMP_RC" -eq 0 ] && [ "$(label_count add bd-prod-gated refined)" -eq 1 ] \
    && ! grep -q "sensitive-prod" "$BR_LOG"; then
  pass "sensitive-prod plus a DECISION blocks edge passes without auto-labelling"
else
  fail "gated prod-write signal" "rc=$STAMP_RC: $STAMP_OUT / log: $(cat "$BR_LOG")"
fi

run_stamp bd-prod-label-only
if [ "$STAMP_RC" -eq 1 ] && printf '%s\n' "$STAMP_OUT" | grep -q "missing recorded gate pair" \
    && [ "$(label_count add bd-prod-label-only refined)" -eq 0 ] && ! grep -q "sensitive-prod" "$BR_LOG"; then
  pass "sensitive-prod without its DECISION blocks edge is refused"
else
  fail "label-only prod-write signal" "rc=$STAMP_RC: $STAMP_OUT / log: $(cat "$BR_LOG")"
fi

run_stamp bd-prod-plain
if [ "$STAMP_RC" -eq 0 ] && [ "$(label_count add bd-prod-plain refined)" -eq 1 ]; then
  pass "a plain code-only bead still stamps"
else
  fail "plain code bead" "rc=$STAMP_RC: $STAMP_OUT / log: $(cat "$BR_LOG")"
fi

for id in bd-task-no-delivers bd-feature-prose; do
  run_stamp "$id"
  if [ "$STAMP_RC" -eq 1 ] && { printf '%s\n' "$STAMP_OUT" | grep -q "NO-DELIVERS" \
      || printf '%s\n' "$STAMP_OUT" | grep -q "UNVERIFIABLE-DELIVERS"; } \
      && [ "$(label_count add "$id" refined)" -eq 0 ]; then
    pass "$id is refused before refined can be written"
  else
    fail "$id" "rc=$STAMP_RC: $STAMP_OUT / log: $(cat "$BR_LOG")"
  fi
done

run_stamp bd-bug-prose
if [ "$STAMP_RC" -eq 0 ] && [ "$(label_count add bd-bug-prose refined)" -eq 1 ]; then
  pass "the Delivers leg stays scoped to task/feature; a prose-only bug still stamps"
else
  fail "bug outside Delivers scope" "rc=$STAMP_RC: $STAMP_OUT / log: $(cat "$BR_LOG")"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "$PASSES passed, $FAILURES failed — all stamp-refined integration tests passed."
  exit 0
fi
echo "$FAILURES stamp-refined integration test(s) FAILED."
exit 1
