#!/usr/bin/env bash
# return-hold.sh — the return path for a worker-held bead that needs a human
# decision (a prod-write authorization fork, or any hold the next worker must
# not claim through). A return that lives only in comment prose is invisible to
# every eligibility filter — the bead stays refined and claimable, and the next
# worker proceeds (bd-0yu7v: two prose returns, then a third worker ran
# --execute against prod). This script applies board state, never prose alone:
#
#   1. adds the `human-gate` label (pick.sh excludes human-gate beads: UN-claimable)
#   2. records a `Gate-reason: <reason>` marker comment (the trace a GATED line names)
#   3. releases the claim (status open, assignee "") so no worker holds it
#
# Idempotent: re-running skips the label when present and the marker when
# recorded. Reads and writes go through `$AC2_BR_CMD` (as pick.sh does) so the
# proof harness can stub the board.
#
# Usage:  return-hold.sh <id> --reason <reason> [--actor NAME]
# Exit:   0 the hold landed (or already held) · 1 a write failed, hold uncertain
# Env:    AC2_BR_CMD — the br binary (default: br)
#
#   PROBE:      bash skills/ac-implement/scripts/return-hold.test.sh
#   SCHEDULE:   worker §4 every authorization-fork return · run-all-proofs.sh
#   MODE:       blocking
#   ON-FAILURE: closed — a failed hold exits non-zero; the worker retains the
#               claim and hands back, never unclaims-and-leaves it claimable
#
set -uo pipefail

BR="${AC2_BR_CMD:-br}"
ID=""
REASON=""
ACTOR=""

while [ $# -gt 0 ]; do
  case $1 in
    --reason) REASON=${2-}; shift 2 ;;
    --actor) ACTOR=${2-}; shift 2 ;;
    --*) echo "return-hold.sh: unknown argument: $1" >&2; exit 1 ;;
    *) if [ -n "$ID" ]; then echo "return-hold.sh: unexpected argument: $1" >&2; exit 1; fi
       ID=$1; shift ;;
  esac
done

[ -n "$ID" ] || { echo "return-hold.sh: a bead id is required" >&2; exit 1; }
[ -n "$REASON" ] || { echo "return-hold.sh: --reason is required (e.g. authorization)" >&2; exit 1; }
[ -n "$ACTOR" ] || { echo "return-hold.sh: --actor is required" >&2; exit 1; }

export RUST_LOG=error

_HOLD_TOOLS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../_tools" && pwd)"
# shellcheck source=../../_tools/br-call.sh
. "$_HOLD_TOOLS_DIR/br-call.sh"

MARKER="Gate-reason: $REASON"

# 1 — label, skipped when already held. The board read routes through br_call:
# with --json a br failure is a VALID error envelope on stdout, so a raw read
# would convert a dead board into "no labels" and skip the hold (Check 36).
show_json=$(br_call show --json "$ID") \
  || { echo "return-hold.sh: could not read $ID — hold uncertain, claim retained" >&2; exit 1; }
labels=$(printf '%s' "$show_json" | jq -r '.[0].labels // [] | .[]') \
  || { echo "return-hold.sh: could not parse $ID — hold uncertain, claim retained" >&2; exit 1; }
held=0
while IFS= read -r lab; do
  [ "$lab" = "human-gate" ] && held=1
done <<EOF
$labels
EOF
if [ "$held" -eq 0 ]; then
  RUST_LOG=error "$BR" update "$ID" --add-label human-gate --actor "$ACTOR" >/dev/null \
    || { echo "return-hold.sh: could not label $ID human-gate — hold uncertain, claim retained" >&2; exit 1; }
fi

# 2 — marker comment, skipped when already recorded.
if ! RUST_LOG=error "$BR" comments list "$ID" 2>/dev/null | grep -qF "$MARKER"; then
  f=$(mktemp) || { echo "return-hold.sh: could not stage the marker — hold uncertain, claim retained" >&2; exit 1; }
  {
    printf '%s\n' "$MARKER"
    printf 'Returned by %s: this bead needs a human decision before any worker claims it. ' "$ACTOR"
    printf 'Prose alone never holds — the human-gate label above is the hold.\n'
  } > "$f"
  RUST_LOG=error "$BR" comments add "$ID" -f "$f" --actor "$ACTOR" >/dev/null
  rc=$?
  rm -f "$f"
  [ "$rc" -eq 0 ] \
    || { echo "return-hold.sh: could not record the marker on $ID — hold uncertain, claim retained" >&2; exit 1; }
fi

# 3 — release the claim. The label (step 1) is the exclusion; an unclaim failure
# leaves the bead held-but-claimed, so it still fails loud, never silent.
RUST_LOG=error "$BR" update "$ID" --status open --assignee "" --actor "$ACTOR" >/dev/null \
  || { echo "return-hold.sh: hold applied but the claim could not be released — retry, never leave silently" >&2; exit 1; }

echo "return-hold: $ID held (human-gate + '$MARKER'), claim released"
