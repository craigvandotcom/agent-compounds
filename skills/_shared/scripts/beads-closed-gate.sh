#!/usr/bin/env bash
# beads-closed-gate.sh — BEADS-CLOSED-GATE: the loop's own pre-merge gate
# (ac-batch-close no longer checks beads itself).
#
# TRUNK-DIRECT REWRITE (bd-u2lo1.7): under trunk-direct there is no wave
# branch and no commit range to scope against. Work partitioning is now
# CLAIM-AT-SELECTION — a conductor marks its whole selected batch
# `in_progress` + assignee (its Agent Mail AGENT_NAME) at selection time,
# BEFORE any implementation (see ac-loop Phase 1/2, ac-implement Phase 1a).
# The gate's scope is therefore simply: `br list` filtered to
# `assignee == <conductor> && status != closed`. No commit-trailer parsing,
# no merge-base range computation, no wave-label lookup, no L4-gate-handoff
# plumbing remains — the assignee IS the scope.
#
# Assignee comes from $1 if given, else from `$AGENT_NAME` (the conductor's
# Agent Mail identity, exported earlier in the invoking skill's session) —
# this keeps the existing zero-arg invocation surface working as long as
# AGENT_NAME is exported in the SAME shell call (exports don't persist
# across bash tool calls — re-assert it in the call that runs this script).
#
# Prints the set of genuinely open, IN-SCOPE beads: status != closed,
# EXCLUDING `post-merge`-labelled beads — those are deliberately un-closeable
# until the merge ships (carried forward as known tails, listed in the PR
# body), never blockers.
#
# Exit 0 — the in-scope open set is empty: safe to proceed to ac-batch-close.
# Exit 1 — genuinely open (non-post-merge) beads remain IN SCOPE: do NOT merge.
# Exit 2 — br/jq query itself failed, or no assignee could be determined.
set -o pipefail

ASSIGNEE="${1:-${AGENT_NAME:-}}"
if [ -z "$ASSIGNEE" ]; then
  echo "beads-closed-gate: no assignee provided — pass it as \$1 or export AGENT_NAME before calling this script" >&2
  exit 2
fi

# --- Out-of-scope bead-status-bleed check (non-blocking; bd-vtrlm) ---
# Detects whether this run's own .beads/issues.jsonl diff touches any
# PRE-EXISTING bead ID outside this conductor's own claimed (in-scope) set.
# A match means `br sync --flush-only` picked up a concurrent session's
# transient bead status (br sync exports the FULL local DB, not a scoped
# diff) -- flag it, don't block (often self-healing; see memory
# br-sync-exports-full-db-cross-branch-bleed). $1 = space/newline-separated
# in-scope id list (may be empty -- an empty declared scope means nothing
# claimed, so ANY pre-existing changed id is flagged). UNCHANGED in
# behavior from the wave-branch era -- only what feeds `in_scope` changed
# (assignee-derived claim set instead of a commit-trailer/wave-label set).
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

BASE_REF=$(git merge-base origin/main HEAD 2>/dev/null || git merge-base main HEAD 2>/dev/null)
if [ -z "$BASE_REF" ]; then
  echo "beads-closed-gate: could not determine merge-base with main" >&2
  exit 2
fi

# `br list --json` paginates (default --limit 50); --limit 0 = unlimited, so
# a single call always returns this conductor's FULL claimed set regardless
# of batch size. `-a`/`--all` includes closed beads too — needed so the
# bleed check's in-scope id list covers beads this conductor claimed AND has
# already closed (a closed-but-claimed id must not read as "out of scope").
FULL_CLAIMED=$(br list --json --limit 0 --all --assignee "$ASSIGNEE" | jq '.issues') || exit 2

OPEN=$(echo "$FULL_CLAIMED" | jq \
  '[.[] | select(.status != "closed") | select((.labels // []) | index("post-merge") | not)]') || exit 2

IN_SCOPE_IDS=$(echo "$FULL_CLAIMED" | jq -r '.[].id' | sort -u)
warn_bead_bleed "$IN_SCOPE_IDS"

echo "$OPEN"
[ "$(printf '%s' "$OPEN" | jq 'length')" -eq 0 ]
