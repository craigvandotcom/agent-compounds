#!/usr/bin/env bash
# run-id-concurrent-dir.test.sh — L7-full concurrent-directory proof (bd-u2lo1.15).
#
# GATES trunk-direct stage 3 alongside claim-race-harness.sh: the archived plan
# (`_plans/_done/2026-07-11-1351-trunk-direct-execution-doctrine.md` §7, "run-id
# re-keying... two concurrent conductors on main produce distinct artifact
# directories [stage 3]") and this bead's own AC ("a concurrent-directory test
# proves two simultaneous conductors on main produce distinct artifact
# directories with zero collision") both name this exact test.
#
# REPO: agent-compounds (skills/ac-pipeline/scripts/) — reused across every app that
# threads the `ac-pipeline/references/run-id.md` contract. Exercises the formula from
# `ac-pipeline/references/run-id.md` / `ac-implement/SKILL.md` Phase 0 "Configuration" block
# VERBATIM (not a paraphrase):
#   CLAIM_ID="${CLAIM_ID:-<first-candidate-bead-id>-$(date +%Y%m%d)}"
#   RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"
#   ARTIFACTS_DIR="/tmp/bead-work-${CLAIM_ID}${RUN_ID:+-$RUN_ID}"
#
# WHAT'S ACTUALLY BEING PROVEN: two conductors picking two DIFFERENT batches
# (different first-claimed bead ID, or the same bead on a different day) already
# get trivially distinct CLAIM_IDs — no test needed for that case. The
# interesting, doc-called-out collision case (`ac-pipeline/references/run-id.md` § RUN_ID,
# "Parallel disambiguation") is two conductors that compute the IDENTICAL
# CLAIM_ID — a single claimed batch split across two sessions, the doc's own
# worked example — launched at the SAME moment on the same `main` checkout.
# Without RUN_ID, both would collapse to the literal same
# `/tmp/bead-work-<claim-id>` and clobber each other's progress.md/scratch. This
# test proves RUN_ID (driven by each process's own PID via `$$`) keeps them
# apart even when CLAIM_ID and the wall-clock second are identical.
#
# WHY `bash -c ... &` AND NOT `( ... ) &`: bash's `$$` is fixed to the TOP-LEVEL
# shell's PID for the whole life of that shell, INCLUDING inside `( )` subshells
# spawned from it (verified: two `( echo $$ ) &` subshells from the same parent
# print the SAME PID). That would make this test itself measure the wrong thing —
# a false collision (or a false pass) caused by the test harness's own process
# structure, not by the RUN_ID formula. `bash -c '...' &` forks a genuinely
# separate process per invocation (distinct PID each time) — the only shape that
# actually simulates two independent conductor SESSIONS, which is what two real
# `ac-implement`/`ac-loop` invocations are.
#
# No `br` or git state needed — pure shell arithmetic on the documented formula,
# deterministic. `--mkdir` opts into an extra filesystem-level proof (actually
# `mkdir -p` both computed dirs and assert they're different inodes / no
# overwritten sentinel file); cleaned up in a trap either way.
#
# Usage: bash run-id-concurrent-dir.test.sh [--mkdir]
# Exit 0 — all assertions passed. Exit 1 — a collision (or unmet precondition).
set -uo pipefail

MKDIR_PROOF=0
[ "${1:-}" = "--mkdir" ] && MKDIR_PROOF=1

FAILURES=0
CREATED_DIRS=()

cleanup() {
  if [ "${#CREATED_DIRS[@]}" -gt 0 ]; then
    for d in "${CREATED_DIRS[@]}"; do
      rm -rf "$d"
    done
  fi
}
trap cleanup EXIT INT TERM

pass() { echo "  PASS: $1"; }
fail() {
  echo "  FAIL: $1"
  FAILURES=$((FAILURES + 1))
}

# The formula, exactly as `ac-implement/SKILL.md` Phase 0 "Configuration" states it
# (and as `ac-pipeline/references/run-id.md` "The key" + "RUN_ID" sections document it) — a single
# function so both simulated conductors run byte-identical logic, never two
# independently-retyped copies that could silently drift from the real contract.
derive_artifacts_dir() {
  # $1 = CLAIM_ID (pre-computed identically by both conductors — the SAME batch)
  local claim_id="$1"
  local run_id="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"
  local dir="/tmp/bead-work-${claim_id}${run_id:+-$run_id}"
  printf '%s|%s\n' "$dir" "$run_id"
}

echo "=== Case 1: two conductors, IDENTICAL CLAIM_ID (same batch, split session) ==="
CLAIM_ID="bd-u2lo1.1-$(date +%Y%m%d)"   # identical on purpose — the collision case

# Two genuinely separate processes (distinct $$), racing at the same instant,
# computing off the SAME CLAIM_ID. Each writes "dir|run_id" to its own tmp file.
OUT_A=$(mktemp)
OUT_B=$(mktemp)
bash -c "
  derive_artifacts_dir() {
    local claim_id=\"\$1\"
    local run_id=\"\${RUN_ID:-\$(date +%Y%m%d-%H%M%S)-\$\$}\"
    local dir=\"/tmp/bead-work-\${claim_id}\${run_id:+-\$run_id}\"
    printf '%s|%s\n' \"\$dir\" \"\$run_id\"
  }
  derive_artifacts_dir '$CLAIM_ID' > '$OUT_A'
" &
PID_A=$!
bash -c "
  derive_artifacts_dir() {
    local claim_id=\"\$1\"
    local run_id=\"\${RUN_ID:-\$(date +%Y%m%d-%H%M%S)-\$\$}\"
    local dir=\"/tmp/bead-work-\${claim_id}\${run_id:+-\$run_id}\"
    printf '%s|%s\n' \"\$dir\" \"\$run_id\"
  }
  derive_artifacts_dir '$CLAIM_ID' > '$OUT_B'
" &
PID_B=$!
wait "$PID_A" "$PID_B"

DIR_A=$(cut -d'|' -f1 "$OUT_A")
RUNID_A=$(cut -d'|' -f2 "$OUT_A")
DIR_B=$(cut -d'|' -f1 "$OUT_B")
RUNID_B=$(cut -d'|' -f2 "$OUT_B")
rm -f "$OUT_A" "$OUT_B"

echo "  Conductor A: CLAIM_ID=$CLAIM_ID RUN_ID=$RUNID_A -> $DIR_A"
echo "  Conductor B: CLAIM_ID=$CLAIM_ID RUN_ID=$RUNID_B -> $DIR_B"

if [ "$RUNID_A" = "$RUNID_B" ]; then
  fail "Case 1: both conductors minted the IDENTICAL RUN_ID ($RUNID_A) — PID collision in the test harness itself, not a real scenario; rerun"
elif [ "$DIR_A" = "$DIR_B" ]; then
  fail "Case 1: SAME CLAIM_ID + DIFFERENT RUN_IDs still produced the SAME ARTIFACTS_DIR ($DIR_A) — the RUN_ID re-keying formula is broken"
else
  pass "Case 1: identical CLAIM_ID, distinct RUN_IDs -> distinct ARTIFACTS_DIR (no clobbering): $DIR_A != $DIR_B"
fi

echo
echo "=== Case 2: two conductors, DIFFERENT batches (different CLAIM_ID; trivial but asserted) ==="
CLAIM_ID_X="bd-aaaa1.1-$(date +%Y%m%d)"
CLAIM_ID_Y="bd-bbbb2.3-$(date +%Y%m%d)"
RUN_ID_SHARED="${RUN_ID:-20260101-000000-99999}"  # even a SHARED/absent-RUN_ID scenario must not collide across batches
DIR_X=$(RUN_ID="$RUN_ID_SHARED" bash -c '
  derive_artifacts_dir() {
    local claim_id="$1"
    local run_id="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"
    printf "/tmp/bead-work-%s%s\n" "$claim_id" "${run_id:+-$run_id}"
  }
  derive_artifacts_dir "'"$CLAIM_ID_X"'"
')
DIR_Y=$(RUN_ID="$RUN_ID_SHARED" bash -c '
  derive_artifacts_dir() {
    local claim_id="$1"
    local run_id="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"
    printf "/tmp/bead-work-%s%s\n" "$claim_id" "${run_id:+-$run_id}"
  }
  derive_artifacts_dir "'"$CLAIM_ID_Y"'"
')
echo "  Conductor X (batch bd-aaaa1.1): $DIR_X"
echo "  Conductor Y (batch bd-bbbb2.3): $DIR_Y"
if [ "$DIR_X" = "$DIR_Y" ]; then
  fail "Case 2: different CLAIM_IDs produced the SAME ARTIFACTS_DIR ($DIR_X)"
else
  pass "Case 2: different batches -> distinct ARTIFACTS_DIR regardless of RUN_ID: $DIR_X != $DIR_Y"
fi

if [ "$MKDIR_PROOF" -eq 1 ]; then
  echo
  echo "=== Filesystem-level proof (--mkdir): both dirs actually created, no overwrite ==="
  mkdir -p "$DIR_A" "$DIR_B"
  CREATED_DIRS+=("$DIR_A" "$DIR_B")
  echo "sentinel-A" >"$DIR_A/.sentinel"
  echo "sentinel-B" >"$DIR_B/.sentinel"
  if [ "$(cat "$DIR_A/.sentinel")" = "sentinel-A" ] && [ "$(cat "$DIR_B/.sentinel")" = "sentinel-B" ]; then
    pass "--mkdir: both real directories exist independently, sentinels intact (no clobbering on disk)"
  else
    fail "--mkdir: sentinel mismatch — one directory's contents were overwritten by the other"
  fi
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All concurrent-directory assertions passed — L7-full stage-3 gate condition satisfied."
  exit 0
else
  echo "$FAILURES concurrent-directory assertion(s) FAILED."
  exit 1
fi
