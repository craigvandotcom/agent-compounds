#!/usr/bin/env bash
# citation-grammar.sh — the ONE home of the Delivers/Consumes citation grammar check.
#
# Canon: skills/ac-beadify/references/bead-schema.md § The citation rule. A `## Delivers`
# entry and the artifact half of a `## Consumes` line are the same thing — a dependent cites
# a Delivers entry VERBATIM — so they obey one grammar:
#
#     ## Delivers                      ## Consumes
#     - <one path> [(gloss)]           - <blocker-id> -> <one path> [(gloss)]
#
# One bare path, first thing. Optional trailing parenthetical gloss that names no second
# path. No label prefix, no second artifact, no prose, no placeholder. `- none` is the
# explicit empty section at either end. A wrapped entry is folded before it is graded, so a
# second artifact cannot hide past a line break; a `touchers:` line beneath a Delivers
# bullet is STRUCTURE, not prose, and is skipped — touchers.sh re-runs its command, a
# stronger read of that line than this grammar could give it.
#
# WHY (measured 2026-09-27, bd-1tq1 in easy-mode): four bead-polish rounds converged on
# Delivers bullets with trailing prose, because VALIDATE ran element4 + touchers only and
# nothing in-round read the grammar; only that app's pre-commit lint caught it.
#
# Path SHAPE is judged here, never existence — a Delivers path is usually new, and whether a
# cited path is on the tree is flight-check's premise leg at claim. The multi-segment shape
# is delivers-paths.sh's DELIVERS_PATH_RE (one home of the pattern); a top-level `name.ext`
# or a path that exists on the tree is also a path.
#
# ASSURANCE (ac-pipeline/references/assurance-declarations.md § The four fields):
#   PROBE:      skills/_tools/citation-grammar.test.sh — every violation class and the
#               conforming forms, both polarities
#   SCHEDULE:   every bead-mode polish round (ac-polish/workflows/bead.md VALIDATE), and on
#               every CI run via scripts/run-all-proofs.sh
#   MODE:       blocking
#   ON-FAILURE: closed   (an unreadable input is NOT-GATED, never OK)
#
# Usage:
#   citation-grammar.sh check <description-file> [<label>]   one bead description
#   citation-grammar.sh artifact <artifact-file>              every <!-- BEAD:id --> block
#                                                             of a bead-artifact.py export
#
# Output: one `citations: VIOLATION <label> [<CLASS>] <Section>: '<entry>' — <fix>` line per
# defect, then one verdict line. Classes: LABEL-PREFIX · TWO-ARTIFACTS · PROSE ·
# PLACEHOLDER · NOT-BARE · EMPTY · NO-ARROW.
#
# Exit 0  citations: OK        — every entry conforms (or there is none to read)
# Exit 1  citations: REFUSED   — at least one VIOLATION
# Exit 2  citations: NOT-GATED — the input could not be read; nothing was checked
set -uo pipefail

_CG_SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$_CG_SELF/delivers-paths.sh" ] || {
  printf 'citations: NOT-GATED — delivers-paths.sh missing beside %s; the path pattern cannot be resolved\n' "$_CG_SELF" >&2
  exit 2
}
. "$_CG_SELF/delivers-paths.sh"

_CG_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
_CG_VIOLATIONS=0

# entries <description-file> -> "<Section>\t<folded entry>" per Delivers/Consumes entry.
entries() {
  awk '
    function flush() { if (have) print sec "\t" cur; cur = ""; have = 0 }
    /^## / {
      flush()
      if ($0 ~ /^## Delivers/) sec = "Delivers"
      else if ($0 ~ /^## Consumes/) sec = "Consumes"
      else sec = ""
      next
    }
    sec == ""                                   { next }
    /^[[:space:]]*<!--/                         { flush(); next }
    sec == "Delivers" && /^[[:space:]]*touchers:/ { next }
    /^[[:space:]]*$/                            { flush(); next }
    /^[[:space:]]*[-*]([[:space:]]|$)/ {
      flush(); line = $0; sub(/^[[:space:]]*[-*][[:space:]]*/, "", line)
      cur = line; have = 1; next
    }
    {
      line = $0; sub(/^[[:space:]]+/, "", line)
      if (have) cur = cur " " line; else { cur = line; have = 1 }
    }
    END { flush() }
  ' "$1"
}

path_shaped() { # <token>
  local t="$1"
  printf '%s\n' "$t" | grep -qxE "$DELIVERS_PATH_RE" && return 0
  printf '%s\n' "$t" | grep -qxE '[A-Za-z0-9_@-][A-Za-z0-9_@.()-]*\.[A-Za-z0-9]{1,6}' && return 0
  [ -n "$_CG_ROOT" ] && [ -e "$_CG_ROOT/$t" ]
}

# A gloss is ONE parenthetical that opens the remainder and closes at its last character.
is_gloss() { # <rest>
  local s="$1" i c depth=0
  [ "${s:0:1}" = "(" ] && [ "${s: -1}" = ")" ] || return 1
  for (( i = 0; i < ${#s}; i++ )); do
    c=${s:i:1}
    case "$c" in
      "(") depth=$((depth + 1)) ;;
      ")") depth=$((depth - 1))
           [ "$depth" -gt 0 ] || [ "$i" -eq $(( ${#s} - 1 )) ] || return 1 ;;
    esac
  done
  [ "$depth" -eq 0 ]
}

violation() { # <label> <class> <section> <entry> <fix>
  _CG_VIOLATIONS=$((_CG_VIOLATIONS + 1))
  printf "citations: VIOLATION %s [%s] %s: '%s' — %s\n" "$1" "$2" "$3" "$4" "$5"
}

# grade <label> <section> <entry> <cited> — the grammar, once, for both ends.
grade() {
  local label="$1" sec="$2" entry="$3" cited="$4" head rest bare
  cited="${cited#"${cited%%[![:space:]]*}"}"; cited="${cited%"${cited##*[![:space:]]}"}"
  if [ -z "$cited" ]; then
    violation "$label" EMPTY "$sec" "$entry" "the entry names nothing; cite one path, or write '- none'"
    return
  fi
  head=${cited%%[[:space:]]*}
  rest=${cited#"$head"}; rest="${rest#"${rest%%[![:space:]]*}"}"
  bare=$head
  [ -n "$rest" ] || bare=${bare%.}                       # a sentence period is punctuation
  bare=${bare%[,;]}

  case "$head" in
    *'<'*|*'>'*|TBD|tbd|TODO|todo|TBA|XXX|'...'|'…'|'?'*)
      violation "$label" PLACEHOLDER "$sec" "$entry" "'$head' is a placeholder, not an artifact — name the real path, or leave the entry out until it exists"
      return ;;
    *:)
      violation "$label" LABEL-PREFIX "$sec" "$entry" "'$head' is a label, not a path — drop it; the path comes first"
      return ;;
    '`'*|'*'*|'"'*|"'"*)
      violation "$label" NOT-BARE "$sec" "$entry" "'$head' wraps the path in markup — cite it bare so the head token is the path itself"
      return ;;
  esac
  if ! path_shaped "$bare"; then
    violation "$label" PROSE "$sec" "$entry" "'$head' is not a path — this entry is prose; move it to ## Intent, or make it an AC with a probe"
    return
  fi
  [ -n "$rest" ] || return 0
  if is_gloss "$rest"; then
    if [ -n "$(extract_paths "$rest")" ]; then
      violation "$label" TWO-ARTIFACTS "$sec" "$entry" "the gloss names a second path ($(extract_paths "$rest" | tr '\n' ' ' | sed 's/ $//')) — one artifact per entry; give it its own line"
    fi
    return 0
  fi
  if [ -n "$(extract_paths "$rest")" ]; then
    violation "$label" TWO-ARTIFACTS "$sec" "$entry" "a second artifact trails the path ($(extract_paths "$rest" | tr '\n' ' ' | sed 's/ $//')) — one artifact per entry; give it its own line"
  else
    violation "$label" PROSE "$sec" "$entry" "'$rest' trails the path — prose belongs in ## Intent; a gloss goes in one trailing (parenthetical)"
  fi
}

# check_description <file> <label> -> grades every entry; prints nothing when all conform.
check_description() {
  local file="$1" label="$2" sec entry lower list
  # A reader that failed is NOT-GATED, never an empty (and therefore conforming) list.
  list=$(entries "$file") || return 2
  while IFS=$'\t' read -r sec entry; do
    [ -n "$sec" ] || continue
    lower=$(printf '%s' "$entry" | tr '[:upper:]' '[:lower:]')
    case "$lower" in none|none.) continue ;; esac
    if [ "$sec" = "Consumes" ]; then
      entry=${entry//→/->}
      case "$entry" in
        *"->"*) grade "$label" Consumes "$entry" "${entry#*->}" ;;
        *) violation "$label" NO-ARROW Consumes "$entry" "a Consumes line is '<blocker-id> -> <one path>', or the single word 'none'" ;;
      esac
    else
      grade "$label" Delivers "$entry" "$entry"
    fi
  done <<EOF
$list
EOF
}

cmd_check() { # <file> [label]
  local file="${1:-}" label="${2:-${1:-description}}" before rc
  if [ -z "$file" ] || [ ! -r "$file" ]; then
    printf 'citations: NOT-GATED %s — no readable description file at "%s"; nothing was checked\n' "$label" "${file:-<none>}" >&2
    return 2
  fi
  before=$_CG_VIOLATIONS
  set -f; check_description "$file" "$label"; rc=$?; set +f
  if [ "$rc" -eq 2 ]; then
    printf 'citations: NOT-GATED %s — the Delivers/Consumes sections of "%s" could not be read; nothing was checked\n' "$label" "$file" >&2
    return 2
  fi
  if [ "$_CG_VIOLATIONS" -gt "$before" ]; then
    printf 'citations: REFUSED %s — %s citation(s) break the one-bare-path grammar (bead-schema.md § The citation rule)\n' \
      "$label" "$((_CG_VIOLATIONS - before))"
    return 1
  fi
  printf 'citations: OK %s — every Delivers entry and Consumes citation is one bare path\n' "$label"
  return 0
}

cmd_artifact() { # <artifact-file>
  local file="${1:-}" ids id work rc=0
  if [ -z "$file" ] || [ ! -r "$file" ]; then
    printf 'citations: NOT-GATED — no readable artifact at "%s"; nothing was checked\n' "${file:-<none>}" >&2
    return 2
  fi
  ids=$(sed -n 's/^<!-- BEAD:\([^ ]*\) -->$/\1/p' "$file")
  if [ -z "$ids" ]; then
    printf 'citations: NOT-GATED — no <!-- BEAD:id --> block in %s; a sweep over nothing is never a pass\n' "$file" >&2
    return 2
  fi
  work=$(mktemp -d) || return 2
  for id in $ids; do
    awk -v o="<!-- BEAD:$id -->" -v c="<!-- /BEAD:$id -->" \
      '$0 == c { on = 0 } on { print } $0 == o { on = 1 }' "$file" >"$work/$id.md"
    # An empty block is a split that failed, never a bead with nothing to check.
    if [ ! -s "$work/$id.md" ]; then
      printf 'citations: NOT-GATED %s — its block could not be read out of %s; nothing was checked\n' "$id" "$file" >&2
      rm -rf "$work"; return 2
    fi
    cmd_check "$work/$id.md" "$id"
    case $? in 0) ;; 1) rc=1 ;; *) rm -rf "$work"; return 2 ;; esac
  done
  rm -rf "$work"
  return "$rc"
}

case "${1:-}" in
  check)    shift; cmd_check "$@" ;;
  artifact) shift; cmd_artifact "$@" ;;
  *)
    printf 'usage: citation-grammar.sh check <description-file> [<label>]\n       citation-grammar.sh artifact <artifact-file>\n' >&2
    exit 2 ;;
esac
