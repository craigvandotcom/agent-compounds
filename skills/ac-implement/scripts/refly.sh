#!/usr/bin/env bash
#
# refly.sh — re-check every PREMISE-FAILED bead and strip the stamp from those that fly again.
#
# ASSURANCE
#   PROBE:      bash skills/ac-implement/scripts/refly.test.sh
#   SCHEDULE:   once per ac2 swarm run, in Phase 0 (SKILL.md), before the pool is counted;
#               the harness runs on every scripts/run-all-harnesses.sh invocation, which
#               lint.sh Check 20 audits for scheduling.
#   MODE:       advisory — a bead it cannot re-check stays stamped; it never stamps
#   ON-FAILURE: closed — br/jq missing or flight-check absent exits 2 and strips nothing
#
# WHY IT EXISTS: flight-check.sh stamps `PREMISE-FAILED:` onto a title and every worker
# skips that title forever. The stamp is a cached verdict with no expiry. When the verdict
# was wrong — a parser truncated `bd-new-entry-…` to `bd-new` and refused five beads whose
# blockers were closed — fixing the parser did not un-stamp the beads, and a human comment
# saying "resolved" changed nothing workers read. Six beads sat dead for a day. This pass is
# the expiry: it re-asks flight-check the same question (--check-only, so nothing is
# written on the way) and strips the stamp only when the answer is now "flyable".
#
# It NEVER stamps and NEVER unclaims. A bead that still fails stays exactly as it was.
#
# Usage:
#   refly.sh [--root <repo root>] [--dry-run]
#
# Exit 0  every stamped bead re-checked (stripped or left, each reported)
# Exit 2  NOT-GATED — br/jq/flight-check unavailable; nothing was touched
#
set -uo pipefail

ROOT=""; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root)    ROOT="${2:-}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,30p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "NOT-GATED: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
GATE="$HERE/flight-check.sh"
[ -x "$GATE" ] || { echo "NOT-GATED: flight-check.sh missing or not executable at $GATE" >&2; exit 2; }
command -v br >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 \
  || { echo "NOT-GATED: br/jq are not on PATH — stamped beads cannot be re-checked" >&2; exit 2; }

if [ -z "$ROOT" ]; then
  ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || ROOT="$PWD"
fi
cd "$ROOT" || { echo "NOT-GATED: cannot enter repo root '$ROOT'" >&2; exit 2; }

STAMPED=$(br list --json --limit 5000 </dev/null 2>/dev/null \
  | jq -r '(if type == "array" then . else (.issues // []) end)[]
           | select(.status == "open" and (.title | startswith("PREMISE-FAILED:"))) | .id')

if [ -z "$STAMPED" ]; then
  echo "refly: no PREMISE-FAILED beads on the board"
  exit 0
fi

TREE=$(git rev-parse --short HEAD 2>/dev/null || echo no-git)
STRIPPED=0; KEPT=0
while IFS= read -r id; do
  [ -n "$id" ] || continue
  out=$(bash "$GATE" "$id" --check-only --root "$ROOT" 2>&1)
  rc=$?
  if [ "$rc" -ne 0 ]; then
    KEPT=$(( KEPT + 1 ))
    why=$(printf '%s\n' "$out" | grep -m1 -E '^(PREMISE-FAILED|NOT-GATED)' || echo "exit $rc")
    echo "refly: $id — still stamped: $why"
    continue
  fi
  title=$(br show "$id" --json </dev/null 2>/dev/null \
    | jq -r 'if type == "array" then .[0] else . end | .title // ""')
  new=$(printf '%s' "$title" | sed -E 's/^PREMISE-FAILED:[[:space:]]*//')
  if [ -z "$new" ] || [ "$new" = "$title" ]; then
    KEPT=$(( KEPT + 1 ))
    echo "refly: $id — flyable but its title could not be read back; left as is"
    continue
  fi
  if [ "$DRY" -eq 1 ]; then
    STRIPPED=$(( STRIPPED + 1 ))
    echo "refly (dry-run): $id — would strip the stamp"
    continue
  fi
  br update "$id" --title "$new" </dev/null >/dev/null 2>&1 \
    || { KEPT=$(( KEPT + 1 )); echo "refly: $id — flyable but br update failed; left stamped" >&2; continue; }
  br comments add "$id" "PREMISE-REPAIR (refly.sh, $(date -u +%Y-%m-%dT%H:%M:%SZ)): flight-check --check-only passes against the tree at $TREE — the premises hold again. Stamp stripped; re-flyable." </dev/null >/dev/null 2>&1 \
    || echo "warn: could not add the repair comment to $id" >&2
  STRIPPED=$(( STRIPPED + 1 ))
  echo "refly: $id — stamp stripped"
done <<EOF
$STAMPED
EOF

echo "refly: $STRIPPED stripped, $KEPT still stamped"
exit 0
