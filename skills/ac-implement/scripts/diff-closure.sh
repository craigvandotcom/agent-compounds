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
#               and on every CI run via scripts/run-all-proofs.sh
#   MODE:       blocking
#   ON-FAILURE: closed — a refusal exits 1 before any commit; no bead and no callers passes,
#               so a self-contained hotfix pays nothing
#
# Usage: diff-closure.sh [--base <ref>] [--bead <id> | --declared <file>]
#                        [--territory <path> ...] [-C <repo>]
#   --base       what to diff the WORKING TREE against. Default when --bead is given: HEAD —
#                a bead's own uncommitted change, never the branch's whole history, so a
#                sibling's already-committed WIP cannot seed a symbol this close depends on.
#                Default otherwise: the branch's tracking-ref merge-base, then the shared
#                trunk resolver when the branch tracks nothing.
#   --bead       read the bead's own scope and `touchers:` command(s) via the br show read.
#                Scope oracle, in order: an explicit --territory/--scope below; else the
#                bead's own `## Delivers` paths (bead.py's plain-text extractor, touchers:
#                lines excluded — the same paths close-gate's UNCOMMITTED leg reads); else
#                unscoped (today's behaviour for a bead with no Delivers paths).
#   --declared   a file of touchers commands, one per line (what --bead would have found)
#   --territory  limit the diff and caller snapshot to these repo-relative paths; repeat for
#                more than one path. Wins outright over a bead's own Delivers scope.
#                `--base HEAD --territory <path>` is the shared-checkout mode: it measures this
#                worker's uncommitted scope without the batch history or sibling WIP.
# Symbols: TS/JS `export (function|const|class|interface|type|enum) NAME` lines added or
# removed; SQL `alter table … (add|drop|alter) column NAME`; deleted files (by import stem).
set -euo pipefail

die2() { printf 'diff-closure: NOT-GATED %s\n' "$*" >&2; echo "NEXT: handback" >&2; exit 2; }

# The ONE br_call invocation shape (ac-heyt.3); a refusal below is a NOT-GATED,
# never empty data. Absolute path computed before any cd: BASH_SOURCE may be relative.
# shellcheck source=br-call.sh
BR_CALL="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../_tools" 2>/dev/null && pwd)/br-call.sh"
. "$BR_CALL" 2>/dev/null || die2 "br-call.sh helper missing at '$BR_CALL' — no br read can be verified"
# bead.py is the one bead reader every tool parses cards through (ac-m9y4.10): a `--bead`
# scope reads a bead's own `## Delivers` paths through its plain-text extractor, never a
# second hand-rolled copy of the pattern (canon:
# beads-standards/reference/bead-schema.md § Required axes).
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../_tools" 2>/dev/null && pwd)"
BEAD_PY_HOME="$TOOLS_DIR/bead.py"
[ -f "$BEAD_PY_HOME" ] || die2 "bead.py missing at '$BEAD_PY_HOME' — the Delivers-path extraction pattern cannot be resolved"
command -v python3 >/dev/null 2>&1 || die2 "python3 not on PATH — bead.py cannot be run"

# The program lives in its own file, never a heredoc attached to `python3 -`: a heredoc IS
# the command's stdin, so a text argument piped in on the same command would starve
# `sys.stdin.read()` of everything but EOF (the lesson needs-device-gate.sh's own
# write_device_paths_py already paid for) — the text travels via a temp FILE argument
# instead (the same shape plan-approve.sh's `_write_bead_extract_py` uses). `BEAD_MODULE_PATH`
# is the same test-only override bead-capture-guard.py's own `_load_bead_module()` uses: a
# nonexistent path drives the crash-path fixture without ever touching the real file in a
# shared checkout.
_write_bead_extract_py() {
  cat > "$1" <<'PY'
import importlib.util, os, sys


def _load_bead():
    override = os.environ.get("BEAD_MODULE_PATH")
    path = override or os.environ["BEAD_PY_PATH"]
    spec = importlib.util.spec_from_file_location("bead", path)
    if spec is None or spec.loader is None:
        raise ImportError(f"cannot load bead.py at {path!r}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    bead = _load_bead()
    with open(sys.argv[1], "r") as f:
        text = f.read()
    for p in bead.extract_paths(text):
        print(p)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        print(f"NOT-GATED: bead.py unavailable or crashed: {e}", file=sys.stderr)
        sys.exit(2)
PY
}

# _delivers_paths_via_bead [body] (else stdin) -> sorted unique path tokens, via bead.py's
# plain-text extractor. No trap: both temp files are removed by hand on every path through
# this function.
_delivers_paths_via_bead() {
  local input tf py rc
  if [ "$#" -gt 0 ]; then input="$1"; else input="$(cat)"; fi
  tf=$(mktemp) || { printf 'NOT-GATED: mktemp failed extracting Delivers paths\n' >&2; return 2; }
  printf '%s' "$input" > "$tf" || { rm -f "$tf"; printf 'NOT-GATED: writing the scratch text file failed extracting Delivers paths\n' >&2; return 2; }
  py=$(mktemp) || { rm -f "$tf"; printf 'NOT-GATED: mktemp failed extracting Delivers paths\n' >&2; return 2; }
  _write_bead_extract_py "$py"
  BEAD_PY_PATH="$BEAD_PY_HOME" python3 "$py" "$tf"; rc=$?
  rm -f "$tf" "$py"
  return $rc
}
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TRUNK="$SELF_DIR/../../_tools/trunk.sh"

BASE="" BEAD="" DECL="" REPO="." SCOPE=0
TERRITORY=()
while [ $# -gt 0 ]; do
  case "$1" in
    --base)     [ $# -ge 2 ] || die2 "--base requires a ref"; BASE="$2"; shift 2 ;;
    --bead)     [ $# -ge 2 ] || die2 "--bead requires an id"; BEAD="$2"; shift 2 ;;
    --declared) [ $# -ge 2 ] || die2 "--declared requires a file"; DECL="$2"; shift 2 ;;
    --territory|--scope)
      [ $# -ge 2 ] || die2 "$1 requires a repo-relative path"
      TERRITORY+=("$2"); SCOPE=1; shift 2 ;;
    -C)         [ $# -ge 2 ] || die2 "-C requires a repo"; REPO="$2"; shift 2 ;;
    -h|--help)  sed -n '/^# Usage/,/^set -euo/p' "$0" | sed '$d' >&2; exit 2 ;;
    *)          die2 "unknown argument: $1" ;;
  esac
done
[ -n "$BEAD" ] && [ -n "$DECL" ] && die2 "--bead and --declared are exclusive"
git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die2 "not a git repo: $REPO"
ROOT=$(git -C "$REPO" rev-parse --show-toplevel)
cd "$ROOT"
if [ -z "$BASE" ] && [ -n "$BEAD" ]; then
  # A `--bead` read is the swarm-facing call (worker §5, code-checklist §1): the diff must
  # measure THIS bead's own uncommitted change against the last commit, never the branch's
  # whole history back to its tracking ref — that longer reach is what let a sibling's
  # already-landed WIP seed a symbol this bead's close then depended on.
  BASE="HEAD"
fi
if [ -z "$BASE" ]; then
  TRACKING_REF='@{u}'
  BASE=$(git merge-base "$TRACKING_REF" HEAD 2>/dev/null || true)
  if [ -z "$BASE" ]; then
    [ -f "$TRUNK" ] || die2 "no branch upstream and trunk.sh is missing at '$TRUNK'"
    trunk=$(bash "$TRUNK") || die2 "no branch upstream and the shared trunk resolver failed"
    [ -n "$trunk" ] || die2 "no branch upstream and the shared trunk resolver returned no trunk"
    BASE=$(git merge-base "origin/$trunk" HEAD 2>/dev/null || true)
  fi
  [ -n "$BASE" ] || die2 "no --base; neither the branch upstream nor the shared trunk produced a merge-base"
fi
git rev-parse --verify -q "$BASE^{commit}" >/dev/null || die2 "base is not a commit: $BASE"

W=$(mktemp -d "${TMPDIR:-/tmp}/diff-closure-XXXXXX"); trap 'rm -rf "$W"' EXIT

# Read a bead once. The same description supplies its Delivers scope (when present) and its
# touchers commands; a scoped closure must never silently fall back to the whole tree just
# because the caller forgot to repeat the paths.
BEAD_RAW=""
BEAD_DESC=""
if [ -n "$BEAD" ]; then
  command -v br >/dev/null 2>&1 || die2 "br not on PATH — cannot read bead $BEAD"
  BEAD_RAW=$(br_call show --json "$BEAD") \
    || die2 "br_call show refused for bead $BEAD — the touchers declaration cannot be read"
  command -v jq >/dev/null 2>&1 || die2 "jq not on PATH — cannot read bead $BEAD"
  BEAD_DESC=$(printf '%s' "$BEAD_RAW" | jq -r 'if type == "array" then (.[0].description // "") else (.description // "") end') \
    || die2 "cannot parse bead $BEAD description"
fi

# A bead's own `## Delivers` paths ARE its scope oracle — the same paths `touchers.sh` and
# close-gate's UNCOMMITTED leg already read, through the one shared extraction pattern
# (bead.py's plain-text extractor). An explicit --territory/--scope still wins outright, so
# a caller can inspect a deliberate subset without editing the declaration. A bead with no
# Delivers paths and no explicit --territory/--scope stays unscoped (today's behaviour,
# unchanged). The extraction failing (a crashing bead.py) is NOT-GATED, never a silent
# unscoped fall-through — `if !` so `set -e` does not abort before die2 can report it.
# `_delivers_paths_via_bead` runs as its OWN final command over an already-computed
# string, never piped straight from awk/grep: under `pipefail`, a truly empty ## Delivers
# body makes `grep -v` itself exit 1 (nothing to select is not an error, but pipefail
# cannot tell the two apart) — chained into the pipe, that reads as "bead.py crashed" when
# it never ran. `|| true` on the filter alone keeps ITS benign non-match off this leg's verdict.
if [ "$SCOPE" -eq 0 ] && [ -n "$BEAD" ]; then
  DELIVERS_SECTION=$(printf '%s\n' "$BEAD_DESC" \
    | awk '/^## Delivers/{on=1; next} /^## /{on=0} on' \
    | grep -v '^[[:space:]]*touchers:' || true)
  if ! DELIVERS_LIST=$(_delivers_paths_via_bead "$DELIVERS_SECTION"); then
    die2 "bead.py failed extracting Delivers paths for bead $BEAD"
  fi
  if [ -n "$DELIVERS_LIST" ]; then
    SCOPE=1
    while IFS= read -r path; do
      [ -n "$path" ] || continue
      TERRITORY+=("$path")
    done <<< "$DELIVERS_LIST"
  fi
fi

if [ "$SCOPE" -eq 1 ]; then
  : > "$W/territory-normalized"
  for path in "${TERRITORY[@]}"; do
    path=${path#./}
    case "$path" in
      ""|"."|".."|/*|../*|*/../*|*/..) die2 "territory path is not a scoped repo-relative path: $path" ;;
      *$'\n'*|*$'\r'*) die2 "territory path contains a newline: $path" ;;
    esac
    printf '%s\n' "$path" >> "$W/territory-normalized"
  done
  sort -u "$W/territory-normalized" -o "$W/territory-normalized"
  TERRITORY=()
  while IFS= read -r path; do
    [ -n "$path" ] && TERRITORY+=("$path")
  done < "$W/territory-normalized"
  [ "${#TERRITORY[@]}" -gt 0 ] || die2 "territory scope has no paths"
fi

# Keep the symbol diff's path exclusions identical to the caller search's prose exclusions.
# In particular, SQL examples under _docs, _plans, and memory are documentation, not changed
# definitions; letting them seed symbols creates phantom caller closures.
EXCLUDE_DIRS=(node_modules _plans _backlog _docs docs memory _archive .beads)
EXG=()
DIFF_EXG=()
for dir in "${EXCLUDE_DIRS[@]}"; do
  EXG+=("-g" "!$dir/**")
  DIFF_EXG+=(":(exclude,glob)$dir/**")
done
EXG+=("-g" "!*.generated.*" "-g" "!*.lock")
DIFF_EXG+=(":(exclude,glob)**/*.generated.*" ":(exclude,glob)**/*.lock")

# --- 1. what changed: files, deleted files, and the symbols whose DEFINITION lines moved ---
# The symbol leg shares EXG's prose exclusions with caller search: _docs, _plans, memory,
# and the other documentation surfaces cannot mint a definition from an example query.
DIFF_PATHS=(".")
if [ "$SCOPE" -eq 1 ]; then
  DIFF_PATHS=()
  for path in "${TERRITORY[@]}"; do DIFF_PATHS+=(":(literal)$path"); done
fi
git diff --name-only "$BASE" -- "${DIFF_PATHS[@]}" "${DIFF_EXG[@]}" | sort -u > "$W/changed"
git diff --name-status "$BASE" -- "${DIFF_PATHS[@]}" "${DIFF_EXG[@]}" | awk '$1=="D"{print $2}' > "$W/deleted"
git diff -U0 "$BASE" -- "${DIFF_PATHS[@]}" "${DIFF_EXG[@]}" \
  | grep -E '^[-+][^-+]' \
  | sed -E 's/^[-+]//' \
  | grep -oE '^\s*export\s+(default\s+)?(async\s+)?(function\*?|const|let|var|class|interface|type|enum)\s+[A-Za-z_$][A-Za-z0-9_$]*' \
  | awk '{print $NF}' | sort -u > "$W/symbols" || true
git diff -U0 "$BASE" -- "${DIFF_PATHS[@]}" "${DIFF_EXG[@]}" \
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
  printf '%s' "$BEAD_DESC" \
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
# In a scoped read, the caller corpus is the committed HEAD snapshot plus the current
# scope paths only. A sibling's dirty file is not a caller of this bead, and must not be able
# to turn a clean bead into a false REFUSED verdict.
GIT_GREP_TYPES=(":(glob)**/*.ts" ":(glob)**/*.tsx" ":(glob)**/*.mts" ":(glob)**/*.cts" ":(glob)**/*.js" ":(glob)**/*.jsx" ":(glob)**/*.mjs" ":(glob)**/*.cjs")
GIT_GREP_SQL_TYPES=("${GIT_GREP_TYPES[@]}" ":(glob)**/*.sql")
git_grep_head() {  # <pattern> <fixed:0|1>
  local pat="$1" fixed="$2"
  if [ "$fixed" = 1 ]; then
    git grep --name-only -w -F -e "$pat" HEAD -- "${GIT_GREP_SQL_TYPES[@]}" "${DIFF_EXG[@]}" 2>/dev/null || true
  else
    git grep --name-only -w -e "$pat" HEAD -- "${GIT_GREP_TYPES[@]}" "${DIFF_EXG[@]}" 2>/dev/null || true
  fi | sed 's|^HEAD:||'
}
callers_of() {  # <pattern> <fixed:0|1>
  local pat="$1" fixed="$2"
  if [ "$SCOPE" -eq 1 ]; then
    {
      git_grep_head "$pat" "$fixed"
      if [ "$fixed" = 1 ]; then
        rg --no-messages -l -w -F -e "$pat" "${EXG[@]}" --type ts --type js --type sql -- "${TERRITORY[@]}" 2>/dev/null || true
      else
        rg --no-messages -l -w -e "$pat" "${EXG[@]}" --type ts --type js -- "${TERRITORY[@]}" 2>/dev/null || true
      fi
    } | sed -e 's|^\./||' -e 's|^HEAD:||' | sort -u
  elif [ "$fixed" = 1 ]; then
    rg --no-messages -l -w -F -e "$pat" "${EXG[@]}" --type ts --type js --type sql -- . 2>/dev/null || true
  else
    rg --no-messages -l -w -e "$pat" "${EXG[@]}" --type ts --type js -- . 2>/dev/null || true
  fi | sed 's|^\./||' | sort -u
}
: > "$W/refused"; : > "$W/tests"; NCALL=0
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
echo "NEXT: pick" >&2
exit 1
