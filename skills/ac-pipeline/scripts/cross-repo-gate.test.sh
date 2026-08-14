#!/usr/bin/env bash
# cross-repo-gate.test.sh — canon + filter contract for the cross-repo label.
#
# Approach (a) exclusion-at-selection was superseded by agent-compounds b0fff17
# ("BCA implements cross-repo beads, commits in target repo"). This harness
# certifies THAT contract: a refined+cross-repo bead stays selectable, the
# canon defines the label, and the env table names the commit-in-owning-repo
# rule. Extract the filter from ac-implement/SKILL.md — do not hard-code it.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AC_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
IMPLEMENT="$AC_ROOT/skills/ac-implement/SKILL.md"
CANON="$AC_ROOT/skills/beads-standards/SKILL.md"
FAILURES=0
CASES=0

expect() {
  CASES=$((CASES + 1))
  if [ "$1" = 1 ]; then
    printf '  PASS  %s\n' "$2"
  else
    printf '  FAIL  %s\n' "$2"
    FAILURES=$((FAILURES + 1))
  fi
}

echo "--- extract ac-implement selection filter ---"
# First fenced `br ready --json | jq '[...]'` in the file is the :69 selection filter.
FILTER=$(grep -oE "br ready --json \| jq '\[[^']+\]'" "$IMPLEMENT" | head -1 | sed "s/^br ready --json | jq '//;s/'$//")
if [ -z "$FILTER" ]; then
  expect 0 "extracted a jq filter from ac-implement/SKILL.md"
  echo "cross-repo-gate.test: ${CASES} cases, ${FAILURES} failures"
  exit 1
fi
expect 1 "extracted a jq filter from ac-implement/SKILL.md"

BOARD=$(mktemp)
cat > "$BOARD" <<'JSON'
[
  {"id":"scratch-xrepo","labels":["refined","cross-repo"]},
  {"id":"scratch-plain","labels":["refined"]},
  {"id":"scratch-gate","labels":["refined","human-gate"]}
]
JSON
SELECTED=$(jq "$FILTER" "$BOARD")
XREPO=$(printf '%s' "$SELECTED" | jq '[.[] | select(.id=="scratch-xrepo")] | length')
PLAIN=$(printf '%s' "$SELECTED" | jq '[.[] | select(.id=="scratch-plain")] | length')
GATE=$(printf '%s' "$SELECTED" | jq '[.[] | select(.id=="scratch-gate")] | length')
rm -f "$BOARD"

# b0fff17: cross-repo stays selectable (exclusion would hide the only board that holds the id).
expect "$( [ "$XREPO" = 1 ] && echo 1 || echo 0 )" \
  "refined+cross-repo bead IS selected (b0fff17; exclusion would limbo the id)"
expect "$( [ "$PLAIN" = 1 ] && echo 1 || echo 0 )" \
  "plain refined bead IS still selected (over-filter guard)"
expect "$( [ "$GATE" = 0 ] && echo 1 || echo 0 )" \
  "human-gate bead is NOT selected"

# Both br-ready jq sites carry the human-gate clause (the :341 restatement was weaker).
SITES=$(grep -c "br ready --json | jq" "$IMPLEMENT")
HG_SITES=$(grep -n "br ready --json | jq" "$IMPLEMENT" | grep -c "human-gate")
expect "$( [ "$SITES" -ge 2 ] && [ "$HG_SITES" -ge 2 ] && echo 1 || echo 0 )" \
  "both br-ready jq sites exclude human-gate (sites=$SITES hg=$HG_SITES)"

echo "--- canon defines cross-repo ---"
if grep -q 'Repo: <name>' "$CANON" && grep -q 'ac-implement/SKILL.md' "$CANON" && grep -q '`cross-repo`' "$CANON"; then
  expect 1 "beads-standards defines cross-repo with Repo: <name> and names ac-implement"
else
  expect 0 "beads-standards defines cross-repo with Repo: <name> and names ac-implement"
fi

echo "--- env-prerequisite table ---"
# Data rows in the env table (skip header + separator).
ROWS=$(awk '/^\| Signal in bead spec /{p=1; next} p && /^\|/{c++} p && !/^\|/{exit} END{print c+0}' "$IMPLEMENT")
# header + separator + 4 data = 6 pipe-rows; we counted only after the header line, so
# separator + 4 data = 5 if we increment on every |, or 4 if we skip :--- .
DATA_ROWS=$(awk '/^\| Signal in bead spec /{p=1; next} p && /^\|/{if ($0 !~ /^\|[-:| ]+\|$/) c++} p && !/^\|/{exit} END{print c+0}' "$IMPLEMENT")
expect "$( [ "$DATA_ROWS" -ge 4 ] && echo 1 || echo 0 )" \
  "env table has >=4 data rows (got $DATA_ROWS)"
if awk '/^\| Signal in bead spec /{p=1; next} p && /^\|/{print} p && !/^\|/{exit}' "$IMPLEMENT" | grep -q 'cross-repo'; then
  expect 1 "env table has a cross-repo / Repo: <name> row"
else
  expect 0 "env table has a cross-repo / Repo: <name> row"
fi

echo ""
echo "cross-repo-gate.test: ${CASES} cases, ${FAILURES} failures"
[ "$FAILURES" -eq 0 ]
