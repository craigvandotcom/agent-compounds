#!/usr/bin/env bash
# stamp-refined.sh — the only sanctioned way to write the `refined` label.
#
# `refined` is the label `ac-loop-swarm` (and `ac-implement`) select on. Writing it with a bare
# `br label add <id> refined` skips the implementation contract. This wrapper cannot be
# skimmed past: the label write lives INSIDE the function and the function shells out to
# element4-check.sh first, unconditionally. Bypassing it takes deleting code.
#
# Source it to get the function, or run it to stamp ids directly:
#   source <path>/stamp-refined.sh ; stamp_refined <bead-id> [<refine-path-label>]
#   bash    <path>/stamp-refined.sh <bead-id> [<bead-id>...]     # REFINE_PATH from env
#   zsh     <path>/stamp-refined.sh <bead-id> [<bead-id>...]
#
# Both forms work under bash and zsh, sourced or executed, from any cwd.
#
# Per-bead exit: 0 stamped · 1 refused (element 4 unmet — nothing written) · 2 check unusable.
# A refusal is not an error to route around: author the `## Declared RED`, then re-stamp.

# Self-location. zsh does not populate BASH_SOURCE; bash does not set $0 to the file
# when sourced. Read each shell's own answer in its own branch.
# Never put a zsh-only expansion where bash must parse it. Never use `eval` to hide one:
# eval rewrites zsh's %N and zsh_eval_context to `(eval)`.
if [ -n "${ZSH_VERSION:-}" ]; then
  _STAMP_REFINED_SELF="$0"
else
  _STAMP_REFINED_SELF="${BASH_SOURCE[0]}"
fi
# A failed cd leaves the dir empty, ELEMENT4_CHECK misses, and the FATAL guard below
# refuses. Fail-closed by construction.
_STAMP_REFINED_DIR="$(cd "$(dirname "$_STAMP_REFINED_SELF")" && pwd)"
ELEMENT4_CHECK="${ELEMENT4_CHECK:-$_STAMP_REFINED_DIR/element4-check.sh}"

stamp_refined() {
  local id="$1" path_label="${2:-${REFINE_PATH:-refine-full}}"
  [ -n "$id" ] || { echo "stamp_refined: no bead id given" >&2; return 2; }

  if [ ! -x "$ELEMENT4_CHECK" ] && [ ! -f "$ELEMENT4_CHECK" ]; then
    echo "stamp_refined: FATAL — element4-check.sh not found at '$ELEMENT4_CHECK'; refusing to stamp $id" >&2
    return 2
  fi

  local out rc
  out=$(bash "$ELEMENT4_CHECK" "$id" 2>&1); rc=$?
  if [ "$rc" -ne 0 ]; then
    printf '%s\n' "$out" >&2
    echo "stamp_refined: REFUSED $id — element 4 unmet; no label written." >&2
    return "$rc"
  fi

  br label remove "$id" "unrefined" 2>/dev/null
  br label add "$id" "refined" 2>/dev/null
  br label add "$id" "$path_label" 2>/dev/null
  echo "stamp_refined: STAMPED $id ($path_label)"
}

# Executed, or sourced? bash compares BASH_SOURCE[0] to $0. zsh sets $0 to the file in
# BOTH modes, so it cannot discriminate — read zsh_eval_context, whose last frame is
# `toplevel` when executed and `file` when sourced.
# Test this at top level only: inside a function zsh appends `shfunc` and it never matches.
_STAMP_REFINED_DIRECT=0
if [ -n "${ZSH_VERSION:-}" ]; then
  [ "${zsh_eval_context[-1]-}" = toplevel ] && _STAMP_REFINED_DIRECT=1
else
  [ "${BASH_SOURCE[0]-}" = "${0}" ] && _STAMP_REFINED_DIRECT=1
fi

if [ "$_STAMP_REFINED_DIRECT" = 1 ]; then
  _rc=0
  for _id in "$@"; do stamp_refined "$_id" || _rc=1; done
  exit "$_rc"
fi
