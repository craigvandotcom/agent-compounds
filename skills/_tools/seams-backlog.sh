#!/usr/bin/env bash
#
# seams-backlog.sh — the measuring query for plan-less beads that owe a `## Seams` section.
#
# A bead matches when ALL hold: labelled `refined`, not closed, type task|feature|bug, not
# `human-gate`, no `origin:ac-beadify` label (a plan-less bead; a beadified one inherits its
# plan's Seams), at least one `## Delivers` path, and an empty `## Seams` section. The
# repos are every directory under the org root, the registry and the machine's targets that
# carries `.beads/`. The sweep that clears a match is `ac-polish/workflows/bead.md`
# § Seams sweep at export.
#
# ASSURANCE
#   PROBE:      bash skills/_tools/seams-backlog.sh --zero, and bash skills/_tools/seams-backlog.test.sh
#   SCHEDULE:   before the seams-missing ready-gate rule lands, and on demand thereafter
#   MODE:       blocking
#   ON-FAILURE: closed   (a board that cannot be read is NOT-GATED, never a zero)
#
# Usage
#   seams-backlog.sh            one `<repo>\t<id>` line per match; a count line on stderr
#   seams-backlog.sh --zero     exit 0 iff no bead matches, else list the matches and exit 1
#
# Exit codes: 0 none match (--zero) or listed (default) · 1 matches remain (--zero) ·
#             2 NOT-GATED (a board unreadable, no repo found) · 64 usage.
#
# Seams: SEAMS_BACKLOG_REPOS (newline-separated repo paths) replaces the repo discovery;
# AC2_BR_CMD replaces the br binary (br-call.sh).
set -uo pipefail

SELF=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REGISTRY=$(cd "$SELF/../.." && pwd)
BEAD_PY="$SELF/bead.py"

ZERO=0
case "${1:-}" in
  "") ;;
  --zero) ZERO=1 ;;
  *) printf 'usage: seams-backlog.sh [--zero]\n' >&2; exit 64 ;;
esac
[ "$#" -le 1 ] || { printf 'usage: seams-backlog.sh [--zero]\n' >&2; exit 64; }

notgated() { printf 'NOT-GATED: seams-backlog.sh — %s\n' "$*" >&2; exit 2; }

command -v python3 >/dev/null 2>&1 || notgated "python3 not found"
[ -r "$BEAD_PY" ] || notgated "bead.py not found at $BEAD_PY"
# shellcheck source=br-call.sh
. "$SELF/br-call.sh"

repos() {
  if [ -n "${SEAMS_BACKLOG_REPOS:-}" ]; then
    printf '%s\n' "$SEAMS_BACKLOG_REPOS"
    return
  fi
  local org
  org=$("$REGISTRY/engine/machine.sh" --org-root 2>/dev/null)
  {
    echo "$REGISTRY"
    "$REGISTRY/engine/machine.sh" --targets 2>/dev/null | cut -f1
    if [ -n "$org" ]; then
      # Hidden directories and dependency trees never hold a project board.
      find "$org" -maxdepth 4 \( -name node_modules -o \( -name '.*' ! -name .beads \) \) -prune \
        -o -type d -name .beads -print 2>/dev/null | sed 's|/\.beads$||'
    fi
  } | awk 'NF && !seen[$0]++'
}

FOUND=0 MATCHES=0
while IFS= read -r repo; do
  [ -d "$repo/.beads" ] || continue
  FOUND=$((FOUND + 1))
  payload=$(cd "$repo" && br_call list --json --limit 0) \
    || notgated "cannot read the board of $repo"
  out=$(printf '%s' "$payload" | python3 -c '
import json, os, sys
sys.path.insert(0, os.path.dirname(sys.argv[1]))
import bead
data = json.load(sys.stdin)
issues = data["issues"] if isinstance(data, dict) else data
for i in issues:
    labels = set(i.get("labels") or [])
    if i.get("status") == "closed" or i.get("issue_type") not in ("task", "feature", "bug"):
        continue
    if "refined" not in labels or "human-gate" in labels or "origin:ac-beadify" in labels:
        continue
    desc = i.get("description") or ""
    if not any(d["path"] for d in bead.delivers(desc)):
        continue
    if bead.section(desc, "Seams").strip():
        continue
    print(i["id"])
' "$BEAD_PY") || notgated "cannot evaluate the board of $repo"
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    MATCHES=$((MATCHES + 1))
    printf '%s\t%s\n' "$repo" "$id"
  done <<<"$out"
done < <(repos)

[ "$FOUND" -gt 0 ] || notgated "no repository with .beads/ found"
printf 'seams-backlog: %d match(es) across %d repo(s)\n' "$MATCHES" "$FOUND" >&2
if [ "$ZERO" -eq 1 ] && [ "$MATCHES" -gt 0 ]; then
  exit 1
fi
exit 0
