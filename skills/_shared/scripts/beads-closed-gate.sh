#!/usr/bin/env bash
# beads-closed-gate.sh — BEADS-CLOSED-GATE: the loop's own pre-close gate
# (ac-batch-close no longer checks beads itself).
#
# TRUNK-DIRECT REWRITE (bd-u2lo1.7): under trunk-direct there is no wave
# branch and no commit range to scope against. Work partitioning is now
# CLAIM-AT-SELECTION — a conductor marks its whole selected batch
# `in_progress` + assignee (its Agent Mail AGENT_NAME) at selection time,
# BEFORE any implementation (see ac-loop Phase 1/2, ac-implement Phase 1a).
# The gate's scope is therefore simply: `br list` filtered to
# `assignee ∈ <identities> && status != closed`. No commit-trailer parsing,
# no merge-base range computation, no wave-label lookup — the assignee IS the
# scope.
#
# UNION OF IDENTITIES (bd-w504y): a single batch may be claimed under MORE
# THAN ONE Agent Mail identity. ac-loop claims the batch under its own name
# (e.g. BlueLake), but a delegated ac-implement session self-registers a
# DIFFERENT name (e.g. SunnyBear; ac-loop's name is NOT inherited) and its
# incremental/replacement-bead claims land under THAT identity. Querying only
# the loop identity silently MISSES the delegate's open beads → a fail-OPEN of
# the exact safety gate. So this gate now accepts ONE OR MORE assignees (every
# positional arg = the union) and checks the UNION of their claimed sets.
#   The invoking skill MUST pass every identity that claimed into this batch:
#   the loop identity PLUS each delegated ac-implement identity it was told
#   about (ac-implement reports its registered name back in its summary, and
#   ALSO threads the conductor's claim identity onto its incremental claims —
#   belt-and-suspenders, see ac-implement Phase 1a). If no positional assignee
#   is given, $AGENT_NAME is the sole fallback identity.
#
# FAIL-CLOSED (bd-w504y): the gate must never quietly say "safe to close" when
# it cannot actually see the batch.
#   * No assignee determinable (no positional arg, no $AGENT_NAME) → exit 2.
#   * The UNION claimed-set is EMPTY — every given identity returns zero beads,
#     even with `--all` — → the gate is being asked about a batch that nothing
#     is claimed under, which almost always means the assignee set is
#     wrong/incomplete (a delegated identity was dropped) = fail-open risk. So
#     warn loudly and exit 2, UNLESS `--allow-empty` is passed (the caller has
#     asserted the board is legitimately empty).
#
# Assignees come from the positional args if any; else from `$AGENT_NAME` (the
# conductor's Agent Mail identity, exported earlier in the invoking skill's
# session). Exports don't persist across bash tool calls — re-assert AGENT_NAME
# in the SAME call that runs this script, or pass the identities explicitly.
#
# Prints the set of genuinely open, IN-SCOPE beads (union across identities):
# status != closed, EXCLUDING `post-merge`-labelled beads — those are
# deliberately un-closeable until the merge ships (carried forward as known
# tails, listed in the PR body), never blockers.
#
# Exit 0 — the union in-scope open set is empty: safe to proceed to ac-batch-close.
# Exit 1 — genuinely open (non-post-merge) beads remain in the union: do NOT close.
# Exit 2 — br/jq query failed, no assignee determinable, OR empty claimed-set
#          without --allow-empty (fail-closed).
#
# Usage: beads-closed-gate.sh [--allow-empty] <assignee1> [assignee2 ...]
#        beads-closed-gate.sh                 # falls back to $AGENT_NAME
set -o pipefail

# --- Out-of-scope bead-status-bleed check (non-blocking; bd-vtrlm) ---
# Detects whether this run's own .beads/issues.jsonl diff touches any
# PRE-EXISTING bead ID outside this conductor's own claimed (in-scope) set.
# A match means `br sync --flush-only` picked up a concurrent session's
# transient bead status (br sync exports the FULL local DB, not a scoped
# diff) -- flag it, don't block (often self-healing; see memory
# br-sync-exports-full-db-cross-branch-bleed). $1 = space/newline-separated
# in-scope id list (may be empty -- an empty declared scope means nothing
# claimed, so ANY pre-existing changed id is flagged). NOTE: .beads/issues.jsonl
# is JSON LINES (one bead object per line) — `jq -r '.id'` streams it directly;
# feeding it a single `[...]` JSON array breaks the stream (jq: "Cannot index
# array with \"id\"") and silently voids this check.
warn_bead_bleed() {
  local in_scope="$1"
  local old_ids changed_ids preexisting_changed out_of_scope
  old_ids=$(git show "${BASE_REF}:.beads/issues.jsonl" 2>/dev/null | jq -r '.id' | sort -u)
  changed_ids=$(git diff --unified=0 "${BASE_REF}..HEAD" -- .beads/issues.jsonl 2>/dev/null \
    | grep -E '^\+\{' | sed -E 's/^\+//' | jq -r '.id' 2>/dev/null | sort -u)
  preexisting_changed=$(comm -12 <(printf '%s\n' "$old_ids") <(printf '%s\n' "$changed_ids"))
  out_of_scope=$(comm -23 <(printf '%s\n' "$preexisting_changed" | sort -u) <(printf '%s\n' "$in_scope" | sort -u))
  if [ -n "$out_of_scope" ]; then
    echo "beads-closed-gate: WARNING -- this run's .beads/issues.jsonl diff changes bead(s) outside its own claimed scope (br sync cross-branch bleed -- see memory br-sync-exports-full-db-cross-branch-bleed):" >&2
    printf '  %s\n' $out_of_scope >&2
  fi
}

# --- Parse flags + collect the union of assignee identities ---
ALLOW_EMPTY=0
ASSIGNEES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --allow-empty) ALLOW_EMPTY=1; shift ;;
    --) shift ;;
    *) ASSIGNEES+=("$1"); shift ;;
  esac
done

# Fall back to $AGENT_NAME only when no positional identity was given.
if [ "${#ASSIGNEES[@]}" -eq 0 ] && [ -n "${AGENT_NAME:-}" ]; then
  ASSIGNEES=("$AGENT_NAME")
fi
if [ "${#ASSIGNEES[@]}" -eq 0 ]; then
  echo "beads-closed-gate: no assignee provided — pass one or more identities as positional args (loop identity + each delegated ac-implement identity), or export AGENT_NAME before calling this script" >&2
  exit 2
fi

# HARD RULE (bd-w504y / ac-ycr.6; doctrine: _shared/agent-identity.md): FoggyCreek
# is the Tier-2 chore identity and may NEVER claim beads or be a gate assignee.
# A claimed-set under FoggyCreek always means a conductor fell back to the
# settings.json AGENT_NAME=FoggyCreek default instead of re-asserting its minted
# Tier-1 name — a misattribution that would otherwise surface only as a confusing
# empty/foreign claimed-set downstream. Reject it LOUDLY here, BEFORE the union
# claimed-set query, converting silent misattribution into an immediate error.
# (Checks the fully-resolved set, so a FoggyCreek fallback via $AGENT_NAME is
# caught too, not only an explicit positional arg.)
for a in "${ASSIGNEES[@]}"; do
  if [ "$a" = "FoggyCreek" ]; then
    echo "beads-closed-gate: REJECTED — 'FoggyCreek' is the Tier-2 chore identity and may NEVER claim beads or be a gate assignee (HARD RULE, _shared/agent-identity.md)." >&2
    echo "  A gate query under FoggyCreek means a conductor fell back to the settings.json AGENT_NAME default instead of re-asserting its minted Tier-1 name." >&2
    echo "  Pass the conductor's actual minted identity (plus each delegated ac-implement identity), never FoggyCreek." >&2
    exit 2
  fi
done

BASE_REF=$(git merge-base origin/main HEAD 2>/dev/null || git merge-base main HEAD 2>/dev/null)
if [ -z "$BASE_REF" ]; then
  echo "beads-closed-gate: could not determine merge-base with main" >&2
  exit 2
fi

# `br list --json` paginates (default --limit 50); --limit 0 = unlimited, so a
# single call always returns an identity's FULL claimed set regardless of batch
# size. `-a`/`--all` includes closed beads too — needed so the bleed check's
# in-scope id list covers beads an identity claimed AND has already closed (a
# closed-but-claimed id must not read as "out of scope"). Query each identity,
# then UNION the results (dedupe by id).
FULL_CLAIMED="[]"
for a in "${ASSIGNEES[@]}"; do
  part=$(br list --json --limit 0 --all --assignee "$a" | jq '.issues') || exit 2
  FULL_CLAIMED=$(jq -s 'add | unique_by(.id)' \
    <(printf '%s' "$FULL_CLAIMED") <(printf '%s' "$part")) || exit 2
done

# FAIL-CLOSED: an empty union claimed-set means the gate can't see any batch
# under the identities it was handed — refuse to green-light unless overridden.
CLAIMED_COUNT=$(printf '%s' "$FULL_CLAIMED" | jq 'length') || exit 2
if [ "$CLAIMED_COUNT" -eq 0 ] && [ "$ALLOW_EMPTY" -ne 1 ]; then
  echo "beads-closed-gate: FAIL-CLOSED — the union claimed-set is EMPTY for assignee(s): ${ASSIGNEES[*]}" >&2
  echo "  A batch was expected to be claimed under one of these identities, but br returned zero beads." >&2
  echo "  This usually means the wrong/incomplete assignee set was passed (a delegated ac-implement identity is missing)." >&2
  echo "  Refusing to report 'safe to close'. Pass EVERY claiming identity, or --allow-empty if the board is genuinely empty." >&2
  exit 2
fi

OPEN=$(echo "$FULL_CLAIMED" | jq \
  '[.[] | select(.status != "closed") | select((.labels // []) | index("post-merge") | not) | select(.issue_type != "epic")]') || exit 2

IN_SCOPE_IDS=$(echo "$FULL_CLAIMED" | jq -r '.[].id' | sort -u)
warn_bead_bleed "$IN_SCOPE_IDS"

echo "$OPEN"
[ "$(printf '%s' "$OPEN" | jq 'length')" -eq 0 ]
