#!/usr/bin/env bash
# criteria-chain.test.sh — the five cases fixed in the plan
# (_plans/_done/2026-09-20-acceptance-criteria-state-behaviour.md, Success criterion).
# The worker builds this file and may not change the cases.
#
# Prints `N passed, M failed`. The silver bullet is `5 passed, 0 failed`, exit 0.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT" || exit 2

APPROVE="$HERE/plan-approve.sh"
STAMP="$HERE/stamp-refined.sh"
GATE="$ROOT/skills/ac-implement/scripts/close-gate.sh"
EVIDENCE="$ROOT/skills/ac-pipeline/scripts/close-evidence-check.sh"
BR_CALL="$HERE/br-call.sh"

passed=0
failed=0
ok() { passed=$((passed + 1)); printf 'ok   %s\n' "$*"; }
bad() { failed=$((failed + 1)); printf 'FAIL %s\n' "$*"; }

command -v jq >/dev/null 2>&1 || { echo "FAIL jq is required"; printf '0 passed, 1 failed\n'; exit 1; }
[ -f "$APPROVE" ] || { echo "FAIL plan-approve.sh missing"; printf '0 passed, 1 failed\n'; exit 1; }
[ -f "$STAMP" ] || { echo "FAIL stamp-refined.sh missing"; printf '0 passed, 1 failed\n'; exit 1; }
[ -x "$GATE" ] || { echo "FAIL close-gate.sh missing"; printf '0 passed, 1 failed\n'; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/criteria-chain.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# ---------------------------------------------------------------------------------------
# Case 1 — a plan headed "## Success criterion" is approved, its criterion body is edited,
# and plan-approve.sh ready prints REFUSED regate naming the success criterion.
# ready() also requires a polish stamp; that key is not part of the criterion body.
# ---------------------------------------------------------------------------------------
vision_line='writes the vision back in plain prose'
{
  printf -- '---\nstatus: draft\ncreated: 2026-09-05\n---\n# Plan\n\n## Vision\n\n%s\n\n## Deliverables\n\n- D1 x\n  Done when: x exists.\n\n## Decisions\n\n- **A fork?**\n  + options: a, b.\n  + settled: a (Alex).\n  + vision: "%s"\n\n## Seams\n\na\n\n## Out of scope\n\n- nothing\n\n## Success criterion\n\nSome criterion.\n' \
    "$vision_line" "$vision_line"
} >"$WORK/plan.md"
bash "$APPROVE" approve "$WORK/plan.md" "Alex" >/dev/null
awk 'NR==2{print; print "polish_rounds: 2"; print "polish_fixpoint_sha256: deadbeef"; next}1' "$WORK/plan.md" > "$WORK/plan.md.tmp" && mv "$WORK/plan.md.tmp" "$WORK/plan.md"
sed -i.bak 's/Some criterion\./Some amended criterion./' "$WORK/plan.md"; rm -f "$WORK/plan.md.bak"
OUT=$(bash "$APPROVE" ready "$WORK/plan.md" 2>&1); RC=$?
if [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -q 'REFUSED regate' \
   && printf '%s\n' "$OUT" | grep -q 'SuccessCriterion'; then
  ok "case 1: editing ## Success criterion regates (REFUSED regate SuccessCriterion)"
else
  bad "case 1: expected REFUSED regate naming the success criterion, got rc=$RC. Output: $OUT"
fi

# ---------------------------------------------------------------------------------------
# Cases 2-4 — stamp-refined judges the probe command on a code-file Delivers.
# br is a file-backed board; the probes are not executed.
# ---------------------------------------------------------------------------------------
MOCK="$WORK/bin"
mkdir -p "$MOCK"
BR_LOG="$WORK/br.log"
FIXTURE="$WORK/beads.json"
export BR_LOG FIXTURE
cat >"$MOCK/br" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$BR_LOG"
cmd="${1:-}"; shift || true
if [ "$cmd" = "show" ]; then
  ids=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --json) shift ;;
      *) ids+=("$1"); shift ;;
    esac
  done
  want=$(printf '%s\n' "${ids[@]}" | jq -R . | jq -s .)
  out=$(jq --argjson want "$want" '[ .[] | select(.id as $i | $want | index($i)) ]' "$FIXTURE")
  if [ "$(printf '%s' "$out" | jq 'length')" -gt 0 ]; then
    printf '%s\n' "$out"
    exit 0
  fi
  printf '%s\n' '{"error":{"code":"ISSUE_NOT_FOUND","message":"missing"}}'
  exit 0
fi
if [ "$cmd" = "label" ]; then
  op="$1"; id="$2"; name="$3"
  tmp=$(mktemp)
  jq --arg id "$id" --arg name "$name" --arg op "$op" '
    [ .[] | if .id == $id then
        if $op == "add" then .labels = ((.labels // []) + [$name] | unique)
        else .labels = ((.labels // []) - [$name]) end
      else . end ]' "$FIXTURE" >"$tmp" && mv "$tmp" "$FIXTURE"
  exit 0
fi
if [ "$cmd" = "comments" ]; then
  printf '%s\n' '[]'
  exit 0
fi
exit 0
EOF
chmod +x "$MOCK/br"

bead_json() { # <id> <description-file>
  jq -n --arg id "$1" --rawfile d "$2" \
    '{id:$id,title:"chain fixture",issue_type:"task",status:"open",assignee:"",labels:["origin:ac-triage"],description:$d,comments:[]}'
}

cat >"$WORK/d-grep.md" <<'EOF'
## Acceptance Criteria
- The module is proven only by a text match.
  Probe: `grep -q foo lib/x.ts` — tier: none

## Delivers
- module: lib/x.ts
EOF
cat >"$WORK/d-vitest.md" <<'EOF'
## Acceptance Criteria
- The module is proven by a text match and a run.
  Probe: `grep -q foo lib/x.ts && npx vitest run lib/x.test.ts` — tier: none

## Delivers
- module: lib/x.ts
EOF
cat >"$WORK/d-bash.md" <<'EOF'
## Acceptance Criteria
- The script is proven by running it.
  Probe: `test -x scripts/x.sh && bash scripts/x.sh` — tier: none

## Delivers
- script: scripts/x.sh
EOF
jq -s '.' \
  <(bead_json bd-grep "$WORK/d-grep.md") \
  <(bead_json bd-vitest "$WORK/d-vitest.md") \
  <(bead_json bd-bash "$WORK/d-bash.md") >"$FIXTURE"

: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-grep 2>&1); RC=$?
if [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -q 'nothing left to run' \
   && ! grep -q 'label add bd-grep refined' "$BR_LOG"; then
  ok "case 2: lib/x.ts whose only probe is grep -q is refused refined"
else
  bad "case 2: expected a refined refusal (nothing left to run, no label), got rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-vitest 2>&1); RC=$?
if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q 'STAMPED' \
   && grep -q 'label add bd-vitest refined' "$BR_LOG"; then
  ok "case 3: grep -q && npx vitest run is stamped"
else
  bad "case 3: expected a stamp, got rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

: >"$BR_LOG"
OUT=$(PATH="$MOCK:$PATH" bash "$STAMP" bd-bash 2>&1); RC=$?
if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q 'STAMPED' \
   && grep -q 'label add bd-bash refined' "$BR_LOG"; then
  ok "case 4: test -x scripts/x.sh && bash scripts/x.sh is stamped"
else
  bad "case 4: expected a stamp, got rc=$RC. Output: $OUT / log: $(cat "$BR_LOG")"
fi

# ---------------------------------------------------------------------------------------
# Case 5 — an epic whose Probe exits 1 is refused CLOSE-REFUSED: GREEN; exiting 0 closes.
# The subject is close-gate.sh as it stands. No gate edit. A temp root keeps the
# UNCOMMITTED leg off the real work tree; the evidence core is the real script.
# ---------------------------------------------------------------------------------------
EPIC="$WORK/epic"
mkdir -p "$EPIC/skills/ac-pipeline/scripts" "$EPIC/skills/_tools" "$EPIC/.flight" "$EPIC/.br"
cp "$EVIDENCE" "$EPIC/skills/ac-pipeline/scripts/close-evidence-check.sh"
cp "$BR_CALL" "$EPIC/skills/_tools/br-call.sh"
chmod +x "$EPIC/skills/ac-pipeline/scripts/close-evidence-check.sh"
cat >"$EPIC/body.md" <<'EOF'
## Acceptance Criteria
- The marker the epic promises is on disk.
  Probe: `test -f marker.txt` — tier: none

## Delivers
- marker: marker.txt

## Consumes
- none
EOF
jq -n --rawfile d "$EPIC/body.md" \
  '{id:"ac-chain-epic",title:"chain epic",issue_type:"epic",status:"in_progress",assignee:"chain",labels:[],description:$d}' \
  >"$EPIC/.br/ac-chain-epic.json"
cat >"$EPIC/br" <<'EOF'
#!/usr/bin/env bash
STATE="${AC2_TEST_BR_STATE:-/nonexistent}"
cmd="${1:-}"; shift || true
id=""
for a in "$@"; do
  case "$a" in
    --*) ;;
    -*) ;;
    *) [ -z "$id" ] && id="$a" ;;
  esac
done
case "$cmd" in
  show)
    [ -f "$STATE/$id.json" ] || { printf '%s\n' '{"error":{"message":"missing"}}'; exit 0; }
    cat "$STATE/$id.json"
    ;;
  close)
    [ -f "$STATE/$id.json" ] || exit 1
    tmp=$(mktemp)
    jq '.status = "closed"' "$STATE/$id.json" >"$tmp" && mv "$tmp" "$STATE/$id.json"
    ;;
  comments)
    printf '%s\n' '[]'
    ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$EPIC/br"
REASON='shipped: probe receipt all green. Delivered: marker.txt'
OUT=$(AC2_BR_CMD="$EPIC/br" AC2_TEST_BR_STATE="$EPIC/.br" AC2_FLIGHT_DIR="$EPIC/.flight" \
  bash "$GATE" ac-chain-epic --reason "$REASON" --actor chain --root "$EPIC" 2>&1); RC=$?
STATUS=$(jq -r '.status' "$EPIC/.br/ac-chain-epic.json")
RED_OK=0
if [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -q 'CLOSE-REFUSED: GREEN' \
   && [ "$STATUS" != "closed" ]; then
  RED_OK=1
fi
printf 'marker\n' >"$EPIC/marker.txt"
OUT2=$(AC2_BR_CMD="$EPIC/br" AC2_TEST_BR_STATE="$EPIC/.br" AC2_FLIGHT_DIR="$EPIC/.flight" \
  bash "$GATE" ac-chain-epic --reason "$REASON" --actor chain --root "$EPIC" 2>&1); RC2=$?
STATUS2=$(jq -r '.status' "$EPIC/.br/ac-chain-epic.json")
if [ "$RED_OK" -eq 1 ] && [ "$RC2" -eq 0 ] && [ "$STATUS2" = "closed" ]; then
  ok "case 5: epic probe exit 1 is CLOSE-REFUSED: GREEN; exit 0 closes"
else
  bad "case 5: red rc=$RC status=$STATUS; green rc=$RC2 status=$STATUS2. Red: $OUT / Green: $OUT2"
fi

printf '%s passed, %s failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ] && [ "$passed" -eq 5 ]
exit $?
