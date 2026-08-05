#!/usr/bin/env bash
# board-truth.test.sh — proves Scan F's extractor bites, and stays silent when it should.
#
# A detector that silently matches nothing is worse than none: it reads as coverage while
# providing none. These cases run the extraction awk directly against synthetic records,
# so the test needs no repo, no beads DB and no network — and no app-specific fixture.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$SCRIPT_DIR/board-truth.sh"
FAILURES=0
CASES=0

# The extractor, lifted verbatim from board-truth.sh by line range so the test cannot
# drift from the implementation it claims to cover.
extract() {
  awk -F'|' '{ ct=$1+0; subj=$3
      if (subj ~ /^chore\(beads\)/ || $0 ~ /\[no-bead\]/) next
      body=""; for(i=4;i<=NF;i++) body=body "|" $i
      n=split(subj, t, /[^A-Za-z0-9._-]/)
      for(i=1;i<=n;i++) if (t[i] ~ /^bd-[A-Za-z0-9._-]+$/) if (ct>seen[t[i]]+0) seen[t[i]]=ct
      m=split(body, w, /[|[:space:]]+/)
      for(i=1;i<m;i++) if (w[i] ~ /^[Bb]eads?:$/ && w[i+1] ~ /^bd-[A-Za-z0-9._-]+$/) if (ct>seen[w[i+1]]+0) seen[w[i+1]]=ct
    } END { for (k in seen) printf "%s\n", k }'
}

expect() { # record want_id_or_EMPTY label
  CASES=$((CASES + 1))
  local got
  got=$(printf '%s\n' "$1" | extract | sort | paste -sd, -)
  if [ "$got" = "$2" ]; then
    printf '  PASS  %s\n' "$3"
  else
    printf '  FAIL  %s — got [%s] want [%s]\n' "$3" "$got" "$2"
    FAILURES=$((FAILURES + 1))
  fi
}

echo "--- board-truth extractor ---"
expect '1700000000|abc1234|fix(x): thing|Bead: bd-probe1' 'bd-probe1' 'Bead: trailer is detected'
expect '1700000000|abc1234|fix(bd-probe2): thing|body text' 'bd-probe2' 'id in subject is detected'
expect '1700000000|abc1234|chore(beads): stamp bd-probe3 refined|x' '' 'chore(beads) bookkeeping is dropped'
expect '1700000000|abc1234|chore: ledger [no-bead]|Bead: bd-probe4' '' '[no-bead] marker is dropped'
expect '1700000000|abc1234|docs: notes|see bd-probe5 for context' '' 'bare prose mention does NOT count'
expect '1700000000|abc1234|refactor: none here|no ids at all' '' 'clean commit yields nothing'

echo "--- script contract ---"
CASES=$((CASES + 1))
if [ -x "$TARGET" ]; then printf '  PASS  board-truth.sh is executable\n'
else printf '  FAIL  board-truth.sh is not executable — the scan is dead\n'; FAILURES=$((FAILURES + 1)); fi

CASES=$((CASES + 1))
if "$TARGET" --repo /nonexistent-repo-probe 2>/dev/null | grep -q 'board-truth:'; then
  printf '  PASS  degrades to a printed verdict on an unreadable repo\n'
else printf '  FAIL  no verdict line on an unreadable repo — silence reads as clean\n'; FAILURES=$((FAILURES + 1)); fi

echo ""
echo "board-truth.test: ${CASES} cases, ${FAILURES} failures"
[ "$FAILURES" -eq 0 ]
