#!/usr/bin/env bash
# planned-layer.sh — read-only: computes the PLANNED LAYER (every open non-epic bead's
# `## Delivers` paths, plus the `## Deliverables` paths of every top-level `_plans/` plan
# that `plan-approve.sh check --approved` accepts and that carries no `beadified:`) and
# answers whether a plan's or an epic's overlaps with it are declared.
#
# Canon: _plans/_done/2026-09-25-1535-planned-layer.md § Approach (deliverable D1).
#
# "Open" means not closed — a finished (closed) bead is just code, not a promise; a draft
# plan, a beadified plan (read as its epic's own open beads instead) and a closed bead
# sharing a path never appear in the layer. A bead with no `## Delivers` path is listed
# `unindexed`, never keyword-guessed.
#
# Matching follows canon meaning, never keyword or semantic guessing: `## Delivers` /
# `## Deliverables` is the required write set, so a shared path is a `delivers` match; a
# subject file whose TEXT carries the `_touchers_stem` (skills/_tools/touchers.sh) of a
# layer Delivers path is a `referrer` match — the same stem rule the touchers gate uses,
# scoped to the subject's own files instead of the whole tree.
#
# THREE MODES:
#
#   list                    One row per layer item:
#                             bead\t<id>\t<title>\t<comma-separated paths>
#                             plan\t<path>\t<title>\t<comma-separated paths>
#                             unindexed\t<id>            (an open bead with no Delivers path)
#
#   scan <plan-file|epic-id>
#                           One TAB row per match against the layer:
#                             <matched-path>\t<delivers|referrer>\t<bead-id|plan-path>\t<title>
#                           Excludes the subject itself (a plan never matches itself; an
#                           epic never matches its own children — dotted `<epic>.*` ids
#                           unioned with `parent-child` dependency edges, same union rule
#                           as an epic close).
#
#   check <plan-file>      Read-only, never writes. Exit 0 when every id the scan names
#                           has one `## Planned layer` line `- <id> · <relationship> — …`
#                           naming one of consumes|supersedes|conflicts|independent.
#                           Exit 1 REFUSED, listing each undeclared id with its matched
#                           paths. Exit 2 NOT-GATED when `br`, the plan, or a required
#                           tool is unreadable/absent — never a silent pass.
#
# Seams for testing (never used against the real board/plans in this repo's own harness):
#   AC2_BR_CMD    — the br binary to invoke (default: br); honored via br-call.sh's br_call,
#                   so a stub executable stands in for `br list` / `br show` in fixtures.
#   AC2_PLANS_DIR — the top-level plans directory to scan for the plan half of the layer
#                   (default: <repo-root>/_plans). A fixture harness points this at a
#                   scratch directory so it never reads this repo's own _plans/.
#
# Usage: planned-layer.sh list
#        planned-layer.sh scan <plan-file|epic-id>
#        planned-layer.sh check <plan-file>
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for _pl_f in delivers-paths.sh br-call.sh touchers.sh; do
  [ -f "$HERE/$_pl_f" ] || { printf 'NOT-GATED: %s missing at %s — cannot resolve the shared pattern\n' "$_pl_f" "$HERE/$_pl_f" >&2; exit 2; }
  . "$HERE/$_pl_f"
done
_PA="$HERE/plan-approve.sh"
[ -f "$_PA" ] || { printf 'NOT-GATED: plan-approve.sh missing at %s\n' "$_PA" >&2; exit 2; }

command -v jq >/dev/null 2>&1 || { printf 'NOT-GATED: jq not on PATH — cannot read the board\n' >&2; exit 2; }

_PL_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
[ -n "$_PL_ROOT" ] || { printf 'NOT-GATED: not inside a git repo — the plans directory cannot be resolved\n' >&2; exit 2; }
_PL_PLANS_DIR="${AC2_PLANS_DIR:-$_PL_ROOT/_plans}"

# ---------------------------------------------------------------------------------------
# shared helpers
# ---------------------------------------------------------------------------------------

# Same awk shape as plan-approve.sh's _section_body, over STDIN instead of a file — the
# board's bead descriptions arrive as strings, never as files.
_pl_section_body() {
  awk -v h="$1" '
    $0 ~ ("^" h) { on=1; next }
    /^## / { on=0 }
    on { print }
  '
}

# The Delivers-path extraction contract: touchers: lines are dropped BEFORE extraction —
# they name a command, not a promised artifact.
_pl_delivers_paths_from_body() {
  grep -v '^[[:space:]]*touchers:' | extract_paths
}

_pl_plan_title() {
  grep -m1 '^# ' "$1" | sed 's/^# *//'
}

# Frontmatter-scoped: a `beadified:` MENTION in the body (e.g. this very file's own prose)
# must never count — only the frontmatter key does.
_pl_has_beadified() {
  awk 'NR==1 && $0=="---" { infm=1; next } infm && $0=="---" { exit } infm && /^beadified:/ { found=1 } END { exit !found }' "$1"
}

# Absolute path, whether or not the file/dir exists yet on disk at the moment of call —
# used only for path IDENTITY (self-exclusion), never for existence testing.
_pl_abspath() {
  local p="$1" dir base
  if [ -d "$p" ]; then (cd "$p" 2>/dev/null && pwd) || printf '%s' "$p"; return; fi
  dir=$(cd "$(dirname "$p")" 2>/dev/null && pwd) || { printf '%s' "$p"; return; }
  base=$(basename "$p")
  printf '%s/%s' "$dir" "$base"
}

# The canonical id for a plan: absolute path, displayed root-relative when it falls under
# the repo root (the common case) — computed the SAME way for the CLI subject and for
# every plan-layer row, so self-exclusion is a plain string match regardless of how either
# path was spelled (relative, absolute, or via AC2_PLANS_DIR pointing outside the root).
_pl_canon_path() {
  local abs; abs=$(_pl_abspath "$1")
  case "$abs" in
    "$_PL_ROOT"/*) printf '%s' "${abs#"$_PL_ROOT"/}" ;;
    *) printf '%s' "$abs" ;;
  esac
}

# One real board read, failing loud rather than reading a dead board as empty.
_pl_preflight() {
  br_call list --status all --limit 0 --json >/dev/null || { printf 'NOT-GATED: br list failed — the board could not be read\n' >&2; exit 2; }
}

# ---------------------------------------------------------------------------------------
# layer half 1: open, non-epic beads
# ---------------------------------------------------------------------------------------

# TSV: id \t title \t comma-separated Delivers paths (empty = unindexed).
_pl_bead_layer() {
  local json line id title desc body paths
  json=$(br_call list --status all --limit 0 --json) || { printf 'NOT-GATED: br list failed\n' >&2; return 2; }
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    id=$(printf '%s' "$line" | jq -r '.id')
    title=$(printf '%s' "$line" | jq -r '.title')
    desc=$(printf '%s' "$line" | jq -r '.description // ""')
    body=$(printf '%s\n' "$desc" | _pl_section_body "## Delivers")
    paths=$(printf '%s\n' "$body" | _pl_delivers_paths_from_body | tr '\n' ',' | sed 's/,$//')
    printf '%s\t%s\t%s\n' "$id" "$title" "$paths"
  done < <(printf '%s' "$json" | jq -c '.issues[] | select(.status != "closed" and .issue_type != "epic")')
}

# ---------------------------------------------------------------------------------------
# layer half 2: top-level approved (not-beadified) plans
# ---------------------------------------------------------------------------------------

# TSV: id (canon path) \t title \t comma-separated Deliverables paths.
_pl_plan_layer() {
  local f id title body paths
  [ -d "$_PL_PLANS_DIR" ] || return 0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    _pl_has_beadified "$f" && continue
    bash "$_PA" check --approved "$f" >/dev/null 2>&1 || continue
    id=$(_pl_canon_path "$f")
    title=$(_pl_plan_title "$f")
    body=$(_pl_section_body "## Deliverables" < "$f")
    paths=$(printf '%s\n' "$body" | _pl_delivers_paths_from_body | tr '\n' ',' | sed 's/,$//')
    printf '%s\t%s\t%s\n' "$id" "$title" "$paths"
  done < <(find "$_PL_PLANS_DIR" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort)
}

_pl_full_layer() {
  _pl_bead_layer
  _pl_plan_layer
}

# ---------------------------------------------------------------------------------------
# epic children — same union rule as an epic close (dotted ids ∪ parent-child edges)
# ---------------------------------------------------------------------------------------

_pl_epic_children() {
  local epic="$1" show_json list_json edge dotted
  show_json=$(br_call show "$epic" --json) || return 2
  edge=$(printf '%s' "$show_json" | jq -r '.[0].dependents[]? | select(.dependency_type=="parent-child") | .id')
  list_json=$(br_call list --status all --limit 0 --json) || return 2
  dotted=$(printf '%s' "$list_json" | jq -r --arg p "$epic." '.issues[] | select(.id | startswith($p)) | .id')
  { printf '%s\n' "$edge"; printf '%s\n' "$dotted"; } | grep -v '^$' | sort -u
}

_pl_epic_subject_paths() {
  local epic="$1" children list_json id desc body paths out=""
  children=$(_pl_epic_children "$epic") || return 2
  list_json=$(br_call list --status all --limit 0 --json) || return 2
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    desc=$(printf '%s' "$list_json" | jq -r --arg id "$id" '.issues[] | select(.id==$id) | .description // empty')
    [ -n "$desc" ] || continue
    body=$(printf '%s\n' "$desc" | _pl_section_body "## Delivers")
    paths=$(printf '%s\n' "$body" | _pl_delivers_paths_from_body)
    out="${out}${paths}"$'\n'
  done <<EOF
$children
EOF
  printf '%s\n' "$out" | grep -v '^$' | sort -u
}

# ---------------------------------------------------------------------------------------
# matching engine
# ---------------------------------------------------------------------------------------

# subj_paths_list (newline list) x exclude (" id1 id2 … " space-padded) -> scan rows.
_pl_match() {
  local subj_paths_list="$1" exclude="$2"
  local kind_unused id title paths p stem found sf matched_kind parr
  while IFS=$'\t' read -r id title paths; do
    [ -n "$paths" ] || continue
    case "$exclude" in *" $id "*) continue ;; esac
    IFS=',' read -ra parr <<< "$paths"
    for p in "${parr[@]}"; do
      [ -n "$p" ] || continue
      matched_kind=""
      if printf '%s\n' "$subj_paths_list" | grep -qxF "$p"; then
        matched_kind=delivers
      else
        stem=$(_touchers_stem "$p")
        found=0
        while IFS= read -r sf; do
          [ -n "$sf" ] || continue
          [ -f "$sf" ] || continue
          if grep -qF "$stem" "$sf" 2>/dev/null; then found=1; break; fi
        done <<EOF
$subj_paths_list
EOF
        [ "$found" -eq 1 ] && matched_kind=referrer
      fi
      [ -n "$matched_kind" ] && printf '%s\t%s\t%s\t%s\n' "$p" "$matched_kind" "$id" "$title"
    done
  done < <(_pl_full_layer)
  return 0
}

# ---------------------------------------------------------------------------------------
# list
# ---------------------------------------------------------------------------------------

mode_list() {
  _pl_preflight
  local id title paths
  _pl_bead_layer | while IFS=$'\t' read -r id title paths; do
    if [ -z "$paths" ]; then
      printf 'unindexed\t%s\n' "$id"
    else
      printf 'bead\t%s\t%s\t%s\n' "$id" "$title" "$paths"
    fi
  done
  _pl_plan_layer | while IFS=$'\t' read -r id title paths; do
    printf 'plan\t%s\t%s\t%s\n' "$id" "$title" "$paths"
  done
}

# ---------------------------------------------------------------------------------------
# scan
# ---------------------------------------------------------------------------------------

mode_scan() {
  _pl_preflight
  local subject="${1:-}"
  [ -n "$subject" ] || { printf 'NOT-GATED: scan needs a plan file or epic id\n' >&2; exit 2; }
  local exclude subj_paths_list subj_id children
  if [ -f "$subject" ]; then
    subj_id=$(_pl_canon_path "$subject")
    subj_paths_list=$(_pl_section_body "## Deliverables" < "$subject" | _pl_delivers_paths_from_body)
    exclude=" $subj_id "
  else
    br_call show "$subject" --json >/dev/null 2>&1 || { printf 'NOT-GATED: %s is not a readable plan file or a known bead id\n' "$subject" >&2; exit 2; }
    subj_paths_list=$(_pl_epic_subject_paths "$subject") || { printf 'NOT-GATED: could not derive %s child Delivers paths\n' "$subject" >&2; exit 2; }
    children=$(_pl_epic_children "$subject") || { printf 'NOT-GATED: could not derive %s children\n' "$subject" >&2; exit 2; }
    exclude=" $subject $(printf '%s' "$children" | tr '\n' ' ') "
  fi
  if ! printf '%s\n' "$subj_paths_list" | grep -q .; then
    return 0
  fi
  _pl_match "$subj_paths_list" "$exclude"
}

# ---------------------------------------------------------------------------------------
# check
# ---------------------------------------------------------------------------------------

# Every `- <id> · <relationship> — …` line inside `## Planned layer` whose relationship
# names one of the four tokens — the id column, trimmed.
_pl_declared_ids() {
  awk '
    /^## Planned layer/ { on=1; next }
    /^## / { on=0 }
    on && /^-[[:space:]]/ {
      line=$0
      sub(/^-[[:space:]]*/, "", line)
      n = split(line, parts, "·")
      id = parts[1]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", id)
      if (line ~ /(consumes|supersedes|conflicts|independent)/ && id != "") print id
    }
  ' "$1"
}

mode_check() {
  local plan="${1:-}"
  [ -n "$plan" ] && [ -r "$plan" ] || { printf 'NOT-GATED: plan missing or unreadable: %s\n' "${plan:-<none>}" >&2; exit 2; }
  local scan_out rc
  scan_out=$(mode_scan "$plan"); rc=$?
  [ "$rc" -eq 0 ] || { printf 'NOT-GATED: scan failed for %s (exit %s)\n' "$plan" "$rc" >&2; exit 2; }
  local ids declared undeclared="" id paths
  ids=$(printf '%s\n' "$scan_out" | awk -F'\t' 'NF>=3{print $3}' | sort -u)
  declared=$(_pl_declared_ids "$plan")
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    if ! printf '%s\n' "$declared" | grep -qxF "$id"; then
      paths=$(printf '%s\n' "$scan_out" | awk -F'\t' -v i="$id" '$3==i{print $1}' | paste -sd, -)
      undeclared="${undeclared}${undeclared:+ }${id}(${paths})"
    fi
  done <<EOF
$ids
EOF
  if [ -n "$undeclared" ]; then
    printf 'REFUSED: undeclared overlap — %s\n' "$undeclared"
    exit 1
  fi
  printf 'OK: %s — every scanned overlap is declared\n' "$plan"
  exit 0
}

# ---------------------------------------------------------------------------------------
# dispatch
# ---------------------------------------------------------------------------------------

MODE="${1:-}"
case "$MODE" in
  list)  mode_list ;;
  scan)  shift; mode_scan "$@" ;;
  check) shift; mode_check "$@" ;;
  '')    printf 'NOT-GATED: a mode is required: list | scan | check\n' >&2; exit 2 ;;
  *)     printf 'NOT-GATED: unknown mode '\''%s'\'' — expected list | scan | check\n' "$MODE" >&2; exit 2 ;;
esac
