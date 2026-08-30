#!/usr/bin/env bash
# polish-fixpoint.sh — the lean polish stamp gate. ONE engine, two modes (plan · bead).
#
# It MEASURES and it GATES. It drives nothing and it delegates to no model: the ac-polish
# SKILL runs a stateless reader per round, applies that round's findings, then calls this
# script to record the round and decide whether a stamp is earned. Keeping the measurement
# out of the thing being measured is the whole point — a loop that grades itself will
# always find itself clean.
#
# THE RECEIPT IS THE PRODUCT: a stamp is legal only against N recorded rounds whose LAST
# measured diff is empty, at round >= 2. A clean first round proves nothing — it is equally
# consistent with a reader that found everything and one that read nothing.
#
# ASSURANCE (ac-pipeline/references/assurance-declarations.md § The four fields):
#   PROBE:      skills/_tools/polish-fixpoint.test.sh — RED/GREEN over every verdict below
#   SCHEDULE:   once per polish round, from ac-polish's round step; and on every CI run
#               via scripts/run-all-harnesses.sh (registry-lint `harnesses` job)
#   MODE:       blocking
#   ON-FAILURE: closed   (no receipt, no stamp — the refusal is the feature)
#
# Usage:
#   polish-fixpoint.sh --state <dir> --artifact <path> --round <n> --pre <sha256>
#                      [--mode plan|bead|code] [--target <bead-id>] [--max-rounds 25|0] [--dry-run]
#
#   --pre  the artifact digest the SKILL observed BEFORE this round's reader ran. It is how
#          an out-of-band amendment is detected: if it does not match what the previous
#          round recorded, something edited the artifact from outside the loop.
#
# Exit codes (assurance-declarations § NOT-GATED):
#   0  STAMPED — fixpoint proven and the stamp written
#   1  refused — CONTINUE, round-1-clean, bound-exhausted, or an out-of-band amendment
#   2  NOT-GATED — usage or setup error; nothing was measured, so nothing is claimed
#
# Every verdict prints one greppable `polish-fixpoint: <TOKEN>` line. Callers branch on the
# token, never on stdout prose.
set -euo pipefail

die2() { printf 'polish-fixpoint: NOT-GATED %s\n' "$*" >&2; exit 2; }

MODE=plan TARGET="" ARTIFACT="" STATE="" ROUND="" PRE="" MAX=25 DRYRUN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --mode)       MODE="${2:-}"; shift 2 ;;
    --target)     TARGET="${2:-}"; shift 2 ;;
    --artifact)   ARTIFACT="${2:-}"; shift 2 ;;
    --state)      STATE="${2:-}"; shift 2 ;;
    --round)      ROUND="${2:-}"; shift 2 ;;
    --pre)        PRE="${2:-}"; shift 2 ;;
    --max-rounds) MAX="${2:-}"; shift 2 ;;
    --dry-run)    DRYRUN=1; shift ;;
    -h|--help)    sed -n '20,32p' "$0"; exit 2 ;;
    *)            die2 "unknown argument: $1" ;;
  esac
done

[ -n "$STATE" ]    || die2 "--state is required"
[ -n "$ARTIFACT" ] || die2 "--artifact is required"
[ -f "$ARTIFACT" ] || die2 "artifact does not exist: $ARTIFACT"
[ -n "$PRE" ]      || die2 "--pre is required (the digest observed before this round's reader)"
case "$MODE" in plan|bead|code) ;; *) die2 "--mode must be plan, bead or code (got '$MODE')" ;; esac
case "$ROUND" in ''|*[!0-9]*) die2 "--round must be a positive integer (got '$ROUND')" ;; esac
case "$MAX"   in ''|*[!0-9]*) die2 "--max-rounds must be a non-negative integer, 0 to disable the runaway guard (got '$MAX')" ;; esac
[ "$ROUND" -ge 1 ] || die2 "--round must be >= 1"
[ "$MODE" = plan ] || [ -n "$TARGET" ] || die2 "--mode $MODE requires --target <bead-id>"

digest() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else die2 "no shasum or sha256sum on PATH — cannot measure a diff"; fi
}

mkdir -p "$STATE"
POST=$(digest "$ARTIFACT")
PREV_FILE="$STATE/round-$((ROUND - 1)).sha"

# FROZEN INPUT. The loop measures its OWN edits; anything else moving the artifact means the
# input was never frozen, and extending the loop over a moving input is how a polish run
# reaches round 12. End it — do not extend it, and do not stamp it.
if [ "$ROUND" -ge 2 ]; then
  [ -f "$PREV_FILE" ] || die2 "round $ROUND has no round $((ROUND - 1)) on record in $STATE"
  PREV=$(cat "$PREV_FILE")
  if [ "$PRE" != "$PREV" ]; then
    printf 'polish-fixpoint: ENDED out-of-band-amendment round=%s — the artifact moved between rounds (recorded %s, observed %s). The input was not frozen; no stamp.\n' \
      "$ROUND" "${PREV:0:12}" "${PRE:0:12}"
    exit 1
  fi
fi

printf '%s' "$POST" > "$STATE/round-$ROUND.sha"

# A clean FIRST round is not a fixpoint. Round 1 has nothing to be identical to.
if [ "$ROUND" -eq 1 ]; then
  if [ "$PRE" = "$POST" ]; then
    printf 'polish-fixpoint: REFUSED round-1-clean — a clean first round proves nothing; run round 2 with a fresh reader.\n'
  else
    printf 'polish-fixpoint: CONTINUE round=1 — the reader changed the artifact; a fixpoint needs a clean round >= 2.\n'
  fi
  exit 1
fi

if [ "$POST" != "$PREV" ]; then
  # CYCLING. Matching a round older than the previous one means the artifact has returned to
  # a state it already held: readers are reverting each other and no further round converges.
  # A round count cannot tell this from slow progress. The digests can.
  CYCLE=""
  R=1
  while [ "$R" -le $((ROUND - 2)) ]; do
    if [ -f "$STATE/round-$R.sha" ] && [ "$POST" = "$(cat "$STATE/round-$R.sha")" ]; then
      CYCLE="$R"; break
    fi
    R=$((R + 1))
  done
  if [ -n "$CYCLE" ]; then
    printf 'polish-fixpoint: ENDED cycling round=%s matches round=%s — the artifact returned to a state it already held. More rounds cannot converge. Findings go to the human and NOTHING is stamped. Cycling indicts the CHECKLIST, not the artifact.\n' \
      "$ROUND" "$CYCLE"
    exit 1
  fi
  # RUNAWAY GUARD, not a quality bar. Convergence is decided by the fixpoint and cycling
  # tests, never by a round count. 0 disables the guard.
  if [ "$MAX" -ne 0 ] && [ "$ROUND" -ge "$MAX" ]; then
    printf 'polish-fixpoint: REFUSED bound-exhausted rounds=%s max=%s — no clean round within the runaway guard. Findings go to the human and NOTHING is stamped. Raise --max-rounds for a genuinely large set; routine exhaustion indicts the CHECKLIST.\n' \
      "$ROUND" "$MAX"
    exit 1
  fi
  printf 'polish-fixpoint: CONTINUE round=%s — diff non-empty; not a fixpoint.\n' "$ROUND"
  exit 1
fi

# Fixpoint: round >= 2 and this round changed nothing.
STAMPED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
RECEIPT="POLISH-FIXPOINT: mode=$MODE rounds=$ROUND sha256=$POST at=$STAMPED_AT engine=polish-fixpoint.sh"
printf '%s\n' "$RECEIPT" > "$STATE/receipt.txt"

if [ "$DRYRUN" -eq 1 ]; then
  printf 'polish-fixpoint: STAMPED mode=%s round=%s (dry-run — receipt at %s/receipt.txt, nothing written)\n' \
    "$MODE" "$ROUND" "$STATE"
  exit 0
fi

if [ "$MODE" = plan ]; then
  # SOLE WRITER of the plan-side stamp. Frontmatter only, and idempotent: re-stamping
  # replaces the three keys rather than appending a second, contradictory record.
  head -1 "$ARTIFACT" | grep -q '^---[[:space:]]*$' || die2 "plan has no YAML frontmatter to stamp: $ARTIFACT"
  TMP=$(mktemp)
  awk -v r="$ROUND" -v s="$POST" -v t="$STAMPED_AT" '
    NR==1 { print; infm=1; next }
    infm && /^---[[:space:]]*$/ {
      print "polish_rounds: " r; print "polish_fixpoint_sha256: " s; print "polish_stamped_at: " t
      print; infm=0; next }
    infm && /^polish_(rounds|fixpoint_sha256|stamped_at):/ { next }
    { print }' "$ARTIFACT" > "$TMP"
  cat "$TMP" > "$ARTIFACT"
  rm -f "$TMP"
else
  # Bead-side receipt. `code` shares this writer: a code scope owns no record of its own, so
  # its receipt lands on the bead that owns the scope. The `refined` write is gated on THIS comment from inside
  # skills/_tools/stamp-refined.sh (ac-gv70) — a check a caller can route around is not a gate, so the
  # gating lives in the writer, not here. This script only produces the receipt it reads.
  command -v br >/dev/null 2>&1 || die2 "br not on PATH — cannot write the bead receipt"
  br comments add "$TARGET" -f "$STATE/receipt.txt" >/dev/null
fi

printf 'polish-fixpoint: STAMPED mode=%s round=%s sha256=%s\n' "$MODE" "$ROUND" "${POST:0:12}"
exit 0
