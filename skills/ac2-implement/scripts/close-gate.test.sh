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

# Mock `br` — a file-backed board. `show` emits the bead, `close` flips status to closed
# unless AC2_TEST_BR_CLOSE_NOOP=1, which is how the silent-close-failure case is driven.
cat >"$MOCK_BIN/br" <<'MOCKBR'
#!/usr/bin/env bash
STATE="${AC2_TEST_BR_STATE:-/nonexistent}"
cmd="${1:-}"; shift 2>/dev/null || true
id=""
for a in "$@"; do case "$a" in --*) ;; -*) ;; *) [ -z "$id" ] && id="$a" ;; esac; done
case "$cmd" in
  show)
    [ -f "$STATE/$id.json" ] || exit 1
    cat "$STATE/$id.json" ;;
  close)
    [ -f "$STATE/$id.json" ] || exit 1
    [ "${AC2_TEST_BR_CLOSE_NOOP:-0}" = "1" ] && exit 0
    jq '.status = "closed"' "$STATE/$id.json" >"$STATE/$id.json.tmp" && mv "$STATE/$id.json.tmp" "$STATE/$id.json" ;;
  *) exit 0 ;;
esac
MOCKBR
chmod +x "$MOCK_BIN/br"

# Mock `ubs` — modes drive the scanner leg's four outcomes.
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
esac
MOCKUBS
chmod +x "$MOCK_BIN/ubs"

BEAD="ac-test.1"

# A fixture bead: two ACs (one already green, one RED-able), a Delivers section the
# evidence core can cross-reference, and no Consumes.
mkcase() {
  local root="$WORKDIR/$1"
  mkdir -p "$root/skills/ac-pipeline/scripts" "$root/.flight" "$root/.br"
  cp "$EVIDENCE_SRC" "$root/skills/ac-pipeline/scripts/close-evidence-check.sh"
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
  mkdir -p "$root/skills/ac-pipeline/scripts" "$root/.flight" "$root/.br"
  cp "$EVIDENCE_SRC" "$root/skills/ac-pipeline/scripts/close-evidence-check.sh"
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
      AC2_TEST_UBS_MODE="${AC2_TEST_UBS_MODE:-clean}" \
      bash "$GATE" "$BEAD" --body-file "$root/body.md" --root "$root" "$@" 2>&1
    echo $? > "$RCFILE" )
}

REASON="shipped: the subject now carries FIXED. Delivered: subject.txt, harness.test.sh"

# ============================================================================================
# AC 2 — the three refusals, each NAMING the leg that failed
# ============================================================================================

# --- 2a: no RED receipt --------------------------------------------------------------------
R="$(mkcase no-receipt)"; write_harness "$R"; board "$R" in_progress worker
fix_subject "$R"
out="$(gate "$R" --reason "$REASON")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'RED-RECEIPT'; then
  pass "AC2a: refuses a close with no RED receipt, naming RED-RECEIPT"
else fail "AC2a: rc=$GATE_RC out=$out"; fi
if [ "$(jq -r .status "$R/.br/$BEAD.json")" = "in_progress" ]; then
  pass "AC2a: a refused close leaves the bead open"
else fail "AC2a: the bead was closed despite the refusal"; fi

# --- 2b: the fingerprinted test changed since the receipt -----------------------------------
R="$(mkcase hash-drift)"; write_harness "$R"; board "$R" in_progress worker
fly "$R"                                   # RED banked over probe + harness bytes
fix_subject "$R"
printf '# an edit to the test between RED and GREEN\n' >>"$R/harness.test.sh"
out="$(gate "$R" --reason "$REASON")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'HASH-LOCK'; then
  pass "AC2b: refuses when the fingerprinted test changed since the receipt, naming HASH-LOCK"
else fail "AC2b: rc=$GATE_RC out=$out"; fi

# --- 2b': the fingerprinted test was deleted -------------------------------------------------
R="$(mkcase hash-deleted)"; write_harness "$R"; board "$R" in_progress worker
fly "$R"; fix_subject "$R"; rm -f "$R/harness.test.sh"
out="$(gate "$R" --reason "$REASON")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'HASH-LOCK'; then
  pass "AC2b': a deleted fingerprinted test is refused, naming HASH-LOCK"
else fail "AC2b': rc=$GATE_RC out=$out"; fi

# --- 2c: the probe never reported GREEN ------------------------------------------------------
R="$(mkcase never-green)"; write_harness "$R"; board "$R" in_progress worker
fly "$R"                                   # RED banked, and the subject is NEVER fixed
out="$(gate "$R" --reason "$REASON")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'GREEN'; then
  pass "AC2c: refuses a probe that never reported GREEN, naming GREEN"
else fail "AC2c: rc=$GATE_RC out=$out"; fi

# --- 2d: THE OWN-HARNESS CARVE-OUT ------------------------------------------------------------
# The bead delivers its own harness, so at claim the test does not exist and the RED is
# fingerprinted over the probe alone. Without the carve-out the hash leg would refuse every
# close in this bead set. The carve-out is not "skip the lock": it is "re-run flight-check
# once the harness exists, before any fix, and lock against THAT".
R="$(mkcase carve-out)"; board "$R" in_progress worker
fly "$R"                                   # moment (b'): harness absent -> scope: probe
if grep -q 'red-fingerprint-scope: probe$' "$R/.flight/$BEAD.flight-receipt"; then
  pass "AC2d: with no harness at claim, flight-check banks a probe-scoped RED"
else fail "AC2d: expected a probe-scoped receipt, got: $(grep red-fingerprint-scope "$R/.flight/$BEAD.flight-receipt")"; fi

write_harness "$R"; fix_subject "$R"        # harness written, fix applied, NO re-flight
out="$(gate "$R" --reason "$REASON")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'HASH-LOCK'; then
  pass "AC2d: a probe-scoped RED plus an existing harness is REFUSED — re-run flight-check first"
else fail "AC2d: the carve-out was taken as a free pass: rc=$GATE_RC out=$out"; fi

# now do it correctly: revert the fix, re-fly with the harness present, then fix
R="$(mkcase carve-out-ok)"; board "$R" in_progress worker
fly "$R"                                    # moment (b'): probe scope
write_harness "$R"
fly "$R"                                    # moment (b): harness present, still RED
if grep -q 'red-fingerprint-scope: probe+harness' "$R/.flight/$BEAD.flight-receipt"; then
  pass "AC2d: re-flying with the harness present banks a probe+harness RED"
else fail "AC2d: re-flight did not upgrade the scope"; fi
fix_subject "$R"
out="$(gate "$R" --reason "$REASON")"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ]; then
  pass "AC2d: the two-moment own-harness flow closes — the carve-out does not refuse this bead set"
else fail "AC2d: the correct own-harness flow was refused: rc=$GATE_RC out=$out"; fi
if [ "$(jq -r .status "$R/.br/$BEAD.json")" = "closed" ]; then
  pass "AC2d: and the close actually landed on the board"
else fail "AC2d: exit 0 but the bead is $(jq -r .status "$R/.br/$BEAD.json")"; fi

# --- 2e: THE PROSE PATH — scope subject-scoped (ac-hnsc) ---------------------------------------
# Before ac-hnsc the receipt folded the SUBJECT into the assertion fingerprint, so a prose bead
# moved its own fingerprint by doing the work and HASH-LOCK went NOT-CHECKED before COVERAGE
# was ever reached. The claim it makes now: the ASSERTION is locked, only the SUBJECT moves.
PROSE_REASON="shipped: doc.md now carries TOKEN. Delivered: doc.md"
R="$(mkcase_prose prose-close)"; board "$R" in_progress worker
fly "$R"                                    # RED banked over the probe COMMAND alone
if grep -q 'red-fingerprint-scope: subject-scoped' "$R/.flight/$BEAD.flight-receipt"; then
  pass "AC2e: a prose bead banks a subject-scoped RED"
else fail "AC2e: expected subject-scoped, got: $(grep red-fingerprint-scope "$R/.flight/$BEAD.flight-receipt")"; fi

printf 'TOKEN\n' >>"$R/doc.md"                # the fix IS an edit to the probe's own subject
out="$(gate "$R" --reason "$PROSE_REASON" --actor worker)"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ]; then
  pass "AC2e: a prose bead closes end-to-end — editing the subject no longer breaks the lock"
else fail "AC2e: the prose close was refused: rc=$GATE_RC out=$out"; fi
if ! printf '%s' "$out" | grep -q 'NOT-CHECKED'; then
  pass "AC2e: no leg reports NOT-CHECKED on the prose path"
else fail "AC2e: a leg went NOT-CHECKED: $out"; fi
if printf '%s' "$out" | grep -q 'temporal exit-code pair'; then
  pass "AC2e: HASH-LOCK falls through to COVERAGE, where the temporal exit-code pair is the assertion"
else fail "AC2e: COVERAGE did not use the temporal pair: $out"; fi
if [ "$(jq -r .status "$R/.br/$BEAD.json")" = "closed" ]; then
  pass "AC2e: and the prose close landed on the board"
else fail "AC2e: exit 0 but the bead is $(jq -r .status "$R/.br/$BEAD.json")"; fi

# 2e' THE GUARD: subject-scoped is not an escape hatch. A bead that grows a real harness after
# the RED was banked no longer matches the scope its receipt claims, and is refused.
R="$(mkcase_prose prose-harness-guard)"; board "$R" in_progress worker
fly "$R"
cat >>"$R/body.md" <<'EXTRA'

## Extra
- and the harness passes.
  Probe: `test -x harness.test.sh && bash harness.test.sh` — tier: none
EXTRA
write_harness "$R"; printf 'TOKEN\nFIXED\n' >>"$R/doc.md"
printf 'subject v1\nFIXED\n' >"$R/subject.txt"
board "$R" in_progress worker
out="$(gate "$R" --reason "$PROSE_REASON" --actor worker)"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 1 ] && printf '%s' "$out" | grep -q 'HASH-LOCK'; then
  pass "AC2e': a subject-scoped receipt on a bead that now runs a harness is REFUSED, naming HASH-LOCK"
else fail "AC2e' guard: rc=$GATE_RC out=$out"; fi

# 2e'' The anti-pattern remedy is GONE: the gate must never tell a prose bead to grow a shell
# harness whose only job is to re-run a grep — that is the vacuous-AC shape this pipeline kills.
if ! grep -q 'Name a test-shaped harness' "$GATE"; then
  pass "AC2e'': the gate no longer prescribes a vacuous harness as the prose remedy"
else fail "AC2e'': the vacuous-harness remedy text is still in the gate"; fi

# ============================================================================================
# AC 3 — coverage is asserted, not assumed
# ============================================================================================

# --- 3a: files-run < files-expected ------------------------------------------------------------
R="$(mkcase coverage-shortfall)"; write_harness "$R"; board "$R" in_progress worker
fly "$R"; fix_subject "$R"
cat >>"$R/body.md" <<'EXTRA'

## Extra
- a third criterion whose probe cannot run at all.
  Probe: `ac2-no-such-command-42 subject.txt` — tier: none
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
if [ "$GATE_RC" -ne 0 ] && printf '%s' "$out" | grep -q 'SCANNER'; then
  pass "AC4: DETAIL findings under a clean summary still refuse — the summary counter is not the verdict"
else fail "AC4 findings: rc=$GATE_RC out=$out"; fi

R="$(mk_green scan-clean)"
out="$(AC2_TEST_UBS_MODE=clean gate "$R" --reason "$REASON" --scan subject.txt harness.test.sh)"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && printf '%s' "$out" | grep -q 'SCANNER'; then
  pass "AC4: scanned == handed with no detail findings passes the scanner leg"
else fail "AC4 clean: rc=$GATE_RC out=$out"; fi

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

R="$(mk_green own-happy)"
out="$(gate "$R" --reason "$REASON" --actor worker)"
GATE_RC=$(cat "$RCFILE")
if [ "$GATE_RC" -eq 0 ] && [ "$(jq -r .status "$R/.br/$BEAD.json")" = "closed" ]; then
  pass "AC5: the happy path re-asserts ownership, writes, and reads the close back as landed"
else fail "AC5 happy: rc=$GATE_RC status=$(jq -r .status "$R/.br/$BEAD.json") out=$out"; fi

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
[ "$FAILURES" -eq 0 ]
