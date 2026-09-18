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

# The bookkeeping test, lifted verbatim from board-truth.sh's file-population awk (the
# is_bookkeeping() function + the all-files-bookkeeping fold) so the test cannot drift
# from the implementation it claims to cover. Takes a commit's touched-file list on
# stdin (one path per line, empty for a zero-file commit) and prints the sha iff every
# file is bookkeeping.
is_bookkeeping_commit() { # <sha> <<< files
  awk -v sha="$1" '
      function is_bookkeeping(f,    n, parts, base) {
        n = split(f, parts, "/"); base = parts[n]
        if (base == "FRICTIONS.md" || base == "MAINTENANCE.md") return 1
        if (f ~ /^\.beads\//) return 1
        if (f ~ /^_archive\//) return 1
        if (f ~ /^\.claude\/reviews\//) return 1
        return 0
      }
      NF == 0 { next }
      { files++; if (is_bookkeeping($0)) book++ }
      END { if (files > 0 && files == book) print sha }
    '
}

# The extractor, lifted verbatim from board-truth.sh's citation awk (minus the NR==FNR
# bookkeeping-lookup line, which the harness below substitutes with a real one) so the
# test cannot drift from the implementation it claims to cover.
extract() { # <bookkeeping-sha-or-EMPTY> <<< record
  awk -F'|' -v bk="$1" '
      { ct=$1+0; subj=$3
        if (bk != "" && $2 == bk) next
        body=""; for(i=4;i<=NF;i++) body=body "|" $i
        n=split(subj, t, /[^A-Za-z0-9._-]/)
        for(i=1;i<=n;i++) if (t[i] ~ /^bd-[A-Za-z0-9._-]+$/) if (ct>seen[t[i]]+0) seen[t[i]]=ct
        m=split(body, w, /[|[:space:]]+/)
        for(i=1;i<m;i++) if (w[i] ~ /^[Bb]eads?:$/ && w[i+1] ~ /^bd-[A-Za-z0-9._-]+$/) if (ct>seen[w[i+1]]+0) seen[w[i+1]]=ct
      } END { for (k in seen) printf "%s\n", k }'
}

expect() { # record files(newline-separated, may be empty) want_id_or_EMPTY label
  CASES=$((CASES + 1))
  local record="$1" files="$2" want="$3" label="$4"
  local sha bk got
  sha=$(printf '%s' "$record" | awk -F'|' '{print $2}')
  bk=$(printf '%s\n' "$files" | is_bookkeeping_commit "$sha")
  got=$(printf '%s\n' "$record" | extract "$bk" | sort | paste -sd, -)
  if [ "$got" = "$want" ]; then
    printf '  PASS  %s\n' "$label"
  else
    printf '  FAIL  %s — got [%s] want [%s]\n' "$label" "$got" "$want"
    FAILURES=$((FAILURES + 1))
  fi
}

echo "--- board-truth extractor ---"
expect '1700000000|abc1234|fix(x): thing|Bead: bd-probe1' '' 'bd-probe1' 'Bead: trailer is detected'
expect '1700000000|abc1234|fix(bd-probe2): thing|body text' '' 'bd-probe2' 'id in subject is detected'
expect '1700000000|abc1234|docs: notes|see bd-probe5 for context' '' '' 'bare prose mention does NOT count'
expect '1700000000|abc1234|refactor: none here|no ids at all' '' '' 'clean commit yields nothing'
expect '1700000000|abc1234|docs: ledger note|Bead: bd-probe6' '.beads/issues.jsonl' '' \
  'a ledger-only commit is dropped whatever its subject'
expect '1700000000|abc1234|fix: hotfix [no-bead]|Bead: bd-probe7' "$(printf '.beads/issues.jsonl\nsrc/real.ts')" 'bd-probe7' \
  'a [no-bead]-tagged commit that changes real files is NOT dropped'
expect '1700000000|abc1234|chore(beads): stamp bd-probe8 refined|x' "$(printf '.beads/issues.jsonl\nsrc/real.ts')" 'bd-probe8' \
  'a chore(beads)-subject commit that changes real files is NOT dropped'
expect '1700000000|abc1234|fix(x): correct calc|Bead: bd-probe9' "$(printf '.beads/foo.json\nsrc/real.ts')" 'bd-probe9' \
  'a commit touching one bookkeeping file plus one real file is NOT dropped'

echo "--- script contract ---"
CASES=$((CASES + 1))
if [ -x "$TARGET" ]; then printf '  PASS  board-truth.sh is executable\n'
else printf '  FAIL  board-truth.sh is not executable — the scan is dead\n'; FAILURES=$((FAILURES + 1)); fi

CASES=$((CASES + 1))
if "$TARGET" --repo /nonexistent-repo-probe 2>/dev/null | grep -q 'board-truth:'; then
  printf '  PASS  degrades to a printed verdict on an unreadable repo\n'
else printf '  FAIL  no verdict line on an unreadable repo — silence reads as clean\n'; FAILURES=$((FAILURES + 1)); fi

echo "--- script contract: the unexaminable board says so (D6) ---"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
MOCK="$WORK/bin"; mkdir -p "$MOCK"
REPO="$WORK/repo"; mkdir -p "$REPO"
( cd "$REPO" && git init -q -b main . && git config user.email t@t && git config user.name t \
  && printf 'x\n' >f.txt && git add f.txt && git commit -qm init )
cat >"$MOCK/br" <<'EOF'
#!/usr/bin/env bash
case "${BR_MODE:-ok}" in
  doctor-fail) [ "$1" = doctor ] && exit 1 ;;
  bare-array)  [ "$1" = list ] && { printf '%s\n' '[{"id":"bd-x","updated_at":"2026-09-01T00:00:00Z","created_at":"2026-08-01T00:00:00Z"}]'; exit 0; } ;;
esac
exit 0
EOF
chmod +x "$MOCK/br"

CASES=$((CASES + 1))
OUT=$(PATH="$MOCK:$PATH" BR_MODE=doctor-fail "$TARGET" --repo "$REPO" 2>&1); RC=$?
if [ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q 'board-truth: NOT-GATED'; then
  printf '  PASS  a br that exits non-zero is a NOT-GATED (rc 2), never a clean 0\n'
else printf '  FAIL  doctor-fail: rc=%s out=%s\n' "$RC" "$OUT"; FAILURES=$((FAILURES + 1)); fi

CASES=$((CASES + 1))
OUT=$(PATH="$MOCK:$PATH" BR_MODE=bare-array "$TARGET" --repo "$REPO" 2>&1); RC=$?
if [ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q 'board-truth: NOT-GATED'; then
  printf '  PASS  a bare-array br list answer is a NOT-GATED (rc 2), never a clean 0\n'
else printf '  FAIL  bare-array: rc=%s out=%s\n' "$RC" "$OUT"; FAILURES=$((FAILURES + 1)); fi

echo ""
echo "board-truth.test: ${CASES} cases, ${FAILURES} failures"
[ "$FAILURES" -eq 0 ]
