#!/usr/bin/env bash
# 35-board-integrity.test.sh — the fixture proving Check 35's contract (ac-heyt.9).
#
#   PROBE: a non-JSON board line is RED; a duplicate id is RED; an OPEN
#           post-cutover bead without an origin: label is RED; an OPEN post-cutover
#           implementable bead (task/bug/feature) without a Probe: line is RED;
#           a probed task and an exempt decision are GREEN; closed beads and
#           pre-cutover beads are NEVER scanned (GREEN); a clean board is GREEN;
#           an empty or missing board is NOT-GATED (exit 2).
#
# ASSURANCE
#   PROBE:    bash lint/checks/35-board-integrity.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/35-board-integrity.py"
ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
OUT="$WORK/out"

run_check() { # <board-dir> -> exit code; board read from <dir>/.beads/issues.jsonl
  python3 "$CHECK" "$1" >"$OUT" 2>&1
  echo $?
}

board() { # <board-dir> <lines...> — write a board, one record per arg
  mkdir -p "$1/.beads"
  printf '%s\n' "${@:2}" > "$1/.beads/issues.jsonl"
}

PRE_CUTOVER_OPEN='{"id":"ac-old","status":"open","created_at":"2026-08-22T10:00:00Z","labels":[],"title":"pre-cutover"}'
CLOSED_ORIGINLESS='{"id":"ac-closed","status":"closed","created_at":"2026-08-27T10:00:00Z","labels":[],"title":"closed"}'
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

# --- GREEN: closed and pre-cutover beads are never scanned ---------------------
board "$WORK/d" "$CLOSED_ORIGINLESS" "$PRE_CUTOVER_OPEN" "$OPEN_TAGGED"
rc=$(run_check "$WORK/d")
[ "$rc" -eq 0 ] && ok "closed + pre-cutover origin-less beads are GREEN (never scanned)" || bad "closed/pre-cutover: rc=$rc out=$(cat "$OUT")"

# --- GREEN: clean board --------------------------------------------------------
board "$WORK/e" "$OPEN_TAGGED"
rc=$(run_check "$WORK/e")
[ "$rc" -eq 0 ] && ok "clean board is GREEN" || bad "clean board: rc=$rc out=$(cat "$OUT")"

# --- NOT-GATED: empty board and missing board ----------------------------------
mkdir -p "$WORK/f/.beads"; : > "$WORK/f/.beads/issues.jsonl"
rc=$(run_check "$WORK/f")
[ "$rc" -eq 2 ] && grep -q 'NOT-GATED' "$OUT" && ok "empty board is NOT-GATED (exit 2)" || bad "empty board: rc=$rc out=$(cat "$OUT")"
mkdir -p "$WORK/g"
rc=$(run_check "$WORK/g")
[ "$rc" -eq 2 ] && grep -q 'NOT-GATED' "$OUT" && ok "missing board is NOT-GATED (exit 2)" || bad "missing board: rc=$rc out=$(cat "$OUT")"

echo
if [ "$fails" -eq 0 ]; then
  echo "OK: every board-integrity case passed ($(basename "$0"))"
  exit 0
else
  echo "FAILURES: $fails — the check behaves outside its contract ($(basename "$0"))"
  exit 1
fi