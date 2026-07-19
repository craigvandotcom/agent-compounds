#!/usr/bin/env bash
# beads-closed-gate.test.sh — fixture-based unit tests for beads-closed-gate.sh
#
# TRUNK-DIRECT + UNION-OF-IDENTITIES (bd-u2lo1.7, bd-w504y): the gate scopes by
# `br list --assignee <id> --limit 0 --all` for EACH given identity, unions the
# results, filters to status != closed excluding post-merge-labelled beads, and
# FAILS CLOSED when it can't see the batch. These fixtures assert:
#   (1) the assignee(s) are threaded through to `br list --assignee` (from
#       positional args, or from $AGENT_NAME when none given);
#   (2) post-merge-labelled beads never block;
#   (3) exit codes 0 (clear) / 1 (blocked) / 2 (no assignee OR empty
#       claimed-set without --allow-empty) are correct;
#   (4) the CROSS-IDENTITY fail-open is reproduced (an open bead claimed under a
#       delegate identity is MISSED when only the conductor identity is queried,
#       and CAUGHT once the union is passed) — bd-w504y;
#   (5) --all and --limit 0 are actually sent to `br list` (regression guard so
#       a change dropping them fails a test);
#   (6) the out-of-scope bead-bleed check runs against a REAL JSON-LINES fixture
#       (not a `[]` JSON array, which silently voids the jq stream) and warns
#       without blocking.
#
# No shell-test framework exists in this repo (bats/shellspec/shunit) — this is
# a self-contained assert harness. Run directly:
#   bash .claude/skills/_shared/scripts/beads-closed-gate.test.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_SCRIPT="$SCRIPT_DIR/beads-closed-gate.sh"

FAILURES=0
pass() { echo "  PASS: $1"; }
fail() {
  echo "  FAIL: $1"
  FAILURES=$((FAILURES + 1))
}

# --- Fixture git repo (JSON LINES, not a JSON array — the bleed check streams
#     it with `jq -r '.id'`; a `[]` array would break that jq and void the check) ---
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

git -C "$WORKDIR" init -q -b main
git -C "$WORKDIR" config user.email "test@test.local"
git -C "$WORKDIR" config user.name "test"
mkdir -p "$WORKDIR/.beads"
printf '%s\n' \
  '{"id":"bd-old1","status":"closed","labels":["infra"]}' \
  '{"id":"bd-old2","status":"open","labels":["infra"]}' \
  >"$WORKDIR/.beads/issues.jsonl"
git -C "$WORKDIR" add .beads/issues.jsonl
git -C "$WORKDIR" commit -q -m "chore: init"

MOCK_BIN="$WORKDIR/bin"
FIXTURE_DIR="$WORKDIR/fixtures"
BR_ARGLOG="$WORKDIR/br-args.log"
mkdir -p "$MOCK_BIN" "$FIXTURE_DIR"
export FIXTURE_DIR BR_ARGLOG

# Data-driven mock `br list`: returns the JSON array in
# $FIXTURE_DIR/<assignee>.json for `--assignee <assignee>` (missing = empty),
# simulating the real server-side assignee filter. Every invocation's args are
# appended to $BR_ARGLOG so a test can assert --all / --limit 0 are sent.
cat >"$MOCK_BIN/br" <<'EOF'
#!/usr/bin/env bash
[ -n "${BR_ARGLOG:-}" ] && printf '%s\n' "$*" >>"$BR_ARGLOG"
if [ "$1" = "list" ]; then
  shift
  assignee=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --assignee) assignee="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  fx="${FIXTURE_DIR:-}/${assignee}.json"
  if [ -n "$assignee" ] && [ -f "$fx" ]; then
    printf '{"issues":%s}\n' "$(cat "$fx")"
  else
    echo '{"issues":[]}'
  fi
fi
EOF
chmod +x "$MOCK_BIN/br"

# write_fixture <assignee> <json-array-of-issues>
write_fixture() { printf '%s' "$2" >"$FIXTURE_DIR/$1.json"; }
clear_fixtures() { rm -f "$FIXTURE_DIR"/*.json; }

# run_gate <args...> — AGENT_NAME env comes from $GATE_AGENT (default empty).
run_gate() {
  ( cd "$WORKDIR" && env "PATH=$MOCK_BIN:$PATH" "AGENT_NAME=${GATE_AGENT:-}" \
      "FIXTURE_DIR=$FIXTURE_DIR" "BR_ARGLOG=$BR_ARGLOG" \
      bash "$GATE_SCRIPT" "$@" )
}

# ============================================================================
# Cases A–H run while HEAD == main (empty diff → the bleed check is a no-op).
# ============================================================================

# --- Case A: AGENT_NAME-env-sourced identity, own bead CLOSED -> exit 0 ------
clear_fixtures
write_fixture "ConductorA" '[{"id":"bd-a","status":"closed","labels":["infra"]}]'
OUT=$(GATE_AGENT="ConductorA" run_gate 2>&1); RC=$?
if [ "$RC" -eq 0 ]; then
  pass "Case A: AGENT_NAME-sourced identity, own bead closed -> exit 0"
else
  fail "Case A: expected exit 0, got $RC. Output: $OUT"
fi

# --- Case B: own bead OPEN -> exit 1 (blocked) ------------------------------
clear_fixtures
write_fixture "ConductorA" '[{"id":"bd-a","status":"open","labels":["infra"]}]'
OUT=$(GATE_AGENT="ConductorA" run_gate 2>&1); RC=$?
if [ "$RC" -eq 1 ]; then
  pass "Case B: own bead open -> exit 1 (blocked)"
else
  fail "Case B: expected exit 1, got $RC. Output: $OUT"
fi

# --- Case C: explicit positional identity threads through, independent of env ---
clear_fixtures
write_fixture "ConductorB" '[{"id":"bd-b","status":"open","labels":["infra"]}]'
OUT=$(GATE_AGENT="SomeOtherAgent" run_gate "ConductorB" 2>&1); RC=$?
if [ "$RC" -eq 1 ]; then
  pass "Case C: explicit positional identity threads to br list (env ignored) -> exit 1"
else
  fail "Case C: expected exit 1, got $RC. Output: $OUT"
fi

# --- Case D: post-merge label excludes an open bead -> exit 0 ----------------
clear_fixtures
write_fixture "ConductorA" '[{"id":"bd-a","status":"open","labels":["infra","post-merge"]}]'
OUT=$(GATE_AGENT="ConductorA" run_gate 2>&1); RC=$?
if [ "$RC" -eq 0 ]; then
  pass "Case D: post-merge-labelled open bead excluded -> exit 0"
else
  fail "Case D: expected exit 0, got $RC. Output: $OUT"
fi

# --- Case J: conductor-claimed in_progress EPIC excluded; children closed -> exit 0 (bd-vyiej) ---
# The conductor claims the epic parent as a work signal (status in_progress). The gate must
# NOT read that epic as unfinished batch work — with all non-epic children closed it exits 0.
clear_fixtures
write_fixture "ConductorA" '[{"id":"bd-epic","status":"in_progress","issue_type":"epic","labels":["infra"]},{"id":"bd-child","status":"closed","issue_type":"task","labels":["infra"]}]'
OUT=$(GATE_AGENT="ConductorA" run_gate 2>&1); RC=$?
if [ "$RC" -eq 0 ]; then
  pass "Case J: in_progress epic parent excluded, children closed -> exit 0 (bd-vyiej)"
else
  fail "Case J: expected exit 0 (epic excluded), got $RC. Output: $OUT"
fi

# J2 — fail-closed guard: an OPEN non-epic bead alongside the in_progress epic STILL blocks.
# Proves the epic exclusion did not over-broaden into swallowing genuine open work.
clear_fixtures
write_fixture "ConductorA" '[{"id":"bd-epic","status":"in_progress","issue_type":"epic","labels":["infra"]},{"id":"bd-child","status":"open","issue_type":"task","labels":["infra"]}]'
OUT=$(GATE_AGENT="ConductorA" run_gate 2>&1); RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "bd-child"; then
  pass "Case J2: epic exclusion does not mask an open non-epic child -> exit 1"
else
  fail "Case J2: expected exit 1 listing bd-child, got $RC. Output: $OUT"
fi

# --- Case E: no identity determinable (no arg, no AGENT_NAME) -> exit 2 ------
clear_fixtures
write_fixture "ConductorA" '[{"id":"bd-a","status":"open","labels":["infra"]}]'
OUT=$(GATE_AGENT="" run_gate 2>&1); RC=$?
if [ "$RC" -eq 2 ]; then
  pass "Case E: no identity available -> exit 2"
else
  fail "Case E: expected exit 2, got $RC. Output: $OUT"
fi

# --- Case K: FoggyCreek REJECTED as an assignee (ac-ycr.6 tier boundary) -----
# FoggyCreek is the Tier-2 chore identity — it may commit chore files but may
# NEVER claim beads. The gate must reject it LOUDLY (exit 2) before any br query,
# whether passed positionally or falling back via AGENT_NAME.
clear_fixtures
write_fixture "FoggyCreek" '[{"id":"bd-x","status":"open","labels":["infra"]}]'
# K1 — explicit positional FoggyCreek -> exit 2 with the REJECTED message.
OUT=$(GATE_AGENT="" run_gate "FoggyCreek" 2>&1); RC=$?
if [ "$RC" -eq 2 ] && echo "$OUT" | grep -qi "REJECTED" && echo "$OUT" | grep -q "FoggyCreek"; then
  pass "Case K1: FoggyCreek positional assignee rejected -> exit 2 (REJECTED message)"
else
  fail "Case K1: expected exit 2 with REJECTED/FoggyCreek message, got $RC. Output: $OUT"
fi
# K2 — FoggyCreek arriving via the AGENT_NAME fallback is caught too.
OUT=$(GATE_AGENT="FoggyCreek" run_gate 2>&1); RC=$?
if [ "$RC" -eq 2 ] && echo "$OUT" | grep -qi "REJECTED"; then
  pass "Case K2: FoggyCreek via AGENT_NAME fallback rejected -> exit 2"
else
  fail "Case K2: expected exit 2 with REJECTED message, got $RC. Output: $OUT"
fi

# --- Case F: CROSS-IDENTITY FAIL-OPEN reproduction (bd-w504y) ----------------
# BlueLake = loop conductor (its own batch bead already closed).
# SunnyBear = delegated ac-implement session; its replacement bead is OPEN.
clear_fixtures
write_fixture "BlueLake"  '[{"id":"bd-loop","status":"closed","labels":["infra"]}]'
write_fixture "SunnyBear" '[{"id":"bd-repl","status":"open","labels":["infra"]}]'

# F1 — the BUG: querying ONLY the conductor identity misses the delegate's open
# bead and reports "safe to close" (exit 0). This asserts the pre-union behavior
# so a regression that narrows the union back to a single identity is caught.
OUT=$(GATE_AGENT="" run_gate "BlueLake" 2>&1); RC=$?
if [ "$RC" -eq 0 ]; then
  pass "Case F1: single-identity query MISSES delegate's open bead (documents the fail-open) -> exit 0"
else
  fail "Case F1: expected exit 0 (single-identity blind spot), got $RC. Output: $OUT"
fi

# F2 — the FIX: passing the UNION (loop + delegate) sees the open bead -> exit 1.
OUT=$(GATE_AGENT="" run_gate "BlueLake" "SunnyBear" 2>&1); RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "bd-repl"; then
  pass "Case F2: union of identities catches delegate's open bead -> exit 1"
else
  fail "Case F2: expected exit 1 listing bd-repl, got $RC. Output: $OUT"
fi

# --- Case G: FAIL-CLOSED on empty union claimed-set (bd-w504y) ---------------
clear_fixtures  # every identity returns []
OUT=$(GATE_AGENT="" run_gate "GhostAgent" 2>&1); RC=$?
if [ "$RC" -eq 2 ] && echo "$OUT" | grep -qi "FAIL-CLOSED"; then
  pass "Case G: empty claimed-set fails CLOSED (warns + exit 2)"
else
  fail "Case G: expected exit 2 with FAIL-CLOSED warning, got $RC. Output: $OUT"
fi
# G-override: --allow-empty lets a genuinely empty board pass.
OUT=$(GATE_AGENT="" run_gate --allow-empty "GhostAgent" 2>&1); RC=$?
if [ "$RC" -eq 0 ]; then
  pass "Case G-override: --allow-empty permits an empty board -> exit 0"
else
  fail "Case G-override: expected exit 0, got $RC. Output: $OUT"
fi

# --- Case H: regression guard — gate must send --all AND --limit 0 to br list ---
: >"$BR_ARGLOG"
clear_fixtures
write_fixture "ConductorA" '[{"id":"bd-a","status":"closed","labels":["infra"]}]'
GATE_AGENT="ConductorA" run_gate >/dev/null 2>&1
if grep -q -- '--all' "$BR_ARGLOG" && grep -q -- '--limit 0' "$BR_ARGLOG"; then
  pass "Case H: gate passes --all and --limit 0 to br list (regression guard)"
else
  fail "Case H: gate dropped --all or --limit 0. Arg log: $(cat "$BR_ARGLOG")"
fi

# ============================================================================
# Cases L1-L3: progress.md completeness gate (ac-514). All run while HEAD==main.
# The assignee's beads are CLOSED so the open-bead gate passes and the exit code
# is determined by the completeness check alone.
# ============================================================================

# --- Case L1: multi-bead wave, COMPLETE progress.md -> pass (exit 0) ----------
clear_fixtures
write_fixture "ConductorL" '[{"id":"bd-l1","status":"closed","labels":["infra"]},{"id":"bd-l2","status":"closed","labels":["infra"]}]'
PROG_COMPLETE="$WORKDIR/progress-complete.md"
printf '%s\n' \
  'TARGET_BEADS=2' \
  'WAVE=test-wave' \
  '' \
  '### Bead bd-l1: first bead' \
  '- Status: COMPLETE' \
  '- Commit: abc123' \
  '' \
  '### Bead bd-l2: second bead' \
  '- Status: COMPLETE' \
  '- Commit: def456' \
  '' \
  'COMPLETED: 2 / 2' \
  >"$PROG_COMPLETE"
OUT=$(GATE_AGENT="ConductorL" run_gate --progress "$PROG_COMPLETE" 2>&1); RC=$?
if [ "$RC" -eq 0 ]; then
  pass "Case L1: multi-bead complete progress.md -> exit 0"
else
  fail "Case L1: expected exit 0, got $RC. Output: $OUT"
fi

# --- Case L2: multi-bead wave, THIN progress.md -> HARD-FAIL (exit non-zero) --
clear_fixtures
write_fixture "ConductorL" '[{"id":"bd-l1","status":"closed","labels":["infra"]},{"id":"bd-l2","status":"closed","labels":["infra"]}]'
PROG_THIN="$WORKDIR/progress-thin.md"
printf '%s\n' \
  'TARGET_BEADS=2' \
  'WAVE=test-wave' \
  '' \
  '### Bead bd-l1: first bead' \
  '- Status: COMPLETE' \
  >"$PROG_THIN"
OUT=$(GATE_AGENT="ConductorL" run_gate --progress "$PROG_THIN" 2>&1); RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -qi "PROGRESS-INCOMPLETE" && echo "$OUT" | grep -q "bd-l2"; then
  pass "Case L2: multi-bead thin progress.md -> exit non-zero, names missing bd-l2"
else
  fail "Case L2: expected non-zero exit naming bd-l2, got $RC. Output: $OUT"
fi

# --- Case L3: single-bead wave, THIN progress.md -> WARN, exit 0 --------------
clear_fixtures
write_fixture "ConductorS" '[{"id":"bd-s1","status":"closed","labels":["infra"]}]'
PROG_SINGLE="$WORKDIR/progress-single.md"
printf '%s\n' \
  'TARGET_BEADS=1' \
  'WAVE=single-wave' \
  >"$PROG_SINGLE"
OUT=$(GATE_AGENT="ConductorS" run_gate --progress "$PROG_SINGLE" 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -qi "WARNING (single-bead wave"; then
  pass "Case L3: single-bead thin progress.md -> WARN + exit 0 (never blocks)"
else
  fail "Case L3: expected exit 0 with single-bead WARNING, got $RC. Output: $OUT"
fi

# --- Case L4: multi-bead, DUPLICATE entry masks an absent in-scope bead -------
# Raw counts reach N (bd-l1 appears twice, tally reads 2/2) but bd-l2 has no
# entry at all. Identity-based check must still HARD-FAIL and name bd-l2 —
# guards the count-evasion false-PASS (ac-514 hardening, review-finding).
clear_fixtures
write_fixture "ConductorL" '[{"id":"bd-l1","status":"closed","labels":["infra"]},{"id":"bd-l2","status":"closed","labels":["infra"]}]'
PROG_DUP="$WORKDIR/progress-dup.md"
printf '%s\n' \
  'TARGET_BEADS=2' \
  'WAVE=test-wave' \
  '' \
  '### Bead bd-l1: first bead' \
  '- Status: COMPLETE' \
  '' \
  '### Bead bd-l1: first bead (retried, duplicate section)' \
  '- Status: COMPLETE' \
  '' \
  'COMPLETED: 2 / 2' \
  >"$PROG_DUP"
OUT=$(GATE_AGENT="ConductorL" run_gate --progress "$PROG_DUP" 2>&1); RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -qi "PROGRESS-INCOMPLETE" && echo "$OUT" | grep -q "bd-l2"; then
  pass "Case L4: duplicate entry masking absent bd-l2 -> hard-fail, names bd-l2 (no count-evasion)"
else
  fail "Case L4: expected non-zero exit naming bd-l2, got $RC. Output: $OUT"
fi

# --- Case L5: multi-bead, all entries present but COMPLETED tally SHORT --------
# Every bead has a '### Bead'+Status entry, but the footer reads 1/2. Must
# HARD-FAIL on the short tally (done_n < n).
clear_fixtures
write_fixture "ConductorL" '[{"id":"bd-l1","status":"closed","labels":["infra"]},{"id":"bd-l2","status":"closed","labels":["infra"]}]'
PROG_SHORT="$WORKDIR/progress-short-tally.md"
printf '%s\n' \
  'TARGET_BEADS=2' \
  'WAVE=test-wave' \
  '' \
  '### Bead bd-l1: first bead' \
  '- Status: COMPLETE' \
  '' \
  '### Bead bd-l2: second bead' \
  '- Status: COMPLETE' \
  '' \
  'COMPLETED: 1 / 2' \
  >"$PROG_SHORT"
OUT=$(GATE_AGENT="ConductorL" run_gate --progress "$PROG_SHORT" 2>&1); RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -qi "tally short"; then
  pass "Case L5: complete entries but short COMPLETED tally -> hard-fail (done_n<n)"
else
  fail "Case L5: expected non-zero exit citing short tally, got $RC. Output: $OUT"
fi

# --- Case L6: multi-bead, both entries present but a Status line MISSING -------
# Headers for both beads present, tally 2/2, but bd-l2 has no '- Status:' line.
# status_count (1) < n (2) must HARD-FAIL — guards the "headers-only" regression.
clear_fixtures
write_fixture "ConductorL" '[{"id":"bd-l1","status":"closed","labels":["infra"]},{"id":"bd-l2","status":"closed","labels":["infra"]}]'
PROG_NOSTATUS="$WORKDIR/progress-nostatus.md"
printf '%s\n' \
  'TARGET_BEADS=2' \
  'WAVE=test-wave' \
  '' \
  '### Bead bd-l1: first bead' \
  '- Status: COMPLETE' \
  '' \
  '### Bead bd-l2: second bead' \
  '- Commit: def456' \
  '' \
  'COMPLETED: 2 / 2' \
  >"$PROG_NOSTATUS"
OUT=$(GATE_AGENT="ConductorL" run_gate --progress "$PROG_NOSTATUS" 2>&1); RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -qi "Status line"; then
  pass "Case L6: entry present but missing Status line -> hard-fail (status_count<n)"
else
  fail "Case L6: expected non-zero exit citing Status-line shortfall, got $RC. Output: $OUT"
fi

# --- Case L7: --progress with no path argument -> loud exit 2, no hang ---------
clear_fixtures
write_fixture "ConductorL" '[{"id":"bd-l1","status":"closed","labels":["infra"]}]'
OUT=$(GATE_AGENT="ConductorL" run_gate --progress 2>&1); RC=$?
if [ "$RC" -eq 2 ] && echo "$OUT" | grep -qi "requires a path argument"; then
  pass "Case L7: trailing --progress with no value -> exit 2 (fails loud, no infinite loop)"
else
  fail "Case L7: expected exit 2 citing missing path, got $RC. Output: $OUT"
fi

# ============================================================================
# Case I: bleed check needs a real BASE..HEAD diff — put HEAD ahead of main.
# ============================================================================
git -C "$WORKDIR" checkout -q -b feature-bleed
# Change a PRE-EXISTING bead (bd-old1: closed -> open) OUTSIDE the claimed scope.
printf '%s\n' \
  '{"id":"bd-old1","status":"open","labels":["infra"]}' \
  '{"id":"bd-old2","status":"open","labels":["infra"]}' \
  >"$WORKDIR/.beads/issues.jsonl"
git -C "$WORKDIR" commit -aq -m "chore: touch bd-old1 out of scope"

clear_fixtures
write_fixture "ConductorA" '[{"id":"bd-a","status":"closed","labels":["infra"]}]'
OUT=$(GATE_AGENT="ConductorA" run_gate 2>&1); RC=$?
if echo "$OUT" | grep -qi "cross-branch bleed" && echo "$OUT" | grep -q "bd-old1" && [ "$RC" -eq 0 ]; then
  pass "Case I: out-of-scope pre-existing bead change WARNS via JSONL bleed check (non-blocking, exit 0)"
else
  fail "Case I: expected bleed warning naming bd-old1 + exit 0, got $RC. Output: $OUT"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All beads-closed-gate.sh fixture tests passed."
  exit 0
else
  echo "$FAILURES fixture test(s) FAILED."
  exit 1
fi
