#!/usr/bin/env bash
# beads-closed-gate.sh — BEADS-CLOSED-GATE: the loop's own pre-merge gate
# (ac-merge no longer checks beads itself).
#
# Prints the set of genuinely open beads: status != closed, EXCLUDING
# `post-merge`-labelled beads — those are deliberately un-closeable until the
# merge ships (carried forward as known tails, listed in the PR body), never
# blockers.
#
# Exit 0 — the set is empty: safe to proceed to ac-merge.
# Exit 1 — genuinely open (non-post-merge) beads remain: do NOT merge.
# Exit 2 — br/jq query itself failed (treat as blocked, investigate).
set -o pipefail

OPEN=$(br list --json --limit 1000 | jq '[.issues[]
  | select(.status != "closed")
  | select((.labels // []) | index("post-merge") | not)]') || exit 2

echo "$OPEN"
[ "$(printf '%s' "$OPEN" | jq 'length')" -eq 0 ]
