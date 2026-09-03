#!/usr/bin/env bash
# diff-closure.sh — the REVERSE CLOSURE of a diff: every caller, outside the diff's own files,
# of every symbol the diff changed. The one computation the pipeline never made.
#
# WHY: every serious defect of 2026-08/09 was a caller nobody enumerated — a script archived
# with four live callers, a slate short by two. Upstream, ac-plan and stamp-refined.sh now
# make the DECLARATION (a bead's `touchers:` line names the callers of what it reshapes).
# This script is the SENSOR for that declaration, at the only surface every change crosses:
# the diff. It greps the callers of what ACTUALLY changed and compares them to what was
# declared. Design without a reality check is decoration; the diff is reality.
#
#   PASS      every outside caller was declared (or there are none)
#   REFUSED   [unowned-callers] a caller exists that no declaration named — the declaration
#             was wrong, the change drifted, or a bypass change touched a shared symbol
#   NOT-GATED usage or setup error; nothing measured, nothing claimed
#
# Callers in TEST files are reported but never refuse: a test outside the diff that breaks
# breaks LOUDLY in CI, which is the opposite of a seam.
#
# ASSURANCE (skills/ac-pipeline/references/assurance-declarations.md § The four fields):
#   PROBE:      skills/ac-implement/scripts/diff-closure.test.sh — fixture repos with known
#               callers; asserts refuse / pass-with-declaration / drift / deletion / new export
#   SCHEDULE:   worker §5 before self-review · ac-polish code-checklist §1 · ac-review Phase 5;
#               and on every CI run via scripts/run-all-harnesses.sh
#   MODE:       blocking
#   ON-FAILURE: closed — a refusal exits 1 before any commit; no bead and no callers passes,
#               so a self-contained hotfix pays nothing
#
# Usage: diff-closure.sh [--base <ref>] [--bead <id> | --declared <file>] [-C <repo>]
#   --base      what to diff the WORKING TREE against (default: merge-base of origin/main and HEAD)
#   --bead      read the bead's `touchers:` command(s) via `br show --json` and run them
#   --declared  a file of touchers commands, one per line (what --bead would have found)
# Symbols: TS/JS `export (function|const|class|interface|type|enum) NAME` lines added or
# removed; SQL `alter table … (add|drop|alter) column NAME`; deleted files (by import stem).
set -euo pipefail

die2() { printf 'diff-closure: NOT-GATED %s\n' "$*" >&2; exit 2; }

BASE="" BEAD="" DECL="" REPO="."
while [ $# -gt 0 ]; do
  case "$1" in
    --base)     BASE="${2:-}"; shift 2 ;;
    --bead)     BEAD="${2:-}"; shift 2 ;;
    --declared) DECL="${2:-}"; shift 2 ;;
    -C)         REPO="${2:-}"; shift 2 ;;
    -h|--help)  sed -n '/^# Usage/,/^set -euo/p' "$0" | sed '$d' >&2; exit 2 ;;
    *)          die2 "unknown argument: $1" ;;
  esac
done
[ -n "$BEAD" ] && [ -n "$DECL" ] && die2 "--bead and --declared are exclusive"
git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die2 "not a git repo: $REPO"
ROOT=$(git -C "$REPO" rev-parse --show-toplevel)
cd "$ROOT"
if [ -z "$BASE" ]; then
  BASE=$(git merge-base origin/main HEAD 2>/dev/null || true)
  [ -n "$BASE" ] || die2 "no --base and no origin/main to derive one from"
fi
git rev-parse --verify -q "$BASE^{commit}" >/dev/null || die2 "base is not a commit: $BASE"

W=$(mktemp -d "${TMPDIR:-/tmp}/diff-closure-XXXXXX"); trap 'rm -rf "$W"' EXIT

# --- 1. what changed: files, deleted files, and the symbols whose DEFINITION lines moved ---
git diff --name-only "$BASE" -- . | sort -u > "$W/changed"
git diff --name-status "$BASE" -- . | awk '$1=="D"{print $2}' > "$W/deleted"
git diff -U0 "$BASE" -- . \
  | grep -E '^[-+][^-+]' \
  | sed -E 's/^[-+]//' \
  | grep -oE '^\s*export\s+(default\s+)?(async\s+)?(function\*?|const|let|var|class|interface|type|enum)\s+[A-Za-z_$][A-Za-z0-9_$]*' \
  | awk '{print $NF}' | sort -u > "$W/symbols" || true
git diff -U0 "$BASE" -- . \
  | grep -E '^[-+][^-+]' \
  | grep -ioE 'alter table\s+\S+\s+(add|drop|alter)\s+column\s+[a-z_][a-z0-9_]*' \
  | awk '{print $NF}' | sort -u >> "$W/symbols" || true
while IFS= read -r f; do
  [ -n "$f" ] || continue
  b=$(basename "$f"); printf '%s\n' "${b%%.*}"
done < "$W/deleted" | sort -u > "$W/stems"

NSYM=$(grep -c . "$W/symbols" || true); NSTEM=$(grep -c . "$W/stems" || true)
if [ "$((NSYM + NSTEM))" -eq 0 ]; then
  printf 'diff-closure: PASS symbols=0 callers=0 — no exported definition, altered column or deleted file in the diff\n'
  exit 0
fi

# --- 2. the declaration: outputs of the bead's touchers commands, or the --declared file -----
: > "$W/declared"
if [ -n "$BEAD" ]; then
  command -v br >/dev/null 2>&1 || die2 "br not on PATH — cannot read bead $BEAD"
  br show --json "$BEAD" 2>/dev/null | jq -r '.[0].description // ""' \
    | grep -oE 'touchers:[[:space:]]*`[^`]+`' | sed -E 's/^touchers:[[:space:]]*`//; s/`$//' > "$W/decl-cmds" || true
elif [ -n "$DECL" ]; then
  [ -f "$DECL" ] || die2 "--declared file not found: $DECL"
  grep -v '^\s*$' "$DECL" > "$W/decl-cmds" || true
else
  : > "$W/decl-cmds"
fi
while IFS= read -r c; do
  [ -n "$c" ] || continue
  bash -c "$c" 2>/dev/null | sed 's|^\./||' >> "$W/declared" || true
done < "$W/decl-cmds"
sort -u "$W/declared" -o "$W/declared"
NDECL=$(grep -c . "$W/declared" || true)

# --- 3. the closure: callers outside the diff, per symbol; tests reported, never refused -----
EXG="-g !node_modules/** -g !_plans/** -g !_backlog/** -g !_docs/** -g !docs/** -g !memory/** -g !_archive/** -g !.beads/** -g !*.generated.* -g !*.lock"
: > "$W/refused"; : > "$W/tests"; NCALL=0
callers_of() {  # <pattern> <fixed:0|1>
  if [ "$2" = 1 ]; then rg --no-messages -l -w -F "$1" . $EXG --type ts --type js --type sql 2>/dev/null
  else rg --no-messages -l -w -e "$1" . $EXG --type ts --type js 2>/dev/null; fi | sed 's|^\./||' | sort -u
}
check() {  # <label> <pattern> <fixed>
  local label="$1" pat="$2" fixed="$3" c
  callers_of "$pat" "$fixed" | grep -vxF -f "$W/changed" > "$W/c" || true
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    NCALL=$((NCALL + 1))
    case "$c" in
      *.test.*|*__tests__*|*/tests/*) printf '%s\t%s\n' "$label" "$c" >> "$W/tests" ;;
      *) grep -qxF "$c" "$W/declared" || printf '%s\t%s\n' "$label" "$c" >> "$W/refused" ;;
    esac
  done < "$W/c"
}
while IFS= read -r s; do [ -n "$s" ] && check "$s" "$s" 1; done < "$W/symbols"
# a deleted file's callers import it by stem: `./old-module`, `@/lib/old-module`
while IFS= read -r st; do [ -n "$st" ] && check "deleted:$st" "[/'\"]${st}['\"]" 0; done < "$W/stems"

NTEST=$(grep -c . "$W/tests" || true); NREF=$(grep -c . "$W/refused" || true)
if [ "$NREF" -eq 0 ]; then
  printf 'diff-closure: PASS symbols=%s callers=%s declared=%s tests-outside=%s\n' "$((NSYM + NSTEM))" "$NCALL" "$NDECL" "$NTEST"
  exit 0
fi
printf 'diff-closure: REFUSED [unowned-callers] symbols=%s undeclared=%s declared=%s tests-outside=%s — a caller outside the diff that no touchers: line named. Own it (update it in this change, or add it to the bead touchers: line with its command), or split the change. No commit.\n' \
  "$((NSYM + NSTEM))" "$NREF" "$NDECL" "$NTEST" >&2
awk -F'\t' '{ printf "  %s  <- %s\n", $1, $2 }' "$W/refused" >&2
exit 1
