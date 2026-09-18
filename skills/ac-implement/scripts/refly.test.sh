#!/usr/bin/env bash
#
# refly.test.sh — proof harness for refly.sh.
#
# ASSURANCE
#   PROBE:      this file IS the probe — bash skills/ac-implement/scripts/refly.test.sh
#   SCHEDULE:   every scripts/run-all-proofs.sh run (repo-wide *.test.sh discovery),
#               which lint.sh Check 20 audits for scheduling.
#   MODE:       blocking
#   ON-FAILURE: closed
#
# Proves the four things refly.sh may and may not do: it STRIPS the stamp from a bead whose
# premises hold again, it DISPOSITION-CLOSES a still-refused bead whose state is provably
# settled (through close-gate.sh — never by hand), it LEAVES a bead whose staleness claim
# cannot be proven, and it TOUCHES NOTHING when it cannot verify (dry-run, or br absent).
# A file-backed br shim records every write.
#
# Exit 0  every case passed · Exit 1  at least one failed
#
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REFLY="$HERE/refly.sh"
AC_ROOT="$(cd "$HERE/../../.." && pwd)"
EVIDENCE_SRC="$AC_ROOT/skills/ac-pipeline/scripts/close-evidence-check.sh"

PASS=0; FAIL=0
ok()  { PASS=$(( PASS + 1 )); echo "  ok   — $*"; }
bad() { FAIL=$(( FAIL + 1 )); echo "  FAIL — $*"; }

[ -x "$REFLY" ] || { echo "refly.test: refly.sh missing or not executable at $REFLY"; exit 1; }
[ -f "$EVIDENCE_SRC" ] || { echo "refly.test: close-evidence-check.sh missing at $EVIDENCE_SRC"; exit 1; }

WORK=$(mktemp -d "${TMPDIR:-/tmp}/ac-refly-test.XXXXXX") || { echo "refly.test: cannot create scratch dir"; exit 1; }
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/root" "$WORK/bin" "$WORK/bodies" "$WORK/board" \
  "$WORK/root/.agents/skills/ac-pipeline/scripts"
: >"$WORK/root/present-artifact.md"
WRITES="$WORK/br-writes.log"; : >"$WRITES"
COMMENTS="$WORK/comments.log"; : >"$COMMENTS"

# The vendored evidence core the consumer-repo layout expects (close-gate falls back to
# .agents/skills/ when skills/ is absent). Its own behavior is proven in close-gate.test.sh;
# the stub here is the dependency seam only.
printf '#!/usr/bin/env bash\necho "close-evidence[fixture] PASS: vendored stub"; exit 0\n' \
  >"$WORK/root/.agents/skills/ac-pipeline/scripts/close-evidence-check.sh"
chmod +x "$WORK/root/.agents/skills/ac-pipeline/scripts/close-evidence-check.sh"

# Five beads on a file-backed board. `flies` re-checks flyable (stamp stripped). `landed`
# is refused (probes all green — the work exists) and closes obsolete via fresh verification.
# `cascade` is refused (consumed artifact gone) AND rescues through the cascade leg (its
# blocker closed wontfix). `stuck` is refused and rescues through NOTHING (open blocker,
# no cascade) — it stays stamped. `plain` was never stamped and must never be considered.
mkbody() { # <name> — write the bead body to $WORK/bodies/<name>.md
  case "$1" in
    flies)
      cat >"$WORK/bodies/flies.md" <<'B'
## Acceptance Criteria
- Something.
  Probe: `test -e ./nope.md` — tier: none

## Consumes
- upstream -> ./present-artifact.md (landed)
B
      ;;
    landed)
      cat >"$WORK/bodies/landed.md" <<'B'
## Acceptance Criteria
- Something.
  Probe: `test -e ./present-artifact.md` — tier: none

## Consumes
- none

## Delivers
- artifact: ./present-artifact.md
B
      ;;
    cascade)
      cat >"$WORK/bodies/cascade.md" <<'B'
## Acceptance Criteria
- Something.
  Probe: `test -e ./gone.md` — tier: none

## Consumes
- bd-upstream-9zz -> ./gone.md (landed)

## Delivers
- artifact: ./gone.md
B
      ;;
    stuck)
      cat >"$WORK/bodies/stuck.md" <<'B'
## Acceptance Criteria
- Something.
  Probe: `test -e ./present-artifact.md` — tier: none

## Consumes
- bd-open-blocker.1 -> ./absent.md (pending)
B
      ;;
  esac
}
mkbody flies; mkbody landed; mkbody cascade; mkbody stuck

newbead() { # <id> <title> <status> <body-name> [close_reason]
  jq -n --arg id "$1" --arg t "$2" --arg st "$3" --arg cr "${5:-}" --rawfile d "$WORK/bodies/$4.md" \
    '{id:$id,title:$t,issue_type:"task",status:$st,assignee:"",labels:[],description:$d,close_reason:$cr}' \
    >"$WORK/board/$1.json"
}
newbead flies   "PREMISE-FAILED: fix(x): flies again"     open flies
newbead landed  "PREMISE-FAILED: fix(y): landed elsewhere" open landed
newbead cascade "PREMISE-FAILED: fix(z): premise retired"  open cascade
newbead stuck   "PREMISE-FAILED: fix(w): still wanted"     open stuck
jq -n '{id:"plain",title:"fix(z): never stamped",issue_type:"task",status:"open",assignee:"",labels:[],description:"plain",close_reason:""}' \
  >"$WORK/board/plain.json"
jq -n '{id:"upstream",title:"done",issue_type:"task",status:"closed",assignee:"",labels:[],description:"",close_reason:"shipped: landed"}' \
  >"$WORK/board/upstream.json"
jq -n '{id:"bd-upstream-9zz",title:"upstream 2",issue_type:"task",status:"closed",assignee:"",labels:[],description:"",close_reason:"wontfix: premise retired (bd-upstream.abc)"}' \
  >"$WORK/board/bd-upstream-9zz.json"
jq -n '{id:"bd-open-blocker.1",title:"open blocker",issue_type:"task",status:"open",assignee:"",labels:[],description:"",close_reason:""}' \
  >"$WORK/board/bd-open-blocker.1.json"

# The br shim: file-backed, stateful. `update --claim` flips status/assignee; `close`
# flips status; every invocation lands in the writes log. A missing id prints the error
# envelope br itself would print on stdout at rc 0 — br_call refuses on it.
cat >"$WORK/bin/br" <<'STUB'
#!/usr/bin/env bash
STATE="${BR_STATE:?}"; LOG="${BR_WRITES:?}"
cmd="${1:-}"; shift || true
id=""
for a in "$@"; do case "$a" in --*) ;; -*) ;; *) [ -z "$id" ] && id="$a" ;; esac; done
case "$cmd" in
  list)
    files=()
    for f in "$STATE"/*.json; do [ -f "$f" ] && files+=("$f"); done
    jq -s '{issues: .}' "${files[@]}" ;;
  show)
    [ -n "$id" ] || exit 1
    if [ -f "$STATE/$id.json" ]; then
      cat "$STATE/$id.json"
    else
      printf '{"error":{"code":"NOT_FOUND","message":"no such bead: %s"}}\n' "$id"
    fi ;;
  update)
    [ -n "$id" ] || exit 1
    if [ ! -f "$STATE/$id.json" ]; then
      printf '{"error":{"code":"NOT_FOUND","message":"no such bead: %s"}}\n' "$id"; exit 0
    fi
    echo "update $*" >>"$LOG"
    claim=0; actor=""; title=""; status=""; assignee="__unset__"; prev=""
    for a in "$@"; do
      case "$prev" in
        actor)    actor="$a"; prev="" ;;
        title)    title="$a"; prev="" ;;
        status)   status="$a"; prev="" ;;
        assignee) assignee="$a"; prev="" ;;
        *) case "$a" in
             --claim) claim=1 ;;
             --actor) prev=actor ;;
             --title) prev=title ;;
             --status) prev=status ;;
             --assignee) prev=assignee ;;
           esac ;;
      esac
    done
    if [ "$claim" = 1 ]; then
      jq --arg a "${actor:-}" '.status="in_progress" | .assignee=$a' "$STATE/$id.json" >"$STATE/$id.json.tmp" \
        && mv "$STATE/$id.json.tmp" "$STATE/$id.json"
    fi
    if [ -n "$title" ]; then
      jq --arg t "$title" '.title=$t' "$STATE/$id.json" >"$STATE/$id.json.tmp" \
        && mv "$STATE/$id.json.tmp" "$STATE/$id.json"
    fi
    if [ "$status" = "open" ] && [ "$assignee" = "" ]; then
      jq '.status="open" | .assignee=""' "$STATE/$id.json" >"$STATE/$id.json.tmp" \
        && mv "$STATE/$id.json.tmp" "$STATE/$id.json"
    fi
    exit 0 ;;
  comments)
    echo "comments $*" >>"$LOG"
    sub="${1:-}"; shift || true
    id2=""; body=""
    if [ "$sub" = "add" ]; then
      if [ "${1:-}" = "-f" ]; then
        shift; body="$(cat "${1:-}" 2>/dev/null)"; shift 2>/dev/null || true; id2="${1:-}"
      else
        id2="${1:-}"; shift 2>/dev/null || true; body="${1:-}"
      fi
    fi
    [ -n "$body" ] || body="inline"
    printf '%s\n' "$body" >>"${BR_COMMENTS_LOG:?}"
    exit 0 ;;
  close)
    [ -n "$id" ] || exit 1
    if [ ! -f "$STATE/$id.json" ]; then
      printf '{"error":{"code":"NOT_FOUND","message":"no such bead: %s"}}\n' "$id"; exit 0
    fi
    echo "close $*" >>"$LOG"
    jq '.status="closed"' "$STATE/$id.json" >"$STATE/$id.json.tmp" \
      && mv "$STATE/$id.json.tmp" "$STATE/$id.json"
    exit 0 ;;
  *) echo "update $cmd $*" >>"$LOG"; exit 0 ;;
esac
STUB
chmod +x "$WORK/bin/br"

run() {
  RUN_OUT=$(env BR_WRITES="$WRITES" BR_STATE="$WORK/board" BR_COMMENTS_LOG="$COMMENTS" \
    PATH="$WORK/bin:$PATH" bash "$REFLY" --root "$WORK/root" "$@" 2>&1)
  RUN_RC=$?
}

# ---------------------------------------------------------------------------------------
echo "refly.test: case 1 — strip the flyable, disposition-close the settled, leave the stuck"
# ---------------------------------------------------------------------------------------
run
[ "$RUN_RC" -eq 0 ] && ok "refly exits 0 after re-checking" || bad "expected exit 0, got $RUN_RC: $RUN_OUT"
grep -q -- 'update flies --title fix(x): flies again' "$WRITES" \
  && ok "flyable bead: stamp stripped, title otherwise untouched" \
  || bad "flyable bead: no clean-title update recorded: $(cat "$WRITES")"
grep -q -- 'comments add flies' "$WRITES" && ok "flyable bead: repair comment recorded" \
  || bad "flyable bead: no repair comment"
status=$(jq -r .status "$WORK/board/landed.json")
[ "$status" = "closed" ] && ok "landed bead: disposition-closed through the gate" \
  || bad "landed bead: status '$status', not closed"
grep -q 'FRESH-VERIFY' "$COMMENTS" && ok "landed bead: the fresh verification is recorded on it" \
  || bad "landed bead: no FRESH-VERIFY record"
status=$(jq -r .status "$WORK/board/cascade.json")
[ "$status" = "closed" ] && ok "cascade bead: disposition-closed through the cascade leg" \
  || bad "cascade bead: status '$status', not closed"
grep -q 'TRIAGE-CLOSE' "$COMMENTS" && ok "cascade bead: the cascade evidence is recorded on it" \
  || bad "cascade bead: no TRIAGE-CLOSE record"
printf '%s' "$RUN_OUT" | grep -q 'stuck — still stamped: PREMISE-FAILED: CONSUMES' \
  && ok "stuck bead: still stamped, its surviving refusal reported by class" \
  || bad "stuck bead: not reported as still stamped: $RUN_OUT"
status=$(jq -r .status "$WORK/board/stuck.json"); assignee=$(jq -r .assignee "$WORK/board/stuck.json")
[ "$status" = "open" ] && [ -z "$assignee" ] \
  && ok "stuck bead: the refused triage left it open and unclaimed" \
  || bad "stuck bead: status '$status', assignee '$assignee'"
grep -q -- 'close stuck' "$WRITES" && bad "stuck bead: a close was written despite the refusal" \
  || ok "stuck bead: no close was ever written for it"
grep -q -- 'plain' "$WRITES" && bad "an unstamped bead was written to" || ok "unstamped bead: never considered"
printf '%s' "$RUN_OUT" | grep -q 'disposition-closed (obsolete)' && ok "the disposition closes are reported" \
  || bad "no disposition-closed line: $RUN_OUT"
printf '%s' "$RUN_OUT" | grep -q 'stripped, 2 disposition-closed, 1 still stamped' \
  && ok "the summary counts strips, disposition-closes and survivors" \
  || bad "summary line wrong: $RUN_OUT"

# ---------------------------------------------------------------------------------------
echo "refly.test: case 2 — --dry-run reports and writes nothing"
# ---------------------------------------------------------------------------------------
: >"$WRITES"; : >"$COMMENTS"
# Restore the three beads case 1 changed — dry-run must see the same board state.
newbead flies   "PREMISE-FAILED: fix(x): flies again"     open flies
newbead landed  "PREMISE-FAILED: fix(y): landed elsewhere" open landed
newbead cascade "PREMISE-FAILED: fix(z): premise retired"  open cascade
run --dry-run
[ "$RUN_RC" -eq 0 ] && ok "dry-run exits 0" || bad "dry-run: expected exit 0, got $RUN_RC"
printf '%s' "$RUN_OUT" | grep -q 'would strip the stamp' && ok "dry-run names what it would strip" \
  || bad "dry-run: no would-strip line: $RUN_OUT"
printf '%s' "$RUN_OUT" | grep -q 'would attempt a disposition close' \
  && ok "dry-run names the disposition attempt" || bad "dry-run: no would-attempt line: $RUN_OUT"
[ ! -s "$WRITES" ] && ok "dry-run wrote nothing to the board" || bad "dry-run wrote: $(cat "$WRITES")"

# ---------------------------------------------------------------------------------------
echo "refly.test: case 3 — cannot verify -> NOT-GATED, nothing touched"
# ---------------------------------------------------------------------------------------
: >"$WRITES"
NOBR="$WORK/nobr"; mkdir -p "$NOBR"
for t in bash jq git sed grep printf date mktemp dirname cat awk sh env; do
  p=$(command -v "$t" 2>/dev/null) && ln -sf "$p" "$NOBR/$t"
done
RUN_OUT=$(env BR_WRITES="$WRITES" PATH="$NOBR" bash "$REFLY" --root "$WORK/root" 2>&1); RUN_RC=$?
[ "$RUN_RC" -eq 2 ] && ok "no br on PATH exits 2" || bad "no br: expected exit 2, got $RUN_RC: $RUN_OUT"
printf '%s' "$RUN_OUT" | grep -q 'NOT-GATED' && ok "no br: says NOT-GATED" || bad "no br: silent: $RUN_OUT"
[ ! -s "$WRITES" ] && ok "no br: wrote nothing" || bad "no br: wrote: $(cat "$WRITES")"

# ---------------------------------------------------------------------------------------
echo ""
echo "refly.test: $PASS passed, $FAIL failed"
[ "$PASS" -gt 0 ] || { echo "refly.test: NOT-GATED — zero cases ran"; exit 1; }
[ "$FAIL" -eq 0 ]
