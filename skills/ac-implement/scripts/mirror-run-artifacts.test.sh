#!/usr/bin/env bash
#
# mirror-run-artifacts.test.sh — RED/GREEN proof harness for mirror-run-artifacts.sh.
#
# ASSURANCE
#   PROBE:      this file IS the probe — bash skills/ac-implement/scripts/mirror-run-artifacts.test.sh
#   SCHEDULE:   every scripts/run-all-harnesses.sh run (repo-wide *.test.sh discovery),
#               which lint.sh Check 20 audits for scheduling.
#   MODE:       blocking
#   ON-FAILURE: closed
#
# It proves the checkpoint leg:
#   - refuses to run without a run id (nothing to scope the mirror against);
#   - mirrors the run's /tmp-mortal files AND directories into <dest>/artifacts/;
#   - is IDEMPOTENT — a second run copies over the same destination without error
#     and without duplicating the mirrored set;
#   - prints what it mirrored;
#   - honours an explicit --dest.
#
# The real /tmp is never touched: every case drives the script against a scratch
# $AC2_MIRROR_SCRATCH root so it is hermetic and portable.
#
# Exit 0  every case passed · 77 self-skip (precondition this harness cannot provision)
# Exit 1  at least one case failed
#
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
GATE="$HERE/mirror-run-artifacts.sh"

PASS=0
FAIL=0
ok()   { PASS=$(( PASS + 1 )); echo "  ok   — $*"; }
bad()  { FAIL=$(( FAIL + 1 )); echo "  FAIL — $*"; }

if [ ! -x "$GATE" ]; then
  echo "mirror-run-artifacts.test: mirror-run-artifacts.sh missing or not executable at $GATE"
  exit 1
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/ac-mirror-test.XXXXXX") || { echo "mirror-run-artifacts.test: cannot create scratch dir"; exit 1; }
trap 'rm -rf "$WORK"' EXIT

# A scratch "run" that mimics the /tmp layout a swarm run leaves behind: a run-id
# embedded in file names (ac-*.swarm-<RUN>*.txt) and a run-scoped directory.
RUN="20260907-exhaust"
SCRATCH="$WORK/scratch"
mkdir -p "$SCRATCH" "$WORK/dest"
printf 'claim one\n'    > "$SCRATCH/ac-claim.swarm-$RUN-GreenTree.txt"
printf 'worker one\n'   > "$SCRATCH/ac-worker.swarm-$RUN-GreenTree.txt"
printf 'msg one\n'      > "$SCRATCH/ac-msg.swarm-$RUN-GreenTree.txt"
# a non-run file that shares a numeric prefix but not the full run id — must NOT be mirrored
printf 'unrelated\n'    > "$SCRATCH/ac-claim.swarm-20260907-GreenTree.txt"
# a run-scoped DIRECTORY (bead-work / swarm-<RUN>-<name>)
mkdir -p "$SCRATCH/swarm-$RUN-GreenTree"
printf 'progress one\n' > "$SCRATCH/swarm-$RUN-GreenTree/progress.md"

# --- refusal without --run -----------------------------------------------------------
out="$(AC2_MIRROR_SCRATCH="$SCRATCH" bash "$GATE" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q -- '--run' \
  && ok "refuses without --run, naming the flag" \
  || bad "missing --run did not refuse (rc=$rc): $out"

# --- mirrors run-scoped files and dirs into <dest>/artifacts/ -----------------------
DEST="$WORK/dest"
AC2_MIRROR_SCRATCH="$SCRATCH" bash "$GATE" --run "$RUN" --dest "$DEST" >"$WORK/out1" 2>&1
art="$DEST/artifacts"
[ -f "$art/ac-claim.swarm-$RUN-GreenTree.txt" ] \
  && [ -f "$art/ac-worker.swarm-$RUN-GreenTree.txt" ] \
  && [ -f "$art/ac-msg.swarm-$RUN-GreenTree.txt" ] \
  && [ -f "$art/swarm-$RUN-GreenTree/progress.md" ] \
  && ok "run-scoped files and the run dir are mirrored under artifacts/" \
  || bad "run-scoped artifacts not mirrored: $(ls -1 "$art" 2>/dev/null | tr '\n' ' ')"
[ ! -e "$art/ac-claim.swarm-20260907-GreenTree.txt" ] \
  && ok "a name sharing only a numeric prefix (not the full run id) is left alone" \
  || bad "non-run file was mirrored"

# --- idempotent: a second run succeeds without duplicating --------------------------
before=$(find "$art" -type f | wc -l | tr -d ' ')
AC2_MIRROR_SCRATCH="$SCRATCH" bash "$GATE" --run "$RUN" --dest "$DEST" >"$WORK/out2" 2>&1; rc=$?
after=$(find "$art" -type f | wc -l | tr -d ' ')
[ "$rc" -eq 0 ] && [ "$after" -eq "$before" ] && [ "$after" -gt 0 ] \
  && ok "idempotent — second run exits 0 and mirrors the same set without duplicating" \
  || bad "second run not idempotent (rc=$rc, files $before -> $after)"

# --- prints what it mirrored --------------------------------------------------------
printf '%s\n' "$(<"$WORK/out1")" | grep -q 'mirrored' \
  && ok "prints what it mirrored" \
  || bad "did not print a mirror summary: $(<"$WORK/out1")"

echo ""
echo "mirror-run-artifacts.test: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
