#!/usr/bin/env bash
# 35-board-integrity.test.sh — the fixture proving Check 35's contract (ac-heyt.9).
#
#   PROBE: a non-JSON board line is RED; a duplicate id is RED; an OPEN
#           post-cutover bead without an origin: label is RED; an OPEN post-cutover
#           implementable bead (task/bug/feature) without a Probe: line is RED;
#           a probed task and an exempt decision are GREEN; closed beads and
#           pre-cutover beads are NEVER scanned (GREEN); a clean board is GREEN;
#           an off-canon status is RED regardless of lane or open/closed; a
#           malformed WORKER: receipt on a changed id is RED in the staged lane
#           and skipped entirely in the whole-board lane; an empty or missing
#           board is NOT-GATED (exit 2).
#
# ASSURANCE
#   PROBE:    bash lint/checks/35-board-integrity.test.sh
#   SCHEDULE: scripts/run-all-proofs.sh + CI harness job
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

# --- RED: off-canon status, unconditional (fires even on a non-open row) -------
board "$WORK/status-red" '{"id":"ac-donebad","status":"done","created_at":"2026-08-01T10:00:00Z","labels":[],"title":"off canon status"}'
rc=$(run_check "$WORK/status-red")
[ "$rc" -eq 1 ] && grep -q "off-canon status is RED" "$OUT" && grep -q 'ac-donebad' "$OUT" \
  && ok "off-canon status is RED even when status != open" \
  || bad "off-canon status: rc=$rc out=$(cat "$OUT")"

# --- GREEN: every canon status, including the newly-admitted blocked -----------
board "$WORK/status-green" \
  '{"id":"ac-s1","status":"open","created_at":"2026-08-01T10:00:00Z","labels":["origin:manual"],"title":"o"}' \
  '{"id":"ac-s2","status":"in_progress","created_at":"2026-08-01T10:00:00Z","labels":["origin:manual"],"title":"i"}' \
  '{"id":"ac-s3","status":"blocked","created_at":"2026-08-01T10:00:00Z","labels":["origin:manual"],"title":"b"}' \
  '{"id":"ac-s4","status":"deferred","created_at":"2026-08-01T10:00:00Z","labels":["origin:manual"],"title":"d"}' \
  '{"id":"ac-s5","status":"closed","created_at":"2026-08-01T10:00:00Z","labels":["origin:manual"],"title":"c"}' \
  '{"id":"ac-s6","status":"tombstone","created_at":"2026-08-01T10:00:00Z","labels":["origin:manual"],"title":"t"}'
rc=$(run_check "$WORK/status-green")
[ "$rc" -eq 0 ] && ok "every canon status (incl. blocked) is GREEN" || bad "canon statuses: rc=$rc out=$(cat "$OUT")"

# --- GREEN: a pre-existing malformed bead untouched by this commit does not ---
# --- fail a commit that only stages an unrelated bead (2026-09-12 audit) ------
git_board() { # <dir> <lines...> — a git checkout with the board committed at HEAD
  mkdir -p "$1/.beads"
  git -C "$1" init -q
  git -C "$1" config user.email "test@example.com"
  git -C "$1" config user.name "test"
  printf '%s\n' "${@:2}" > "$1/.beads/issues.jsonl"
  git -C "$1" add .beads/issues.jsonl
  git -C "$1" commit -q -m init
}

t="$WORK/scoped-clean"
git_board "$t" "$OPEN_ORIGINLESS" "$OPEN_TAGGED"
# this commit only touches a NEW bead — the pre-existing origin-less one is untouched
printf '%s\n' "$OPEN_ORIGINLESS" "$OPEN_TAGGED" \
  '{"id":"ac-new","status":"open","created_at":"2026-08-26T10:00:00Z","labels":["origin:manual"],"title":"new, unrelated"}' \
  > "$t/.beads/issues.jsonl"
git -C "$t" add .beads/issues.jsonl
rc=$(run_check "$t")
[ "$rc" -eq 0 ] && ok "pre-existing malformed bead untouched by this commit does not fail it" \
  || bad "scoped-clean: expected exit 0, rc=$rc out=$(cat "$OUT")"

# --- RED: a malformed bead ADDED by this commit still fails it -----------------
t="$WORK/scoped-dirty"
git_board "$t" "$OPEN_TAGGED"
# this commit adds the origin-less bead itself
printf '%s\n' "$OPEN_TAGGED" "$OPEN_ORIGINLESS" > "$t/.beads/issues.jsonl"
git -C "$t" add .beads/issues.jsonl
rc=$(run_check "$t")
[ "$rc" -eq 1 ] && grep -q "origin: label" "$OUT" && grep -q 'ac-lost' "$OUT" \
  && ok "malformed bead ADDED by this commit still fails it" \
  || bad "scoped-dirty: expected exit 1 naming ac-lost, rc=$rc out=$(cat "$OUT")"

# --- RED: a malformed WORKER: receipt on a changed id, staged lane only -------
WORKER_BAD='{"id":"ac-workerbad","status":"closed","created_at":"2026-08-25T10:00:00Z","labels":["origin:manual"],"title":"bad worker stamp","comments":[{"id":1,"issue_id":"ac-workerbad","author":"x","text":"WORKER: model=foo session=bar skill@version=abc duration=1m","created_at":"2026-08-25T10:01:00Z"}]}'
WORKER_GOOD='{"id":"ac-workerok","status":"closed","created_at":"2026-08-25T10:00:00Z","labels":["origin:manual"],"title":"good worker stamp","comments":[{"id":2,"issue_id":"ac-workerok","author":"x","text":"WORKER: model=claude-sonnet-5 actor=ac-123 tree=abc1234","created_at":"2026-08-25T10:01:00Z"}]}'

t="$WORK/worker-staged-red"
git_board "$t" "$OPEN_TAGGED"
# this commit adds the malformed-WORKER-comment bead itself — it is a changed id
printf '%s\n' "$OPEN_TAGGED" "$WORKER_BAD" > "$t/.beads/issues.jsonl"
git -C "$t" add .beads/issues.jsonl
rc=$(run_check "$t")
[ "$rc" -eq 1 ] && grep -q "malformed WORKER receipt is RED" "$OUT" && grep -q 'ac-workerbad' "$OUT" \
  && ok "malformed WORKER: receipt on a changed id is RED in the staged lane" \
  || bad "worker-staged-red: rc=$rc out=$(cat "$OUT")"

t="$WORK/worker-staged-green"
git_board "$t" "$OPEN_TAGGED"
printf '%s\n' "$OPEN_TAGGED" "$WORKER_GOOD" > "$t/.beads/issues.jsonl"
git -C "$t" add .beads/issues.jsonl
rc=$(run_check "$t")
[ "$rc" -eq 0 ] && ok "canon WORKER: receipt (model=/actor=/tree=) is GREEN in the staged lane" \
  || bad "worker-staged-green: rc=$rc out=$(cat "$OUT")"

# --- GREEN: a malformed WORKER: receipt is skipped entirely on a whole-board run
board "$WORK/worker-wholeboard" "$OPEN_TAGGED" "$WORKER_BAD"
rc=$(run_check "$WORK/worker-wholeboard")
[ "$rc" -eq 0 ] && ok "malformed WORKER: receipt is skipped entirely on a whole-board run" \
  || bad "worker-wholeboard: rc=$rc out=$(cat "$OUT")"

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