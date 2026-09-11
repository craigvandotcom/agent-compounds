#!/usr/bin/env bash
# plan-approve.sh — the ONE writer of plan approval. Sibling of polish-fixpoint.sh and
# stamp-refined.sh; never a fifth fixpoint mode, never a hand edit (ac-wp8i.10).
#
# Three checks, then three keys:
#   1. the plan carries the polish stamp keys (a plan nobody polished is not approvable)
#   2. a `## Decisions` section exists
#   3. zero Decision cards stand in state needs-human — the state token LINE-INITIAL
#      inside the `## Decisions` section (never a bare string match; plan prose
#      legitimately carries the word). Card canon: ac-plan/references/decisions.md.
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
if ! grep -q '^polish_rounds:' "$PLAN" || ! grep -q '^polish_fixpoint_' "$PLAN"; then
  echo "REFUSED not-polished: $PLAN carries no polish stamp keys (polish_rounds / polish_fixpoint_*)"
  exit 1
fi

if ! grep -q '^## Decisions' "$PLAN"; then
  echo "REFUSED no-decisions: $PLAN carries no ## Decisions section"
  exit 1
fi

# Decision cards in state needs-human.
#
# WHY THIS SHAPE (2026-09-11, ac-1p7j). The previous matcher required the literal `DECISION`
# and the token `needs-human` on the SAME `-` bullet. Nothing prescribes that co-occurrence:
# `ac-plan/references/decisions.md`, `ac-plan/SKILL.md` step 3, `ac-polish/references/
# plan-checklist.md` and `ac-beadify/SKILL.md` all give the state vocabulary as exactly two
# tokens, `settled:` and `needs-human`, and `DECISION` appears in the canon ONLY as step 3b's
# record of a human's ANSWER (`DECISION (<human>): <choice> — <why>`) — i.e. on a card that is
# already SETTLED. The matcher therefore demanded a token that only appears on closed cards
# while hunting for open ones, and matched 0 lines in every real plan: measured against
# easy-mode `_plans/2026-09-11-0851-model-gateway.md`, which carried an open card and was
# handed APPROVED. Four documents against one regex: the DOCUMENTS are authoritative and the
# regex is the side that moved.
#
# THE RULE: inside the `## Decisions` section, a card's state is the LINE-INITIAL token —
# the first word on its line once a list marker, an optional `state` label and markdown
# decoration (backticks, bold) are stripped. Both card shapes in use satisfy it:
#   - **state** — `needs-human`              (decisions.md's prescribed bullet)
#   `needs-human — already owned by bd-2mik` (the heading-per-card shape plans emit)
# Prose cannot reach it: `settled: … the needs-human escalation was rejected` leads with
# `settled:`, and a narrative sentence leads with its own first word. Scoping to the section
# keeps the rest of the plan free to discuss the state by name.
# It fails CLOSED — a prose line that happens to open with the token refuses, and a refusal
# is a human reading the plan, never a plan through the gate unread.
DEC_SECTION=$(awk '/^## Decisions/{inx=1;next} inx && /^## /{inx=0} inx' "$PLAN")
NEEDS_HUMAN_RE='^[[:space:]]*([-*+][[:space:]]+)?((\*\*)?state:?(\*\*)?:?[[:space:]]*(—|–|-|:)?[[:space:]]*)?[`*_]*needs-human([^a-z-]|$)'
OPEN=$(printf '%s\n' "$DEC_SECTION" | grep -cE "$NEEDS_HUMAN_RE")
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
