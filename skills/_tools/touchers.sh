#!/usr/bin/env bash
# touchers.sh — the single home of the `touchers:` derivation and its check.
#
# Canon: beads-standards/reference/bead-schema.md § Required axes. A `## Delivers` path
# that git TRACKS and that is REFERENCED by another file owes, beneath its bullet, one
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
#               and on every CI run via scripts/run-all-proofs.sh
#   MODE:       blocking
#   ON-FAILURE: closed   (a count that could not be derived is a refusal, never a zero)
#
# Usage — sourced, or run:
#   . <path>/touchers.sh ; touchers_derive <rel-path> ; touchers_check <desc-file> [label]
#   bash <path>/touchers.sh derive <rel-path>
#   bash <path>/touchers.sh check  <desc-file> [label]
#
# `derive <rel-path>` prints one TAB-separated line `<stem>\t<command>`, where the command is
# the gate's own rg shape written to run from the repo root — paste it into the bead. A path
# git does not track prints `new` (a new artifact owes nothing). The command is re-run LIVE at
# every check, never a remembered count: a bead's `touchers:` line names WHO owns keeping its
# referrers current, not a number that goes stale the moment any other bead lands.
#
# Exit codes (assurance-declarations § NOT-GATED):
#   0  touchers: OK        — nothing owed, or every owed line present and its command runs clean
#   1  touchers: REFUSED   — a content verdict (missing, malformed, zero-referrer, or multi-path bullet)
#   2  touchers: NOT-GATED — the command was never verified runnable (no rg, no repo); nothing is claimed
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

# bead.py is the one bead reader every tool parses cards through (ac-m9y4.10): the
# Delivers-path extraction below reads through its plain-text `extract_paths()`, never a
# second hand-rolled copy of the pattern (the prior shared-pattern file is deleted by this
# same bead). Checked at load time — this file is SOURCED, so a missing/unusable bead.py
# must refuse before any caller (stamp-refined.sh, touchers.test.sh) ever reaches a check.
_TOUCHERS_TOOLS_DIR="$(cd "$(dirname "$_TOUCHERS_SELF")" && pwd)"
_BEAD_PY_HOME="$_TOUCHERS_TOOLS_DIR/bead.py"
[ -f "$_BEAD_PY_HOME" ] || { printf 'touchers: NOT-GATED — bead.py missing at %s — the Delivers-path extraction pattern cannot be resolved\n' "$_BEAD_PY_HOME" >&2; return 2 2>/dev/null || exit 2; }
command -v python3 >/dev/null 2>&1 || { printf 'touchers: NOT-GATED — python3 not on PATH — bead.py cannot be run\n' >&2; return 2 2>/dev/null || exit 2; }

# The program lives in its own file, never a heredoc attached to `python3 -`: a heredoc
# IS the command's stdin, so a text argument piped in on the same command would starve
# `sys.stdin.read()` of everything but EOF (the lesson needs-device-gate.sh's own
# write_device_paths_py already paid for) — the text travels via a temp FILE argument
# instead, written and removed BY HAND rather than an EXIT trap: this library is SOURCED
# into other scripts (stamp-refined.sh), so a trap set here would stomp — or be stomped
# by — the caller's own (same reasoning plan-approve.sh's `_write_bead_extract_py` /
# `_extract_paths_via_bead` pair already carries; this is that shape, scoped to touchers.sh).
# `BEAD_MODULE_PATH` is the same test-only override bead-capture-guard.py's own
# `_load_bead_module()` uses: a nonexistent path drives the crash-path fixture without
# ever touching the real file in a shared checkout.
_touchers_write_extract_py() {
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

# _touchers_extract_paths [body] (else stdin) -> sorted unique path tokens, via bead.py's
# plain-text extractor. No trap: both temp files are removed by hand on every path through
# this function, so sourcing into a caller with its own EXIT trap is safe either way.
_touchers_extract_paths() {
  local input tf py rc
  if [ "$#" -gt 0 ]; then input="$1"; else input="$(cat)"; fi
  tf=$(mktemp) || { printf 'touchers: NOT-GATED mktemp failed extracting Delivers paths\n' >&2; return 2; }
  printf '%s' "$input" > "$tf" || { rm -f "$tf"; printf 'touchers: NOT-GATED writing the scratch text file failed extracting Delivers paths\n' >&2; return 2; }
  py=$(mktemp) || { rm -f "$tf"; printf 'touchers: NOT-GATED mktemp failed extracting Delivers paths\n' >&2; return 2; }
  _touchers_write_extract_py "$py"
  BEAD_PY_PATH="$_BEAD_PY_HOME" python3 "$py" "$tf"; rc=$?
  rm -f "$tf" "$py"
  return $rc
}

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
# `../db/foods`. A monorepo container directory (`src`, `lib`, `test`, `tests`, `dist`) is
# generic by design — `packages/a/src/index.ts` and `packages/b/src/index.ts` both reduce to
# `src/index`, collapsing two distinct artifacts into one touchers count. When the path opens
# `packages/` or `apps/` and a container segment sits directly above the file, the stem is
# widened by one more segment: the one directly above the container (`$(NF-2)`, computed from
# the END of the path, never a fixed `$2` — deeper nesting must still read a CONTIGUOUS suffix
# of the path, not an arbitrary early segment). Invariant: the stem is always a contiguous
# suffix of the path with the extension dropped. Trade-off accepted: a relative import written
# from INSIDE the package itself, like `../src/event`, no longer matches the widened stem at
# stamp time — it is not lost, it surfaces at close as diff-closure `[unowned-callers]`.
_touchers_stem() {
  printf '%s' "$1" | awk -F/ '
    {
      s = $NF
      sub(/\.[^.]*$/, "", s)
      if (NF > 2 && ($1 == "packages" || $1 == "apps")) {
        container = $(NF - 1)
        if (container == "src" || container == "lib" || container == "test" || \
            container == "tests" || container == "dist") {
          print $(NF - 2) "/" container "/" s
          next
        }
      }
      if (NF > 1) s = $(NF - 1) "/" s
      print s
    }
  '
}

# The stem alone misses a caller that names the script by BARE FILENAME rather than its
# stem path — `close-gate.sh` in prose, or `$HERE/close-gate.sh` / a runtime-built path whose
# static text still carries the plain filename (measured 2026-09-26: worker.md, refly.sh and
# flight-check.sh all cite touchers.sh's own subjects this way and derive missed every one).
# The extension survives here — the stem drops it, so the two patterns are never redundant.
_touchers_basename() {
  printf '%s' "$1" | awk -F/ '{print $NF}'
}

# A basename many tracked files share (SKILL.md, MAINTENANCE.md, README.md, …) identifies
# no single artifact — counting ITS referrers means counting every unrelated file's referrers
# too (measured 2026-09-27, ac-dovy: ~174 "referrers" for any SKILL.md). The bare-filename
# alternative is only added when exactly one tracked file carries that basename.
_touchers_basename_unique() {
  local root="$1" base="$2" n
  n=$(git -C "$root" ls-files -- '*' 2>/dev/null | awk -F/ -v b="$base" '$NF == b' | grep -c .)
  [ "$n" = 1 ]
}

# The command a bead pastes: the gate's shape, rooted at `.` so it runs from the repo root.
# Two -F alternatives when the basename is unique — the stem catches a path-shaped reference,
# the basename catches a bare-filename or built-path one; a shared basename keeps the stem-only
# command, since a bare-filename alternative there would match every file of that name.
_touchers_command() {
  local _tc_q="'" root="$1" rel="$2" stem="$3" base
  base=$(_touchers_basename "$rel")
  if _touchers_basename_unique "$root" "$base"; then
    printf 'rg -l -F -e "%s" -e "%s" . -g %s!%s%s %s' "$stem" "$base" "$_tc_q" "$rel" "$_tc_q" "$(_touchers_globs)"
  else
    printf 'rg -l -F -e "%s" . -g %s!%s%s %s' "$stem" "$_tc_q" "$rel" "$_tc_q" "$(_touchers_globs)"
  fi
}

# Existence is a GIT fact, not a disk fact: a path on disk but untracked is a NEW artifact
# that owes nothing. `derive` and `check` share this ONE home so the two readings of "exists"
# cannot drift.
_touchers_tracked() {
  git -C "$1" ls-files --error-unmatch -- "$2" >/dev/null 2>&1
}

# touchers_derive <rel-path>
#   -> `<stem>\t<command>`  (path is git-tracked; the command is verified runnable)
#   -> `new`                (path is not tracked yet — nothing owed)
#   -> exit 2               (rg absent or broken; runnability is UNKNOWN, never assumed clean)
touchers_derive() {
  local rel="${1:-}" root stem cmd rc
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
  if ! _touchers_tracked "$root" "$rel"; then
    printf 'new\n'
    return 0
  fi
  stem=$(_touchers_stem "$rel")
  cmd=$(_touchers_command "$root" "$rel" "$stem")
  # rg exits 0 (matches) or 1 (none) — both are a verified-runnable command. Anything else —
  # 127 absent, 2 bad invocation — means the command was never verified; reading that as fine
  # would let a missing tool wave a bead through, so it is a refusal, never a silent pass.
  (cd "$root" && bash -c "$cmd") >/dev/null 2>&1; rc=$?
  if [ "$rc" -gt 1 ]; then
    printf 'touchers: NOT-GATED rg exited %s deriving touchers for `%s` (absent or broken); refusing rather than reading it as clean.\n' "$rc" "$rel" >&2
    return 2
  fi
  printf '%s\t%s\n' "$stem" "$cmd"
}

# touchers_check <description-file> [<label-for-messages>]
# The whole leg over one bead description. One verdict, one greppable token.
touchers_check() {
  local file="${1:-}" label="${2:-}" root dl numbered maxb b block paths existing count
  local rel dout stem cmd refs tline tcmd actual ep_rc
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
      | _touchers_extract_paths); ep_rc=$?
    if [ "$ep_rc" -ne 0 ]; then
      printf 'touchers: NOT-GATED %s — bead.py failed extracting Delivers paths for this bullet (exit %s); nothing was checked.\n' "$label" "$ep_rc" >&2
      return 2
    fi
    existing=$(printf '%s\n' "$paths" | while IFS= read -r p; do
      p="${p#./}"
      [ -n "$p" ] || continue
      _touchers_tracked "$root" "$p" && printf '%s\n' "$p"
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
      printf 'touchers: NOT-GATED %s — the touchers command for `%s` could not be verified runnable; nothing was checked.\n' "$label" "$rel" >&2
      return 2
    }
    [ "$dout" != "new" ] || continue
    stem=$(printf '%s' "$dout" | cut -f1)
    cmd=$(printf '%s' "$dout" | cut -f2-)
    refs=$( (cd "$root" && bash -c "$cmd" 2>/dev/null) | grep -c . )
    [ "${refs:-0}" -gt 0 ] || continue           # nothing references it

    # The line belongs to THIS bullet: the first `touchers:` line inside this block.
    tline=$(printf '%s\n' "$block" | grep -m1 '^[[:space:]]*touchers:')
    if [ -z "$tline" ]; then
      printf 'touchers: REFUSED %s — [unowned-touchers] `%s` exists and is referenced by %s file(s) (rg -l -F "%s"), but its ## Delivers entry carries no touchers: line. Add beneath the bullet: touchers: `<command>` · owned by: <bead ids> | out-of-scope: <reason>.\n' \
        "$label" "$rel" "$refs" "$stem" >&2
      return 1
    fi

    tcmd=$(printf '%s' "$tline" | sed -n 's/.*touchers:[[:space:]]*`\([^`]*\)`.*/\1/p'); tcmd=${tcmd//\\|/|}
    if [ -z "$tcmd" ] || ! printf '%s' "$tline" | grep -qE 'owned by:|out-of-scope:'; then
      printf 'touchers: REFUSED %s — [unowned-touchers] the touchers line for `%s` is malformed; expected: touchers: `<command>` · owned by: … | out-of-scope: ….\n' \
        "$label" "$rel" >&2
      return 1
    fi

    # No stored count survives to compare against — the command IS the check, re-run live
    # every time (canon: this bead, ac-ftfz.6). What still refuses is a command that no
    # longer finds ANYTHING: a rotted or mistyped command is indistinguishable from an
    # honest zero unless it is run, and "owned by" a command that owns nothing is the same
    # defect a stale count used to catch, reached a different way.
    actual=$( (cd "$root" && bash -c "$tcmd" 2>/dev/null) | grep -c . )
    if [ "${actual:-0}" -eq 0 ]; then
      printf 'touchers: REFUSED %s — [unowned-touchers] the touchers command for `%s` reproduces ZERO referrers now; a command that owns nothing is the defect this gate exists for. Re-derive, then re-stamp.\n' \
        "$label" "$rel" >&2
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
