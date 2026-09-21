#!/usr/bin/env bash
# close-gate.test.sh — proof harness for close-gate.sh, the ac2 temporal causal-necessity
# probe (ac-k25c.3).
#
# EVERY CASE IS DERIVED FROM THE BEAD'S ACCEPTANCE CRITERIA, not from reading close-gate.sh.
# A harness written by reading the implementation tests that the implementation does what
# it does, which is not what the ACs ask; this bead is unusually exposed to that trap
# because its subject arrived as an unverified draft.
#
# The RED receipts are written by the REAL flight-check.sh, never forged here. The receipt
# format is a two-script contract, and a harness that hand-writes the receipt proves the
# author's belief about that contract rather than the contract. `br` IS mocked —
# it is the outside world, and the gate's own seam for it is what we drive.
#
# Exit 0 = all cases pass · 77 = self-skip (jq absent; the fixtures cannot be built).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/close-gate.sh"
FLIGHT="$SCRIPT_DIR/flight-check.sh"
AC_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
EVIDENCE_SRC="$AC_ROOT/skills/ac-pipeline/scripts/close-evidence-check.sh"
BR_CALL_SRC="$AC_ROOT/skills/_tools/br-call.sh"
CASES=0
FAILURES=0

pass() { CASES=$((CASES+1)); echo "ok   $*"; }
fail() { CASES=$((CASES+1)); FAILURES=$((FAILURES+1)); echo "FAIL $*"; }

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq is not installed — fixtures cannot be built"; exit 77; }
[ -x "$FLIGHT" ]       || { echo "FAIL flight-check.sh missing at $FLIGHT — the receipt writer is a hard dependency"; exit 1; }
[ -x "$EVIDENCE_SRC" ] || { echo "FAIL close-evidence-check.sh missing at $EVIDENCE_SRC"; exit 1; }

# --- GIT HERMETICITY (ac-fy8s AC 2) ---------------------------------------------------------
# The UNCOMMITTED fixtures measure `git status`, so the suite may not inherit ambient git
# config. A caller with a global `status.showUntrackedFiles=no` would silence the very
# entries cases 4a/4b depend on — the suite would then go green over the same bypass it is
# supposed to detect (measured: mutation-convicted, 66-case suite, 3 failures). Pin global
# and system config to /dev/null for the whole run; the work trees below carry explicit
# per-invocation `-c` identity/commit pins, never a `git config` write that reads ambient.
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1
unset GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 2>/dev/null

# --- AC 1: the gate ships as an executable script ------------------------------------------
if [ -x "$GATE" ]; then pass "AC1: close-gate.sh exists and is executable"
else fail "AC1: close-gate.sh is missing or not executable at $GATE"; exit 1; fi

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/close-gate.XXXXXX")"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

MOCK_BIN="$WORKDIR/bin"
mkdir -p "$MOCK_BIN"
PATH="$MOCK_BIN:$PATH"
export PATH

# Mock `br` — a file-backed board. `show` emits the bead unless AC2_TEST_BR_SHOW_FAIL=1
# (the read refuses while the fixture board stays intact — ac-8n94). `close` flips
# status to closed unless AC2_TEST_BR_CLOSE_NOOP=1, which is how the silent-close-failure
# case is driven.
cat >"$MOCK_BIN/br" <<'MOCKBR'
#!/usr/bin/env bash
STATE="${AC2_TEST_BR_STATE:-/nonexistent}"
cmd="${1:-}"; shift 2>/dev/null || true
id=""
for a in "$@"; do case "$a" in --*) ;; -*) ;; *) [ -z "$id" ] && id="$a" ;; esac; done

# next_id <bead-id> — a per-bead incrementing integer comment id, the real br 0.5.12 shape
# (`{"id": <int>, ...}`) — needed so a citation-by-id (GATE: decided's ruling-comment id) has
# a real id to cite and check-35's cross-reference can resolve it.
next_id() {
  local seqf="$STATE/$1.seq" n
  n=$(cat "$seqf" 2>/dev/null || echo 0)
  n=$((n + 1))
  printf '%s' "$n" >"$seqf"
  printf '%s' "$n"
}

append_comment() { # <bead-id> <text> — one writer for both the close-transition path and
                    # `comments add`, so the two can never disagree on shape.
  local cid="$1" body="$2" cfile cnid
  cfile="$STATE/$cid.comments.json"
  [ -f "$cfile" ] || echo '[]' >"$cfile"
  cnid=$(next_id "$cid")
  jq --arg t "$body" --argjson i "$cnid" \
    '. + [{"id":$i,"author":"mock","created_at":"2026-01-01T00:00:00Z","text":$t}]' \
    "$cfile" >"$cfile.tmp" 2>/dev/null && mv "$cfile.tmp" "$cfile"
}

case "$cmd" in
  show)
    [ "${AC2_TEST_BR_SHOW_FAIL:-0}" = "1" ] && exit 1
    [ -f "$STATE/$id.json" ] || exit 1
    cat "$STATE/$id.json" ;;
  close)
    [ -f "$STATE/$id.json" ] || exit 1
    [ "${AC2_TEST_BR_CLOSE_NOOP:-0}" = "1" ] && exit 0
    # `--transition-comment <text>` (br 0.5.12) — the landing record commits ATOMICALLY
    # with the close: recorded into the same comments log/store a `comments add` would use,
    # so a fixture cannot tell the two write paths apart by their output.
    tc=""; tprev=""
    for a in "$@"; do
      case "$tprev" in tc) tc="$a"; tprev=""; continue ;; esac
      case "$a" in --transition-comment) tprev=tc ;; *) tprev="" ;; esac
    done
    jq '.status = "closed"' "$STATE/$id.json" >"$STATE/$id.json.tmp" && mv "$STATE/$id.json.tmp" "$STATE/$id.json"
    if [ -n "$tc" ]; then
      printf '%s\n' "$tc" >> "$STATE/comments.log"
      append_comment "$id" "$tc"
    fi ;;
  comments)
    sub="${1:-}"
    if [ "$sub" = "list" ]; then
      # `comments list <id> --json` — the ruling path's own read. Bare array of objects
      # carrying the comment in a `text` key, the real br 0.5.12 shape.
      shift 2>/dev/null || true
      lcid=""
      for a in "$@"; do case "$a" in --*) ;; *) [ -z "$lcid" ] && lcid="$a" ;; esac; done
      cfile="$STATE/$lcid.comments.json"
      [ -f "$cfile" ] && cat "$cfile" || echo '[]'
      exit 0
    fi
    # `comments add <id> -f <file>` (or inline text) — recorded so a fixture can assert
    # that the gate WROTE the record it claims to write (the fresh-verification receipt).
    cid=""; body=""; prev=""
    for a in "$@"; do
      case "$a" in
        -f) prev=f ;;
        --*) prev="" ;;
        add) prev="" ;;
        *)
          case "$prev" in
            f) body="$(cat "$a" 2>/dev/null)" ;;
            *) if [ -z "$cid" ]; then cid="$a"; else body="$a"; fi ;;
          esac
          prev="" ;;
      esac
    done
    [ -f "$STATE/$cid.json" ] || exit 1
    printf '%s\n' "$body" >> "$STATE/comments.log"
    append_comment "$cid" "$body"
    exit 0 ;;
  *) exit 0 ;;
esac
MOCKBR
chmod +x "$MOCK_BIN/br"

BEAD="ac-test.1"

# A fixture bead: two ACs (one already green, one RED-able), a Delivers section the
# evidence core can cross-reference, and no Consumes.
mkcase() {
  local root="$WORKDIR/$1"
  mkdir -p "$root/skills/ac-pipeline/scripts" "$root/skills/_tools" "$root/.flight" "$root/.br"
  cp "$EVIDENCE_SRC" "$root/skills/ac-pipeline/scripts/close-evidence-check.sh"
  cp "$BR_CALL_SRC" "$root/skills/_tools/br-call.sh"
  chmod +x "$root/skills/ac-pipeline/scripts/close-evidence-check.sh"
  printf 'subject v1\n' >"$root/subject.txt"
  cat >"$root/body.md" <<'BODY'
## Acceptance Criteria
- the subject file exists.
  Probe: `test -f subject.txt` — tier: none
- the harness passes.
  Probe: `test -x harness.test.sh && bash harness.test.sh` — tier: none

## Delivers
- artifact: subject.txt
- harness: harness.test.sh

## Consumes
- none
BODY
  echo "$root"
}

# The bead's own harness. Its assertion is about the SUBJECT, so the fix never touches it —
# which is exactly the unchanged-test guarantee the hash lock is buying.
write_harness() {
  cat >"$1/harness.test.sh" <<'H'
#!/usr/bin/env bash
rc=0
if grep -q FIXED subject.txt; then echo "ok   subject carries FIXED"; else echo "FAIL subject lacks FIXED"; rc=1; fi
echo "ok   harness ran to completion"
exit $rc
H
  chmod +x "$1/harness.test.sh"
}

# A harness that exits 0 while asserting NOTHING — a bail-killed run wearing a green code.
write_silent_harness() {
  printf '#!/usr/bin/env bash\necho "starting up"\nexit 0\n' >"$1/harness.test.sh"
  chmod +x "$1/harness.test.sh"
}

# A PROSE fixture: no harness anywhere in its ACs, and its single probe asserts on the very
# file it ships. This is the shape whose close was structurally impossible before ac-hnsc.
mkcase_prose() {
  local root="$WORKDIR/$1"
  mkdir -p "$root/skills/ac-pipeline/scripts" "$root/skills/_tools" "$root/.flight" "$root/.br"
  cp "$EVIDENCE_SRC" "$root/skills/ac-pipeline/scripts/close-evidence-check.sh"
  cp "$BR_CALL_SRC" "$root/skills/_tools/br-call.sh"
  chmod +x "$root/skills/ac-pipeline/scripts/close-evidence-check.sh"
  printf 'a doc with no token yet\n' >"$root/doc.md"
  cat >"$root/body.md" <<'BODY'
## Acceptance Criteria
- the doc carries the TOKEN.
  Probe: `grep -q TOKEN doc.md` — tier: none

## Delivers
- doc: doc.md

## Consumes
- none
BODY
  echo "$root"
}

board() { # <root> <status> <assignee>
  jq -n --arg id "$BEAD" --arg st "$2" --arg as "$3" --rawfile d "$1/body.md" \
    '{id:$id,title:"fixture",issue_type:"task",status:$st,assignee:$as,labels:[],description:$d}' \
    >"$1/.br/$BEAD.json"
}

# A decision-type fixture: no harness, no extractable Probe: line at all — proving the
# ruling path truly skips legs 1-8 rather than merely passing them. `.beads/config.yaml`'s
# `humans:` key is the ruling matcher's live authority (ac-4y7l.25); "Alice" is this
# fixture's authorized name.
mkcase_decision() {
  local root="$WORKDIR/$1"
  mkdir -p "$root/skills/ac-pipeline/scripts" "$root/skills/_tools" "$root/.flight" "$root/.br" "$root/.beads"
  cp "$EVIDENCE_SRC" "$root/skills/ac-pipeline/scripts/close-evidence-check.sh"
  cp "$BR_CALL_SRC" "$root/skills/_tools/br-call.sh"
  chmod +x "$root/skills/ac-pipeline/scripts/close-evidence-check.sh"
  printf 'humans: Alice, Alice Smith\n' >"$root/.beads/config.yaml"
  printf 'Pick between option A and option B.\n' >"$root/body.md"
  echo "$root"
}

board_decision() { # <root> <status> <assignee> [labels-json]
  local labels="${4:-[]}"
  jq -n --arg id "$BEAD" --arg st "$2" --arg as "$3" --argjson lb "$labels" --rawfile d "$1/body.md" \
    '{id:$id,title:"fixture decision",issue_type:"decision",status:$st,assignee:$as,labels:$lb,description:$d}' \
    >"$1/.br/$BEAD.json"
}

add_ruling() { # <root> <text> — records a ruling comment directly via the mock, as a human
               # or system actor would before the close is attempted.
  ( cd "$1" && AC2_TEST_BR_STATE="$1/.br" br comments add "$BEAD" "$2" >/dev/null 2>&1 )
}

fly() { # <root> — run the REAL flight-check to bank a receipt
  ( cd "$1" && AC2_FLIGHT_DIR="$1/.flight" AC2_TEST_BR_STATE="$1/.br" AC2_DRY_RUN=1 \
      bash "$FLIGHT" "$BEAD" --body-file "$1/body.md" --root "$1" ) >/dev/null 2>&1
}

fix_subject() { printf 'subject v1\nFIXED\n' >"$1/subject.txt"; }

RCFILE="$WORKDIR/gate.rc"
GATE_RC=0
# Echoes the gate's output; the exit code travels through RCFILE because the caller reads
# the output in a command substitution, and a subshell cannot hand a variable back.
gate() { # <root> [extra args...]
  local root="$1"; shift
  ( cd "$root" && AC2_FLIGHT_DIR="$root/.flight" AC2_TEST_BR_STATE="$root/.br" \
      AC2_TEST_BR_CLOSE_NOOP="${AC2_TEST_BR_CLOSE_NOOP:-0}" \
      AC2_TEST_BR_SHOW_FAIL="${AC2_TEST_BR_SHOW_FAIL:-0}" \
      bash "$GATE" "$BEAD" --body-file "$root/body.md" --root "$root" "$@" 2>&1
    echo $? > "$RCFILE" )
}

REASON="shipped: the subject now carries FIXED. Delivered: subject.txt, harness.test.sh"

# mk_green — a fixture standing at the moment of a legitimate close: harness written, board
# row claimed, a REAL flight receipt banked, the RED subject fixed.
mk_green() {
  local r; r="$(mkcase "$1")"; write_harness "$r"; board "$r" in_progress worker
  fly "$r"; fix_subject "$r"; echo "$r"
}

# 2e'' The anti-pattern remedy is GONE: the gate must never tell a prose bead to grow a shell
# harness whose only job is to re-run a grep — that is the vacuous-AC shape this pipeline kills.
if ! grep -q 'Name a test-shaped harness' "$GATE"; then
  pass "AC2e'': the gate no longer prescribes a vacuous harness as the prose remedy"
else fail "AC2e'': the vacuous-harness remedy text is still in the gate"; fi

# ============================================================================================
# AC-ruling — a decision-type bead closes on a recorded ruling comment, never through the
# probe machinery: unclaimed (no in_progress row, no --actor), a body with no extractable
# Probe: line at all — proving legs 1-8 truly did not run, not merely pass.
# ============================================================================================
R="$(mkcase_decision ruling-accept)"
board_decision "$R" open ""
add_ruling "$R" "DECISION (Alice): option A — because it is cheaper"
out="$(gate "$R" --reason "decided: option A, per the recorded ruling")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && printf '%s' "$out" | grep -qi 'ruling'; then
  pass "AC-ruling: a decision bead with a recorded DECISION comment closes via the type-routed path"
else fail "AC-ruling accept: rc=$GATE_RC out=$out"; fi
if [ "$(jq -r .status "$R/.br/$BEAD.json")" = "closed" ]; then
  pass "AC-ruling: the ruling close landed"
else fail "AC-ruling: the ruling close did not land"; fi
if [ -f "$R/.br/comments.log" ] && grep -q 'GATE: decided' "$R/.br/comments.log"; then
  pass "AC-ruling: the landing record begins GATE: decided"
else fail "AC-ruling: no GATE: decided record landed"; fi

R="$(mkcase_decision ruling-refuse)"
board_decision "$R" open ""     # unclaimed; NO ruling comment recorded at all
out="$(gate "$R" --reason "decided: nothing was ruled")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'CLOSE-REFUSED DECISION'; then
  pass "AC-ruling: CLOSE-REFUSED DECISION when no ruling comment is recorded"
else fail "AC-ruling refuse: rc=$GATE_RC out=$out"; fi
if [ "$(jq -r .status "$R/.br/$BEAD.json")" = "open" ]; then
  pass "AC-ruling: the refused decision bead stays open"
else fail "AC-ruling: the bead was closed despite no ruling"; fi

# ============================================================================================
# AC-ruling — a placeholder ruling never counts, and a draft note does not count either: only
# a comment's own FIRST LINE, at column 0, is ever read as a ruling. An indented draft buried
# inside a longer conductor note, and an unfilled template quoted on a memo's second line, are
# each a REAL comment in the fixture — neither is ever line 1 of its own comment.
# ============================================================================================
R="$(mkcase_decision ruling-placeholder)"
board_decision "$R" open ""
add_ruling "$R" "Conductor note: still discussing.
  DECISION (Alice): draft — not final yet
Will update after standup."
add_ruling "$R" "See template below:
DECISION (<human>): <choice> — <why>"
out="$(gate "$R" --reason "decided: nothing was actually ruled")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'CLOSE-REFUSED DECISION'; then
  pass "AC-ruling: a placeholder ruling never counts, and a draft note does not count either"
else fail "AC-ruling placeholder: rc=$GATE_RC out=$out"; fi
if [ "$(jq -r .status "$R/.br/$BEAD.json")" = "open" ]; then
  pass "AC-ruling: the placeholder-ruling bead stays open"
else fail "AC-ruling placeholder: the bead was closed despite no valid ruling"; fi

# ============================================================================================
# AC-ruling — WHO MAY RULE: only a human on the closing board's own `.beads/config.yaml`
# `humans:` key, or the exact `DECISION (ac-tidy): moot` on a bead labelled
# `pipeline-proposal`.
# ============================================================================================
R="$(mkcase_decision ruling-agent-refused)"
board_decision "$R" open ""
add_ruling "$R" "DECISION (agent): option A — because it is cheaper"
out="$(gate "$R" --reason "decided: option A")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'CLOSE-REFUSED DECISION'; then
  pass "AC-ruling: agent self-ruling refused — DECISION (agent) is not an authorized human"
else fail "AC-ruling agent-refused: rc=$GATE_RC out=$out"; fi
if [ "$(jq -r .status "$R/.br/$BEAD.json")" = "open" ]; then
  pass "AC-ruling: the agent-ruled bead stays open"
else fail "AC-ruling agent-refused: the bead was closed despite an unauthorized ruling"; fi

R="$(mkcase_decision ruling-ac-tidy-moot)"
board_decision "$R" open "" '["pipeline-proposal"]'
add_ruling "$R" "DECISION (ac-tidy): moot"
out="$(gate "$R" --reason "decided: moot, superseded by a later proposal")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ]; then
  pass "AC-ruling: DECISION (ac-tidy): moot is accepted on a pipeline-proposal bead"
else fail "AC-ruling ac-tidy-moot: rc=$GATE_RC out=$out"; fi

R="$(mkcase_decision ruling-ac-tidy-unlabeled)"
board_decision "$R" open ""
add_ruling "$R" "DECISION (ac-tidy): moot"
out="$(gate "$R" --reason "decided: moot")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'CLOSE-REFUSED DECISION'; then
  pass "AC-ruling: DECISION (ac-tidy): moot is refused without the pipeline-proposal label"
else fail "AC-ruling ac-tidy-unlabeled: rc=$GATE_RC out=$out"; fi

R="$(mkcase_decision ruling-ac-tidy-nonmoot)"
board_decision "$R" open "" '["pipeline-proposal"]'
add_ruling "$R" "DECISION (ac-tidy): shipped — not the literal moot text"
out="$(gate "$R" --reason "decided: shipped")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'CLOSE-REFUSED DECISION'; then
  pass "AC-ruling: a non-moot ac-tidy ruling is refused — only the exact 'DECISION (ac-tidy): moot' is accepted"
else fail "AC-ruling ac-tidy-nonmoot: rc=$GATE_RC out=$out"; fi

# ============================================================================================
# AC-ruling — the newest authorized ruling wins, across every comment on the bead, never just
# the first DECISION-shaped line found (ac-4y7l.25: an earlier `DECISION (agent)` used to
# block a later valid human ruling forever, and between two human rulings the older one won).
# ============================================================================================
R="$(mkcase_decision ruling-agent-then-human)"
board_decision "$R" open ""
add_ruling "$R" "DECISION (agent): option A — because it is cheaper"
add_ruling "$R" "DECISION (Alice): option B — overriding the agent's earlier call"
out="$(gate "$R" --reason "decided: option B, per Alice's later ruling")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && printf '%s' "$out" | grep -qi 'ruling'; then
  pass "AC-ruling: the newest authorized ruling wins — a later human ruling is not blocked by an earlier unauthorized agent line"
else fail "AC-ruling agent-then-human: rc=$GATE_RC out=$out"; fi

R="$(mkcase_decision ruling-two-humans)"
board_decision "$R" open ""
add_ruling "$R" "DECISION (Alice): option A — the first call"
add_ruling "$R" "DECISION (Alice): option B — changed my mind, this one"
out="$(gate "$R" --reason "decided: option B, the newer human ruling")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && [ -f "$R/.br/comments.log" ] && grep -q 'option B' "$R/.br/comments.log"; then
  pass "AC-ruling: the newest authorized ruling wins — with two human rulings the newer one is what lands, never the first grep hit"
else fail "AC-ruling two-humans: rc=$GATE_RC out=$out"; fi

R="$(mkcase_decision ruling-multiword-name)"
board_decision "$R" open ""
add_ruling "$R" "DECISION (Alice Smith): option A — signed with the full name on the humans: key"
out="$(gate "$R" --reason "decided: option A, full-name ruling")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && printf '%s' "$out" | grep -qi 'ruling'; then
  pass "AC-ruling: a multi-word name on the humans: key authorizes as one whole entry, never split on its own inner spaces"
else fail "AC-ruling multiword-name: rc=$GATE_RC out=$out"; fi

# ============================================================================================
# AC-ruling — a `human-gate`-labelled bead (not typed `decision`) also routes through the
# ruling path.
# ============================================================================================
R="$(mkcase_decision ruling-human-gate-label)"
board_decision "$R" open "" '["human-gate"]'
jq '.issue_type = "task"' "$R/.br/$BEAD.json" >"$R/.br/$BEAD.json.tmp" && mv "$R/.br/$BEAD.json.tmp" "$R/.br/$BEAD.json"
add_ruling "$R" "DECISION (Alice): option A — because it is cheaper"
out="$(gate "$R" --reason "decided: option A, per the recorded ruling")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && printf '%s' "$out" | grep -qi 'ruling'; then
  pass "AC-ruling: a task typed bead labelled human-gate also routes through the ruling path"
else fail "AC-ruling human-gate-label: rc=$GATE_RC out=$out"; fi

# ============================================================================================
# AC 2 — the three refusals, each NAMING the leg that failed
# ============================================================================================

# --- 2a: no RED receipt — the all-green no-receipt close was RE-CLASSIFIED by the
# fresh-verify extension (run 20260907-exhaust): it now passes via fresh verification
# (fixture 3i). The refusal that remains in the no-receipt world is the not-green probe.
R="$(mkcase no-receipt-red)"; write_harness "$R"; board "$R" in_progress worker
# subject NEVER fixed: `test -x harness.test.sh && bash harness.test.sh` exits 1 at HEAD;
# no fly() — NO receipt file exists.
out="$(gate "$R" --reason "$REASON")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'GREEN'; then
  pass "AC2a: a no-receipt close with a not-green probe is refused, naming GREEN"
else fail "AC2a: rc=$GATE_RC out=$out"; fi
if [ "$(jq -r .status "$R/.br/$BEAD.json")" = "in_progress" ]; then
  pass "AC2a: a refused close leaves the bead open"
else fail "AC2a: the bead was closed despite the refusal"; fi

# --- 2c: the probe never reported GREEN ------------------------------------------------------
R="$(mkcase never-green)"; write_harness "$R"; board "$R" in_progress worker
fly "$R"                                   # RED banked, and the subject is NEVER fixed
out="$(gate "$R" --reason "$REASON")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'GREEN'; then
  pass "AC2c: refuses a probe that never reported GREEN, naming GREEN"
else fail "AC2c: rc=$GATE_RC out=$out"; fi

# ============================================================================================
# AC 3 — coverage is asserted, not assumed
# ============================================================================================

# --- 3a: files-run < files-expected ------------------------------------------------------------
R="$(mkcase coverage-shortfall)"; write_harness "$R"; board "$R" in_progress worker
fly "$R"; fix_subject "$R"
cat >>"$R/body.md" <<'EXTRA'

## Extra
- a third criterion whose probe cannot run at all.
  Probe: `ac-no-such-command-42 subject.txt` — tier: none
EXTRA
board "$R" in_progress worker
out="$(gate "$R" --reason "$REASON")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 2 ] && printf '%s' "$out" | grep -q 'NOT-CHECKED'; then
  pass "AC3a: a probe that cannot run is NOT-CHECKED (exit 2), never a pass"
else fail "AC3a: rc=$GATE_RC out=$out"; fi

# --- 3b: green exit code, ZERO assertion results -------------------------------------------------
R="$(mkcase coverage-silent)"; write_silent_harness "$R"; board "$R" in_progress worker
# make the silent harness RED for the flight, then GREEN for the close, without editing it:
# it asserts nothing either way, which is the whole point.
cat >"$R/harness.test.sh" <<'H'
#!/usr/bin/env bash
echo "starting up"
grep -q FIXED subject.txt || exit 1
exit 0
H
chmod +x "$R/harness.test.sh"
fly "$R"; fix_subject "$R"
out="$(gate "$R" --reason "$REASON")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 2 ] && printf '%s' "$out" | grep -qi 'assertion'; then
  pass "AC3b: a green run with zero assertion results is NOT-CHECKED — a bail-killed run is not a pass"
else fail "AC3b: rc=$GATE_RC out=$out"; fi

# --- 3c: the literal vitest assertionResults path ---------------------------------------------
R="$(mkcase coverage-vitest)"; write_harness "$R"; board "$R" in_progress worker
fly "$R"; fix_subject "$R"
printf '{"testResults":[{"assertionResults":[]}]}\n' >"$R/empty.json"
out="$(gate "$R" --reason "$REASON" --vitest-json "$R/empty.json")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 2 ]; then
  pass "AC3c: an empty assertionResults array is NOT-CHECKED"
else fail "AC3c: rc=$GATE_RC out=$out"; fi
printf '{"testResults":[{"assertionResults":[{"status":"passed"},{"status":"passed"}]}]}\n' >"$R/full.json"
out="$(gate "$R" --reason "$REASON" --vitest-json "$R/full.json")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ]; then
  pass "AC3c: a populated assertionResults array satisfies the coverage leg"
else fail "AC3c: rc=$GATE_RC out=$out"; fi
if grep -q 'assertionResults' "$GATE"; then
  pass "AC3: the gate names the assertionResults field it reads"
else fail "AC3: the gate never mentions assertionResults"; fi

# --- 3d (ac-close-gate-coverage-silent-probe-ja8l, instance 4): one AC names a test-shaped
# file through a SILENT grep probe (-q), and a real harness probe also exists. The
# assertion-bearing probe must be the one whose stdout can carry assertion lines — never a
# grep that merely names a test-shaped file, whose stdout is empty by construction.
R="$(mkcase coverage-silent-grep)"
write_harness "$R"; board "$R" in_progress worker
cat >"$R/body.md" <<'BODY'
## Acceptance Criteria
- the harness names the assertion format.
  Probe: `grep -q 'ok' harness.test.sh` — tier: none
- the harness passes.
  Probe: `bash harness.test.sh` — tier: none

## Delivers
- artifact: subject.txt
- harness: harness.test.sh

## Consumes
- none
BODY
fly "$R"; fix_subject "$R"
out="$(gate "$R" --reason "$REASON")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && printf '%s' "$out" | grep -q 'COVERAGE ok'; then
  pass "AC3d: a silent grep naming a test-shaped file is never the assertion probe — the output-carrying harness probe is"
else fail "AC3d: rc=$GATE_RC out=$out"; fi

# --- 3e (ac-close-gate-coverage-silent-probe-ja8l, instance 5): a REAL harness probe whose
# assertion lines are the registry-live `  PASS: <label>` format — not TAP ok/N — and whose
# summary carries no "N passed" count. The gate must recognize the formats live harnesses
# in this registry actually emit.
write_registry_format_harness() {
  cat >"$1/harness.test.sh" <<'H'
#!/usr/bin/env bash
rc=0
if grep -q FIXED subject.txt; then echo "  PASS: AC1: subject carries FIXED"; else echo "  FAIL: AC1: subject lacks FIXED"; rc=1; fi
echo "All fixture tests passed."
exit $rc
H
  chmod +x "$1/harness.test.sh"
}
R="$(mkcase coverage-pass-format)"
write_registry_format_harness "$R"; board "$R" in_progress worker
cat >"$R/body.md" <<'BODY'
## Acceptance Criteria
- the harness passes.
  Probe: `bash harness.test.sh` — tier: none

## Delivers
- artifact: subject.txt
- harness: harness.test.sh

## Consumes
- none
BODY
fly "$R"; fix_subject "$R"
out="$(gate "$R" --reason "$REASON")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && printf '%s' "$out" | grep -q 'COVERAGE ok'; then
  pass "AC3e: '  PASS: <label>' assertion lines are recognized as assertion results"
else fail "AC3e: rc=$GATE_RC out=$out"; fi

# --- 3g (heyt P1, instance 6): an existence-predicate chain (`test -f` over test-shaped
# files) names harness files but emits nothing — `test` has no stdout. The assertion-bearing
# probe must be the output-carrying harness probe, never the predicate chain.
R="$(mkcase coverage-silent-testchain)"
write_registry_format_harness "$R"; board "$R" in_progress worker
cat >"$R/body.md" <<'BODY'
## Acceptance Criteria
- the harness files exist.
  Probe: `test -f harness.test.sh && test -f subject.txt` — tier: none
- the harness passes.
  Probe: `bash harness.test.sh` — tier: none

## Delivers
- artifact: subject.txt
- harness: harness.test.sh

## Consumes
- none
BODY
fly "$R"; fix_subject "$R"
out="$(gate "$R" --reason "$REASON")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && printf '%s' "$out" | grep -q 'COVERAGE ok'; then
  pass "AC3g: a test-predicate chain naming test-shaped files is never the assertion probe — the output-carrying harness probe is"
else fail "AC3g: rc=$GATE_RC out=$out"; fi

# --- 3f (the Delivers carve-out, guarded): when EVERY probe's stdout is suppressed by
# construction, the temporal exit-code pair recorded in the receipt is the assertion —
# the same case the prose path already handled. This must never have to grow a harness.
R="$(mkcase coverage-all-silent)"
board "$R" in_progress worker
cat >"$R/body.md" <<'BODY'
## Acceptance Criteria
- the subject carries the token.
  Probe: `grep -q FIXED subject.txt` — tier: none

## Delivers
- artifact: subject.txt

## Consumes
- none
BODY
fly "$R"; fix_subject "$R"
out="$(gate "$R" --reason "shipped: the subject now carries FIXED. Delivered: subject.txt")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && printf '%s' "$out" | grep -q 'temporal exit-code pair'; then
  pass "AC3f: every-probe-output-silent closes on the receipt's temporal pair — no harness demanded"
else fail "AC3f: rc=$GATE_RC out=$out"; fi

# --- 3k (bd-9y8ii, bd-fswt7.3): a `git diff --quiet` probe naming a test-shaped file must
# never be chosen as the assertion probe — `--quiet` suppresses stdout exactly like `-q`, so
# a COVERAGE leg that missed it reads the probe's empty output and NOT-CHECKEDs a close whose
# real harness probe passed.
R="$(mkcase quiet-probe)"
write_harness "$R"; board "$R" in_progress worker
git -C "$R" init -q
git -C "$R" -c user.name=t -c user.email=t@t -c commit.gpgsign=false add -A >/dev/null 2>&1
git -C "$R" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q -m base >/dev/null 2>&1
cat >"$R/body.md" <<'BODY'
## Acceptance Criteria
- the harness file is unchanged.
  Probe: `git diff --quiet HEAD -- harness.test.sh` — tier: none
- the harness passes.
  Probe: `bash harness.test.sh` — tier: none

## Delivers
- artifact: subject.txt
- harness: harness.test.sh

## Consumes
- none
BODY
fly "$R"; fix_subject "$R"
# The widened extractor (ac-pa51) sees the ROOT-LEVEL `subject.txt` this fixture delivers, so
# the fixture must be committed-clean for the close to land: the fix is then really on disk
# AND in a commit, which is what an honest close asserts. Under the old slash-REQUIRED pattern
# the path was invisible here and the uncommitted fix slipped through the UNCOMMITTED leg —
# the exact fail-open this bead closes, not a property to preserve.
git -C "$R" -c user.name=t -c user.email=t@t -c commit.gpgsign=false add -A >/dev/null 2>&1
git -C "$R" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q -m fixed >/dev/null 2>&1
out="$(gate "$R" --reason "$REASON")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && printf '%s' "$out" | grep -q 'COVERAGE ok'; then
  pass "AC3k: a 'git diff --quiet' probe naming a test-shaped file is never the assertion probe — the output-carrying harness probe is"
else fail "AC3k: rc=$GATE_RC out=$out"; fi

# ============================================================================================
# AC 3g/3h/3i/3j — the fresh-verification carve-out (ac-close-gate-already-green-carveout-8r3o,
# extended by run 20260907-exhaust): a bead with no usable claim-time receipt banks no
# temporal anchor, so LEG 1 refused every future close of it — an honest obsolete/duplicate
# disposition (measured: 4 beads dead on the identical refusal) AND legitimate shipped
# closes of cross-repo work whose probes could not resolve from the claim cwd (measured:
# ac-dream-docket-sweep-mgzw, ac-dream-emitter-born-verified-uo7n). ANY disposition now
# closes through the fresh leg, under four conditions: (a) every AC probe exits 0 at HEAD
# and the per-probe results are RECORDED in the FRESH-VERIFY comment at landing — never a
# bare summary; (b) the close reason still names a Delivers artifact the evidence core
# resolves; (c) a usable claim-time receipt still takes precedence (temporal pair
# preferred); (d) the abuse-guard — a fresh-verify attempt on a bead with ANY not-green
# probe is REFUSED. The guard fixtures (3j) are the spine of this extension.
# ============================================================================================

# --- 3g (AC1 + AC2 first half): an obsolete: close with no claim-time receipt is ACCEPTED,
# and the fresh verification is RECORDED on the bead — a receipt nobody wrote is a claim.
OBSOLETE_REASON="obsolete: the defect is resolved at HEAD by other work (ec5fa64); the probes pass at HEAD. Delivered: subject.txt, harness.test.sh"
R="$(mkcase fresh-verify-accept)"
write_harness "$R"; board "$R" in_progress worker
fix_subject "$R"                    # green at HEAD — no fly(), so NO receipt file exists
out="$(gate "$R" --reason "$OBSOLETE_REASON")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && printf '%s' "$out" | grep -qi 'fresh'; then
  pass "AC3g: an obsolete close with no claim-time receipt is accepted via fresh verification"
else fail "AC3g: rc=$GATE_RC out=$out"; fi
if [ -f "$R/.br/comments.log" ] && grep -q 'FRESH-VERIFY' "$R/.br/comments.log"; then
  pass "AC3g: the fresh verification is RECORDED on the bead (FRESH-VERIFY comment)"
else fail "AC3g: no FRESH-VERIFY record landed on the bead"; fi
if [ "$(jq -r .status "$R/.br/$BEAD.json")" = "closed" ]; then
  pass "AC3g: the fresh-verified close landed"
else fail "AC3g: the close did not land"; fi

# --- 3h (AC2 second half): a BOGUS obsolete close — probes NOT green at HEAD — is refused.
R="$(mkcase fresh-verify-bogus)"
write_harness "$R"; board "$R" in_progress worker
# subject NEVER fixed: `test -x harness.test.sh && bash harness.test.sh` exits 1 at HEAD.
out="$(gate "$R" --reason "$OBSOLETE_REASON")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'GREEN'; then
  pass "AC3h: a bogus obsolete close (probes not green at HEAD) is refused, naming GREEN"
else fail "AC3h: rc=$GATE_RC out=$out"; fi

# --- 3i (run 20260907-exhaust, fixture A): a shipped: close with no claim-time receipt
# and EVERY AC probe green at HEAD is accepted via fresh verification, and the FRESH-VERIFY
# comment records the PER-PROBE results — never a bare summary.
R="$(mkcase fresh-verify-shipped-green)"
write_harness "$R"; board "$R" in_progress worker
fix_subject "$R"                    # all probes green at HEAD; no fly() — NO receipt file
out="$(gate "$R" --reason "$REASON")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && [ "$(jq -r .status "$R/.br/$BEAD.json")" = "closed" ]; then
  pass "AC3i: a shipped close with no claim-time receipt passes fresh verification when every AC probe is green at HEAD"
else fail "AC3i: rc=$GATE_RC out=$out"; fi
if [ -f "$R/.br/comments.log" ] && grep -q 'FRESH-VERIFY' "$R/.br/comments.log" \
   && grep -q '=> exit 0' "$R/.br/comments.log" \
   && grep -q 'test -f subject.txt' "$R/.br/comments.log" \
   && grep -q 'harness.test.sh' "$R/.br/comments.log"; then
  pass "AC3i: the FRESH-VERIFY record carries the PER-PROBE results (each probe named with its exit code)"
else fail "AC3i: the FRESH-VERIFY record lacks per-probe results"; fi

# --- 3j (the abuse-guard spine, fixture B): the SAME shipped close with ONE not-green
# probe is REFUSED — a fresh-verified close demands every AC probe green; one red probe
# is a refusal, and the refusal names GREEN.
R="$(mkcase fresh-verify-shipped-red)"
write_harness "$R"; board "$R" in_progress worker
# subject NEVER fixed: `test -x harness.test.sh && bash harness.test.sh` exits 1 at HEAD.
out="$(gate "$R" --reason "$REASON")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'GREEN'; then
  pass "AC3j: a fresh-verify shipped close with ANY not-green probe is refused, naming GREEN"
else fail "AC3j: rc=$GATE_RC out=$out"; fi
if [ "$(jq -r .status "$R/.br/$BEAD.json")" = "in_progress" ]; then
  pass "AC3j: the refused fresh-verify close leaves the bead open"
else fail "AC3j: the bead was closed despite the refusal"; fi

# ============================================================================================
# AC 3l/3m/3n — the DISPOSITION carve-out (condition e, the cascade): a disposition close
# whose probes are NOT all green closes ONLY when every Consumes blocker is closed with a
# disposition close reason, read live from the board — never assumed, never a bare claim.
# The close claims "the state this bead aimed at is settled", NOT "a diff caused a flip",
# so it may land where the temporal pair cannot (no receipt, RED probe still red).
# ============================================================================================

DEP="bd-upstream-9zz"
board_dep() { # <root> <status> <assignee> <close reason> — the consumed blocker on the mock board
  jq -n --arg id "$DEP" --arg st "$2" --arg as "$3" --arg cr "$4" \
    '{id:$id,title:"upstream fixture",issue_type:"task",status:$st,assignee:$as,labels:[],description:"consumed by the fixture bead",close_reason:$cr}' \
    >"$1/.br/$DEP.json"
}

# --- 3l: probe RED at HEAD (work never landed), blocker closed wontfix → ACCEPTED via the
# cascade leg, and the TRIAGE-CLOSE record lands on the bead — the bead's stranded-premise
# close, verified.
R="$(mkcase cascade-accept)"
cat >"$R/body.md" <<'BODY'
## Acceptance Criteria
- the consumed artifact exists.
  Probe: `test -f gone.md` — tier: none

## Delivers
- artifact: gone.md

## Consumes
- bd-upstream-9zz -> gone.md (landed)
BODY
board "$R" in_progress worker
board_dep "$R" closed "triager" "wontfix: the upstream chose not to ship — premise retired (bd-upstream.abc)"
out="$(gate "$R" --reason "obsolete: TRIAGE — the consumed blocker closed wontfix. Delivered: gone.md" --actor worker)"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && printf '%s' "$out" | grep -q 'cascade'; then
  pass "AC3l: a disposition close with a red probe and a disposition-closed blocker is accepted via the cascade leg"
else fail "AC3l: rc=$GATE_RC out=$out"; fi
if [ "$(jq -r .status "$R/.br/$BEAD.json")" = "closed" ]; then
  pass "AC3l: the cascade close landed"
else fail "AC3l: the cascade close did not land"; fi
if [ -f "$R/.br/comments.log" ] && grep -q 'TRIAGE-CLOSE' "$R/.br/comments.log"; then
  pass "AC3l: the cascade evidence is RECORDED on the bead (TRIAGE-CLOSE comment)"
else fail "AC3l: no TRIAGE-CLOSE record landed on the bead"; fi

# --- 3m: the SAME red-probe disposition close where the blocker closed shipped: (the
# deliverable is final, not retired) → REFUSED. The cascade does not rescue a premise
# that was delivered-and-moved-on; that staleness is intent, and intent stays human.
R="$(mkcase cascade-shipped-blocker)"
cat >"$R/body.md" <<'BODY'
## Acceptance Criteria
- the consumed artifact exists.
  Probe: `test -f gone.md` — tier: none

## Delivers
- artifact: gone.md

## Consumes
- bd-upstream-9zz -> gone.md (landed)
BODY
board "$R" in_progress worker
board_dep "$R" closed "worker" "shipped: the upstream landed its deliverable"
out="$(gate "$R" --reason "obsolete: TRIAGE — resolved at HEAD by other work. Delivered: gone.md")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'disposition close'; then
  pass "AC3m: a disposition close rescued by a shipped-closed blocker is refused — the cascade demands a disposition close"
else fail "AC3m: rc=$GATE_RC out=$out"; fi
if [ "$(jq -r .status "$R/.br/$BEAD.json")" = "in_progress" ]; then
  pass "AC3m: the refused cascade close leaves the bead open"
else fail "AC3m: the bead was closed despite the refusal"; fi

# --- 3n: the blocker is OPEN → the premise is not gone, the cascade does not hold → REFUSED.
R="$(mkcase cascade-open-blocker)"
cat >"$R/body.md" <<'BODY'
## Acceptance Criteria
- the consumed artifact exists.
  Probe: `test -f gone.md` — tier: none

## Delivers
- artifact: gone.md

## Consumes
- bd-upstream-9zz -> gone.md (landed)
BODY
board "$R" in_progress worker
board_dep "$R" open "" ""
out="$(gate "$R" --reason "obsolete: TRIAGE — resolved at HEAD by other work. Delivered: gone.md")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'disposition close'; then
  pass "AC3n: a disposition close over an OPEN blocker is refused — the premise still holds"
else fail "AC3n: rc=$GATE_RC out=$out"; fi

# --- 3o: wontfix is NOT a disposition carve-out verb — intent stays human.
R="$(mkcase cascade-wontfix-reason)"
cat >"$R/body.md" <<'BODY'
## Acceptance Criteria
- the consumed artifact exists.
  Probe: `test -f gone.md` — tier: none

## Delivers
- artifact: gone.md

## Consumes
- bd-upstream-9zz -> gone.md (landed)
BODY
board "$R" in_progress worker
board_dep "$R" closed "triager" "wontfix: premise retired (bd-upstream-9zz)"
out="$(gate "$R" --reason "wontfix: we decided not to build this. Delivered: gone.md")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'fresh-verify'; then
  pass "AC3o: a wontfix: close with a red probe is refused by the fresh-verify guard — wontfix is not a carve-out verb; intent stays human"
else fail "AC3o: rc=$GATE_RC out=$out"; fi

# ============================================================================================
# AC 4 — the UNCOMMITTED leg: a Delivers path the working tree carries but no commit does
# cannot support a close. Fixtures are real git work trees, so `git status --porcelain` has
# something to judge; the non-git case proves the skip is reported, never read as clean.
# ============================================================================================
# mk_gitcase <name> <delivers-rel-path> — a green fixture whose one Delivers path is a
# repo-relative path (touchers.sh's extractor reads root-level and nested names alike, ac-pa51).
# The path is NOT created here: each case decides whether it is committed-clean, untracked,
# ignored or deleted.
mk_gitcase() {
  local root="$WORKDIR/$1" dp="$2"
  mkdir -p "$root/skills/ac-pipeline/scripts" "$root/skills/_tools" "$root/.flight" "$root/.br" "$root/$(dirname "$dp")"
  cp "$EVIDENCE_SRC" "$root/skills/ac-pipeline/scripts/close-evidence-check.sh"
  cp "$BR_CALL_SRC" "$root/skills/_tools/br-call.sh"
  chmod +x "$root/skills/ac-pipeline/scripts/close-evidence-check.sh"
  printf 'subject v1\n' >"$root/subject.txt"
  cat >"$root/body.md" <<BODY
## Acceptance Criteria
- the subject file exists.
  Probe: \`test -f subject.txt\` — tier: none
- the harness passes.
  Probe: \`test -x harness.test.sh && bash harness.test.sh\` — tier: none

## Delivers
- artifact: $dp

## Consumes
- none
BODY
  echo "$root"
}

mk_git_green() { # <name> <delivers-rel-path> — a green fixture in a work tree, not yet committed
  local r; r="$(mk_gitcase "$1" "$2")"
  write_harness "$r"; board "$r" in_progress worker; fly "$r"; fix_subject "$r"
  echo "$r"
}

git_commit_clean() { # <root> — init a work tree and commit the fixture's current state
  # Explicit -c identity/commit pins, never a `git config` write: the fixture's git
  # behaviour is stated at each call and cannot be steered by whatever ambient config the
  # caller carries (ac-fy8s AC2).
  ( cd "$1" && git init -q \
      && git -c user.email=fixture@test -c user.name=fixture -c commit.gpgsign=false add -A \
      && git -c user.email=fixture@test -c user.name=fixture -c commit.gpgsign=false commit -qm fixture )
}

# --- 4a: an untracked Delivers path refuses.
R="$(mk_git_green uncommitted-untracked 'skills/demo/artifact.txt')"
git_commit_clean "$R"
printf 'artifact v1\n' >"$R/skills/demo/artifact.txt"       # on disk, never added -> ??
out="$(gate "$R" --reason "shipped: the artifact landed. Delivered: skills/demo/artifact.txt")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'CLOSE-REFUSED: UNCOMMITTED'; then
  pass "AC4: an untracked Delivers path refuses with CLOSE-REFUSED: UNCOMMITTED"
else fail "AC4 untracked: rc=$GATE_RC out=$out"; fi
if [ "$(jq -r .status "$R/.br/$BEAD.json")" = "in_progress" ]; then
  pass "AC4: the refused uncommitted close leaves the bead open"
else fail "AC4 untracked: the bead was closed despite an uncommitted Delivers path"; fi

# --- 4b: a Next.js route-group path (parens) is extracted intact and refuses the same way.
# The parens are the point: close-evidence-check.sh's regex would stop at `(auth)` and leave
# the path unchecked.
R="$(mk_git_green uncommitted-route-group 'app/(auth)/page.tsx')"
git_commit_clean "$R"
mkdir -p "$R/app/(auth)"; printf 'export default function Page(){}\n' >"$R/app/(auth)/page.tsx"
out="$(gate "$R" --reason "shipped: the page landed. Delivered: app/(auth)/page.tsx")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'CLOSE-REFUSED: UNCOMMITTED' \
   && printf '%s' "$out" | grep -q 'app/(auth)/page.tsx'; then
  pass "AC4: an untracked app/(auth) route-group Delivers path is extracted intact and refuses"
else fail "AC4 route-group: rc=$GATE_RC out=$out"; fi

# --- 4c: an ignored Delivers path prints nothing under git status and passes.
R="$(mk_git_green uncommitted-ignored 'skills/demo/artifact.txt')"
printf 'skills/demo/artifact.txt\n' >"$R/.gitignore"
git_commit_clean "$R"
printf 'artifact v1\n' >"$R/skills/demo/artifact.txt"       # ignored -> not reported
out="$(gate "$R" --reason "shipped: the artifact landed. Delivered: skills/demo/artifact.txt")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && printf '%s' "$out" | grep -q 'UNCOMMITTED ok'; then
  pass "AC4: an ignored Delivers path is not reported by git status and the close lands"
else fail "AC4 ignored: rc=$GATE_RC out=$out"; fi

# --- 4d: outside a git work tree the leg reports the skip; it never implies clean.
R="$(mk_green uncommitted-non-git)"
out="$(gate "$R" --reason "$REASON")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && printf '%s' "$out" | grep -q 'UNCOMMITTED skipped'; then
  pass "AC4: outside a git work tree the UNCOMMITTED leg reports a skip, never a silent clean"
else fail "AC4 non-git: rc=$GATE_RC out=$out"; fi

# --- 4e: a warning-laden file no longer blocks a green close (the scanner leg is deleted).
R="$(mk_git_green uncommitted-warn-laden 'skills/demo/artifact.txt')"
printf 'artifact v1\n' >"$R/skills/demo/artifact.txt"
printf 'try:\n    pass\nexcept:\n    pass\n' >"$R/legacy.py"     # the shape ubs flagged
git_commit_clean "$R"
out="$(gate "$R" --reason "shipped: the artifact landed. Delivered: skills/demo/artifact.txt")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && [ "$(jq -r .status "$R/.br/$BEAD.json")" = "closed" ]; then
  pass "AC4: green probes over a warning-laden file close — no scanner leg refuses them"
else fail "AC4 warn-laden: rc=$GATE_RC out=$out"; fi

# --- 4f (ac-fy8s): THE REPO'S OWN CONFIG silences untracked entries. Bare
# `git status --porcelain` honors status.showUntrackedFiles, so a repo that sets it to `no`
# makes an untracked Delivers path print nothing — the leg then certifies a delivery that
# exists in no commit as committed-clean and the close LANDS. The verdict may not be
# readable off config the gated party controls.
R="$(mk_git_green uncommitted-silenced-local 'skills/demo/artifact.txt')"
git_commit_clean "$R"
git -C "$R" config status.showUntrackedFiles no                    # the silencing config
printf 'artifact v1\n' >"$R/skills/demo/artifact.txt"              # on disk, never added -> ??
out="$(gate "$R" --reason "shipped: the artifact landed. Delivered: skills/demo/artifact.txt")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'CLOSE-REFUSED: UNCOMMITTED'; then
  pass "AC4f: an untracked Delivers path refuses even when the REPO sets status.showUntrackedFiles=no"
else fail "AC4f silenced-local: rc=$GATE_RC out=$out"; fi
if [ "$(jq -r .status "$R/.br/$BEAD.json")" = "in_progress" ]; then
  pass "AC4f: the silenced-config close leaves the bead open"
else fail "AC4f silenced-local: the bead was closed despite an uncommitted Delivers path"; fi

# --- 4g (ac-fy8s): the silencing lives in GLOBAL config, outside the repo entirely — the
# "ambient config" half of the finding. A gated party need not touch the repo at all;
# ~/.gitconfig is enough to buy a false clean. Reproduced through GIT_CONFIG_GLOBAL, which is
# exactly how an ambient global config reaches `git` in a subprocess.
R="$(mk_git_green uncommitted-silenced-global 'skills/demo/artifact.txt')"
git_commit_clean "$R"
printf '[status]\n\tshowUntrackedFiles = no\n' >"$R/silent.gitconfig"
printf 'artifact v1\n' >"$R/skills/demo/artifact.txt"              # on disk, never added -> ??
out="$(GIT_CONFIG_GLOBAL="$R/silent.gitconfig" gate "$R" --reason "shipped: the artifact landed. Delivered: skills/demo/artifact.txt")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'CLOSE-REFUSED: UNCOMMITTED'; then
  pass "AC4g: an untracked Delivers path refuses even when GLOBAL config sets status.showUntrackedFiles=no"
else fail "AC4g silenced-global: rc=$GATE_RC out=$out"; fi
if [ "$(jq -r .status "$R/.br/$BEAD.json")" = "in_progress" ]; then
  pass "AC4g: the ambient-global-config close leaves the bead open"
else fail "AC4g silenced-global: the bead was closed despite an uncommitted Delivers path"; fi

# --- 4h (ac-fy8s, the complement): a COMMITTED-CLEAN Delivers path must still close under
# the same silencing config — the fix must force the listing, never force a refusal. Without
# this case a "fix" that refused everything would pass 4f/4g and break every honest close.
R="$(mk_git_green uncommitted-silenced-clean 'skills/demo/artifact.txt')"
printf 'artifact v1\n' >"$R/skills/demo/artifact.txt"
git_commit_clean "$R"                                              # the artifact IS committed
git -C "$R" config status.showUntrackedFiles no
out="$(gate "$R" --reason "shipped: the artifact landed. Delivered: skills/demo/artifact.txt")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && printf '%s' "$out" | grep -q 'UNCOMMITTED ok'; then
  pass "AC4h: a committed-clean Delivers path still closes under the silencing config — the fix forces the listing, not a refusal"
else fail "AC4h silenced-clean: rc=$GATE_RC out=$out"; fi

# --- 4i (ac-jdkb): INDEX STATE silences the status leg. `git update-index --assume-unchanged`
# tells git to skip the working-tree file when computing status, so a MODIFIED Delivers path
# prints nothing and a status-derived verdict certifies a delivery no commit carries. The
# index flag is local and silent; the verdict must rest on a content comparison the index
# cannot silence — git hash-object <path> against git rev-parse HEAD:<path>.
R="$(mk_git_green uncommitted-assume-unchanged 'skills/demo/artifact.txt')"
printf 'artifact v1\n' >"$R/skills/demo/artifact.txt"
git_commit_clean "$R"                                              # artifact v1 IS committed
printf 'artifact v2 — modified, hidden by the index\n' >"$R/skills/demo/artifact.txt"
git -C "$R" update-index --assume-unchanged skills/demo/artifact.txt
if [ -z "$(git -C "$R" status --porcelain --untracked-files=all -- skills/demo/artifact.txt)" ]; then
  pass "AC4i: fixture precondition — --assume-unchanged really silences git status for the path"
else fail "AC4i precondition: the assume-unchanged flag did not silence git status"; fi
out="$(gate "$R" --reason "shipped: the artifact landed. Delivered: skills/demo/artifact.txt")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'CLOSE-REFUSED: UNCOMMITTED'; then
  pass "AC4i: a modified Delivers path refuses even when update-index --assume-unchanged silences git status"
else fail "AC4i assume-unchanged: rc=$GATE_RC out=$out"; fi
if [ "$(jq -r .status "$R/.br/$BEAD.json")" = "in_progress" ]; then
  pass "AC4i: the assume-unchanged close leaves the bead open"
else fail "AC4i assume-unchanged: the bead was closed despite a hidden modification"; fi

# --- 4j (ac-jdkb): the same bypass through the sibling index flag, `--skip-worktree`. A
# distinct bit with the same silence, so it gets its own fixture rather than riding on 4i's.
R="$(mk_git_green uncommitted-skip-worktree 'skills/demo/artifact.txt')"
printf 'artifact v1\n' >"$R/skills/demo/artifact.txt"
git_commit_clean "$R"                                              # artifact v1 IS committed
printf 'artifact v2 — modified, hidden by skip-worktree\n' >"$R/skills/demo/artifact.txt"
git -C "$R" update-index --skip-worktree skills/demo/artifact.txt
if [ -z "$(git -C "$R" status --porcelain --untracked-files=all -- skills/demo/artifact.txt)" ]; then
  pass "AC4j: fixture precondition — --skip-worktree really silences git status for the path"
else fail "AC4j precondition: the skip-worktree flag did not silence git status"; fi
out="$(gate "$R" --reason "shipped: the artifact landed. Delivered: skills/demo/artifact.txt")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'CLOSE-REFUSED: UNCOMMITTED'; then
  pass "AC4j: a modified Delivers path refuses even when update-index --skip-worktree silences git status"
else fail "AC4j skip-worktree: rc=$GATE_RC out=$out"; fi
if [ "$(jq -r .status "$R/.br/$BEAD.json")" = "in_progress" ]; then
  pass "AC4j: the skip-worktree close leaves the bead open"
else fail "AC4j skip-worktree: the bead was closed despite a hidden modification"; fi

# --- 4k (the complement, ac-jdkb): a COMMITTED-CLEAN Delivers path carrying an index flag
# must still close — the content comparison forces the truth, never a blanket refusal. Without
# this case a "fix" that refused every index-flagged path would pass 4i/4j and break honest
# closes on a checkout that legitimately carries assume-unchanged bits.
R="$(mk_git_green uncommitted-index-flag-clean 'skills/demo/artifact.txt')"
printf 'artifact v1\n' >"$R/skills/demo/artifact.txt"
git_commit_clean "$R"                                              # the artifact IS committed
git -C "$R" update-index --assume-unchanged skills/demo/artifact.txt
out="$(gate "$R" --reason "shipped: the artifact landed. Delivered: skills/demo/artifact.txt")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && printf '%s' "$out" | grep -q 'UNCOMMITTED ok'; then
  pass "AC4k: a committed-clean Delivers path with an index flag still closes — content comparison, never a blanket refusal"
else fail "AC4k index-flag-clean: rc=$GATE_RC out=$out"; fi

# --- 4l (ac-jdkb, the symlink branch's complement): a committed-clean SYMLINKED Delivers path
# must still close. `git hash-object <path>` dereferences a symlink, so a naive content
# comparison would compare the target's bytes against the link's blob and refuse every honest
# symlink; the gate hashes the link's own target string instead.
R="$(mk_git_green uncommitted-symlink-clean 'skills/demo/artifact.txt')"
printf 'artifact v1\n' >"$R/skills/demo/artifact.real"
ln -s artifact.real "$R/skills/demo/artifact.txt"
git_commit_clean "$R"
out="$(gate "$R" --reason "shipped: the artifact landed. Delivered: skills/demo/artifact.txt")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && printf '%s' "$out" | grep -q 'UNCOMMITTED ok'; then
  pass "AC4l: a committed-clean symlinked Delivers path still closes — the comparison hashes the link, never its target's bytes"
else fail "AC4l symlink-clean: rc=$GATE_RC out=$out"; fi

# --- 4m (ac-jdkb): the symlink branch still refuses a link whose TARGET STRING changed under
# an index flag — --assume-unchanged silences status for a symlink exactly as for a file.
R="$(mk_git_green uncommitted-symlink-assume-unchanged 'skills/demo/artifact.txt')"
printf 'artifact v1\n' >"$R/skills/demo/artifact.real"
printf 'artifact v2\n' >"$R/skills/demo/artifact.real2"
ln -s artifact.real "$R/skills/demo/artifact.txt"
git_commit_clean "$R"
ln -sfn artifact.real2 "$R/skills/demo/artifact.txt"
git -C "$R" update-index --assume-unchanged skills/demo/artifact.txt
if [ -z "$(git -C "$R" status --porcelain --untracked-files=all -- skills/demo/artifact.txt)" ]; then
  pass "AC4m: fixture precondition — --assume-unchanged really silences git status for the symlink"
else fail "AC4m precondition: the index flag did not silence git status for the symlink"; fi
out="$(gate "$R" --reason "shipped: the artifact landed. Delivered: skills/demo/artifact.txt")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'CLOSE-REFUSED: UNCOMMITTED'; then
  pass "AC4m: a retargeted symlinked Delivers path refuses even when --assume-unchanged silences git status"
else fail "AC4m symlink assume-unchanged: rc=$GATE_RC out=$out"; fi

# ============================================================================================
# AC 4n..4q (ac-pa51) — the extraction and the content verdict both failed OPEN. Four
# fixtures, one per conviction: a root-level delivery the old slash-REQUIRED pattern dropped;
# a `+`-bearing delivery the old class stopped at; a HEAD-tracked delivery DELETED from the
# tree that the old `[ -e ] || continue` prefilter skipped; and a required clean filter whose
# missing process made `git hash-object` print NOTHING, which the old `[ -n "$wt_blob" ]`
# guard read as "no difference" and handed to the index-silenced status leg.
# ============================================================================================

# --- 4n: a ROOT-LEVEL untracked Delivers path refuses. `artifact.txt` has no slash, so the
# old `(/…)+` group extracted nothing, the UNCOMMITTED leg never saw it, and the close LANDED
# over a file that exists in no commit.
R="$(mk_git_green uncommitted-root-level 'artifact.txt')"
git_commit_clean "$R"
printf 'artifact v1\n' >"$R/artifact.txt"                       # on disk, never added -> ??
out="$(gate "$R" --reason "shipped: the artifact landed. Delivered: artifact.txt")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'CLOSE-REFUSED: UNCOMMITTED' \
   && printf '%s' "$out" | grep -q 'artifact.txt'; then
  pass "AC4n: a ROOT-LEVEL untracked Delivers path is extracted and refuses"
else fail "AC4n root-level: rc=$GATE_RC out=$out"; fi
if [ "$(jq -r .status "$R/.br/$BEAD.json")" = "in_progress" ]; then
  pass "AC4n: the root-level refusal leaves the bead open"
else fail "AC4n root-level: the bead was closed despite an untracked root-level path"; fi

# --- 4o: a `+`-bearing untracked Delivers path refuses. The old character class stopped the
# match at the `+`, so `skills/demo/pl+us.txt` extracted to nothing and the close LANDED.
R="$(mk_git_green uncommitted-plus-bearing 'skills/demo/pl+us.txt')"
git_commit_clean "$R"
printf 'artifact v1\n' >"$R/skills/demo/pl+us.txt"             # on disk, never added -> ??
out="$(gate "$R" --reason "shipped: the artifact landed. Delivered: skills/demo/pl+us.txt")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'CLOSE-REFUSED: UNCOMMITTED' \
   && printf '%s' "$out" | grep -qF 'skills/demo/pl+us.txt'; then
  pass "AC4o: a +-bearing untracked Delivers path is extracted and refuses"
else fail "AC4o pl+us: rc=$GATE_RC out=$out"; fi

# --- 4p: a HEAD-tracked Delivers path DELETED from the tree refuses. The old
# `[ -e "$dp" ] || continue` prefilter skipped the path entirely, so the one state the leg
# exists to catch was the one state it could not see, and the close LANDED while the artifact
# was gone (round-1 existence-guard-skips-deletion).
R="$(mk_git_green uncommitted-deleted-tracked 'skills/demo/artifact.txt')"
printf 'artifact v1\n' >"$R/skills/demo/artifact.txt"
git_commit_clean "$R"                                          # artifact v1 IS committed
rm -f "$R/skills/demo/artifact.txt"                            # ...then deleted from the tree
if [ -n "$(git -C "$R" status --porcelain --untracked-files=all -- skills/demo/artifact.txt)" ]; then
  pass "AC4p: fixture precondition — the deletion is visible to git status, so only the gate's verdict is in question"
else fail "AC4p precondition: git status did not report the deleted tracked path"; fi
out="$(gate "$R" --reason "shipped: the artifact landed. Delivered: skills/demo/artifact.txt")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'CLOSE-REFUSED: UNCOMMITTED'; then
  pass "AC4p: a HEAD-tracked Delivers path DELETED from the tree refuses (the [ -e ] prefilter no longer skips it)"
else fail "AC4p deleted-tracked: rc=$GATE_RC out=$out"; fi

# --- 4q: the CONTENT verdict FAILS CLOSED. A required clean filter whose process is missing
# (the path carries `filter=f`, filter.f.required=true, and the filter binary does not exist)
# makes `git hash-object` exit non-zero and print NOTHING. The old `[ -n "$wt_blob" ] &&` guard
# read that empty string as "no difference" and fell to the status leg; `--assume-unchanged`
# silences status, so unreadable content decided the verdict and the close LANDED.
R="$(mk_git_green uncommitted-filter-broken 'skills/demo/artifact.txt')"
printf 'artifact v1\n' >"$R/skills/demo/artifact.txt"
printf 'skills/demo/artifact.txt filter=f\n' >"$R/.gitattributes"
git_commit_clean "$R"                                          # artifact v1 IS committed
git -C "$R" config filter.f.clean 'missing-filter-process'
git -C "$R" config filter.f.required true
printf 'artifact v2 — modified behind a broken clean filter\n' >"$R/skills/demo/artifact.txt"
git -C "$R" update-index --assume-unchanged skills/demo/artifact.txt
if [ -z "$(git -C "$R" status --porcelain --untracked-files=all -- skills/demo/artifact.txt)" ]; then
  pass "AC4q: fixture precondition — the index flag silences git status, so only the content verdict can decide"
else fail "AC4q precondition: the assume-unchanged flag did not silence git status"; fi
out="$(gate "$R" --reason "shipped: the artifact landed. Delivered: skills/demo/artifact.txt")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'CLOSE-REFUSED: UNCOMMITTED'; then
  pass "AC4q: a broken required clean filter yields REFUSAL, never a silent status fallback"
else fail "AC4q filter: rc=$GATE_RC out=$out"; fi
if [ "$(jq -r .status "$R/.br/$BEAD.json")" = "in_progress" ]; then
  pass "AC4q: the broken-filter refusal leaves the bead open"
else fail "AC4q filter: the bead was closed despite unreadable content"; fi

# --- 4r (ac-y4c6): the extension group was LENGTH-CAPPED at six characters, so a native-app
# delivery extracted TRUNCATED — `project.pbxproj` became `project.pbxpro`, a token no commit
# carries. Neither leg could then see the real path: the content comparison finds no
# `HEAD:native/project.pbxproj`, and the status leg reports nothing for a path nobody named, so
# an UNTRACKED pbxproj closed clean. The fixture pins the full path extracting and refusing.
# 4s is the negative pole — the same extension with the file committed must still close, so a
# "fix" that simply refused every long-extension path cannot pass 4r.
LONG_EXT_PATH='native/project.pbxproj'
R="$(mk_git_green uncommitted-long-extension "$LONG_EXT_PATH")"
git_commit_clean "$R"
printf '// pbxproj v1\n' >"$R/$LONG_EXT_PATH"                       # on disk, never added -> ??
out="$(gate "$R" --reason "shipped: the project landed. Delivered: $LONG_EXT_PATH")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'CLOSE-REFUSED: UNCOMMITTED' \
   && printf '%s' "$out" | grep -qF "$LONG_EXT_PATH"; then
  pass "AC4r: a >6-char-extension (pbxproj) Delivers path is extracted whole and refuses untracked"
else fail "AC4r pbxproj: rc=$GATE_RC out=$out"; fi
if [ "$(jq -r .status "$R/.br/$BEAD.json")" = "in_progress" ]; then
  pass "AC4r: the long-extension refusal leaves the bead open"
else fail "AC4r pbxproj: the bead was closed despite an untracked long-extension path"; fi

# --- 4s: the negative pole — a COMMITTED-CLEAN >6-char-extension Delivers path still closes.
R="$(mk_git_green uncommitted-long-extension-clean "$LONG_EXT_PATH")"
printf '// pbxproj v1\n' >"$R/$LONG_EXT_PATH"
git_commit_clean "$R"                                              # the pbxproj IS committed
out="$(gate "$R" --reason "shipped: the project landed. Delivered: $LONG_EXT_PATH")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && printf '%s' "$out" | grep -q 'UNCOMMITTED ok'; then
  pass "AC4s: a committed-clean pbxproj Delivers path still closes — the fix admits the path, it does not refuse it"
else fail "AC4s pbxproj-clean: rc=$GATE_RC out=$out"; fi

# ============================================================================================
# AC 5 — ownership immediately before the write, and the close verified as LANDED
# ============================================================================================
R="$(mk_green own-not-inprogress)"; board "$R" open ""
out="$(gate "$R" --reason "$REASON")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'OWNERSHIP'; then
  pass "AC5: a bead that is not in_progress at the write is refused, naming OWNERSHIP"
else fail "AC5 status: rc=$GATE_RC out=$out"; fi

R="$(mk_green own-stolen)"; board "$R" in_progress someone-else
out="$(gate "$R" --reason "$REASON" --actor me)"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'OWNERSHIP'; then
  pass "AC5: a bead reassigned to another actor is refused, naming OWNERSHIP"
else fail "AC5 assignee: rc=$GATE_RC out=$out"; fi

R="$(mk_green own-silent-close)"
out="$(AC2_TEST_BR_CLOSE_NOOP=1 gate "$R" --reason "$REASON")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'LANDING'; then
  pass "AC5: a close that silently did not land is caught by reading it back, naming LANDING"
else fail "AC5 landing: rc=$GATE_RC out=$out"; fi

# --- READ: show refused → NOT-CHECKED (ac-8n94). The fixture board stays intact so the
# failure is the br_field show --json read, not a missing bead file. A refused read is
# never a pass, and no status is fabricated.
R="$(mk_green read-show-refused)"
out="$(AC2_TEST_BR_SHOW_FAIL=1 gate "$R" --reason "$REASON")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 2 ] && printf '%s' "$out" | grep -q 'NOT-CHECKED'; then
  pass "AC5: show refused is NOT-CHECKED (exit 2) — a refused read is never a pass"
else fail "AC5 show refused: rc=$GATE_RC out=$out"; fi
if [ "$(jq -r .status "$R/.br/$BEAD.json")" = "in_progress" ]; then
  pass "AC5: a refused show leaves the bead open — no status is fabricated"
else fail "AC5 show refused: the bead was closed despite the refused read"; fi
if [ -f "$R/.br/$BEAD.json" ]; then
  pass "AC5: the fixture board stayed intact — the refusal is the read, not a missing file"
else fail "AC5 show refused: the fixture board was removed"; fi

R="$(mk_green own-happy)"
out="$(gate "$R" --reason "$REASON" --actor worker)"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && [ "$(jq -r .status "$R/.br/$BEAD.json")" = "closed" ]; then
  pass "AC5: the happy path re-asserts ownership, writes, and reads the close back as landed"
else fail "AC5 happy: rc=$GATE_RC status=$(jq -r .status "$R/.br/$BEAD.json") out=$out"; fi
if [ -f "$R/.br/comments.log" ] && grep -q '^GATE: receipt' "$R/.br/comments.log"; then
  pass "AC-receipt: an ordinary receipt close records GATE: receipt on landing, written atomically via --transition-comment"
else fail "AC-receipt: no GATE: receipt landing record"; fi

R="$(mk_green own-dry-run)"
out="$(gate "$R" --reason "$REASON" --dry-run)"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && [ "$(jq -r .status "$R/.br/$BEAD.json")" = "in_progress" ]; then
  pass "AC5: --dry-run verifies every leg without writing"
else fail "AC5 dry-run: rc=$GATE_RC status=$(jq -r .status "$R/.br/$BEAD.json")"; fi

if grep -q 'in_progress' "$GATE"; then
  pass "AC5: the gate names the in_progress ownership it re-asserts"
else fail "AC5: the gate never checks in_progress"; fi

# ============================================================================================
# AC 6 — the evidence core is ac-on0y.2's, not a private reimplementation
# ============================================================================================
R="$(mk_green evidence-refuse)"
out="$(gate "$R" --reason "shipped: some words that name no declared artifact at all")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'EVIDENCE'; then
  pass "AC6: a reason naming none of the bead's Delivers artifacts is refused, naming EVIDENCE"
else fail "AC6 refuse: rc=$GATE_RC out=$out"; fi

# SEAM PROOF: the gate must DEPEND on the core, not merely mention it. Remove the core and
# the gate must go NOT-CHECKED — a gate that sails on without its evidence core has grown a
# private one, which is exactly what this AC forbids.
R="$(mk_green evidence-seam)"
rm -f "$R/skills/ac-pipeline/scripts/close-evidence-check.sh"
out="$(gate "$R" --reason "$REASON")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 2 ] && printf '%s' "$out" | grep -q 'EVIDENCE'; then
  pass "AC6: with the evidence core removed the gate goes NOT-CHECKED — it really delegates"
else fail "AC6 seam: rc=$GATE_RC out=$out"; fi

if grep -q 'close-evidence-check' "$GATE"; then
  pass "AC6: the gate calls close-evidence-check by name"
else fail "AC6: the gate does not reference close-evidence-check"; fi

# ============================================================================================
# AC 7 — the assurance declaration at birth
# ============================================================================================
miss=""
for f in "PROBE:" "SCHEDULE:" "MODE:" "ON-FAILURE:"; do
  grep -q "$f" "$GATE" || miss="$miss $f"
done
if [ -z "$miss" ]; then pass "AC7: 4-field assurance declaration present"
else fail "AC7: assurance declaration missing:$miss"; fi

echo "---"
echo "close-gate.test.sh: $CASES case(s), $FAILURES failure(s)"
# ac-close-gate-coverage-silent-probe-ja8l's RED probe greps this output for 'passed' — it
# must therefore appear ONLY when the run is all-green, never as part of a failure count.
[ "$FAILURES" -eq 0 ] && echo "close-gate.test.sh: all $CASES case(s) passed"
[ "$FAILURES" -eq 0 ]
