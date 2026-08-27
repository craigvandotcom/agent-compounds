#!/usr/bin/env bash
#
# close-gate.sh — the ac2 TEMPORAL causal-necessity probe at close (ac-k25c.3).
#
# ASSURANCE
#   PROBE:      bash skills/ac2-implement/scripts/close-gate.test.sh
#   SCHEDULE:   every ac2 worker close; the harness runs on every
#               scripts/run-all-harnesses.sh invocation, which lint.sh Check 20 audits.
#   MODE:       blocking
#   ON-FAILURE: closed
#
# THE CLAIM IT MAKES, AND THE ONLY ONE:
#
#   RED before the diff · the test UNCHANGED · GREEN after the diff
#   ------------------------------------------------------------------
#   therefore the diff CAUSED the flip.
#
# The RED was captured at flight-check, with its assertion fingerprint recorded BEFORE the
# diff existed. Here the same test — hash-locked since that receipt, an unchanged-test
# guarantee one checksum buys — runs GREEN. Prose and config beads take the same temporal
# shape using the AC's own grep or diff check; no separate class, no separate gate.
#
# This replaces six prose conventions a worker used to self-audit, and it structurally kills
# the vacuous-AC class: an AC that was already green at claim never got a receipt, so there
# is nothing here to close against.
#
# OUT OF SCOPE, deliberately:
#   - spatial isolation (worktrees survive only where ac2-review's destructive sabotage
#     probes need them)
#   - writing VERDICT comments — those belong to the VERIFIER, never the implementer.
#     That separation is the Goodhart guard: the party optimising against the measure does
#     not get to record the verdict.
#   - suite-level green. The local run is PER-BEAD only. Suite green is the batch CI
#     layer's verdict on the committed tree and is never a shared-tree local claim.
#
# THE OWN-HARNESS CARVE-OUT (why the hash leg does not refuse every close in this bead set):
#   A bead that DELIVERS ITS OWN HARNESS has no test at claim, so flight-check re-runs once
#   the harness is written and BEFORE any fix, and the fingerprint it records THEN is what
#   this lock runs from. One writer, one receipt format, two moments. Without the carve-out
#   the hash leg would refuse every close in this very epic, all of whose code beads deliver
#   their own harness.
#
# Usage:
#   close-gate.sh <bead-id> --reason "<close reason>" [--actor <name>]
#                 [--scan <file> …] [--vitest-json <report>]
#                 [--body-file <path>] [--root <repo>] [--dry-run]
#
# Env:
#   AC2_FLIGHT_DIR  where flight-check wrote the receipt (default <git-common-dir>/ac2-flight)
#   AC2_BR_CMD      the br binary to use (default: br) — the seam the harness drives
#
# Exit 0  the causal claim holds and the close LANDED
# Exit 1  CLOSE-REFUSED — a named leg failed; the bead stays open
# Exit 2  NOT-CHECKED — this gate could not verify. NEVER a pass: a gate that verified
#         nothing must not read as coverage.
#
set -uo pipefail

BEAD=""; REASON=""; ACTOR=""; BODY_FILE=""; ROOT=""; DRY=0; VITEST_JSON=""
SCAN_FILES=()

while [ $# -gt 0 ]; do
  case "$1" in
    --reason)      REASON="${2:-}"; shift 2 ;;
    --actor)       ACTOR="${2:-}"; shift 2 ;;
    --body-file)   BODY_FILE="${2:-}"; shift 2 ;;
    --root)        ROOT="${2:-}"; shift 2 ;;
    --vitest-json) VITEST_JSON="${2:-}"; shift 2 ;;
    --dry-run)     DRY=1; shift ;;
    --scan)        shift; while [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; do SCAN_FILES+=("$1"); shift; done ;;
    -h|--help)     sed -n '2,55p' "${BASH_SOURCE[0]}"; exit 0 ;;
    -*)            echo "NOT-CHECKED: unknown option '$1'" >&2; exit 2 ;;
    *)             [ -z "$BEAD" ] && BEAD="$1" || { echo "NOT-CHECKED: unexpected argument '$1'" >&2; exit 2; }; shift ;;
  esac
done

[ -n "$BEAD" ]   || { echo "NOT-CHECKED: usage: $0 <bead-id> --reason '<close reason>'" >&2; exit 2; }
[ -n "$REASON" ] || { echo "NOT-CHECKED: no --reason given — the evidence core has nothing to cross-reference" >&2; exit 2; }

if [ -z "$ROOT" ]; then
  ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd) || ROOT="$PWD"
fi
cd "$ROOT" || { echo "NOT-CHECKED: cannot enter repo root '$ROOT'" >&2; exit 2; }

BR="${AC2_BR_CMD:-br}"
EVIDENCE_CORE="$ROOT/skills/ac-pipeline/scripts/close-evidence-check.sh"

refuse()      { echo "CLOSE-REFUSED: $1 — refusing: $2"; exit 1; }
not_checked() { echo "NOT-CHECKED: $1 — $2" >&2; exit 2; }

sha256_of_stdin() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
  else return 1
  fi
}

is_test_shaped() {
  case "$1" in
    *.test.sh|*.test.py|*.test.ts|*.test.js|*.test.tsx|*.spec.ts|*.spec.js|*.spec.tsx) return 0 ;;
    *_test.go|*_test.py|*_test.rb|*Test.java|*Tests.swift)                             return 0 ;;
    *) return 1 ;;
  esac
}

br_field() { # <bead-id> <jq field> -> value, empty when unreadable
  "$BR" show "$1" --json </dev/null 2>/dev/null \
    | jq -r "if type == \"array\" then .[0] else . end | .$2 // \"\"" 2>/dev/null
}

# ---------------------------------------------------------------------------------------
# LEG 1 — RED-RECEIPT. The temporal anchor. No receipt, no causal claim.
# ---------------------------------------------------------------------------------------
FLIGHT_DIR="${AC2_FLIGHT_DIR:-$(git rev-parse --git-common-dir 2>/dev/null || echo .)/ac2-flight}"
RECEIPT_FILE="$FLIGHT_DIR/${BEAD}.flight-receipt"

if [ ! -s "$RECEIPT_FILE" ]; then
  refuse "RED-RECEIPT" "no probe receipt for $BEAD at ${RECEIPT_FILE} — flight-check.sh never recorded a RED, so nothing here can be shown to have been caused by the diff"
fi

# Receipts APPEND. The LAST one is the moment the lock runs from — for a bead that wrote its
# own harness, that is the re-invocation, not the claim.
LAST=$(awk '/^FLIGHT-RECEIPT v1/{buf=""} {buf = buf $0 "\n"} END{printf "%s", buf}' "$RECEIPT_FILE")
rfield() { printf '%s\n' "$LAST" | grep -m1 "^$1:" | sed "s|^$1:[[:space:]]*||"; }

RED_PROBE=$(rfield 'red-probe')
RED_FP=$(rfield 'red-fingerprint')
RED_SCOPE=$(rfield 'red-fingerprint-scope')
RED_INPUTS=$(rfield 'red-fingerprint-inputs')
RED_BEAD=$(rfield 'bead')

[ -n "$RED_PROBE" ] || refuse "RED-RECEIPT" "the last receipt carries no red-probe — an unusable receipt is not a receipt"
[ -n "$RED_FP" ]    || refuse "RED-RECEIPT" "the last receipt carries no red-fingerprint — there is no field to hash-lock against"
[ "$RED_BEAD" = "$BEAD" ] || not_checked "RED-RECEIPT" "receipt at $RECEIPT_FILE is for '$RED_BEAD', not '$BEAD'"
echo "close-gate[$BEAD] RED-RECEIPT ok — RED was: $RED_PROBE"

# ---------------------------------------------------------------------------------------
# LEG 2 — PROBE-DRIFT. The RED probe must still be an AC of this bead. Otherwise the
# acceptance criterion was rewritten after the RED was banked, and the lock guards a
# question nobody is asking any more.
# ---------------------------------------------------------------------------------------
BODY=$(mktemp -t ac2-close-body) || not_checked "SETUP" "cannot create a scratch file"
trap 'rm -f "$BODY"' EXIT

if [ -n "$BODY_FILE" ]; then
  [ -r "$BODY_FILE" ] || not_checked "PROBE-DRIFT" "body file '$BODY_FILE' is unreadable"
  cat "$BODY_FILE" >"$BODY"
elif command -v "$BR" >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  br_field "$BEAD" description >"$BODY"
else
  not_checked "PROBE-DRIFT" "no --body-file and br/jq unavailable — the bead's ACs are unreadable"
fi
[ -s "$BODY" ] || not_checked "PROBE-DRIFT" "bead '$BEAD' has an empty body — it declares no ACs to close against"

PROBES=$(grep -o 'Probe: `[^`]*`' "$BODY" | sed 's/^Probe: `//; s/`$//')
PROBE_EXPECTED=$(printf '%s\n' "$PROBES" | grep -c '[^[:space:]]' || true)
[ "$PROBE_EXPECTED" -gt 0 ] || not_checked "PROBE-DRIFT" "bead '$BEAD' names zero extractable probes — there is nothing to run"

printf '%s\n' "$PROBES" | grep -qxF "$RED_PROBE" \
  || refuse "PROBE-DRIFT" "the fingerprinted RED probe is no longer among this bead's ACs — the criterion was rewritten after the RED was recorded"
echo "close-gate[$BEAD] PROBE-DRIFT ok — the RED probe is still a live AC"

# ---------------------------------------------------------------------------------------
# LEG 3 — HASH-LOCK. The unchanged-test guarantee, recomputed exactly the way flight-check
# computed it: the RED probe command, then the recorded fingerprint inputs as they stand NOW.
# ---------------------------------------------------------------------------------------
LOCK_FILES=""
if [ "$RED_SCOPE" = "probe+harness" ]; then
  for f in $RED_INPUTS; do
    [ -f "$f" ] || refuse "HASH-LOCK" "the fingerprinted test '$f' is gone from the tree — a deleted test cannot be the thing that flipped"
    LOCK_FILES="$LOCK_FILES $f"
  done
  [ -n "${LOCK_FILES// /}" ] || not_checked "HASH-LOCK" "scope says probe+harness but the receipt lists no inputs"
elif [ "$RED_SCOPE" = "probe" ]; then
  # The carve-out. At claim this bead's own harness did not exist, so the RED was
  # fingerprinted over the probe command alone. That is legitimate ONLY while the harness
  # still does not exist. Once it does, flight-check must re-run — before any fix — so the
  # lock has real assertions to run from.
  for tok in $(printf '%s' "$RED_PROBE" | grep -oE '[A-Za-z0-9_.][A-Za-z0-9_./-]*\.[A-Za-z0-9]+' || true); do
    if is_test_shaped "$tok" && [ -f "$tok" ]; then
      refuse "HASH-LOCK" "the RED was fingerprinted before this bead's own harness existed, and '$tok' exists now — re-run flight-check.sh BEFORE the fix so the lock runs from the real assertions"
    fi
  done
else
  not_checked "HASH-LOCK" "receipt declares an unknown red-fingerprint-scope '$RED_SCOPE'"
fi

NOW_FP="sha256:$( { printf '%s\n' "$RED_PROBE"; for f in $LOCK_FILES; do cat "$f"; done; } | sha256_of_stdin )"
[ "$NOW_FP" != "sha256:" ] || not_checked "HASH-LOCK" "no sha256 tool (shasum/sha256sum) — the lock cannot be recomputed"

if [ "$NOW_FP" != "$RED_FP" ]; then
  ALL_TEST_SHAPED=1
  for f in $LOCK_FILES; do is_test_shaped "$f" || ALL_TEST_SHAPED=0; done
  if [ "$ALL_TEST_SHAPED" = 1 ]; then
    refuse "HASH-LOCK" "the fingerprinted test changed since the RED was recorded ($RED_FP -> $NOW_FP) — a test edited between RED and GREEN proves nothing about the diff"
  fi
  # The receipt mixed the SUBJECT of the bead into the assertion fingerprint, so a change is
  # unattributable: it may be the fix (legitimate) or the test (fatal), and nothing here can
  # tell them apart. Refusing would be wrong; passing would be a lie. Say so and FAIL.
  not_checked "HASH-LOCK" "the fingerprint moved ($RED_FP -> $NOW_FP) but its inputs ($LOCK_FILES) are not all test-shaped, so the change cannot be attributed to test-vs-fix. Name a test-shaped harness in the AC probe (the guarded 'test -x <harness> && bash <harness>' form) and re-run flight-check before the fix"
fi
echo "close-gate[$BEAD] HASH-LOCK ok — $RED_FP (scope: $RED_SCOPE)"

# ---------------------------------------------------------------------------------------
# LEG 4 — GREEN, and LEG 5 — COVERAGE. Running the probes is not enough: a run that was
# killed early reads exactly like a run that passed, so files-run must equal files-expected
# and the fingerprinted test must have produced NON-EMPTY assertion results.
# ---------------------------------------------------------------------------------------
PROBE_RUN=0
PROBE_GREEN=0
ASSERT_OUT=$(mktemp -t ac2-close-out) || not_checked "SETUP" "cannot create a scratch file"
trap 'rm -f "$BODY" "$ASSERT_OUT"' EXIT

# The assertion-bearing probe is the one that RUNS A HARNESS, which is not always the probe
# that happened to be RED first: `test -x <script>` is a legitimate RED and emits no
# assertions by construction. Pick the first probe naming a test-shaped file that exists;
# when the bead has none (a prose or config bead), the temporal exit-code pair recorded in
# the receipt is the assertion, and that pair is checked below instead.
ASSERT_PROBE=""
while IFS= read -r pr; do
  [ -n "$pr" ] || continue
  for tok in $(printf '%s' "$pr" | grep -oE '[A-Za-z0-9_.][A-Za-z0-9_./-]*\.[A-Za-z0-9]+' || true); do
    if is_test_shaped "$tok" && [ -f "$tok" ]; then ASSERT_PROBE="$pr"; break 2; fi
  done
done <<EOF
$PROBES
EOF

while IFS= read -r pr; do
  [ -n "$pr" ] || continue
  lead=$(printf '%s' "$pr" | awk '{print $1}')
  case "$lead" in ''|'#'|*=*) ;; *)
    command -v "$lead" >/dev/null 2>&1 \
      || not_checked "COVERAGE" "probe '$pr' leads with '$lead', which does not resolve — that probe could not run, so files-run < files-expected"
  ;; esac
  if [ -n "$ASSERT_PROBE" ] && [ "$pr" = "$ASSERT_PROBE" ]; then
    sh -c "$pr" >"$ASSERT_OUT" 2>&1 </dev/null
  else
    sh -c "$pr" >/dev/null 2>&1 </dev/null
  fi
  rc=$?
  PROBE_RUN=$(( PROBE_RUN + 1 ))
  [ "$rc" -eq 0 ] && PROBE_GREEN=$(( PROBE_GREEN + 1 ))
  if [ "$pr" = "$RED_PROBE" ] && [ "$rc" -ne 0 ]; then
    refuse "GREEN" "the RED probe still exits $rc — it never reported GREEN, so the diff caused nothing"
  fi
done <<EOF
$PROBES
EOF

[ "$PROBE_RUN" -eq "$PROBE_EXPECTED" ] \
  || not_checked "COVERAGE" "files-run ($PROBE_RUN) != files-expected ($PROBE_EXPECTED) — a partial run is not a pass"
[ "$PROBE_GREEN" -eq "$PROBE_EXPECTED" ] \
  || refuse "GREEN" "$(( PROBE_EXPECTED - PROBE_GREEN )) of $PROBE_EXPECTED probe(s) are not green"
echo "close-gate[$BEAD] GREEN ok — $PROBE_GREEN/$PROBE_EXPECTED probe(s) green, files-run == files-expected"

# Assertion results — the anti-bail leg. In vitest's JSON report the field is literally
# `assertionResults` under `.testResults[]`; for a shell harness the analogue is its own
# ok/FAIL assertion lines. Either way an EMPTY result set is a bail-killed run wearing a
# green exit code, and this refuses it.
ASSERTIONS=0
ASSERT_SOURCE=""
if [ -n "$VITEST_JSON" ]; then
  [ -r "$VITEST_JSON" ] || not_checked "COVERAGE" "--vitest-json '$VITEST_JSON' is unreadable"
  command -v jq >/dev/null 2>&1 || not_checked "COVERAGE" "jq unavailable — assertionResults cannot be counted"
  ASSERTIONS=$(jq '[.testResults[]?.assertionResults[]?] | length' "$VITEST_JSON" 2>/dev/null || echo 0)
  ASSERT_SOURCE="assertionResults in $VITEST_JSON"
elif [ -n "$ASSERT_PROBE" ]; then
  ASSERTIONS=$(grep -cE '^[[:space:]]*(ok|not ok|FAIL|PASS|✓|✗)([[:space:]]|$)' "$ASSERT_OUT" 2>/dev/null || true)
  if [ "${ASSERTIONS:-0}" -eq 0 ]; then
    # A summary line is a fallback, never the primary: it counts what the runner chose to
    # report, and this leg exists precisely because that number can be produced by a run
    # that asserted nothing.
    ASSERTIONS=$(grep -oE '[0-9]+ (passed|assertions?)' "$ASSERT_OUT" 2>/dev/null | head -1 | awk '{print $1}')
  fi
  ASSERT_SOURCE="assertion lines from the harness probe"
else
  # No harness in this bead — a prose or config bead. The assertion is the TEMPORAL PAIR
  # itself: the exit code the receipt recorded as RED, against the exit code measured GREEN
  # a moment ago. It is only an assertion because the receipt actually carries the before
  # value, so a receipt without red-exit gets no credit here.
  RED_EXIT=$(rfield 'red-exit')
  case "$RED_EXIT" in
    ''|0) not_checked "COVERAGE" "this bead runs no harness and its receipt records no non-zero red-exit, so there is no recorded before-state to compare the GREEN against — the assertion set is empty" ;;
    *)    ASSERTIONS=1; ASSERT_SOURCE="the temporal exit-code pair (RED $RED_EXIT -> GREEN 0) recorded in the receipt" ;;
  esac
fi
[ -n "${ASSERTIONS:-}" ] || ASSERTIONS=0
if [ "$ASSERTIONS" -eq 0 ]; then
  not_checked "COVERAGE" "the assertion-bearing probe produced ZERO assertion results (no assertionResults, no ok/FAIL lines) — a run that asserted nothing reads identical to one that passed"
fi
echo "close-gate[$BEAD] COVERAGE ok — $ASSERTIONS assertion result(s) from $ASSERT_SOURCE"

# ---------------------------------------------------------------------------------------
# LEG 6 — SCANNER. Only on non-empty argv, and it asserts scanned-equals-passed by reading
# the DETAIL lines, never the summary counter: ubs's summary counts CATEGORIES CHECKED, not
# findings, and it silently drops every language it has no scanner for.
# ---------------------------------------------------------------------------------------
if [ "${#SCAN_FILES[@]}" -gt 0 ]; then
  command -v ubs >/dev/null 2>&1 \
    || not_checked "SCANNER" "${#SCAN_FILES[@]} file(s) were handed to --scan but ubs is not on PATH — NOT-GATED, not clean"
  SCAN_OUT=$(ubs "${SCAN_FILES[@]}" 2>&1); SCAN_RC=$?
  if printf '%s' "$SCAN_OUT" | grep -qiE 'no supported languages detected|nothing was checked'; then
    not_checked "SCANNER" "ubs ran no scanner over ${#SCAN_FILES[@]} file(s) — 'nothing was checked' is explicitly NOT a pass"
  fi
  SCANNED=$(printf '%s' "$SCAN_OUT" | grep -oiE 'files scanned[^0-9]*([0-9]+)' | grep -oE '[0-9]+' | head -1)
  [ -n "${SCANNED:-}" ] || not_checked "SCANNER" "ubs printed no 'Files scanned' count — coverage is unassertable"
  [ "$SCANNED" -eq "${#SCAN_FILES[@]}" ] \
    || not_checked "SCANNER" "ubs scanned $SCANNED of ${#SCAN_FILES[@]} file(s) — a shortfall is NOT-GATED, not a pass"
  FINDINGS=$(printf '%s' "$SCAN_OUT" | grep -cE '^[[:space:]]+[^[:space:]]+:[0-9]+:[0-9]+' || true)
  [ "$SCAN_RC" -eq 0 ] && [ "${FINDINGS:-0}" -eq 0 ] \
    || refuse "SCANNER" "ubs exit $SCAN_RC with ${FINDINGS:-0} detail finding(s) over ${#SCAN_FILES[@]} scanned file(s)"
  echo "close-gate[$BEAD] SCANNER ok — $SCANNED/${#SCAN_FILES[@]} scanned, 0 detail findings"
else
  echo "close-gate[$BEAD] SCANNER skipped — no --scan argv (this gate reports the skip; it never implies clean)"
fi

# ---------------------------------------------------------------------------------------
# LEG 7 — EVIDENCE. Delegated to ac-on0y.2's close-evidence-check.sh, the registry's evidence
# core, rather than growing a private second one that would drift from it.
# ---------------------------------------------------------------------------------------
if [ -x "$EVIDENCE_CORE" ]; then
  EV_OUT=$(AC2_BR_CMD="$BR" bash "$EVIDENCE_CORE" "$BEAD" "$REASON" 2>&1); EV_RC=$?
  printf '%s\n' "$EV_OUT" | sed 's/^/  /'
  case "$EV_RC" in
    0) echo "close-gate[$BEAD] EVIDENCE ok" ;;
    1) refuse "EVIDENCE" "close-evidence-check refused: the reason carries no evidence of the shape this type declares" ;;
    *) not_checked "EVIDENCE" "close-evidence-check could not verify (exit $EV_RC)" ;;
  esac
else
  not_checked "EVIDENCE" "close-evidence-check.sh missing at ${EVIDENCE_CORE#$ROOT/} — the evidence core is the one thing this gate does not reimplement"
fi

# ---------------------------------------------------------------------------------------
# LEG 8 — OWNERSHIP, THE WRITE, AND LANDING. A claim does not hold for the duration: it can
# expire, a sibling can take the bead, a human can reassign it. So ownership is re-asserted
# IMMEDIATELY BEFORE the write — and the close is read back, because a close has failed
# silently before and an unverified write is a claim, not a fact.
# ---------------------------------------------------------------------------------------
if [ "$DRY" = 1 ]; then
  echo "close-gate[$BEAD] DRY-RUN — every leg held; would re-assert in_progress ownership, then:"
  echo "close-gate[$BEAD]   $BR close $BEAD --reason \"$REASON\""
  echo "close-gate[$BEAD]   then read back status == closed"
  exit 0
fi

command -v "$BR" >/dev/null 2>&1 || not_checked "OWNERSHIP" "br unavailable — ownership cannot be re-asserted and the close cannot be verified"

PRE_STATUS=$(br_field "$BEAD" status)
PRE_ASSIGNEE=$(br_field "$BEAD" assignee)
[ "$PRE_STATUS" = "in_progress" ] \
  || refuse "OWNERSHIP" "the bead is '$PRE_STATUS', not in_progress, at the moment of the write — the claim did not hold for the duration"
if [ -n "$ACTOR" ] && [ "$PRE_ASSIGNEE" != "$ACTOR" ]; then
  refuse "OWNERSHIP" "the bead is assigned to '$PRE_ASSIGNEE', not '$ACTOR' — someone else owns this close"
fi

"$BR" close "$BEAD" --reason "$REASON" </dev/null >/dev/null 2>&1 || true

POST_STATUS=$(br_field "$BEAD" status)
[ "$POST_STATUS" = "closed" ] \
  || refuse "LANDING" "the close did not land — $BEAD reads '$POST_STATUS' after the write"

echo "close-gate[$BEAD] CLOSED — RED before the diff, test unchanged, GREEN after: the diff caused the flip."
exit 0
