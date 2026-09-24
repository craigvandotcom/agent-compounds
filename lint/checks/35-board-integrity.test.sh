#!/usr/bin/env bash
# 35-board-integrity.test.sh — the fixture proving Check 35's contract.
#
#   PROBE: a non-JSON board line is RED; a duplicate id is RED; an OPEN
#           post-cutover bead without an origin: label is RED; an OPEN post-cutover
#           implementable bead (task/bug/feature) without a Probe: line is RED;
#           a probed task and an exempt decision are GREEN; closed beads and
#           pre-cutover beads are NEVER scanned for origin/probe (GREEN); a clean
#           board is GREEN; every rule scans the WHOLE board — no git checkout
#           required anywhere in this file; a closed bead's landing record must cite
#           evidence resolving against its own row when closed_at is on/after the
#           rule-6 cutover, and is never re-judged before it; an empty board is
#           NOT-GATED (exit 2); a missing board skips (exit 77). (Rules 4 "status
#           outside the canon set" and 5 "malformed WORKER: receipt" were cut,
#           2026-09-24 — see lint/checks/35-board-integrity.py's module docstring.)
#
# ASSURANCE
#   PROBE:    bash lint/checks/35-board-integrity.test.sh
#   SCHEDULE: scripts/run-all-proofs.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/35-board-integrity.py"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
OUT="$WORK/out"

run_check() { # <board-dir> -> exit code; board read from <dir>/.beads/issues.jsonl
  python3 "$CHECK" "$1" >"$OUT" 2>&1
  echo $?
}

board() { # <board-dir> <lines...> — write a board, one record per arg (no git, ever)
  mkdir -p "$1/.beads"
  printf '%s\n' "${@:2}" > "$1/.beads/issues.jsonl"
}

PRE_CUTOVER_OPEN='{"id":"ac-old","status":"open","created_at":"2026-08-22T10:00:00Z","labels":[],"title":"pre-cutover"}'
CLOSED_ORIGINLESS='{"id":"ac-closed","status":"closed","created_at":"2026-08-27T10:00:00Z","closed_at":"2026-08-27T10:00:00Z","labels":[],"title":"closed"}'
OPEN_TAGGED='{"id":"ac-ok","status":"open","created_at":"2026-08-25T10:00:00Z","labels":["origin:manual"],"title":"tagged"}'
OPEN_ORIGINLESS='{"id":"ac-lost","status":"open","created_at":"2026-08-25T10:00:00Z","labels":["refined"],"title":"origin-less post-cutover"}'
OPEN_TASK_NOPROBE='{"id":"ac-noprobe","status":"open","created_at":"2026-08-25T10:00:00Z","labels":["origin:ac-review"],"issue_type":"task","title":"probe-less task"}'
OPEN_TASK_PROBED='{"id":"ac-probed","status":"open","created_at":"2026-08-25T10:00:00Z","labels":["origin:ac-review"],"issue_type":"task","title":"probed task","description":"## Acceptance Criteria\n- it does a thing.\n  Probe: `true` — tier: none"}'
OPEN_DECISION='{"id":"ac-dec","status":"open","created_at":"2026-08-25T10:00:00Z","labels":["origin:human-gate"],"issue_type":"decision","title":"a human fork"}'

# --- RED: a non-JSON line ------------------------------------------------------
board "$WORK/a" '{"id":"ac-ok","status":"open","created_at":"2026-08-25T10:00:00Z","labels":["origin:manual"],"title":"ok"}' 'not json at all'
rc=$(run_check "$WORK/a")
[ "$rc" -eq 1 ] && grep -q 'not JSON' "$OUT" && ok "non-JSON line is RED" || bad "non-JSON line: rc=$rc out=$(cat "$OUT")"

# --- RED: duplicate id ---------------------------------------------------------
board "$WORK/b" '{"id":"ac-dup","status":"open","created_at":"2026-08-25T10:00:00Z","labels":["origin:manual"],"title":"one"}' '{"id":"ac-dup","status":"open","created_at":"2026-08-25T10:00:00Z","labels":["origin:manual"],"title":"two"}'
rc=$(run_check "$WORK/b")
[ "$rc" -eq 1 ] && grep -q "duplicate id 'ac-dup'" "$OUT" && ok "duplicate id is RED" || bad "duplicate id: rc=$rc out=$(cat "$OUT")"

# --- RED: open post-cutover origin-less bead -----------------------------------
board "$WORK/c" "$OPEN_TAGGED" "$OPEN_ORIGINLESS"
rc=$(run_check "$WORK/c")
[ "$rc" -eq 1 ] && grep -q "origin: label" "$OUT" && grep -q 'ac-lost' "$OUT" && ok "origin-less open post-cutover bead is RED" || bad "origin-less bead: rc=$rc out=$(cat "$OUT")"

# --- RED: open post-cutover implementable bead with no Probe -------------------
board "$WORK/h" "$OPEN_TASK_NOPROBE"
rc=$(run_check "$WORK/h")
[ "$rc" -eq 1 ] && grep -q "carries no Probe: line" "$OUT" && grep -q 'ac-noprobe' "$OUT" && ok "probe-less implementable bead is RED" || bad "probe-less bead: rc=$rc out=$(cat "$OUT")"

# --- GREEN: probed task and exempt decision -----------------------------------
board "$WORK/i" "$OPEN_TASK_PROBED" "$OPEN_DECISION"
rc=$(run_check "$WORK/i")
[ "$rc" -eq 0 ] && ok "probed task + exempt decision are GREEN" || bad "probed/exempt: rc=$rc out=$(cat "$OUT")"

# --- GREEN: closed and pre-cutover beads are never scanned for origin/probe ---
board "$WORK/d" "$CLOSED_ORIGINLESS" "$PRE_CUTOVER_OPEN" "$OPEN_TAGGED"
rc=$(run_check "$WORK/d")
[ "$rc" -eq 0 ] && ok "closed + pre-cutover origin-less beads are GREEN (never scanned)" || bad "closed/pre-cutover: rc=$rc out=$(cat "$OUT")"

# --- GREEN: clean board --------------------------------------------------------
board "$WORK/e" "$OPEN_TAGGED"
rc=$(run_check "$WORK/e")
[ "$rc" -eq 0 ] && ok "clean board is GREEN" || bad "clean board: rc=$rc out=$(cat "$OUT")"

# --- GREEN: an off-canon status is no longer judged (rule 4 cut, 2026-09-24 — `br`
# --- validates status on write; only a hand-edited JSONL could ever trip this) ------
board "$WORK/status-cut" '{"id":"ac-donebad","status":"done","created_at":"2026-08-01T10:00:00Z","labels":[],"title":"off canon status"}'
rc=$(run_check "$WORK/status-cut")
[ "$rc" -eq 0 ] && ok "an off-canon status is GREEN now that rule 4 is cut" \
  || bad "status-cut: rc=$rc out=$(cat "$OUT")"

# --- GREEN: a malformed WORKER: comment is no longer judged (rule 5 cut, 2026-09-24 —
# --- nothing reads a WORKER: field) --------------------------------------------------
WORKER_BAD='{"id":"ac-workerbad","status":"open","created_at":"2026-08-25T10:00:00Z","labels":["origin:manual"],"title":"bad worker stamp","comments":[{"id":1,"issue_id":"ac-workerbad","author":"x","text":"WORKER: model=foo session=bar skill@version=abc duration=1m","created_at":"2026-09-23T10:01:00Z"}]}'
board "$WORK/worker-cut" "$OPEN_TAGGED" "$WORKER_BAD"
rc=$(run_check "$WORK/worker-cut")
[ "$rc" -eq 0 ] && ok "a malformed WORKER: comment is GREEN now that rule 5 is cut" \
  || bad "worker-cut: rc=$rc out=$(cat "$OUT")"

# =====================================================================
# Rule 6 — a closed bead's landing record cites its evidence, whole-board,
# forward-only by the bead's own closed_at against the rule-5/6 cutover.
# =====================================================================

# --- RED: a bead closed on/after the cutover with no landing record ------------
LANDING_MISSING='{"id":"ac-landingmissing","status":"closed","created_at":"2026-08-25T10:00:00Z","closed_at":"2026-09-23T10:00:00Z","labels":["origin:manual"],"title":"closed with no landing record"}'
board "$WORK/landing-red" "$OPEN_TAGGED" "$LANDING_MISSING"
rc=$(run_check "$WORK/landing-red")
[ "$rc" -eq 1 ] && grep -q 'no landing record' "$OUT" && grep -q 'ac-landingmissing' "$OUT" \
  && ok "a closed row (on/after cutover) with no landing record is RED" \
  || bad "landing-red: rc=$rc out=$(cat "$OUT")"

# --- GREEN: a bead closed BEFORE the cutover with no landing record ------------
# forward-only by closed_at: a close that happened before the cutover is never
# re-judged, no matter how it looks.
LANDING_MISSING_PRE='{"id":"ac-landinglegacy","status":"closed","created_at":"2026-08-20T10:00:00Z","closed_at":"2026-09-22T23:59:59Z","labels":["origin:manual"],"title":"closed before the cutover, no landing record"}'
board "$WORK/landing-legacy" "$OPEN_TAGGED" "$LANDING_MISSING_PRE"
rc=$(run_check "$WORK/landing-legacy")
[ "$rc" -eq 0 ] && ok "a close before the cutover with no landing record is never re-judged" \
  || bad "landing-legacy: rc=$rc out=$(cat "$OUT")"

# --- GREEN: a GATE: receipt landing record whose citation resolves against the
# --- flight receipt sitting on the same row (the record cites its evidence) ---
LANDING_PRESENT='{"id":"ac-landingpresent","status":"closed","created_at":"2026-08-25T10:00:00Z","closed_at":"2026-09-23T10:01:00Z","labels":["origin:manual"],"title":"closed with a landing record","comments":[{"id":22,"issue_id":"ac-landingpresent","author":"x","text":"FLIGHT-RECEIPT v1\nbead: ac-landingpresent\nat: 2026-09-23T09:00:00Z","created_at":"2026-09-23T09:00:01Z"},{"id":7,"issue_id":"ac-landingpresent","author":"x","text":"GATE: receipt — ac-landingpresent — RED probe: true; receipt-at: 2026-09-23T09:00:00Z; reason: shipped","created_at":"2026-09-23T10:01:00Z"}]}'
board "$WORK/landing-green" "$OPEN_TAGGED" "$LANDING_PRESENT"
rc=$(run_check "$WORK/landing-green")
[ "$rc" -eq 0 ] && ok "a GATE: receipt landing record that cites its evidence is GREEN" \
  || bad "landing-green: rc=$rc out=$(cat "$OUT")"

# --- RED: a bare GATE: receipt with no citation at all (the close-gate.sh bypass) -
LANDING_BARE='{"id":"ac-bare","status":"closed","created_at":"2026-08-25T10:00:00Z","closed_at":"2026-09-23T10:01:00Z","labels":["origin:manual"],"title":"closed via a bare transition-comment bypass","comments":[{"id":23,"issue_id":"ac-bare","author":"x","text":"GATE: receipt","created_at":"2026-09-23T10:01:00Z"}]}'
board "$WORK/landing-bare" "$OPEN_TAGGED" "$LANDING_BARE"
rc=$(run_check "$WORK/landing-bare")
[ "$rc" -eq 1 ] && grep -q 'cites no evidence' "$OUT" && grep -q 'ac-bare' "$OUT" \
  && ok "a bare GATE: receipt with no citation is RED — the record cites its evidence, or it is refused" \
  || bad "landing-bare: rc=$rc out=$(cat "$OUT")"

# --- RED: a GATE: receipt citing a receipt-at stamp that resolves against NOTHING
# --- on the row — a forged or stale citation is refused like no citation at all --
LANDING_MISMATCH='{"id":"ac-mismatch","status":"closed","created_at":"2026-08-25T10:00:00Z","closed_at":"2026-09-23T10:01:00Z","labels":["origin:manual"],"title":"citation resolves to nothing","comments":[{"id":24,"issue_id":"ac-mismatch","author":"x","text":"GATE: receipt — ac-mismatch — RED probe: true; receipt-at: 2099-01-01T00:00:00Z; reason: shipped","created_at":"2026-09-23T10:01:00Z"}]}'
board "$WORK/landing-mismatch" "$OPEN_TAGGED" "$LANDING_MISMATCH"
rc=$(run_check "$WORK/landing-mismatch")
[ "$rc" -eq 1 ] && grep -q 'cites no evidence' "$OUT" && grep -q 'ac-mismatch' "$OUT" \
  && ok "a GATE: receipt citation that resolves against nothing on the row is RED" \
  || bad "landing-mismatch: rc=$rc out=$(cat "$OUT")"

# --- GREEN: an uncited FIRST landing comment followed by a CITED addendum still
# --- passes — the check asks "does evidence exist among the row's comments",
# --- never "is the first prefixed comment perfect" -----------------------------
LANDING_ADDENDUM='{"id":"ac-addendum","status":"closed","created_at":"2026-08-25T10:00:00Z","closed_at":"2026-09-23T10:02:00Z","labels":["origin:manual"],"title":"first comment uncited, addendum cites it","comments":[{"id":27,"issue_id":"ac-addendum","author":"x","text":"FLIGHT-RECEIPT v1\nbead: ac-addendum\nat: 2026-09-23T09:00:00Z","created_at":"2026-09-23T09:00:01Z"},{"id":28,"issue_id":"ac-addendum","author":"x","text":"GATE: receipt — ac-addendum — RED probe: true; reason: shipped","created_at":"2026-09-23T10:01:00Z"},{"id":29,"issue_id":"ac-addendum","author":"x","text":"GATE: receipt-addendum — ac-addendum — receipt-at: 2026-09-23T09:00:00Z (retroactive citation)","created_at":"2026-09-23T10:02:00Z"}]}'
board "$WORK/landing-addendum" "$OPEN_TAGGED" "$LANDING_ADDENDUM"
rc=$(run_check "$WORK/landing-addendum")
[ "$rc" -eq 0 ] && ok "an uncited first landing comment plus a cited addendum still passes" \
  || bad "landing-addendum: rc=$rc out=$(cat "$OUT")"

# --- GREEN: a GATE: decided landing record citing the ruling comment's own id --
LANDING_DECIDED='{"id":"ac-decided","status":"closed","created_at":"2026-08-25T10:00:00Z","closed_at":"2026-09-23T10:01:00Z","labels":["origin:manual"],"title":"closed via the ruling path","comments":[{"id":25,"issue_id":"ac-decided","author":"x","text":"DECISION (Alice): option A — because it is cheaper","created_at":"2026-09-23T09:00:00Z"},{"id":26,"issue_id":"ac-decided","author":"x","text":"GATE: decided — ac-decided — decided: option A; ruling verified: DECISION (Alice): option A — because it is cheaper (ruling-comment: #25; at abc1234)","created_at":"2026-09-23T10:01:00Z"}]}'
board "$WORK/landing-decided" "$OPEN_TAGGED" "$LANDING_DECIDED"
rc=$(run_check "$WORK/landing-decided")
[ "$rc" -eq 0 ] && ok "a GATE: decided landing record citing the ruling comment's own id is GREEN" \
  || bad "landing-decided: rc=$rc out=$(cat "$OUT")"

# --- GREEN: a FRESH-VERIFY: close is a valid landing record --------------------
FRESHVERIFY_CLOSE='{"id":"ac-freshverify","status":"closed","created_at":"2026-08-25T10:00:00Z","closed_at":"2026-09-23T10:01:00Z","labels":["origin:manual"],"title":"closed on a fresh-verify","comments":[{"id":9,"issue_id":"ac-freshverify","author":"x","text":"FRESH-VERIFY: ac-freshverify — probes re-run green at (tree: abc1234)","created_at":"2026-09-23T10:01:00Z"}]}'
board "$WORK/landing-freshverify" "$OPEN_TAGGED" "$FRESHVERIFY_CLOSE"
rc=$(run_check "$WORK/landing-freshverify")
[ "$rc" -eq 0 ] && ok "a fresh-verify close passes rule 6" \
  || bad "landing-freshverify: rc=$rc out=$(cat "$OUT")"

# --- GREEN: a TRIAGE-CLOSE: (cascade) close is a valid landing record ----------
CASCADE_CLOSE='{"id":"ac-cascade","status":"closed","created_at":"2026-08-25T10:00:00Z","closed_at":"2026-09-23T10:01:00Z","labels":["origin:manual"],"title":"closed on the cascade leg","comments":[{"id":10,"issue_id":"ac-cascade","author":"x","text":"TRIAGE-CLOSE: ac-cascade — cascade close accepted on a consumed blocker (tree: abc1234)","created_at":"2026-09-23T10:01:00Z"}]}'
board "$WORK/landing-cascade" "$OPEN_TAGGED" "$CASCADE_CLOSE"
rc=$(run_check "$WORK/landing-cascade")
[ "$rc" -eq 0 ] && ok "a cascade close passes rule 6" \
  || bad "landing-cascade: rc=$rc out=$(cat "$OUT")"

# --- An EMPTY board stays NOT-GATED; a MISSING board skips ----------------------
mkdir -p "$WORK/f/.beads"; : > "$WORK/f/.beads/issues.jsonl"
rc=$(run_check "$WORK/f")
[ "$rc" -eq 2 ] && grep -q 'NOT-GATED' "$OUT" && ok "empty board is NOT-GATED (exit 2)" || bad "empty board: rc=$rc out=$(cat "$OUT")"
mkdir -p "$WORK/g"
rc=$(run_check "$WORK/g")
[ "$rc" -eq 77 ] && grep -q 'skipped' "$OUT" && ok "missing board skips (exit 77, reported as a skip)" || bad "missing board: rc=$rc out=$(cat "$OUT")"
grep -q 'record(s) scanned' "$OUT" && bad "missing board: claimed records scanned while gating nothing"

echo
if [ "$fails" -eq 0 ]; then
  echo "OK: every board-integrity case passed ($(basename "$0"))"
  exit 0
else
  echo "FAILURES: $fails — the check behaves outside its contract ($(basename "$0"))"
  exit 1
fi
