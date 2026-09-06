#!/usr/bin/env bash
# touchers.sh — the single home of the `touchers:` derivation and its check.
#
# Canon: beads-standards/reference/bead-create-contract.md § Touchers. A `## Delivers` path
# that EXISTS in the tree and is REFERENCED by another file owes, beneath its bullet, one
# line naming who updates those referrers:
#
#   touchers: `<command>` → <N> · owned by: <bead ids> | out-of-scope: <reason>
#
# The trigger is DERIVED, never declared — a bead cannot opt out by staying quiet. New files
# and unreferenced files owe nothing. WHY the count is re-run rather than remembered:
# bead-polish measured a 16.2% repair rate on hand-listed consumer sets, the cutover slate's
# caller list was short by two, and stamp-refined.sh itself was once archived with four live
# callers. A stale list is not a smaller claim — the list being stale when used IS the defect.
#
# ONE HOME, TWO CALLERS: the writer (`ac-beadify`, which runs `derive` and writes the line)
# and the gate (`stamp-refined.sh`, which runs `check` before writing `refined`). Two
# implementations of the same derivation drift, and the drift is invisible: the writer emits
# a line the gate then refuses.
#
# ASSURANCE (ac-pipeline/references/assurance-declarations.md § The four fields):
#   PROBE:      skills/_tools/touchers.test.sh — both polarities over every verdict below
#   SCHEDULE:   every `refined` stamp (stamp-refined.sh sources this file and calls
#               touchers_check); every ac-beadify Delivers/Consumes wiring step (`derive`);
#               and on every CI run via scripts/run-all-harnesses.sh
#   MODE:       blocking
#   ON-FAILURE: closed   (a count that could not be derived is a refusal, never a zero)
#
# Usage — sourced, or run:
#   . <path>/touchers.sh ; touchers_derive <rel-path> ; touchers_check <desc-file> [label]
#   bash <path>/touchers.sh derive <rel-path>
#   bash <path>/touchers.sh check  <desc-file> [label]
#
# `derive <rel-path>` prints one TAB-separated line `<stem>\t<N>\t<command>`, where the
# command is the gate's own rg shape written to run from the repo root — paste it into the
# bead. A path that does not exist in the tree prints `new` (a new artifact owes nothing).
#
# Exit codes (assurance-declarations § NOT-GATED):
#   0  touchers: OK        — nothing owed, or every owed line present and reproducing
#   1  touchers: REFUSED   — a content verdict (missing, malformed, stale, or multi-path bullet)
#   2  touchers: NOT-GATED — the count was never derived (no rg, no repo); nothing is claimed
#
# Deliberately NO `set -u` / `set -e` / `pipefail` at top level: this file is SOURCED into
# stamp-refined.sh, and shell options set here would leak into every caller.

# Self-location, bash and zsh, sourced or executed (same construction as stamp-refined.sh).
# zsh does not populate BASH_SOURCE; bash does not set $0 to the file when sourced.
if [ -n "${ZSH_VERSION:-}" ]; then
  _TOUCHERS_SELF="$0"
else
  _TOUCHERS_SELF="${BASH_SOURCE[0]}"
fi

# The exclusion set is part of the DERIVATION, not a caller's taste: change it here and the
# writer and the gate change together. `.beads/**`, `_plans/**` and the doc dirs are excluded
# because a bead body or a retired plan naming a path is not a caller of it.
_touchers_globs() {
  local _tg_q="'"
  printf -- '-g %s!node_modules/**%s -g %s!.beads/**%s -g %s!_plans/**%s -g %s!_backlog/**%s -g %s!_docs/**%s -g %s!docs/**%s -g %s!memory/**%s -g %s!CHANGELOG*%s' \
    "$_tg_q" "$_tg_q" "$_tg_q" "$_tg_q" "$_tg_q" "$_tg_q" "$_tg_q" "$_tg_q" \
    "$_tg_q" "$_tg_q" "$_tg_q" "$_tg_q" "$_tg_q" "$_tg_q" "$_tg_q" "$_tg_q"
}

# The stem is the last TWO path segments with the extension dropped — narrow enough that
# `foods` does not match every food in the tree, wide enough to catch an import written as
# `../db/foods`.
_touchers_stem() {
  printf '%s' "$1" | awk -F/ '{ s=$NF; sub(/\.[^.]*$/, "", s); if (NF>1) s=$(NF-1) "/" s; print s }'
}

# The command a bead pastes: the gate's shape, rooted at `.` so it runs from the repo root.
_touchers_command() {
  local _tc_q="'"
  printf 'rg -l -F "%s" . -g %s!%s%s %s' "$2" "$_tc_q" "$1" "$_tc_q" "$(_touchers_globs)"
}

# touchers_derive <rel-path>
#   -> `<stem>\t<N>\t<command>`  (path exists and was measured)
#   -> `new`                     (path does not exist yet — nothing owed)
#   -> exit 2                    (rg absent or broken; the count is UNKNOWN, never zero)
touchers_derive() {
  local rel="${1:-}" root stem cmd out rc n
  rel="${rel#./}"
  if [ -z "$rel" ]; then
    printf 'touchers: NOT-GATED derive needs a repo-relative path\n' >&2
    return 2
  fi
  root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [ -z "$root" ]; then
    printf 'touchers: NOT-GATED not inside a git repo, so touchers cannot be derived; refusing rather than guessing.\n' >&2
    return 2
  fi
  if [ ! -f "$root/$rel" ]; then
    printf 'new\n'
    return 0
  fi
  stem=$(_touchers_stem "$rel")
  cmd=$(_touchers_command "$rel" "$stem")
  # rg exits 0 (matches) or 1 (none). Anything else — 127 absent, 2 bad invocation — means
  # the count was never derived; reading that as "zero references" would let a missing tool
  # wave a bead through, so it is a refusal, not a zero.
  out=$( (cd "$root" && bash -c "$cmd") 2>/dev/null ); rc=$?
  if [ "$rc" -gt 1 ]; then
    printf 'touchers: NOT-GATED rg exited %s deriving touchers for `%s` (absent or broken), so the reference count is unknown; refusing rather than reading it as zero.\n' "$rc" "$rel" >&2
    return 2
  fi
  n=$(printf '%s\n' "$out" | grep -c .)
  printf '%s\t%s\t%s\n' "$stem" "$n" "$cmd"
}

# touchers_check <description-file> [<label-for-messages>]
# The whole leg over one bead description. One verdict, one greppable token.
touchers_check() {
  local file="${1:-}" label="${2:-}" root dl numbered maxb b block paths existing count
  local rel dout stem refs tline tcmd tn actual
  [ -n "$label" ] || label="${file:-description}"

  if [ -z "$file" ] || [ ! -f "$file" ]; then
    printf 'touchers: NOT-GATED %s — no readable description file at "%s"; nothing was checked.\n' "$label" "${file:-<none>}" >&2
    return 2
  fi
  root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [ -z "$root" ]; then
    printf 'touchers: NOT-GATED %s — not inside a git repo, so touchers cannot be derived; refusing rather than guessing.\n' "$label" >&2
    return 2
  fi

  dl=$(awk '/^## Delivers/{on=1; next} /^## /{on=0} on' "$file")
  if [ -z "$(printf '%s' "$dl" | tr -d '[:space:]')" ]; then
    printf 'touchers: OK %s — no ## Delivers content, so nothing can be owed.\n' "$label"
    return 0
  fi

  # BLOCKS, not the flat section (defect measured 2026-09-06). Each `- ` bullet opens a block
  # that ends at the next bullet; a path is read against the touchers line of ITS OWN bullet.
  # Reading the section flat made the FIRST touchers line answer for every later path.
  numbered=$(printf '%s\n' "$dl" | awk '{ if ($0 ~ /^[[:space:]]*[-*][[:space:]]/) b++; printf "%d\t%s\n", b+0, $0 }')
  maxb=$(printf '%s\n' "$numbered" | awk -F'\t' '{ if ($1+0 > m) m = $1+0 } END { print m+0 }')

  b=0
  while [ "$b" -le "$maxb" ]; do
    block=$(printf '%s\n' "$numbered" | awk -F'\t' -v want="$b" '$1+0 == want { sub(/^[0-9]*\t/, ""); print }')
    b=$((b + 1))
    [ -n "$block" ] || continue

    # A touchers line NAMES paths — inside its own -g glob, and often in its reason. Reading
    # those as deliveries invented obligations no bullet could ever satisfy (measured
    # 2026-09-06), so the disposition is excluded from the extraction, never from the check.
    paths=$(printf '%s\n' "$block" | grep -v '^[[:space:]]*touchers:' \
      | grep -oE '(\./)?[][A-Za-z0-9_@.()-]+(/[][A-Za-z0-9_@.()-]+)+\.[A-Za-z0-9]{1,6}' | sort -u)
    existing=$(printf '%s\n' "$paths" | while IFS= read -r p; do
      p="${p#./}"
      [ -n "$p" ] || continue
      [ -f "$root/$p" ] && printf '%s\n' "$p"
    done)
    count=$(printf '%s\n' "$existing" | grep -c .)
    [ "${count:-0}" -gt 0 ] || continue          # only NEW artifacts here — nothing owed

    if [ "$count" -gt 1 ]; then
      printf 'touchers: REFUSED %s — [unowned-touchers] one path per Delivers bullet: this bullet names %s paths that exist in the tree (%s), and a single touchers line cannot own more than one — every path after the first would go silently unchecked. Split it into one bullet per path.\n' \
        "$label" "$count" "$(printf '%s' "$existing" | tr '\n' ' ')" >&2
      return 1
    fi
    rel="$existing"

    dout=$(touchers_derive "$rel") || {
      printf 'touchers: NOT-GATED %s — the reference count for `%s` could not be derived; nothing was checked.\n' "$label" "$rel" >&2
      return 2
    }
    [ "$dout" != "new" ] || continue
    stem=$(printf '%s' "$dout" | cut -f1)
    refs=$(printf '%s' "$dout" | cut -f2)
    [ "${refs:-0}" -gt 0 ] || continue           # nothing references it

    # The line belongs to THIS bullet: the first `touchers:` line inside this block.
    tline=$(printf '%s\n' "$block" | grep -m1 '^[[:space:]]*touchers:')
    if [ -z "$tline" ]; then
      printf 'touchers: REFUSED %s — [unowned-touchers] `%s` exists and is referenced by %s file(s) (rg -l -F "%s"), but its ## Delivers entry carries no touchers: line. Add beneath the bullet: touchers: `<command>` → <N> · owned by: <bead ids> | out-of-scope: <reason>.\n' \
        "$label" "$rel" "$refs" "$stem" >&2
      return 1
    fi

    tcmd=$(printf '%s' "$tline" | sed -n 's/.*touchers:[[:space:]]*`\([^`]*\)`.*/\1/p'); tcmd=${tcmd//\\|/|}
    tn=$(printf '%s' "$tline" | grep -oE '→[[:space:]]*[0-9]+' | head -1 | grep -oE '[0-9]+')
    if [ -z "$tcmd" ] || [ -z "$tn" ] || ! printf '%s' "$tline" | grep -qE 'owned by:|out-of-scope:'; then
      printf 'touchers: REFUSED %s — [unowned-touchers] the touchers line for `%s` is malformed; expected: touchers: `<command>` → <N> · owned by: … | out-of-scope: ….\n' \
        "$label" "$rel" >&2
      return 1
    fi

    actual=$( (cd "$root" && bash -c "$tcmd" 2>/dev/null) | grep -c . )
    if [ "$actual" -ne "$tn" ]; then
      printf 'touchers: REFUSED %s — [unowned-touchers] touchers for `%s` declare → %s but the command reproduces %s now; a stale toucher list is the defect this gate exists for. Re-derive, then re-stamp.\n' \
        "$label" "$rel" "$tn" "$actual" >&2
      return 1
    fi
  done

  printf 'touchers: OK %s — every referenced ## Delivers path carries a touchers line whose command reproduces its count.\n' "$label"
  return 0
}

_touchers_main() {
  local sub="${1:-}"
  case "$sub" in
    derive) shift; touchers_derive "$@" ;;
    check)  shift; touchers_check "$@" ;;
    *)
      printf 'usage: touchers.sh derive <rel-path>\n       touchers.sh check <description-file> [<label>]\n' >&2
      return 2 ;;
  esac
}

# Executed, or sourced? bash compares BASH_SOURCE[0] to $0. zsh sets $0 to the file in BOTH
# modes, so it cannot discriminate — read zsh_eval_context, whose last frame is `toplevel`
# when executed and `file` when sourced. Top level only: inside a function zsh appends
# `shfunc` and it never matches (which is what makes `. touchers.sh` legal from inside
# stamp_refined without running the CLI).
_TOUCHERS_DIRECT=0
if [ -n "${ZSH_VERSION:-}" ]; then
  [ "${zsh_eval_context[-1]-}" = toplevel ] && _TOUCHERS_DIRECT=1
else
  [ "${BASH_SOURCE[0]-}" = "${0}" ] && _TOUCHERS_DIRECT=1
fi

if [ "$_TOUCHERS_DIRECT" = 1 ]; then
  _touchers_main "$@"
  exit $?
fi
