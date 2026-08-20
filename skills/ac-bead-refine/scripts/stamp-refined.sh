#!/usr/bin/env bash
# stamp-refined.sh — the only sanctioned way to write the `refined` label.
#
# `refined` is the label `ac-implement` and `ac-loop` select on. Writing it with a bare
# `br label add <id> refined` skips the implementation contract. This wrapper cannot be
# skimmed past: the label write lives INSIDE the function and the function shells out to
# element4-check.sh first, unconditionally. Bypassing it takes deleting code.
#
# Source it to get the function, or run it to stamp ids directly:
#   source <path>/stamp-refined.sh ; stamp_refined <bead-id> [<refine-path-label>]
#   bash    <path>/stamp-refined.sh <bead-id> [<bead-id>...]     # REFINE_PATH from env
#
# Per-bead exit: 0 stamped · 1 refused (element 4 unmet — nothing written) · 2 check unusable.
# A refusal is not an error to route around: author the `## Declared RED`, then re-stamp.

_STAMP_REFINED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  _rc=0
  for _id in "$@"; do stamp_refined "$_id" || _rc=1; done
  exit "$_rc"
fi
