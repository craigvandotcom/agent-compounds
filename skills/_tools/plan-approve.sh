#!/usr/bin/env bash
# plan-approve.sh — the ONE writer of plan approval. Sibling of polish-fixpoint.sh and
# stamp-refined.sh; never a fifth fixpoint mode, never a hand edit (ac-wp8i.10).
#
# Three checks, then three keys:
#   1. the plan carries the polish stamp keys (a plan nobody polished is not approvable)
#   2. a `## Decisions` section exists
#   3. zero Decision cards stand in state needs-human (the state token on a Decision
#      bullet — never a bare string match; plan prose legitimately carries the word)
# On success it writes status: loop-ready, loop_ready_at, approved_by — nothing else.
# Deliberately no digest binding: beadify follows approval within seconds, and a digest
# chain is unreconstructable on re-polished plans (plan 2026-09-05-2318 v2).
#
# Verdict tokens (one greppable line each):
#   APPROVED · REFUSED needs-human N · REFUSED no-decisions · REFUSED not-polished · NOT-GATED
#
# Usage: plan-approve.sh <plan-path> [approved-by]
# Env:   APPROVED_BY (arg 2 overrides); AM_SELF / BR_AGENT_NAME as fallback identity
set -u
PLAN="${1:-}"
WHO="${2:-${APPROVED_BY:-${AM_SELF:-${BR_AGENT_NAME:-human}}}}"

if [ -z "$PLAN" ] || [ ! -r "$PLAN" ]; then
  echo "NOT-GATED: plan missing or unreadable: ${PLAN:-<none>}"
  exit 2
fi

# The polish stamp keys (written by polish-fixpoint.sh --mode plan) must both be present.
if ! grep -q '^polish_rounds:' "$PLAN" || ! grep -q '^polish_fixpoint_sha256:' "$PLAN"; then
  echo "REFUSED not-polished: $PLAN carries no polish stamp keys (polish_rounds / polish_fixpoint_sha256)"
  exit 1
fi

if ! grep -q '^## Decisions' "$PLAN"; then
  echo "REFUSED no-decisions: $PLAN carries no ## Decisions section"
  exit 1
fi

# Decision cards in state needs-human: a Decision BULLET carrying the state token —
# matched as a token on a Decision bullet, never as a bare string anywhere in prose.
OPEN=$(grep -cE '^-.*DECISION.*(^|[^-a-z])needs-human([^a-z-]|$)|^-.*(^|[^-a-z])needs-human([^a-z-]|$).*DECISION' "$PLAN")
if [ "${OPEN:-0}" -gt 0 ]; then
  echo "REFUSED needs-human $OPEN: Decision card(s) still need a human ruling"
  exit 1
fi

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TMP="$(mktemp /tmp/plan-approve-XXXXXX)"
awk -v ts="$TS" -v who="$WHO" '
  BEGIN { infm=0 }
  NR==1 && $0=="---" { infm=1; print; next }
  infm && $0=="---" {
    if (!seen_status) printf "status: loop-ready\n"
    if (!seen_at)     printf "loop_ready_at: %s\n", ts
    if (!seen_by)     printf "approved_by: %s\n", who
    infm=0; print; next
  }
  infm && /^status:/        { printf "status: loop-ready\n"; seen_status=1; next }
  infm && /^loop_ready_at:/ { printf "loop_ready_at: %s\n", ts; seen_at=1; next }
  infm && /^approved_by:/   { printf "approved_by: %s\n", who; seen_by=1; next }
  infm && /^polish_rounds:/ { print; seen_status=seen_status; next }
  { print }
' "$PLAN" > "$TMP"
mv "$TMP" "$PLAN"
echo "APPROVED: $PLAN — status: loop-ready, loop_ready_at: $TS, approved_by: $WHO"
exit 0
