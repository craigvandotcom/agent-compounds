#!/usr/bin/env bash
#
# close-gate.sh — the ac2 TEMPORAL causal-necessity probe at close (ac-k25c.3).
#
# ASSURANCE
#   PROBE:      bash skills/ac-implement/scripts/close-gate.test.sh
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
#   - spatial isolation (worktrees survive only where ac-review's destructive sabotage
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
# THE PROSE SCOPE (`subject-scoped`, ac-hnsc): a prose or config bead's probe names the file
#   the bead itself edits, so the receipt hash-locks the probe COMMAND alone and the SUBJECT is
#   free to move — otherwise this leg is unsatisfiable for every prose bead by construction.
#   The full argument, and the guard that keeps a harness-bearing bead out of it, sits at LEG 3.
#
# Usage:
#   close-gate.sh <bead-id> --reason "<close reason>" [--actor <name>]
#                 [--scan <file> …] [--vitest-json <report>]
#                 [--body-file <path>] [--root <repo>] [--dry-run]
#
# Env:
#   AC2_FLIGHT_DIR  where flight-check wrote the receipt (default <git-common-dir>/ac-flight)
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
  # ROOT is the CONSUMER repo's root, never the script's own repo: these scripts are
  # symlinked into consumer repos via .agents/skills/, so script-relative resolution
  # lands inside the skills checkout (or .agents/) and every repo-relative probe
  # dies with FileNotFoundError. Derive from the calling repo's git toplevel.
  ROOT=$(git rev-parse --show-toplevel 2>/dev/null) \
    || ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd) \
    || ROOT="$PWD"
fi
cd "$ROOT" || { echo "NOT-CHECKED: cannot enter repo root '$ROOT'" >&2; exit 2; }

BR="${AC2_BR_CMD:-br}"
EVIDENCE_CORE="$ROOT/skills/ac-pipeline/scripts/close-evidence-check.sh"
# Vendored-copy layout: app repos track these scripts under .agents/skills/ (the
# agent-compounds registry layout puts skills/ at the repo root), so the evidence
# core may sit one level deeper. Try the canonical path first, then the vendored one.
[ -f "$EVIDENCE_CORE" ] \
  || EVIDENCE_CORE="$ROOT/.agents/skills/ac-pipeline/scripts/close-evidence-check.sh"

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

# A probe whose stdout is SUPPRESSED BY CONSTRUCTION can never carry assertion lines:
# a silent test (-q) or a redirect into /dev/null produces nothing to count, so selecting
# it as the assertion-bearing probe bails COVERAGE on a bead whose harness asserts fine
# (measured: ac-close-gate-coverage-silent-probe-ja8l, instances 4 and 5). Deliberately
# static — it reads the probe's CONSTRUCTION, never its run: a harness that ran but
# emitted nothing stays NOT-CHECKED, because a run that asserted nothing reads identical
# to one that passed.
is_output_silent() {
  case "$1" in
    *grep\ -q*|*rg\ -q*|*\|grep\ -q*|*\>/dev/null*|*\>/\ dev/null*) return 0 ;;
    *) return 1 ;;
  esac
}

br_field() { # <bead-id> <jq field> -> value, empty when unreadable
  "$BR" show "$1" --json </dev/null 2>/dev/null \
    | jq -r "if type == \"array\" then .[0] else . end | .$2 // \"\"" 2>/dev/null
}

# ---------------------------------------------------------------------------------------
# LEG 1 — RED-RECEIPT. The temporal anchor: this bead was observed RED before the diff.
# Whether the diff CAUSED the flip is judged by ac-review (causal sufficiency), not
# proven here — a checksum shows a file did not change, never that a change sufficed.
# ---------------------------------------------------------------------------------------
FLIGHT_DIR="${AC2_FLIGHT_DIR:-$(git rev-parse --git-common-dir 2>/dev/null || echo .)/ac-flight}"
RECEIPT_FILE="$FLIGHT_DIR/${BEAD}.flight-receipt"

# Receipts APPEND. The LAST one is the moment the lock runs from — for a bead that wrote its
# own harness, that is the re-invocation, not the claim.
LAST=$(awk '/^FLIGHT-RECEIPT v1/{buf=""} {buf = buf $0 "\n"} END{printf "%s", buf}' "$RECEIPT_FILE" 2>/dev/null)
rfield() { printf '%s\n' "$LAST" | grep -m1 "^$1:" | sed "s|^$1:[[:space:]]*||"; }

RED_PROBE=$(rfield 'red-probe')
RED_BEAD=$(rfield 'bead')

# THE FRESH-VERIFICATION CARVE-OUT (ac-close-gate-already-green-carveout-8r3o, extended by
# run 20260907-exhaust): a bead with no usable claim-time receipt banks no temporal anchor,
# so LEG 1 refused every future close of it — an honest obsolete:/duplicate: disposition
# whose evidence core would otherwise pass (measured: 4 beads dead on the identical verbatim
# refusal), and legitimate shipped: closes of cross-repo work whose probes could not resolve
# from the claim cwd (measured: ac-dream-docket-sweep-mgzw, ac-dream-emitter-born-verified-uo7n,
# 2026-09-08). ANY disposition now closes through the fresh-verify leg instead, under four
# conditions:
#   (a) EVERY AC probe exits 0 at HEAD, and the per-probe results are recorded in the
#       FRESH-VERIFY comment at landing — never a bare summary;
#   (b) the close reason still names a Delivers artifact the evidence core resolves (LEG 7);
#   (c) a usable claim-time receipt still takes precedence — the temporal pair is the
#       preferred proof whenever it exists;
#   (d) the abuse-guard: a fresh-verify attempt on a bead with ANY not-green probe is
#       REFUSED. A fresh close claims only that the state the bead aimed at holds at HEAD;
#       it never claims a diff caused a flip.
FRESH_VERIFY=0
if [ ! -s "$RECEIPT_FILE" ] || [ -z "$RED_PROBE" ] || [ "$RED_BEAD" != "$BEAD" ]; then
  FRESH_VERIFY=1
  echo "close-gate[$BEAD] RED-RECEIPT fresh-verify — no usable claim-time receipt (missing, empty, or for another bead); every AC probe is verified green at HEAD below and the per-probe results are recorded on the bead at landing"
fi
[ "$FRESH_VERIFY" = 1 ] || echo "close-gate[$BEAD] RED-RECEIPT ok — RED was: $RED_PROBE"

# ---------------------------------------------------------------------------------------
# LEG 2 — PROBE-DRIFT. The RED probe must still be an AC of this bead. Otherwise the
# acceptance criterion was rewritten after the RED was banked, and the GREEN below answers
# a question nobody is asking any more.
# ---------------------------------------------------------------------------------------
BODY=$(mktemp "${TMPDIR:-/tmp}/ac-close-body.XXXXXX") || not_checked "SETUP" "cannot create a scratch file"
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

if [ "$FRESH_VERIFY" = 1 ]; then
  echo "close-gate[$BEAD] PROBE-DRIFT fresh-verify — no claim-time RED probe; every live AC probe is re-run below instead"
elif printf '%s\n' "$PROBES" | grep -qxF "$RED_PROBE"; then
  echo "close-gate[$BEAD] PROBE-DRIFT ok — the RED probe is still a live AC"
else
  # The receipt exists but its fingerprinted probe is no longer among the live ACs — the
  # criterion was rewritten after the RED was banked, so no temporal pair can be formed and
  # the receipt cannot take precedence (condition c). Fresh verification takes over: every
  # live AC probe must be green at HEAD, and any red probe refuses (condition d).
  FRESH_VERIFY=1
  echo "close-gate[$BEAD] PROBE-DRIFT drift — the fingerprinted RED probe is no longer among the live ACs; the receipt cannot anchor a temporal pair, so the fresh-verify leg runs"
fi

# ---------------------------------------------------------------------------------------
# LEG 4 — GREEN, and LEG 5 — COVERAGE. Running the probes is not enough: a run that was
# killed early reads exactly like a run that passed, so files-run must equal files-expected
# and the fingerprinted test must have produced NON-EMPTY assertion results.
# ---------------------------------------------------------------------------------------
PROBE_RUN=0
PROBE_GREEN=0
PROBE_RESULTS=()
ASSERT_OUT=$(mktemp "${TMPDIR:-/tmp}/ac-close-out.XXXXXX") || not_checked "SETUP" "cannot create a scratch file"
trap 'rm -f "$BODY" "$ASSERT_OUT"' EXIT

# The assertion-bearing probe is the one that RUNS A HARNESS, which is not always the probe
# that happened to be RED first: `test -x <script>` is a legitimate RED and emits no
# assertions by construction. Two filters, both required: the probe must NAME a test-shaped
# file that exists, AND its stdout must be able to carry assertion lines (a -q test or a
# >/dev/null redirect asserts nothing into any stream we can read — measured as instances
# 4 and 5 of ac-close-gate-coverage-silent-probe-ja8l). When every probe is output-silent
# (or none names a harness), the temporal exit-code pair recorded in the receipt is the
# assertion, and that pair is checked below instead.
ASSERT_PROBE=""
while IFS= read -r pr; do
  [ -n "$pr" ] || continue
  is_output_silent "$pr" && continue
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
  PROBE_RESULTS+=("$pr => exit $rc")
  [ "$rc" -eq 0 ] && PROBE_GREEN=$(( PROBE_GREEN + 1 ))
  if [ "$FRESH_VERIFY" = 1 ] && [ "$rc" -ne 0 ]; then
    refuse "GREEN" "fresh-verify: probe '$pr' exits $rc at HEAD — a fresh-verified close demands EVERY AC probe green; one red probe is a refusal"
  fi
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
  # Assertion line formats live harnesses in this registry actually emit: TAP `ok N …`,
  # `FAIL …`, vitest-style `✓/✗`, and the `  PASS: <label>` label-colon form
  # (ac-close-gate-coverage-silent-probe-ja8l instance 5 — consensus.test.sh's PASS lines
  # missed the old space-or-EOL follower). The token must still be FOLLOWED by something —
  # a bare "PASS" inside prose is not an assertion line.
  ASSERTIONS=$(grep -cE '^[[:space:]]*(ok|not ok|FAIL|PASS|✓|✗)([[:space:]:]|$)' "$ASSERT_OUT" 2>/dev/null || true)
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
  if [ "$FRESH_VERIFY" = 1 ]; then
    # No claim-time receipt under the carve-out: the fresh verification IS the assertion —
    # LEG 4 measured every AC probe green at HEAD, and LEG 8 records it per-probe.
    ASSERTIONS=1; ASSERT_SOURCE="the fresh-verification itself (all $PROBE_GREEN probe(s) green at HEAD, per-probe results recorded on the bead at landing)"
  elif [ "$RED_EXIT" = '' ] || [ "$RED_EXIT" = 0 ]; then
    not_checked "COVERAGE" "this bead runs no harness and its receipt records no non-zero red-exit, so there is no recorded before-state to compare the GREEN against — the assertion set is empty"
  else
    ASSERTIONS=1; ASSERT_SOURCE="the temporal exit-code pair (RED $RED_EXIT -> GREEN 0) recorded in the receipt"
  fi
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

# THE FRESH-VERIFY RECORD: a close accepted on fresh verification leaves the receipt it
# ran from on the bead — the record is the difference between a verified close and a
# wave-through, and a comment nobody wrote proves nothing to the next reader.
if [ "$FRESH_VERIFY" = 1 ]; then
  FRESH_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
  FRESH_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  PER_PROBE=""
  for r in "${PROBE_RESULTS[@]:-}"; do
    [ -n "$r" ] && PER_PROBE="$PER_PROBE [$r]"
  done
  "$BR" comments add "$BEAD" \
    "FRESH-VERIFY: $BEAD — ${REASON%%:*} close with no usable claim-time receipt; all $PROBE_GREEN AC probe(s) verified green at HEAD $FRESH_SHA by ${ACTOR:-<unattributed>} at $FRESH_TS — per-probe:$PER_PROBE" \
    </dev/null >/dev/null 2>&1 || true
  echo "close-gate[$BEAD] fresh-verify RECORDED on the bead"
fi

echo "close-gate[$BEAD] CLOSED — RED before the diff, test unchanged, GREEN after: the diff caused the flip."
exit 0
