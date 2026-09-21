#!/usr/bin/env bash
#
# machine.sh — the ONE reader of this machine's local settings (`machine.json`).
#
# machine.json is this machine's facts in full: where its projects are (`targets[]`),
# where its org root is (`org_root`), and which tools it has (`harnesses`, deep-merged
# over the committed `harnesses.json` exactly as the retired
# `harnesses.local.json` was). It is edited BY HAND — there is no writer, and by
# settled decision no other tool parses it. Everything else asks this reader.
#
#   machine.sh --targets          one `<abs-path>\t<flags>` line per target; flags is a
#                                 space-separated token list, `public` and/or
#                                 `packages=a,b` — the retired roster line's grammar,
#                                 so the installer's port is mechanical
#   machine.sh --org-root         the org root, expanded and validated
#   machine.sh --harnesses        harnesses.json with this machine's overrides merged
#                                 over it; the committed base alone (exit 0) when there
#                                 is no file, because harness settings HAVE a committed
#                                 default and targets DO NOT
#   machine.sh --lit <abs-path>   the form a rendered config carries: `$HOME`-relative
#                                 under $HOME, absolute otherwise — the literal `$HOME`
#                                 is deliberate, one rendered file works for any user
#   (a leading `~` or `~/` is expanded in --lit and in every configured path)
#
# The exit code carries the state. Three states, three codes:
#
#   0  configured
#   4  NOT-CONFIGURED — no file at $AC_MACHINE_FILE (default <repo>/machine.json)
#   2  CONFIGURED-BUT-WRONG — JSON does not parse, org_root is missing / not absolute /
#      not a directory, a target path is missing / not absolute / not a directory, or a
#      target IS org_root. The message names the key and the path.
#      (3 is taken by engine/deploy.sh's `--require-ignored`; 4 is unused elsewhere.)
#
# `--targets` and `--org-root` run the FULL validation on every call. `--harnesses` does
# not: it is the fallback engine/deploy.sh depends on, and giving it a precondition
# would break it on a clean checkout (Check 08 runs deploy.sh dry there). `--lit` is a
# pure path transform and does not read the file at all.
#
# AC_MACHINE_FILE overrides the file's location — the fixture seam, and the documented
# way a machine's file can live versioned in its owner's own infrastructure repo.
#
set -uo pipefail

AC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$AC_ROOT/harnesses.json"
MACHINE_FILE="${AC_MACHINE_FILE:-$AC_ROOT/machine.json}"
EXAMPLE_FILE="$AC_ROOT/machine.example.json"

usage() {
  cat >&2 <<'EOF'
usage: machine.sh --targets | --org-root | --harnesses | --lit <abs-path>

  --targets        one `<abs-path>\t<flags>` line per target (flags: public, packages=a,b)
  --org-root       the org root, validated
  --harnesses      harnesses.json with this machine's overrides merged
  --lit <abs-path> a path rendered $HOME-relative under $HOME, absolute otherwise

Exit: 0 configured · 4 NOT-CONFIGURED (no file) · 2 CONFIGURED-BUT-WRONG
EOF
}

wrong() { printf 'machine.sh: %s\n' "$*" >&2; exit 2; }
not_configured() {
  printf 'machine.sh: no machine settings file at %s — copy %s to %s and edit it\n' \
    "$MACHINE_FILE" "$EXAMPLE_FILE" "$AC_ROOT/machine.json" >&2
  exit 4
}

expand_tilde() { # <path> -> leading ~ and ~/ expanded to $HOME
  case "$1" in
    "~")   printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s\n' "$HOME/${1#\~/}" ;;
    *)     printf '%s\n' "$1" ;;
  esac
}

canon() { # <dir> -> physical path; falls back to the input when it cannot resolve
  (cd "$1" 2>/dev/null && pwd -P) || printf '%s\n' "$1"
}

lit() { # <path> -> `$HOME/rel` under $HOME, else unchanged
  local p
  p="$(expand_tilde "$1")"
  case "$p" in
    "$HOME")   printf '$HOME\n' ;;
    "$HOME"/*) printf '$HOME/%s\n' "${p#"$HOME"/}" ;;
    *)         printf '%s\n' "$p" ;;
  esac
}

MODE=""
LIT_PATH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --targets)  MODE=targets;  shift ;;
    --org-root) MODE=org_root; shift ;;
    --harnesses) MODE=harnesses; shift ;;
    --lit)      MODE=lit; LIT_PATH="${2:-}"; shift 2 ;;
    -h|--help)  usage; exit 0 ;;
    *)          usage; wrong "unknown argument '$1'" ;;
  esac
done

[ -n "$MODE" ] || { usage; exit 2; }

# --- --lit: a pure transform, no file read -----------------------------------------------
if [ "$MODE" = lit ]; then
  [ -n "$LIT_PATH" ] || wrong "--lit needs a path"
  lit "$LIT_PATH"
  exit 0
fi

# --- --harnesses: the committed base alone when there is no file -------------------------
if [ "$MODE" = harnesses ]; then
  [ -f "$MANIFEST" ] || wrong "the committed base $MANIFEST is missing"
  if [ ! -f "$MACHINE_FILE" ]; then
    cat "$MANIFEST"
    exit 0
  fi
  if ! jq_out="$(jq . "$MACHINE_FILE" 2>&1)"; then
    wrong "$MACHINE_FILE is not valid JSON: $(printf '%s' "$jq_out" | head -1)"
  fi
  jq -s '.[0] * .[1]' "$MANIFEST" "$MACHINE_FILE"
  exit $?
fi

# --- --targets / --org-root: full validation on every call -------------------------------
[ -f "$MACHINE_FILE" ] || not_configured

if ! jq_out="$(jq . "$MACHINE_FILE" 2>&1)"; then
  wrong "$MACHINE_FILE is not valid JSON: $(printf '%s' "$jq_out" | head -1)"
fi

org="$(jq -r '
  if (.org_root | type) == "string" and (.org_root | length) > 0
  then .org_root else empty end' "$MACHINE_FILE" 2>/dev/null)"
[ -n "$org" ] || wrong "org_root is missing in $MACHINE_FILE"
org="$(expand_tilde "$org")"
case "$org" in
  /*) ;;
  *)  wrong "org_root '$org' is not an absolute path (in $MACHINE_FILE)" ;;
esac
[ -d "$org" ] || wrong "org_root '$org' is not a directory (in $MACHINE_FILE)"

# Validate every target before printing anything: a run that names three targets and
# then dies on the fourth has already handed half a roster to the installer.
targets_tsv="$(jq -r '
  (if has("targets") then
     if (.targets | type) != "array" then error("targets is not an array") else .targets end
   else [] end)
  | .[]
  | if (.path | type) != "string" or (.path | length) == 0 then
      error("a targets[] entry has no path")
    elif has("packages") and (.packages | type) != "array" then
      error("targets[] packages for \(.path) must be an array")
    elif has("public") and (.public | type) != "boolean" then
      error("targets[] public for \(.path) must be a boolean")
    else . end
  | [ .path,
      ([ (if .public == true then "public" else empty end),
         (if has("packages") then "packages=" + (.packages | join(",")) else empty end) ]
       | join(" "))
    ]
  | @tsv' "$MACHINE_FILE" 2>&1)" \
  || wrong "targets in $MACHINE_FILE are malformed: $targets_tsv"

while IFS=$'\t' read -r tpath tflags; do
  [ -n "$tpath" ] || continue
  tpath="$(expand_tilde "$tpath")"
  case "$tpath" in
    /*) ;;
    *)  wrong "targets[] path '$tpath' is not absolute (in $MACHINE_FILE)" ;;
  esac
  [ -d "$tpath" ] || wrong "targets[] path '$tpath' does not exist as a directory (in $MACHINE_FILE)"
  [ "$(canon "$tpath")" != "$(canon "$org")" ] \
    || wrong "targets[] lists org_root '$org' — the org home is synced by sync_root, and an app-mode pass over the same folder overwrites its .hooks block (in $MACHINE_FILE)"
  if [ "$MODE" = targets ]; then
    printf '%s\t%s\n' "$tpath" "$tflags"
  fi
done <<<"$targets_tsv"

if [ "$MODE" = org_root ]; then
  printf '%s\n' "$org"
fi
exit 0
