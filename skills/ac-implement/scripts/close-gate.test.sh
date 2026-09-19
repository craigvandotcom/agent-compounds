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
# author's belief about that contract rather than the contract. `br` and `ubs` ARE mocked —
# they are the outside world, and the gate's own seams for them are what we drive.
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
      cfile="$STATE/$id.comments.json"
      [ -f "$cfile" ] || echo '[]' >"$cfile"
      jq --arg t "$tc" '. + [{"author":"mock","created_at":"2026-01-01T00:00:00Z","text":$t}]' \
        "$cfile" >"$cfile.tmp" 2>/dev/null && mv "$cfile.tmp" "$cfile"
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
    cfile="$STATE/$cid.comments.json"
    [ -f "$cfile" ] || echo '[]' >"$cfile"
    jq --arg t "$body" '. + [{"author":"mock","created_at":"2026-01-01T00:00:00Z","text":$t}]' \
      "$cfile" >"$cfile.tmp" 2>/dev/null && mv "$cfile.tmp" "$cfile"
    exit 0 ;;
  *) exit 0 ;;
esac
MOCKBR
chmod +x "$MOCK_BIN/br"

# Mock `ubs` — modes drive the scanner leg's outcomes, including ac-x9dy's
# finding-less exit-1 (js tool-side noise) versus exit-1-with-findings.
cat >"$MOCK_BIN/ubs" <<'MOCKUBS'
#!/usr/bin/env bash
n=$#
case "${AC2_TEST_UBS_MODE:-clean}" in
  clean)    echo "UBS Meta-Runner"; echo "Files scanned: $n"; echo "Summary: 12 categories checked"; exit 0 ;;
  short)    echo "UBS Meta-Runner"; echo "Files scanned: 1"; echo "Summary: 12 categories checked"; exit 0 ;;
  nolang)   echo "no supported languages detected in ."; echo "UBS did not run any scanner: nothing was checked (this is NOT a pass)"; exit 0 ;;
  findings) echo "UBS Meta-Runner"; echo "Files scanned: $n"
            echo "   subject.txt:12:3  possible defect here"
            echo "Summary: 12 categories checked"; exit 0 ;;
  nocount)  echo "UBS Meta-Runner"; echo "Summary: 12 categories checked"; exit 0 ;;
  exit1-clean) echo "UBS Meta-Runner"; echo "Files scanned: $n"
            echo "Files: $n"; echo "Critical: 0"; echo "Warning: 0"; echo "Info: 0"; exit 1 ;;
  exit1-findings) echo "UBS Meta-Runner"; echo "Files scanned: $n"
            echo "   subject.txt:12:3  possible defect here"
            echo "Files: $n"; echo "Critical: 1"; echo "Warning: 0"; echo "Info: 0"; exit 1 ;;
  exit1-summary) echo "UBS Meta-Runner"; echo "Files scanned: $n"
            echo "   Location: /tmp/x.py:2:11"
            echo "Files: $n"; echo "Critical: 2"; echo "Warning: 1"; echo "Info: 1"; exit 1 ;;
  captured) # A FIXED transcript captured from a real `ubs` run in this repo (2026-09-19,
            # /tmp/ubs_probe.py) — absolute paths, docs.astral.sh/cwe.mitre.org permalinks and
            # bandit's `Location:` shape (which the DETAIL regex misses; only the Combined
            # Summary counters corroborate it). Replaces the old procedural `content` mode
            # (ac-4y7l.24): LEG 6 no longer diffs against a baseline tree, so a per-line
            # rule+text generator has nothing left to feed.
            echo "UBS Meta-Runner v5.4.2  2026-09-19 23:32:28"
            echo "Project: /home/craigvandotcom/mission/software/agent-compounds"
            echo "Detected: python"
            echo "Scanning python..."
            echo ""
            echo "──────── python ────────"
            echo ">> Issue: [B602:subprocess_popen_with_shell_equals_true] subprocess call with shell=True identified, security issue."
            echo "   CWE: CWE-78 (https://cwe.mitre.org/data/definitions/78.html)"
            echo "   More Info: https://bandit.readthedocs.io/en/1.9.4/plugins/b602_subprocess_popen_with_shell_equals_true.html"
            echo "   Location: /tmp/ubs_probe.py:5:4"
            echo "6. ERROR HANDLING ANTI-PATTERNS"
            echo "[critical] Bare except — except: (1 found) — py.error-handling.bare-except"
            echo "    /tmp/ubs_probe.py:12  Bare except — except:"
            echo "7. SECURITY VULNERABILITIES"
            echo "[critical] Insecure pickle usage — return pickle.loads(data) (1 found) — py.security.pickle-usage"
            echo "    /tmp/ubs_probe.py:8  Insecure pickle usage — return pickle.loads(data)"
            echo "[warning] Subprocess call has no bounded timeout — subprocess.call(cmd, shell=True) (1 found) — py.security.subprocess-timeout"
            echo "    /tmp/ubs_probe.py:5  Subprocess call has no bounded timeout — subprocess.call(cmd, shell=True)"
            echo ""
            echo "Summary Statistics:"
            echo "Files scanned: $n"
            echo "Critical issues: 5"; echo "Warning issues: 1"; echo "Info items: 3"
            echo ""
            echo "──────── Combined Summary ────────"
            echo "Files: $n"; echo "Critical: 5"; echo "Warning: 1"; echo "Info: 3"
            exit 0 ;;
  captured-info) # A FIXED info-only transcript in the same real-ubs shape — a capped detail
            # list (ubs's own "N more not shown" quirk) and no Critical/Warning at all, so
            # LEG 6 must report it without refusing.
            echo "UBS Meta-Runner v5.4.2  2026-09-19 23:32:11"
            echo "Project: /home/craigvandotcom/mission/software/agent-compounds"
            echo "Detected: bash"
            echo "Scanning bash..."
            echo ""
            echo "──────── bash ────────"
            echo "UBS module: Bash (contract v2) — /tmp/ubs-probe.sh"
            echo "4. DEFENSIVE PROGRAMMING & ROBUSTNESS"
            echo "[info] Unquoted variable expansion — rm -rf \$2 (2 found, showing 1) — sh.style.unquoted-var"
            echo "    /tmp/ubs-probe.sh:3  Unquoted variable expansion — rm -rf \$2"
            echo "    ... 1 more finding capped (see full report)"
            echo ""
            echo "Summary Statistics:"
            echo "Files scanned: $n"
            echo "Critical issues: 0"; echo "Warning issues: 0"; echo "Info items: 2"
            echo ""
            echo "──────── Combined Summary ────────"
            echo "Files: $n"; echo "Critical: 0"; echo "Warning: 0"; echo "Info: 2"
            exit 0 ;;
esac
MOCKUBS
chmod +x "$MOCK_BIN/ubs"

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
# `humans:` key is the ruling matcher's live authority (ac-4y7l.25); "Craig" is this
# fixture's authorized name.
mkcase_decision() {
  local root="$WORKDIR/$1"
  mkdir -p "$root/skills/ac-pipeline/scripts" "$root/skills/_tools" "$root/.flight" "$root/.br" "$root/.beads"
  cp "$EVIDENCE_SRC" "$root/skills/ac-pipeline/scripts/close-evidence-check.sh"
  cp "$BR_CALL_SRC" "$root/skills/_tools/br-call.sh"
  chmod +x "$root/skills/ac-pipeline/scripts/close-evidence-check.sh"
  printf 'humans: Craig, Craig van Heerden\n' >"$root/.beads/config.yaml"
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
      AC2_TEST_UBS_MODE="${AC2_TEST_UBS_MODE:-clean}" \
      bash "$GATE" "$BEAD" --body-file "$root/body.md" --root "$root" "$@" 2>&1
    echo $? > "$RCFILE" )
}

REASON="shipped: the subject now carries FIXED. Delivered: subject.txt, harness.test.sh"

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
add_ruling "$R" "DECISION (Craig): option A — because it is cheaper"
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
  DECISION (Craig): draft — not final yet
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
add_ruling "$R" "DECISION (Craig): option B — overriding the agent's earlier call"
out="$(gate "$R" --reason "decided: option B, per Craig's later ruling")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && printf '%s' "$out" | grep -qi 'ruling'; then
  pass "AC-ruling: the newest authorized ruling wins — a later human ruling is not blocked by an earlier unauthorized agent line"
else fail "AC-ruling agent-then-human: rc=$GATE_RC out=$out"; fi

R="$(mkcase_decision ruling-two-humans)"
board_decision "$R" open ""
add_ruling "$R" "DECISION (Craig): option A — the first call"
add_ruling "$R" "DECISION (Craig): option B — changed my mind, this one"
out="$(gate "$R" --reason "decided: option B, the newer human ruling")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && [ -f "$R/.br/comments.log" ] && grep -q 'option B' "$R/.br/comments.log"; then
  pass "AC-ruling: the newest authorized ruling wins — with two human rulings the newer one is what lands, never the first grep hit"
else fail "AC-ruling two-humans: rc=$GATE_RC out=$out"; fi

R="$(mkcase_decision ruling-multiword-name)"
board_decision "$R" open ""
add_ruling "$R" "DECISION (Craig van Heerden): option A — signed with the full name on the humans: key"
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
add_ruling "$R" "DECISION (Craig): option A — because it is cheaper"
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
# AC 4 — the scanner leg
# ============================================================================================
mk_green() { # a fixture standing at the moment of a legitimate close
  local r; r="$(mkcase "$1")"; write_harness "$r"; board "$r" in_progress worker
  fly "$r"; fix_subject "$r"; echo "$r"
}

R="$(mk_green scan-short)"
out="$(AC2_TEST_UBS_MODE=short gate "$R" --reason "$REASON" --scan subject.txt harness.test.sh)"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 2 ] && printf '%s' "$out" | grep -q 'NOT-CHECKED'; then
  pass "AC4: scanned < handed is NOT-CHECKED with exit 2, not a pass"
else fail "AC4 shortfall: rc=$GATE_RC out=$out"; fi

R="$(mk_green scan-nolang)"
out="$(AC2_TEST_UBS_MODE=nolang gate "$R" --reason "$REASON" --scan subject.txt harness.test.sh)"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 2 ] && printf '%s' "$out" | grep -q 'NOT-CHECKED'; then
  pass "AC4: 'nothing was checked' is NOT-CHECKED with exit 2"
else fail "AC4 nolang: rc=$GATE_RC out=$out"; fi

R="$(mk_green scan-nocount)"
out="$(AC2_TEST_UBS_MODE=nocount gate "$R" --reason "$REASON" --scan subject.txt harness.test.sh)"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 2 ]; then
  pass "AC4: no scanned-count printed is NOT-CHECKED — coverage is unassertable"
else fail "AC4 nocount: rc=$GATE_RC out=$out"; fi

R="$(mk_green scan-findings)"
out="$(AC2_TEST_UBS_MODE=findings gate "$R" --reason "$REASON" --scan subject.txt harness.test.sh)"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && printf '%s' "$out" | grep -q 'SCANNER'; then
  pass "AC4: a DETAIL line with no Combined Summary Critical/Warning/Info counters defaults to 0 and passes — the summary's own severity counters are the verdict now (ac-4y7l.24 deletes the baseline diff), never a DETAIL line count"
else fail "AC4 findings: rc=$GATE_RC out=$out"; fi

R="$(mk_green scan-clean)"
out="$(AC2_TEST_UBS_MODE=clean gate "$R" --reason "$REASON" --scan subject.txt harness.test.sh)"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && printf '%s' "$out" | grep -q 'SCANNER'; then
  pass "AC4: scanned == handed with 0 Critical/Warning/Info passes the scanner leg"
else fail "AC4 clean: rc=$GATE_RC out=$out"; fi

R="$(mk_green scan-info-only)"
out="$(AC2_TEST_UBS_MODE=captured-info gate "$R" --reason "$REASON" --scan subject.txt harness.test.sh)"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && printf '%s' "$out" | grep -qi 'Info finding'; then
  pass "AC4c: Info findings are reported in the gate's own output and never refuse the close — only Critical or Warning do"
else fail "AC4c info-only: rc=$GATE_RC out=$out"; fi

R="$(mk_green scan-exit1-clean)"
out="$(AC2_TEST_UBS_MODE=exit1-clean gate "$R" --reason "$REASON" --scan subject.txt harness.test.sh)"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && printf '%s' "$out" | grep -q 'SCANNER'; then
  pass "AC4: finding-less exit-1 passes — the verdict is the finding count, never the exit code alone (ac-x9dy)"
else fail "AC4 exit1-clean: rc=$GATE_RC out=$out"; fi

R="$(mk_green scan-exit1-findings)"
out="$(AC2_TEST_UBS_MODE=exit1-findings gate "$R" --reason "$REASON" --scan subject.txt harness.test.sh)"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -ne 0 ] && printf '%s' "$out" | grep -q 'SCANNER'; then
  pass "AC4: exit-1-with-findings still refuses (ac-x9dy)"
else fail "AC4 exit1-findings: rc=$GATE_RC out=$out"; fi

R="$(mk_green scan-exit1-summary)"
out="$(AC2_TEST_UBS_MODE=exit1-summary gate "$R" --reason "$REASON" --scan subject.txt harness.test.sh)"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -ne 0 ] && printf '%s' "$out" | grep -q 'SCANNER'; then
  pass "AC4: exit-1 with summary-only findings refuses — the Combined Summary corroborates where DETAIL misses (ac-x9dy python shape)"
else fail "AC4 exit1-summary: rc=$GATE_RC out=$out"; fi

R="$(mk_green scan-captured-critical)"
out="$(AC2_TEST_UBS_MODE=captured gate "$R" --reason "$REASON" --scan subject.txt harness.test.sh)"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -ne 0 ] && printf '%s' "$out" | grep -q 'CLOSE-REFUSED: SCANNER'; then
  pass "AC4: a real captured ubs transcript (absolute paths, permalinks) with Critical+Warning findings refuses with the unchanged CLOSE-REFUSED: SCANNER token"
else fail "AC4 captured-critical: rc=$GATE_RC out=$out"; fi

R="$(mk_green scan-empty-argv)"
out="$(gate "$R" --reason "$REASON")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && printf '%s' "$out" | grep -qi 'SCANNER skipped'; then
  pass "AC4: on empty argv the scanner leg reports a SKIP and never implies clean"
else fail "AC4 empty argv: rc=$GATE_RC out=$out"; fi

if grep -q 'NOT-CHECKED' "$GATE"; then
  pass "AC4: the gate carries the NOT-CHECKED verdict"
else fail "AC4: the gate never emits NOT-CHECKED"; fi

# ============================================================================================
# AC-scanner-ruling — a refused SCANNER leg still closes when the bead carries an authorized
# human ruling accepting the findings, via find_authorized_ruling(), the SAME matcher the
# type-routed ruling path above uses (ac-4y7l.24, superseding ac-4y7l.23's baseline diff).
# ============================================================================================
mk_green_ruled() { # a legitimate-close fixture that also carries .beads/config.yaml, so a
                    # "DECISION (Craig): ..." comment can be authorized (humans: Craig)
  local r; r="$(mk_green "$1")"
  mkdir -p "$r/.beads"
  printf 'humans: Craig\n' >"$r/.beads/config.yaml"
  echo "$r"
}

R="$(mk_green_ruled scan-ruling-override)"
add_ruling "$R" "DECISION (Craig): accept the scanner findings — ship now, follow-up separately"
out="$(AC2_TEST_UBS_MODE=captured gate "$R" --reason "$REASON" --scan subject.txt harness.test.sh)"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && printf '%s' "$out" | grep -qi 'ruling'; then
  pass "AC-scanner-ruling: an authorized human ruling overrides a scanner refusal — the close lands despite Critical+Warning findings"
else fail "AC-scanner-ruling override: rc=$GATE_RC out=$out"; fi
if [ "$(jq -r .status "$R/.br/$BEAD.json")" = "closed" ]; then
  pass "AC-scanner-ruling: the ruling-overridden close landed"
else fail "AC-scanner-ruling: the close did not land despite the ruling"; fi
if [ -f "$R/.br/comments.log" ] && grep -qi 'scanner ruling' "$R/.br/comments.log"; then
  pass "AC-scanner-ruling: the landing record names the ruling that overrode the scanner refusal"
else fail "AC-scanner-ruling: the landing record does not mention the scanner ruling"; fi

# The same findings, but no ruling recorded at all — the refusal stands, unchanged token.
R="$(mk_green_ruled scan-ruling-absent)"
out="$(AC2_TEST_UBS_MODE=captured gate "$R" --reason "$REASON" --scan subject.txt harness.test.sh)"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -ne 0 ] && printf '%s' "$out" | grep -q 'CLOSE-REFUSED: SCANNER'; then
  pass "AC-scanner-ruling: with no recorded ruling, Critical+Warning findings still refuse the close"
else fail "AC-scanner-ruling absent: rc=$GATE_RC out=$out"; fi
if [ "$(jq -r .status "$R/.br/$BEAD.json")" = "in_progress" ]; then
  pass "AC-scanner-ruling: the unruled refusal leaves the bead unclosed"
else fail "AC-scanner-ruling absent: the bead was closed despite no ruling"; fi

# An unauthorized ruling (an agent, not a human on Humans who rule:) does not override either.
R="$(mk_green_ruled scan-ruling-unauthorized)"
add_ruling "$R" "DECISION (agent): accept the findings — not a human on the list"
out="$(AC2_TEST_UBS_MODE=captured gate "$R" --reason "$REASON" --scan subject.txt harness.test.sh)"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -ne 0 ] && printf '%s' "$out" | grep -q 'CLOSE-REFUSED: SCANNER'; then
  pass "AC-scanner-ruling: an unauthorized DECISION comment does not override a scanner refusal"
else fail "AC-scanner-ruling unauthorized: rc=$GATE_RC out=$out"; fi

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
