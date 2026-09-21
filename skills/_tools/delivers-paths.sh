#!/usr/bin/env bash
# delivers-paths.sh — the ONE home of the Delivers-path extraction pattern. SOURCED, never executed.
#
# Every reader of a `## Delivers` body extracts path-shaped tokens through
# DELIVERS_PATH_RE. No script carries a second copy of the pattern; a second
# reader either routes through this file or does not read Delivers paths.
#
# Section choice and touchers:-line exclusion stay with the caller — they are
# semantics of the reader, not of the pattern.
#
#   DELIVERS_PATH_RE   path-shaped token: multi-segment, extension-bearing
#   extract_paths      body -> sorted unique path tokens
#
# Canon: beads-standards/reference/bead-create-contract.md § Touchers.

DELIVERS_PATH_RE='(\./)?[][A-Za-z0-9_@.()-]+(/[][A-Za-z0-9_@.()-]+)+\.[A-Za-z0-9]{1,6}'

extract_paths() { # [body] (else stdin) -> sorted unique path tokens
  if [ "$#" -gt 0 ]; then printf '%s\n' "$1"; else cat; fi \
    | grep -oE "$DELIVERS_PATH_RE" | sort -u
}
