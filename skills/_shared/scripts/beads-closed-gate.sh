#!/usr/bin/env bash
# beads-closed-gate.sh — BEADS-CLOSED-GATE: the loop's own pre-merge gate
# (ac-merge no longer checks beads itself).
#
# WAVE-SCOPED (bd-h1tyu, fixed 2026-07-09): scopes to only the beads THIS
# branch owns, never the whole board. A board-wide `br list` that exits 1 on
# ANY open bead anywhere deadlocks every merge on a healthy multi-epic board
# (always has open work elsewhere) — see memory
# beads-closed-gate-board-wide-not-wave-scoped.
#
# Scope is determined two ways (either satisfies the bead's "commit trailers
# OR an explicit wave label" decision):
#   1. Default (no args): derive the bead-ID set from `Bead: <id>` commit
#      trailer LINES ONLY, found between this branch's merge-base with main
#      and HEAD (matches ac-implement's mandated commit template). Trailer-
#      only, exact-match, dot-suffix-preserving — inline/prose `bd-xxxxx`
#      mentions elsewhere in the commit body are deliberately EXCLUDED, since
#      matching them would both prefix-collide dot-suffixed child IDs (e.g.
#      `bd-19o6g.3` truncating to parent `bd-19o6g`) and pull in beads merely
#      referenced in prose (e.g. "deferred to bd-xxxxx") as if in scope.
#      Works uniformly for wave/* branches (many beads) and bug/* lane
#      branches (single bead) — no wave-label lookup needed.
#   2. Optional `$1` = explicit wave label (e.g. "wave-042"): scope to beads
#      carrying that label instead of parsing commits.
#
# Prints the set of genuinely open, IN-SCOPE beads: status != closed,
# EXCLUDING `post-merge`-labelled beads — those are deliberately un-closeable
# until the merge ships (carried forward as known tails, listed in the PR
# body), never blockers.
#
# Exit 0 — the in-scope open set is empty: safe to proceed to ac-merge.
# Exit 1 — genuinely open (non-post-merge) beads remain IN SCOPE: do NOT merge.
# Exit 2 — br/jq/git query itself failed (treat as blocked, investigate).
set -o pipefail

WAVE_LABEL="${1:-}"

ALL_OPEN=$(br list --json --limit 1000 | jq '[.issues[]
  | select(.status != "closed")
  | select((.labels // []) | index("post-merge") | not)]') || exit 2

if [ -n "$WAVE_LABEL" ]; then
  # Explicit label-scoped mode.
  OPEN=$(echo "$ALL_OPEN" | jq --arg label "$WAVE_LABEL" \
    '[.[] | select((.labels // []) | index($label))]') || exit 2
else
  # Default: derive the bead-ID set owned by this branch from `Bead: <id>`
  # commit trailer LINES ONLY (merge-base..HEAD) — exact-match, dot-suffix-
  # preserving. Inline/prose `bd-xxxxx` mentions elsewhere in the commit body
  # are deliberately excluded (prevents prefix-collision on dot-suffixed
  # child IDs and false-positive scope from prose references).
  BASE_REF=$(git merge-base origin/main HEAD 2>/dev/null || git merge-base main HEAD 2>/dev/null)
  if [ -z "$BASE_REF" ]; then
    echo "beads-closed-gate: could not determine merge-base with main" >&2
    exit 2
  fi

  LOG_OUTPUT=$(git log "${BASE_REF}..HEAD" --format=%B 2>/dev/null) || exit 2
  # grep exits 1 on "no matches" (e.g. branch has no commits yet, or none
  # carry a `Bead:` trailer) — that's a valid empty-scope result, not a
  # failure, so it's intentionally NOT `|| exit 2` here (pipefail would
  # otherwise trip). grep is line-oriented, so this naturally captures every
  # `Bead:` line across the full commit range, including multiple distinct
  # trailers inside one squashed/merged commit body.
  BEAD_IDS=$(printf '%s' "$LOG_OUTPUT" | grep -E '^Bead: ' | sed -E 's/^Bead: //' | sort -u)

  if [ -z "$BEAD_IDS" ]; then
    # No beads referenced by this branch's commits yet — nothing in scope.
    echo "[]"
    exit 0
  fi

  IDS_JSON=$(printf '%s\n' "$BEAD_IDS" | jq -R . | jq -s .) || exit 2
  OPEN=$(echo "$ALL_OPEN" | jq --argjson ids "$IDS_JSON" \
    '[.[] | select(.id as $i | $ids | index($i))]') || exit 2
fi

echo "$OPEN"
[ "$(printf '%s' "$OPEN" | jq 'length')" -eq 0 ]
