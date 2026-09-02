#!/usr/bin/env bash
# aim.sh — rank seam candidates from git history, so `ac-polish seams` has somewhere to point.
#
# Two computations, one window, no judgement:
#   HOTSPOTS   per file: commits touching it in the window × its size now. Defects cluster
#              where code is both churning and large (Tornhill, Your Code as a Crime Scene).
#   COUPLING   file pairs co-changed in >= N commits with NO import between them — coupling
#              that lives in developers' heads, not in the code: a seam by definition.
#              Reported only when the window holds enough commits for pair counts to mean
#              anything; below that it SAYS SO instead of printing noise dressed as a table.
#
# The window is the whole design: `1w` = what we just made worse · `4w` = the recent drift ·
# `1y` = where the debt lives (older history is mostly rewritten code) · `all` = literally all.
#
# ASSURANCE (skills/ac-pipeline/references/assurance-declarations.md § The four fields):
#   PROBE:      skills/ac-polish/scripts/aim.test.sh — builds a throwaway repo with known churn
#               and co-changes; asserts the ranking, the coupling threshold refusal, the import
#               filter, and NOT-GATED on bad arguments
#   SCHEDULE:   once per seams session, from the start prompt (workflows/seams.md); and on
#               every CI run via scripts/run-all-harnesses.sh
#   MODE:       advisory — it ranks candidates; the human picks the target
#   ON-FAILURE: open — a usage error exits 2 with NOT-GATED; too few commits prints the hotspot
#               table plus a coupling refusal. Nothing here can wedge a run; nothing it prints
#               is a stamp.
#
# Usage: aim.sh [--since 1w|4w|1y|all] [--top 15] [--min-cochange 3] [--min-commits 30]
#               [--exclude <substr,substr,...>] [-C <repo>]
# Output: markdown — a hotspots table and a coupling table (or its refusal). Every row carries
#         the command that reproduces its number, so a candidate is never a remembered claim.
set -euo pipefail

die2() { printf 'aim: NOT-GATED %s\n' "$*" >&2; exit 2; }

SINCE=1y TOP=15 MINCO=3 MINCOMMITS=30 REPO="." MAXFILES=30
EXCLUDE='node_modules/,_plans/,_backlog/,_docs/,docs/,memory/,_archive/,__snapshots__/,CHANGELOG,.lock,.snap,.generated.'
while [ $# -gt 0 ]; do
  case "$1" in
    --since)        SINCE="${2:-}"; shift 2 ;;
    --top)          TOP="${2:-}"; shift 2 ;;
    --min-cochange) MINCO="${2:-}"; shift 2 ;;
    --min-commits)  MINCOMMITS="${2:-}"; shift 2 ;;
    --exclude)      EXCLUDE="${2:-}"; shift 2 ;;
    -C)             REPO="${2:-}"; shift 2 ;;
    -h|--help)      sed -n '/^# Usage/,/^set -euo/p' "$0" | sed '$d'; exit 2 ;;
    *)              die2 "unknown argument: $1" ;;
  esac
done
case "$SINCE" in
  1w) GS="1 week ago" ;; 4w) GS="4 weeks ago" ;; 1y) GS="1 year ago" ;; all) GS="" ;;
  *) die2 "--since must be 1w, 4w, 1y or all (got '$SINCE')" ;;
esac
for n in "$TOP" "$MINCO" "$MINCOMMITS"; do
  case "$n" in ''|*[!0-9]*) die2 "numeric flag got '$n'" ;; esac
done
git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die2 "not a git repo: $REPO"

# One record per commit: "H <sha>" then its files. --no-merges: a merge lists every file of
# the branch it lands and would fabricate co-changes.
if [ -n "$GS" ]; then
  RAW=$(git -C "$REPO" log --no-merges --format='H %H' --name-only --since="$GS")
  SINCEARG="--since=\"$GS\" "
else
  RAW=$(git -C "$REPO" log --no-merges --format='H %H' --name-only)
  SINCEARG=""
fi

# Exclusion is substring match on the path, every substring in --exclude.
EXRE=$(printf '%s' "$EXCLUDE" | sed 's/[.[\*^$|]/\\&/g; s/,/|/g')
FILTERED=$(printf '%s\n' "$RAW" | awk -v ex="$EXRE" '
  /^H /   { print; next }
  NF == 0 { next }
  ex != "" && $0 ~ ex { next }
  { print }')
NCOMMITS=$(printf '%s\n' "$FILTERED" | grep -c '^H ' || true)

printf '# aim — window: %s · commits: %s · excluded: %s\n\n' "$SINCE" "$NCOMMITS" "$EXCLUDE"
printf '## Hotspots — commits in window × lines now\n\n'
printf '| # | file | commits | lines | score | found-by |\n|---|---|---|---|---|---|\n'

# count commits per file, score = commits × lines, rank
printf '%s\n' "$FILTERED" | awk '!/^H /{c[$0]++} END{for (f in c) print c[f] "\t" f}' \
| while IFS=$'\t' read -r n f; do
    [ -f "$REPO/$f" ] || continue                 # deleted files are not candidates
    l=$(wc -l < "$REPO/$f" | tr -d ' ')
    printf '%s\t%s\t%s\t%s\n' "$((n * l))" "$n" "$l" "$f"
  done \
| sort -rn | head -n "$TOP" \
| awk -F'\t' -v s="$SINCEARG" '
    { i++; printf "| %d | `%s` | %s | %s | %s | `git log --no-merges --format=%%h %s-- %s \\| wc -l` |\n", i, $4, $2, $3, $1, s, $4 }'

printf '\n## Temporal coupling — co-changed ≥ %s times, no import between them\n\n' "$MINCO"
if [ "$NCOMMITS" -lt "$MINCOMMITS" ]; then
  printf 'coupling: insufficient commits in window (%s < %s) — widen --since or lower --min-commits. A pair count over this few commits is noise, not a seam.\n' "$NCOMMITS" "$MINCOMMITS"
  exit 0
fi

# Pairs: within each commit (capped — a mass rename touching >MAXFILES files says nothing
# about coupling), every unordered pair; count per pair and per file; ratio = pair/min(a,b).
PAIRS=$(printf '%s\n' "$FILTERED" | awk -v max="$MAXFILES" -v minco="$MINCO" '
  function flush(   i, j) {
    if (n >= 2 && n <= max) for (i = 1; i <= n; i++) { fc[f[i]]++; for (j = i + 1; j <= n; j++) {
      k = (f[i] < f[j]) ? f[i] "\t" f[j] : f[j] "\t" f[i]; pc[k]++ } }
    else if (n == 1) fc[f[1]]++
    n = 0 }
  /^H / { flush(); next }
  { f[++n] = $0 }
  END { flush()
    for (k in pc) if (pc[k] >= minco) {
      split(k, ab, "\t"); m = (fc[ab[1]] < fc[ab[2]]) ? fc[ab[1]] : fc[ab[2]]
      printf "%d\t%.2f\t%s\t%s\n", pc[k], pc[k] / m, ab[1], ab[2] } }' | sort -rn)

printf '| a | b | co-changes | ratio | found-by |\n|---|---|---|---|---|\n'
FOUND=0
while IFS=$'\t' read -r n r a b; do
  [ -n "$a" ] || continue
  [ -f "$REPO/$a" ] && [ -f "$REPO/$b" ] || continue
  # Import filter: if either file mentions the other's stem AS A WORD, the coupling is IN the
  # code and is not a seam. Stem = basename without extension; language-agnostic on purpose.
  # Whole-word (-w): a stem `b` must not match inside `ab`.
  sa=$(basename "$a"); sa="${sa%%.*}"; sb=$(basename "$b"); sb="${sb%%.*}"
  if grep -qwF "$sb" "$REPO/$a" 2>/dev/null || grep -qwF "$sa" "$REPO/$b" 2>/dev/null; then continue; fi
  FOUND=$((FOUND + 1))
  printf '| `%s` | `%s` | %s | %s | `for c in $(git log --no-merges --format=%%h %s-- %s); do git show --name-only --format= $c \\| grep -qx %s && echo $c; done \\| wc -l` |\n' \
    "$a" "$b" "$n" "$r" "$SINCEARG" "$a" "$b"
done <<EOF
$PAIRS
EOF
[ "$FOUND" -gt 0 ] || printf '| — | — | — | — | no pair reached --min-cochange %s without an import between them |\n' "$MINCO"
exit 0
