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
#           and skipped entirely in the whole-board lane; an empty board is
#           NOT-GATED (exit 2); a missing board skips (exit 77).
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
# The COMBINED-CLEAN fixture: a canon status (closed), a canon WORKER: receipt, and a
# GATE:-prefixed landing record — citing the flight receipt's own `at:` stamp (the same
# comment flight-check.sh posts at claim) — together: one assertion covers rules 4, 5 and 6
# (including the evidence citation) at once.
WORKER_GOOD='{"id":"ac-workerok","status":"closed","created_at":"2026-08-25T10:00:00Z","labels":["origin:manual"],"title":"good worker stamp","comments":[{"id":2,"issue_id":"ac-workerok","author":"x","text":"WORKER: model=claude-sonnet-5 actor=ac-123 tree=abc1234","created_at":"2026-08-25T10:01:00Z"},{"id":20,"issue_id":"ac-workerok","author":"x","text":"FLIGHT-RECEIPT v1\nbead: ac-workerok\nat: 2026-08-25T09:00:00Z","created_at":"2026-08-25T09:00:01Z"},{"id":5,"issue_id":"ac-workerok","author":"x","text":"GATE: receipt — ac-workerok — RED probe: true; receipt-at: 2026-08-25T09:00:00Z; reason: shipped","created_at":"2026-08-25T10:02:00Z"}]}'

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

# --- GREEN: a legacy receipt on an untouched comment of a changed bead stays green -----
# the bead already carried an old-grammar WORKER: comment at HEAD; this commit only
# relabels it — the comment itself is unchanged, so it must never be re-judged.
t="$WORK/worker-legacy-untouched"
LEGACY_AT_HEAD='{"id":"ac-legacy","status":"closed","created_at":"2026-08-20T10:00:00Z","labels":["origin:manual"],"title":"legacy receipt","comments":[{"id":3,"issue_id":"ac-legacy","author":"x","text":"WORKER: model=foo session=bar skill@version=abc duration=1m","created_at":"2026-08-20T10:01:00Z"}]}'
git_board "$t" "$OPEN_TAGGED" "$LEGACY_AT_HEAD"
LEGACY_RELABELED='{"id":"ac-legacy","status":"closed","created_at":"2026-08-20T10:00:00Z","labels":["origin:manual","touched-this-commit"],"title":"legacy receipt","comments":[{"id":3,"issue_id":"ac-legacy","author":"x","text":"WORKER: model=foo session=bar skill@version=abc duration=1m","created_at":"2026-08-20T10:01:00Z"}]}'
printf '%s\n' "$OPEN_TAGGED" "$LEGACY_RELABELED" > "$t/.beads/issues.jsonl"
git -C "$t" add .beads/issues.jsonl
rc=$(run_check "$t")
[ "$rc" -eq 0 ] && ok "legacy receipt on an untouched comment of a changed bead stays green" \
  || bad "worker-legacy-untouched: expected exit 0, rc=$rc out=$(cat "$OUT")"

# --- GREEN: a multi-line canon receipt (canon first line + a note line) stays green ----
t="$WORK/worker-multiline"
git_board "$t" "$OPEN_TAGGED"
WORKER_MULTILINE='{"id":"ac-multiline","status":"closed","created_at":"2026-08-25T10:00:00Z","labels":["origin:manual"],"title":"multi-line worker stamp","comments":[{"id":4,"issue_id":"ac-multiline","author":"x","text":"WORKER: model=claude-sonnet-5 actor=ac-123 tree=abc1234\nnote: closed after review","created_at":"2026-08-25T10:01:00Z"},{"id":21,"issue_id":"ac-multiline","author":"x","text":"FLIGHT-RECEIPT v1\nbead: ac-multiline\nat: 2026-08-25T09:00:00Z","created_at":"2026-08-25T09:00:01Z"},{"id":6,"issue_id":"ac-multiline","author":"x","text":"GATE: receipt — ac-multiline — RED probe: true; receipt-at: 2026-08-25T09:00:00Z; reason: shipped","created_at":"2026-08-25T10:02:00Z"}]}'
printf '%s\n' "$OPEN_TAGGED" "$WORKER_MULTILINE" > "$t/.beads/issues.jsonl"
git -C "$t" add .beads/issues.jsonl
rc=$(run_check "$t")
[ "$rc" -eq 0 ] && ok "a multi-line canon receipt (first line + note) stays green" \
  || bad "worker-multiline: expected exit 0, rc=$rc out=$(cat "$OUT")"

# --- RED: a bead closed by this commit with no landing record ------------------
t="$WORK/landing-red"
git_board "$t" "$OPEN_TAGGED"
LANDING_MISSING='{"id":"ac-landingmissing","status":"closed","created_at":"2026-08-25T10:00:00Z","labels":["origin:manual"],"title":"closed with no landing record"}'
printf '%s\n' "$OPEN_TAGGED" "$LANDING_MISSING" > "$t/.beads/issues.jsonl"
git -C "$t" add .beads/issues.jsonl
rc=$(run_check "$t")
[ "$rc" -eq 1 ] && grep -q 'no landing record' "$OUT" && grep -q 'ac-landingmissing' "$OUT" \
  && ok "a closed row with no GATE:/FRESH-VERIFY:/TRIAGE-CLOSE: landing record is RED" \
  || bad "landing-red: rc=$rc out=$(cat "$OUT")"

# --- GREEN: the same transition carrying a GATE: receipt landing record whose citation
# --- resolves against the flight receipt sitting on the same row (the record cites its
# --- evidence, ac-4y7l.31) -----------------------------------------------------
t="$WORK/landing-green"
git_board "$t" "$OPEN_TAGGED"
LANDING_PRESENT='{"id":"ac-landingpresent","status":"closed","created_at":"2026-08-25T10:00:00Z","labels":["origin:manual"],"title":"closed with a landing record","comments":[{"id":22,"issue_id":"ac-landingpresent","author":"x","text":"FLIGHT-RECEIPT v1\nbead: ac-landingpresent\nat: 2026-08-25T09:00:00Z","created_at":"2026-08-25T09:00:01Z"},{"id":7,"issue_id":"ac-landingpresent","author":"x","text":"GATE: receipt — ac-landingpresent — RED probe: true; receipt-at: 2026-08-25T09:00:00Z; reason: shipped","created_at":"2026-08-25T10:01:00Z"}]}'
printf '%s\n' "$OPEN_TAGGED" "$LANDING_PRESENT" > "$t/.beads/issues.jsonl"
git -C "$t" add .beads/issues.jsonl
rc=$(run_check "$t")
[ "$rc" -eq 0 ] && ok "a closed row carrying a GATE: receipt landing record that cites its evidence is GREEN" \
  || bad "landing-green: rc=$rc out=$(cat "$OUT")"

# --- RED: THE RECORD CITES ITS EVIDENCE — a bare `GATE: receipt` with no citation at all,
# --- the exact bypass `br close --transition-comment "GATE: receipt"` used to satisfy rule 6
# --- with zero evidence behind it, is now refused (the maintainer's ruling on ac-4y7l.29, ac-4y7l.31).
t="$WORK/landing-bare-bypass"
git_board "$t" "$OPEN_TAGGED"
LANDING_BARE='{"id":"ac-bare","status":"closed","created_at":"2026-08-25T10:00:00Z","labels":["origin:manual"],"title":"closed via a bare transition-comment bypass","comments":[{"id":23,"issue_id":"ac-bare","author":"x","text":"GATE: receipt","created_at":"2026-08-25T10:01:00Z"}]}'
printf '%s\n' "$OPEN_TAGGED" "$LANDING_BARE" > "$t/.beads/issues.jsonl"
git -C "$t" add .beads/issues.jsonl
rc=$(run_check "$t")
[ "$rc" -eq 1 ] && grep -q 'cites no evidence' "$OUT" && grep -q 'ac-bare' "$OUT" \
  && ok "a bare GATE: receipt with no citation (the close-gate.sh bypass) is RED — the record cites its evidence, or it is refused" \
  || bad "landing-bare-bypass: rc=$rc out=$(cat "$OUT")"

# --- RED: a GATE: receipt citing a receipt-at stamp that resolves against NOTHING on the
# --- row — a forged or stale citation is refused exactly like no citation at all.
t="$WORK/landing-mismatched-citation"
git_board "$t" "$OPEN_TAGGED"
LANDING_MISMATCH='{"id":"ac-mismatch","status":"closed","created_at":"2026-08-25T10:00:00Z","labels":["origin:manual"],"title":"citation resolves to nothing","comments":[{"id":24,"issue_id":"ac-mismatch","author":"x","text":"GATE: receipt — ac-mismatch — RED probe: true; receipt-at: 2099-01-01T00:00:00Z; reason: shipped","created_at":"2026-08-25T10:01:00Z"}]}'
printf '%s\n' "$OPEN_TAGGED" "$LANDING_MISMATCH" > "$t/.beads/issues.jsonl"
git -C "$t" add .beads/issues.jsonl
rc=$(run_check "$t")
[ "$rc" -eq 1 ] && grep -q 'cites no evidence' "$OUT" && grep -q 'ac-mismatch' "$OUT" \
  && ok "a GATE: receipt citation that resolves against nothing on the row is RED" \
  || bad "landing-mismatched-citation: rc=$rc out=$(cat "$OUT")"

# --- GREEN: an uncited FIRST landing comment followed by a CITED addendum still passes —
# --- the check asks "does evidence exist among what this commit added", never "is the
# --- first prefixed comment perfect" (retroactively citing a pre-existing receipt after
# --- close-gate.sh grew this requirement, ac-4y7l.24/.25, is exactly this shape).
t="$WORK/landing-addendum-cites"
git_board "$t" "$OPEN_TAGGED"
LANDING_ADDENDUM='{"id":"ac-addendum","status":"closed","created_at":"2026-08-25T10:00:00Z","labels":["origin:manual"],"title":"first comment uncited, addendum cites it","comments":[{"id":27,"issue_id":"ac-addendum","author":"x","text":"FLIGHT-RECEIPT v1\nbead: ac-addendum\nat: 2026-08-25T09:00:00Z","created_at":"2026-08-25T09:00:01Z"},{"id":28,"issue_id":"ac-addendum","author":"x","text":"GATE: receipt — ac-addendum — RED probe: true; reason: shipped","created_at":"2026-08-25T10:01:00Z"},{"id":29,"issue_id":"ac-addendum","author":"x","text":"GATE: receipt-addendum — ac-addendum — receipt-at: 2026-08-25T09:00:00Z (retroactive citation)","created_at":"2026-08-25T10:02:00Z"}]}'
printf '%s\n' "$OPEN_TAGGED" "$LANDING_ADDENDUM" > "$t/.beads/issues.jsonl"
git -C "$t" add .beads/issues.jsonl
rc=$(run_check "$t")
[ "$rc" -eq 0 ] && ok "an uncited first landing comment plus a cited addendum still passes — any new landing comment citing evidence is enough" \
  || bad "landing-addendum-cites: rc=$rc out=$(cat "$OUT")"

# --- GREEN: a GATE: decided landing record citing the ruling comment's own id ---------
t="$WORK/landing-decided-cited"
git_board "$t" "$OPEN_TAGGED"
LANDING_DECIDED='{"id":"ac-decided","status":"closed","created_at":"2026-08-25T10:00:00Z","labels":["origin:manual"],"title":"closed via the ruling path","comments":[{"id":25,"issue_id":"ac-decided","author":"x","text":"DECISION (Alice): option A — because it is cheaper","created_at":"2026-08-25T09:00:00Z"},{"id":26,"issue_id":"ac-decided","author":"x","text":"GATE: decided — ac-decided — decided: option A; ruling verified: DECISION (Alice): option A — because it is cheaper (ruling-comment: #25; at abc1234)","created_at":"2026-08-25T10:01:00Z"}]}'
printf '%s\n' "$OPEN_TAGGED" "$LANDING_DECIDED" > "$t/.beads/issues.jsonl"
git -C "$t" add .beads/issues.jsonl
rc=$(run_check "$t")
[ "$rc" -eq 0 ] && ok "a GATE: decided landing record citing the ruling comment's own id is GREEN" \
  || bad "landing-decided-cited: rc=$rc out=$(cat "$OUT")"

# --- GREEN: a bead already closed at HEAD, relabeled this commit — not a NEW close ---
t="$WORK/landing-precloseD-untouched"
LANDING_ALREADY_CLOSED='{"id":"ac-alreadyclosed","status":"closed","created_at":"2026-08-20T10:00:00Z","labels":["origin:manual"],"title":"already closed","comments":[]}'
git_board "$t" "$OPEN_TAGGED" "$LANDING_ALREADY_CLOSED"
LANDING_RELABELED='{"id":"ac-alreadyclosed","status":"closed","created_at":"2026-08-20T10:00:00Z","labels":["origin:manual","touched-this-commit"],"title":"already closed","comments":[]}'
printf '%s\n' "$OPEN_TAGGED" "$LANDING_RELABELED" > "$t/.beads/issues.jsonl"
git -C "$t" add .beads/issues.jsonl
rc=$(run_check "$t")
[ "$rc" -eq 0 ] && ok "a bead already closed at HEAD and only relabeled this commit is never a NEW close" \
  || bad "landing-precloseD-untouched: expected exit 0, rc=$rc out=$(cat "$OUT")"

# --- RED: a stale landing record from an earlier close does not satisfy a new close ---
# the bead was closed once (with a GATE: receipt), reopened (HEAD status back to open,
# the old GATE: comment still sitting on the row), then closed again this commit with
# NO new comment — the stale landing record must not be re-judged as covering the new close.
t="$WORK/landing-stale"
STALE_AT_HEAD='{"id":"ac-stale","status":"open","created_at":"2026-08-20T10:00:00Z","labels":["origin:manual"],"title":"reopened after a prior close","comments":[{"id":8,"issue_id":"ac-stale","author":"x","text":"GATE: receipt — ac-stale — RED probe: true; reason: shipped","created_at":"2026-08-20T10:05:00Z"}]}'
git_board "$t" "$OPEN_TAGGED" "$STALE_AT_HEAD"
STALE_RECLOSED='{"id":"ac-stale","status":"closed","created_at":"2026-08-20T10:00:00Z","labels":["origin:manual"],"title":"reopened after a prior close","comments":[{"id":8,"issue_id":"ac-stale","author":"x","text":"GATE: receipt — ac-stale — RED probe: true; reason: shipped","created_at":"2026-08-20T10:05:00Z"}]}'
printf '%s\n' "$OPEN_TAGGED" "$STALE_RECLOSED" > "$t/.beads/issues.jsonl"
git -C "$t" add .beads/issues.jsonl
rc=$(run_check "$t")
[ "$rc" -eq 1 ] && grep -q 'no landing record' "$OUT" && grep -q 'ac-stale' "$OUT" \
  && ok "a stale landing record from an earlier close does not satisfy a new close" \
  || bad "landing-stale: expected exit 1 naming ac-stale, rc=$rc out=$(cat "$OUT")"

# --- GREEN: a FRESH-VERIFY: close is a valid landing record --------------------
t="$WORK/landing-freshverify"
git_board "$t" "$OPEN_TAGGED"
FRESHVERIFY_CLOSE='{"id":"ac-freshverify","status":"closed","created_at":"2026-08-25T10:00:00Z","labels":["origin:manual"],"title":"closed on a fresh-verify","comments":[{"id":9,"issue_id":"ac-freshverify","author":"x","text":"FRESH-VERIFY: ac-freshverify — probes re-run green at (tree: abc1234)","created_at":"2026-08-25T10:01:00Z"}]}'
printf '%s\n' "$OPEN_TAGGED" "$FRESHVERIFY_CLOSE" > "$t/.beads/issues.jsonl"
git -C "$t" add .beads/issues.jsonl
rc=$(run_check "$t")
[ "$rc" -eq 0 ] && ok "a fresh-verify close passes rule 6" \
  || bad "landing-freshverify: expected exit 0, rc=$rc out=$(cat "$OUT")"

# --- GREEN: a TRIAGE-CLOSE: (cascade) close is a valid landing record ----------
t="$WORK/landing-cascade"
git_board "$t" "$OPEN_TAGGED"
CASCADE_CLOSE='{"id":"ac-cascade","status":"closed","created_at":"2026-08-25T10:00:00Z","labels":["origin:manual"],"title":"closed on the cascade leg","comments":[{"id":10,"issue_id":"ac-cascade","author":"x","text":"TRIAGE-CLOSE: ac-cascade — cascade close accepted on a consumed blocker (tree: abc1234)","created_at":"2026-08-25T10:01:00Z"}]}'
printf '%s\n' "$OPEN_TAGGED" "$CASCADE_CLOSE" > "$t/.beads/issues.jsonl"
git -C "$t" add .beads/issues.jsonl
rc=$(run_check "$t")
[ "$rc" -eq 0 ] && ok "a cascade close passes rule 6" \
  || bad "landing-cascade: expected exit 0, rc=$rc out=$(cat "$OUT")"

# --- GREEN: identity is by id, never position — a new comment sorted before a legacy
# --- receipt (a same-second created_at tie can reorder) is still recognized correctly.
# --- A naive "the last comment is the new one" positional slice would misjudge here: the
# --- true new comment (id 13) sits FIRST, so a positional slice would instead flag the
# --- LAST comment (id 11, legacy and malformed) as new and go RED — the case only stays
# --- green under identity-by-id.
t="$WORK/comment-identity-not-position"
LEGACY_REORDER_HEAD='{"id":"ac-reorder","status":"open","created_at":"2026-08-20T10:00:00Z","labels":["origin:manual"],"title":"legacy comment reordered","comments":[{"id":11,"issue_id":"ac-reorder","author":"x","text":"WORKER: model=foo session=bar skill@version=abc duration=1m","created_at":"2026-08-20T10:01:00Z"},{"id":12,"issue_id":"ac-reorder","author":"x","text":"GATE: receipt — ac-reorder — RED probe: true; reason: shipped","created_at":"2026-08-20T10:02:00Z"}]}'
git_board "$t" "$OPEN_TAGGED" "$LEGACY_REORDER_HEAD"
# staged: the genuinely new canon comment (id 13) is sorted BEFORE the two legacy HEAD
# comments, which also come back reordered (simulating a same-second tie resort by br)
REORDER_STAGED='{"id":"ac-reorder","status":"open","created_at":"2026-08-20T10:00:00Z","labels":["origin:manual","touched-this-commit"],"title":"legacy comment reordered","comments":[{"id":13,"issue_id":"ac-reorder","author":"x","text":"WORKER: model=claude-sonnet-5 actor=ac-123 tree=abc1234","created_at":"2026-08-20T10:03:00Z"},{"id":12,"issue_id":"ac-reorder","author":"x","text":"GATE: receipt — ac-reorder — RED probe: true; reason: shipped","created_at":"2026-08-20T10:02:00Z"},{"id":11,"issue_id":"ac-reorder","author":"x","text":"WORKER: model=foo session=bar skill@version=abc duration=1m","created_at":"2026-08-20T10:01:00Z"}]}'
printf '%s\n' "$OPEN_TAGGED" "$REORDER_STAGED" > "$t/.beads/issues.jsonl"
git -C "$t" add .beads/issues.jsonl
rc=$(run_check "$t")
# id=11's malformed WORKER: text is legacy (present at HEAD, just reordered) and must
# NEVER be re-judged — only id=13 is new, and it is canon-shaped, so this is GREEN
[ "$rc" -eq 0 ] && ok "a new comment sorted before a legacy receipt is not misjudged (identity by id, never position)" \
  || bad "comment-identity-not-position: expected exit 0, rc=$rc out=$(cat "$OUT")"

# --- An EMPTY board stays NOT-GATED; a MISSING board skips ----------------------
# The board is adopter-local (gitignored, 2026-09-20 agnosticism pass): a checkout
# carrying none has nothing to gate, so absent -> skip. A board that EXISTS but is
# empty is still a broken sensor and stays fail-closed.
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