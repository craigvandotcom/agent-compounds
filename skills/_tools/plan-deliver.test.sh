#!/usr/bin/env bash
# plan-deliver.test.sh — RED/GREEN over every plan-deliver.sh verdict (ac-epic-closeout-61ld.1).
# Fixtures: a beadified plan whose epic children are closed (DELIVERED); a plan with no
# beadified: key (REFUSED not-beadified); open non-closeout children (REFUSED children-open
# N); an already-stamped plan (NOOP). `br` is stubbed (a file-backed board); the A1 case
# drives the REAL flight-check.sh and close-gate.sh against a fixture closeout whose only
# change is an ignored path; the A3 case hands the REAL swarm-commit.sh only an ignored
# path and asserts it refuses without committing (the exit is recorded, not pinned).
#
# Exit 0 = all cases pass.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/plan-deliver.sh"
AC_ROOT="$(cd "$HERE/../.." && pwd)"
FLIGHT="$AC_ROOT/skills/ac-implement/scripts/flight-check.sh"
GATE="$AC_ROOT/skills/ac-implement/scripts/close-gate.sh"
COMMIT="$AC_ROOT/skills/ac-implement/scripts/swarm-commit.sh"
EVIDENCE_SRC="$AC_ROOT/skills/ac-pipeline/scripts/close-evidence-check.sh"
BR_CALL_SRC="$AC_ROOT/skills/_tools/br-call.sh"
CASES=0
FAILURES=0

pass() { CASES=$((CASES+1)); echo "ok   $*"; }
fail() { CASES=$((CASES+1)); FAILURES=$((FAILURES+1)); echo "FAIL $*"; }

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq is not installed — fixtures cannot be built"; exit 77; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git is not installed — the A1/A3 fixtures need it"; exit 77; }

if [ ! -x "$SCRIPT" ]; then
  fail "writer missing: $SCRIPT does not exist or is not executable (the AC reason, pre-fix)"
  printf 'plan-deliver.test: %s cases, %s failures\n' "$CASES" "$FAILURES"
  exit 1
fi
pass "writer exists and is executable"

W="$(mktemp -d "${TMPDIR:-/tmp}/plan-deliver-test-XXXXXX")"
cleanup() { rm -rf "$W"; }
trap cleanup EXIT

MOCK_BIN="$W/bin"
mkdir -p "$MOCK_BIN"
PATH="$MOCK_BIN:$PATH"
export PATH

# Mock `br` — a file-backed board. `show` emits [$id] unless the file is absent (a
# refusal, never empty data). `list` aggregates every fixture row (the caller filters
# status itself); MOCK_BR_SHAPE=array emits the bare-array shape instead of
# {issues:[...]}. `close` flips status to closed. `comments add` is recorded.
cat >"$MOCK_BIN/br" <<'MOCKBR'
#!/usr/bin/env bash
STATE="${PLAN_DELIVER_BR_STATE:-/nonexistent}"
cmd="${1:-}"; shift 2>/dev/null || true
ids=()
for a in "$@"; do case "$a" in --*|-*) ;; *) ids+=("$a") ;; esac; done
case "$cmd" in
  show)
    id="${ids[0]:-}"; [ -f "$STATE/$id.json" ] || exit 1
    jq -c '[.]' "$STATE/$id.json" ;;
  list)
    rows=""
    for f in "$STATE"/*.json; do
      [ -f "$f" ] || continue
      [ "$f" = "$STATE/comments.log" ] && continue
      r="$(jq -c '.' "$f" 2>/dev/null)" || continue
      rows="$rows$([ -n "$rows" ] && printf ',')$r"
    done
    if [ "${MOCK_BR_SHAPE:-object}" = "array" ]; then printf '[%s]\n' "$rows"
    else printf '{"issues":[%s]}\n' "$rows"; fi ;;
  close)
    id="${ids[0]:-}"; [ -f "$STATE/$id.json" ] || exit 1
    jq '.status = "closed"' "$STATE/$id.json" >"$STATE/$id.json.tmp" \
      && mv "$STATE/$id.json.tmp" "$STATE/$id.json" ;;
  comments)
    printf '%s\n' "comments $*" >> "$STATE/comments.log"
    exit 0 ;;
  *) exit 0 ;;
esac
MOCKBR
chmod +x "$MOCK_BIN/br"

# A fixture plan frontmatter. $1 = extra keys (e.g. "beadified: FIXEPIC").
mkplan() {
  printf -- '---\ntitle: fixture plan\nstatus: done\n%s---\n# Fixture\n' "${1:+$1
}"
}

board_add() { # <state> <id> <status> <title> <type> <deps-json-or-null> <description>
  jq -n --arg id "$2" --arg st "$3" --arg ti "$4" --arg ty "$5" \
    --argjson deps "$6" --arg d "$7" \
    '{id:$id,title:$ti,issue_type:$ty,status:$st,assignee:null,labels:[],dependencies:$deps,description:$d}' \
    >"$1/$2.json"
}

# --- 1: no beadified: key -> REFUSED not-beadified ---------------------------------------
S1="$W/s1"; mkdir -p "$S1/.br"
mkplan "" >"$S1/plan.md"
export PLAN_DELIVER_BR_STATE="$S1/.br"
OUT=$("$SCRIPT" "$S1/plan.md" 2>&1); RC=$?
[ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q 'REFUSED not-beadified' \
  && pass "no beadified: key -> REFUSED not-beadified (exit 1)" \
  || fail "no beadified: key -> rc=$RC out=$OUT"

# --- 2: already stamped -> NOOP, file untouched ------------------------------------------
S2="$W/s2"; mkdir -p "$S2/.br"
{ mkplan "beadified: FIXEPIC"; printf 'delivered: 2026-09-01T00:00:00Z\n'; } >"$S2/plan.md"
BEFORE="$(cat "$S2/plan.md")"
export PLAN_DELIVER_BR_STATE="$S2/.br"
OUT=$("$SCRIPT" "$S2/plan.md" 2>&1); RC=$?
[ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q 'NOOP' && [ "$(cat "$S2/plan.md")" = "$BEFORE" ] \
  && pass "already-stamped plan -> NOOP (exit 0), file untouched" \
  || fail "already-stamped plan -> rc=$RC out=$OUT"

# --- 3: open children -> REFUSED children-open N -----------------------------------------
S3="$W/s3"; mkdir -p "$S3/.br"
mkplan "beadified: FIXEPIC" >"$S3/plan.md"
board_add "$S3/.br" "FIXEPIC.1" open "shipping work" task null "body"
board_add "$S3/.br" "ac-edgechild" open "edge-wired work" task \
  '[{"id":"FIXEPIC","title":"epic","status":"open","dependency_type":"parent-child"}]' "body"
board_add "$S3/.br" "FIXEPIC.9" open "closeout: fixture epic" task null "body"
board_add "$S3/.br" "ac-unrelated" open "another epic's work" task null "body"
board_add "$S3/.br" "FIXEPIC.2" closed "done work" task null "body"
export PLAN_DELIVER_BR_STATE="$S3/.br"
OUT=$("$SCRIPT" "$S3/plan.md" 2>&1); RC=$?
[ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q 'REFUSED children-open 2' \
  && pass "open dotted + edge children counted, closeout + unrelated + closed excluded -> REFUSED children-open 2" \
  || fail "open children -> rc=$RC out=$OUT"

# --- 3b: the same board through the bare-array list shape --------------------------------
export PLAN_DELIVER_BR_STATE="$S3/.br" MOCK_BR_SHAPE=array
OUT=$("$SCRIPT" "$S3/plan.md" 2>&1); RC=$?
[ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q 'REFUSED children-open 2' \
  && pass "bare-array br list shape -> same REFUSED children-open 2" \
  || fail "bare-array list shape -> rc=$RC out=$OUT"
unset MOCK_BR_SHAPE

# --- 4: every non-closeout child closed -> DELIVERED --------------------------------------
S4="$W/s4"; mkdir -p "$S4/.br"
mkplan "beadified: FIXEPIC" >"$S4/plan.md"
board_add "$S4/.br" "FIXEPIC.1" closed "shipping work" task null "body"
board_add "$S4/.br" "FIXEPIC.9" open "closeout: fixture epic" task null "body"
export PLAN_DELIVER_BR_STATE="$S4/.br"
OUT=$("$SCRIPT" "$S4/plan.md" 2>&1); RC=$?
if [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q '^DELIVERED:' \
   && grep -qE '^delivered: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z' "$S4/plan.md"; then
  pass "closed epic + open closeout only -> DELIVERED with ISO stamp"
else fail "all-closed -> rc=$RC out=$OUT"; fi

# --- 5: missing plan -> NOT-GATED ----------------------------------------------------------
export PLAN_DELIVER_BR_STATE="$S4/.br"
OUT=$("$SCRIPT" "$S4/absent.md" 2>&1); RC=$?
[ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q 'NOT-GATED' \
  && pass "missing plan -> NOT-GATED (exit 2)" \
  || fail "missing plan -> rc=$RC out=$OUT"

# ============================================================================================
# A1 — the closeout shape end to end: a fixture closeout whose only change is an ignored
# path closes through the REAL close-gate.sh with exit 0. The close gates never read git
# for the subject file; if this fails, the D2 doctrine (the WS-B doctrine bead's clause)
# is rewritten — this test does NOT fix close-gate.sh.
# ============================================================================================
R="$W/a1"
mkdir -p "$R/skills/ac-pipeline/scripts" "$R/skills/_tools" "$R/_plans/_done" "$W/a1-flight" "$W/a1-br"
cp "$EVIDENCE_SRC" "$R/skills/ac-pipeline/scripts/close-evidence-check.sh"
cp "$BR_CALL_SRC" "$R/skills/_tools/br-call.sh"
chmod +x "$R/skills/ac-pipeline/scripts/close-evidence-check.sh"
printf '_plans/\n' >"$R/.gitignore"
cat >"$W/a1-body.md" <<'BODY'
## Acceptance Criteria
- the one-shot migration script is gone.
  Probe: `test ! -e _oneshot/fixture-migrate.sh` — tier: none
- the plan carries the delivered stamp.
  Probe: `grep -q '^delivered:' _plans/_done/fixture-plan.md` — tier: none

## Delivers
- plan: _plans/_done/fixture-plan.md
- one-shot: _oneshot/fixture-migrate.sh (deleted)

## Consumes
- none
BODY
BEAD="ac-test-closeout"
jq -n --rawfile d "$W/a1-body.md" \
  '{id:"ac-test-closeout",title:"closeout: fixture epic",issue_type:"task",status:"in_progress",assignee:"worker",labels:[],dependencies:null,description:$d}' \
  >"$W/a1-br/$BEAD.json"
board_add "$W/a1-br" "FIXEPIC.1" closed "shipping work" task null "body"
printf -- '---\ntitle: fixture plan\nstatus: done\nbeadified: FIXEPIC\n---\n# Fixture\n' \
  >"$R/_plans/_done/fixture-plan.md"
export PLAN_DELIVER_BR_STATE="$W/a1-br"
( cd "$R" && git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -qm base ) \
  || { fail "A1 setup: fixture git repo could not be built"; }
if ( cd "$R" && [ -z "$(git status --short)" ] ); then
  pass "A1 setup: fixture tree clean before the stamp (plan is ignored, one-shot never created)"
else fail "A1 setup: fixture tree not clean: $(cd "$R" && git status --short)"; fi
if ( cd "$R" && AC2_FLIGHT_DIR="$W/a1-flight" bash "$FLIGHT" "$BEAD" \
       --body-file "$W/a1-body.md" --root "$R" >/dev/null 2>&1 ); then
  pass "A1: flight-check banks the RED (delivered stamp absent)"
else fail "A1: flight-check did not bank a RED"; fi
if "$SCRIPT" "$R/_plans/_done/fixture-plan.md" >/dev/null 2>&1; then
  pass "A1: plan-deliver.sh stamps the fixture plan"
else fail "A1: plan-deliver.sh refused the fixture plan"; fi
if ( cd "$R" && [ -z "$(git status --short)" ] ); then
  pass "A1: the stamp's only change is the ignored plan path (git status clean)"
else fail "A1: stamp leaked into tracked files: $(cd "$R" && git status --short)"; fi
RCFILE="$W/a1-gate.rc"
( cd "$R" && AC2_FLIGHT_DIR="$W/a1-flight" PLAN_DELIVER_BR_STATE="$W/a1-br" \
    bash "$GATE" "$BEAD" --body-file "$W/a1-body.md" --root "$R" \
    --reason "shipped: fixture closeout delivered. Delivered: _plans/_done/fixture-plan.md, _oneshot/fixture-migrate.sh" >/dev/null 2>&1
  echo $? >"$RCFILE" )
GATE_RC=$(cat "$RCFILE")
[ "$GATE_RC" -eq 0 ] \
  && pass "A1: close-gate.sh exits 0 on a closeout whose only change is an ignored path" \
  || fail "A1: close-gate.sh exited $GATE_RC on the ignored-path closeout (D2 doctrine is wrong, not this script)"

# ============================================================================================
# A3 — swarm-commit.sh handed only an ignored path refuses instead of committing empty.
# The exit is RECORDED, never pinned: any non-zero refusal without a commit passes.
# ============================================================================================
G="$W/a3"
mkdir -p "$G/ignored"
( cd "$G" && git init -q && git config user.email t@t && git config user.name t \
  && printf 'ignored/\n' > .gitignore && printf 'base\n' > base.txt \
  && git add -A && git commit -qm base ) || { fail "A3 setup: fixture git repo could not be built"; }
printf 'plan body\n' >"$G/ignored/plan.md"
printf 'test: ignored-path refusal\n\nnothing should land.\n' >"$W/a3-msg.txt"
HEAD_BEFORE=$(cd "$G" && git rev-parse HEAD)
BRANCH_NOW=$(cd "$G" && git branch --show-current)
( cd "$G" && bash "$COMMIT" --identity test-worker --message-file "$W/a3-msg.txt" \
    --path ignored/plan.md --no-push --branch "$BRANCH_NOW" >/dev/null 2>&1 )
COMMIT_RC=$?
HEAD_AFTER=$(cd "$G" && git rev-parse HEAD)
if [ "$COMMIT_RC" -ne 0 ] && [ "$HEAD_BEFORE" = "$HEAD_AFTER" ]; then
  pass "A3: swarm-commit with only an ignored path refuses (exit=$COMMIT_RC recorded), no commit created"
else fail "A3: swarm-commit exit=$COMMIT_RC head-moved=$([ "$HEAD_BEFORE" = "$HEAD_AFTER" ] && echo no || echo YES)"; fi

rm -rf "$W"
printf 'plan-deliver.test: %s cases, %s failures\n' "$CASES" "$FAILURES"
[ "$FAILURES" -eq 0 ]
