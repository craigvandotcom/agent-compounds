#!/usr/bin/env bash
# aim.sh — decide WHERE to point a seams trace. Two modes, one table shape, no judgement.
#
#   churn    from git history: HOTSPOTS (commits in window × lines now — defects cluster where
#            code is churning AND large; Tornhill) and TEMPORAL COUPLING (file pairs co-changed
#            >= N times with NO import between them — coupling that lives in developers' heads).
#            Outputs FILES. `--since 1w` = what we just made worse; `1y` = where the debt lives.
#   objects  from the tree: every DATA OBJECT that persists or crosses a boundary — schema
#            columns (qualified by table: `foods.image_urls`), exported types, storage keys,
#            buckets — with the seam PRECURSORS you can count without tracing: touchers, layers,
#            writers, tests, storage kinds. Outputs OBJECTS, which is what `ac-polish seams`
#            traces. `--area <regex>` restricts the toucher set to matching files (or keeps all
#            touchers of an object whose name matches) — the bridge from a churn hotspot (a
#            file) or a user's area ("image|photo") to an object, ranked by load INSIDE the area.
#            score = touchers × layers × max(1, writers) ÷ (1 + tests): the DSM row sum, weighted
#            toward competing writers and away from asserted edges. Predicts seam LOAD, never
#            seams — a flow-only seam (two steps that interleave) has no static precursor.
#            A column's touchers are files naming BOTH the column and its table, so `status` on
#            six tables is six objects, not one; a symbol from a test file is never a candidate.
#
# ASSURANCE (skills/ac-pipeline/references/assurance-declarations.md § The four fields):
#   PROBE:      skills/ac-polish/scripts/aim.test.sh — throwaway repos with known churn,
#               co-changes, columns, types and touchers; asserts every column of both tables,
#               the --area bridge, the stoplist, and NOT-GATED on bad arguments
#   SCHEDULE:   once per seams session, at the start prompt (workflows/seams.md § TARGET); and
#               on every CI run via scripts/run-all-harnesses.sh
#   MODE:       advisory — it ranks candidates; the human picks the target
#   ON-FAILURE: open — a usage error exits 2 with NOT-GATED; too few commits prints the hotspot
#               table plus a coupling refusal; an empty inventory says so. Nothing it prints is
#               a stamp.
#
# Usage: aim.sh churn   [--since 1w|4w|1y|all] [--top 15] [--min-cochange 3] [--min-commits 30]
#                       [--exclude <substr,...>] [-C <repo>]
#        aim.sh objects [--area <regex>] [--top 20] [--min-touchers 3] [--exclude <substr,...>] [-C <repo>]
# Output: markdown tables, every row with the command that reproduces its number.
set -euo pipefail

die2() { printf 'aim: NOT-GATED %s\n' "$*" >&2; exit 2; }

MODE="${1:-}"; [ $# -gt 0 ] && shift
case "$MODE" in churn|objects) ;; -h|--help|"") sed -n '/^# Usage/,/^set -euo/p' "$0" | sed '$d' >&2; exit 2 ;; *) die2 "mode must be churn or objects (got '$MODE')" ;; esac

SINCE=1y TOP="" MINCO=3 MINCOMMITS=30 MINTOUCH=3 AREA="" REPO="." MAXFILES=30
EXCLUDE='node_modules/,_plans/,_backlog/,_docs/,docs/,memory/,_archive/,__snapshots__/,CHANGELOG,.lock,.snap,.generated.'
while [ $# -gt 0 ]; do
  case "$1" in
    --since)        SINCE="${2:-}"; shift 2 ;;
    --top)          TOP="${2:-}"; shift 2 ;;
    --min-cochange) MINCO="${2:-}"; shift 2 ;;
    --min-commits)  MINCOMMITS="${2:-}"; shift 2 ;;
    --min-touchers) MINTOUCH="${2:-}"; shift 2 ;;
    --area)         AREA="${2:-}"; shift 2 ;;
    --exclude)      EXCLUDE="${2:-}"; shift 2 ;;
    -C)             REPO="${2:-}"; shift 2 ;;
    *)              die2 "unknown argument: $1" ;;
  esac
done
[ -n "$TOP" ] || { [ "$MODE" = churn ] && TOP=15 || TOP=20; }
for n in "$TOP" "$MINCO" "$MINCOMMITS" "$MINTOUCH"; do
  case "$n" in ''|*[!0-9]*) die2 "numeric flag got '$n'" ;; esac
done
git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die2 "not a git repo: $REPO"
ROOT=$(git -C "$REPO" rev-parse --show-toplevel)
EXRE=$(printf '%s' "$EXCLUDE" | sed 's/[.[\*^$|]/\\&/g; s/,/|/g')

# ============================================================ churn
if [ "$MODE" = churn ]; then
  case "$SINCE" in
    1w) GS="1 week ago" ;; 4w) GS="4 weeks ago" ;; 1y) GS="1 year ago" ;; all) GS="" ;;
    *) die2 "--since must be 1w, 4w, 1y or all (got '$SINCE')" ;;
  esac
  if [ -n "$GS" ]; then
    RAW=$(git -C "$REPO" log --no-merges --format='H %H' --name-only --since="$GS"); SINCEARG="--since=\"$GS\" "
  else
    RAW=$(git -C "$REPO" log --no-merges --format='H %H' --name-only); SINCEARG=""
  fi
  FILTERED=$(printf '%s\n' "$RAW" | awk -v ex="$EXRE" '/^H /{print; next} NF==0{next} ex != "" && $0 ~ ex {next} {print}')
  NCOMMITS=$(printf '%s\n' "$FILTERED" | grep -c '^H ' || true)

  printf '# aim churn — window: %s · commits: %s · excluded: %s\n\n' "$SINCE" "$NCOMMITS" "$EXCLUDE"
  printf '## Hotspots — commits in window × lines now\n\n'
  printf '| # | file | commits | lines | score | found-by |\n|---|---|---|---|---|---|\n'
  printf '%s\n' "$FILTERED" | awk '!/^H /{c[$0]++} END{for (f in c) print c[f] "\t" f}' \
  | while IFS=$'\t' read -r n f; do
      [ -f "$REPO/$f" ] || continue
      l=$(wc -l < "$REPO/$f" | tr -d ' ')
      printf '%s\t%s\t%s\t%s\n' "$((n * l))" "$n" "$l" "$f"
    done \
  | sort -rn | head -n "$TOP" \
  | awk -F'\t' -v s="$SINCEARG" '{ i++; printf "| %d | `%s` | %s | %s | %s | `git log --no-merges --format=%%h %s-- %s \\| wc -l` |\n", i, $4, $2, $3, $1, s, $4 }'

  printf '\n## Temporal coupling — co-changed ≥ %s times, no import between them\n\n' "$MINCO"
  if [ "$NCOMMITS" -lt "$MINCOMMITS" ]; then
    printf 'coupling: insufficient commits in window (%s < %s) — widen --since or lower --min-commits. A pair count over this few commits is noise, not a seam.\n' "$NCOMMITS" "$MINCOMMITS"
    exit 0
  fi
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
fi

# ============================================================ objects
# Candidates: nouns with a lifecycle. Each source is one grep; the union is the inventory.
# Columns carry their table (`foods.image_urls`); nothing is discovered from a test file.
STOP='^(id|created_at|updated_at|deleted_at|user_id|key|value|data|type|name|error|url)$'
RGX="rg --no-messages -g !node_modules/** -g !_plans/** -g !_backlog/** -g !_docs/** -g !docs/** -g !memory/** -g !_archive/** -g !.beads/** -g !*.test.* -g !__tests__/**"
cands() {
  # 1. generated DB types: `  <table>: {` at 6 spaces, then `  <col>: type` at 10 under Row
  $RGX -N --no-filename '^\s{6}[a-z][a-z0-9_]*: \{$|^\s{8}Row: \{$|^\s{10}[a-z][a-z0-9_]*\??:' -g '*.generated.ts' -g '*supabase*types*.ts' "$ROOT" 2>/dev/null \
    | awk '/^ {6}[a-z]/ { t=$1; sub(/:$/, "", t); inrow=0; next }
           /^ {8}Row:/  { inrow=1; next }
           inrow && /^ {10}[a-z]/ { c=$1; sub(/\??:$/, "", c); print "column\t" t "." c }' || true
  # 2. SQL migrations: `create table <t> (` then `  <col> <type>` lines
  $RGX -N --no-filename -i '^create table (if not exists )?[a-z_.]+|^\s+[a-z][a-z0-9_]* (text|int|integer|bigint|uuid|boolean|jsonb|json|timestamptz|timestamp|numeric|float|real|date|text\[\]|varchar)' -g '*.sql' "$ROOT" 2>/dev/null \
    | awk 'tolower($1)=="create" { t=$NF; sub(/^[a-z_]+\./, "", t); sub(/\($/, "", t); next } t != "" { print "column\t" t "." $1 }' || true
  # 3. exported types and interfaces
  $RGX -o -N --no-filename '^export (interface|type) [A-Z][A-Za-z0-9]+' --type ts -g '!*.generated.*' "$ROOT" 2>/dev/null \
    | awk '{print "type\t" $3}' || true
  # 4. storage keys (web + native) and buckets
  $RGX -o -N --no-filename "(sessionStorage|localStorage)\.(setItem|getItem|removeItem)\(['\"][A-Za-z0-9_:.-]+" --type ts "$ROOT" 2>/dev/null \
    | sed "s/.*(['\"]//" | awk '{print "storage-key\t" $0}' || true
  $RGX -o -N --no-filename "Preferences\.(set|get|remove)\(\{\s*key:\s*['\"][A-Za-z0-9_:.-]+" --type ts "$ROOT" 2>/dev/null \
    | sed "s/.*['\"]//" | awk '{print "storage-key\t" $0}' || true
  $RGX -o -N --no-filename "storage\.from\(['\"][a-z0-9-]+" --type ts "$ROOT" 2>/dev/null \
    | sed "s/.*['\"]//" | awk '{print "bucket\t" $0}' || true
}
INV=$(cands | sort -u | awk -F'\t' -v stop="$STOP" '{ n=$2; sub(/^.*\./, "", n); if (length(n) > 2 && n !~ stop) print }')
[ -n "$INV" ] || { printf '# aim objects — no candidates found under %s (no generated DB types, SQL columns, exported types, storage keys or buckets)\n' "$ROOT"; exit 0; }

layer_of() {  # path -> layer
  case "$1" in
    *.test.*|*__tests__*|*/tests/*) echo test ;;
    supabase/*|*/migrations/*) echo schema ;;
    lib/db/*|*/db/*) echo db ;;
    lib/services/*|*/services/*) echo services ;;
    app/api/cron/*) echo cron ;;
    app/api/*|*/api/*) echo api ;;
    *hooks*|*use-*) echo hooks ;;
    features/*|components/*|app/*) echo ui ;;
    scripts/*) echo scripts ;;
    lib/*) echo lib ;;
    *) echo "${1%%/*}" ;;
  esac
}
WRITE_RE='(insert|update|upsert|delete|remove|set[A-Za-z]*)\b[^;]{0,80}\b%s\b|\b%s\b[[:space:]]*[:=][^=]'

printf '# aim objects — inventory under %s%s · min touchers %s · excluded: %s\n\n' "$ROOT" "${AREA:+ · area /$AREA/}" "$MINTOUCH" "$EXCLUDE"
printf '## Objects — seam load = touchers × layers × writers ÷ (1 + tests)%s\n\n' "${AREA:+ — touchers counted inside the area}"
printf '| # | object | kind | touchers | layers | writers | tests | storage kinds | score | found-by |\n|---|---|---|---|---|---|---|---|---|---|\n'
ROWS=$(cd "$ROOT" && printf '%s\n' "$INV" | while IFS=$'\t' read -r kind sym; do
  [ -n "$sym" ] || continue
  table=""; col="$sym"
  case "$sym" in *.*) table="${sym%%.*}"; col="${sym#*.}" ;; esac
  esc=$(printf '%s' "$col" | sed 's/[.[\*^$|()]/\\&/g')
  # touchers: files naming the symbol; for a column, ALSO naming its table (one xargs, one process)
  TOUCH=$(rg --no-messages -l -w -F "$col" --type ts --type sql -g '!*.generated.*' -g '!*.lock' . 2>/dev/null | sed 's|^\./||' | grep -vE "$EXRE" || true)
  if [ -n "$table" ] && [ -n "$TOUCH" ]; then
    # the table's stem with any suffix, case-insensitive: `foods`, `foodsRepo`, `Food`, `FoodEntry`
    # all count; a file that mentions only `status` in a jobs context does not
    tre="\\b${table%s}[A-Za-z]*"
    TOUCH=$(printf '%s\n' "$TOUCH" | xargs grep -liE -- "$tre" 2>/dev/null || true)
  fi
  if [ -n "$AREA" ] && ! printf '%s' "$sym" | grep -qE "$AREA"; then
    TOUCH=$(printf '%s\n' "$TOUCH" | grep -E "$AREA" || true)
  fi
  n=$(printf '%s\n' "$TOUCH" | grep -c . || true)
  [ "$n" -ge "$MINTOUCH" ] || continue
  layers=$(printf '%s\n' "$TOUCH" | while read -r p; do [ -n "$p" ] && layer_of "$p"; done | sort -u | grep -vc '^test$' || true)
  tests=$(printf '%s\n' "$TOUCH" | grep -cE '\.test\.|__tests__|/tests/' || true)
  wre="${WRITE_RE//%s/$esc}"   # not printf: it would turn the regex's \b into a backspace
  writers=$(printf '%s\n' "$TOUCH" | grep -vE '\.test\.|__tests__|/tests/' | xargs grep -lE -- "$wre" 2>/dev/null | grep -c . || true)
  kinds=0
  printf '%s\n' "$TOUCH" | grep -qE '^supabase/|/db/|\.sql$' && kinds=$((kinds + 1))
  [ -n "$(printf '%s\n' "$TOUCH" | xargs grep -lE 'sessionStorage|localStorage|Preferences\.' 2>/dev/null)" ] && kinds=$((kinds + 1))
  [ -n "$(printf '%s\n' "$TOUCH" | xargs grep -lE 'storage\.from\(' 2>/dev/null)" ] && kinds=$((kinds + 1))
  printf '%s\n' "$TOUCH" | grep -qE '^app/api/cron/' && kinds=$((kinds + 1))
  w=$writers; [ "$w" -ge 1 ] || w=1
  score=$(( n * layers * w * 100 / (1 + tests) ))
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$score" "$sym" "$kind" "$n" "$layers" "$writers" "$tests" "$kinds" "$table"
done | sort -rn | head -n "$TOP")
if [ -z "$ROWS" ]; then
  printf '| — | — | — | — | — | — | — | — | — | no object reached --min-touchers %s%s |\n' "$MINTOUCH" "${AREA:+ in area /$AREA/}"
  exit 0
fi
printf '%s\n' "$ROWS" | awk -F'\t' '{
  i++; col=$2; sub(/^.*\./, "", col)
  fb = "rg -l -w -F \x27" col "\x27 --type ts --type sql -g \x27!*.generated.*\x27"
  if ($9 != "") { t=$9; sub(/s$/, "", t); fb = fb " \\| xargs grep -liE \x27\\b" t "[A-Za-z]*\x27" }
  printf "| %d | `%s` | %s | %s | %s | %s | %s | %s | %.1f | `%s \\| wc -l` |\n", i, $2, $3, $4, $5, $6, $7, $8, $1/100, fb }'
exit 0
