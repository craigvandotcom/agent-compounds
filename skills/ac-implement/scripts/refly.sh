#!/usr/bin/env bash
#
# refly.sh — re-check every PREMISE-FAILED bead, strip the stamp from those that fly again,
# and TRIAGE the rest through close-gate.sh's disposition legs.
#
# ASSURANCE
#   PROBE:      bash skills/ac-implement/scripts/refly.test.sh
#   SCHEDULE:   once per ac2 swarm run, in Phase 0 (SKILL.md), before the pool is counted;
#               the harness runs on every scripts/run-all-proofs.sh invocation, scheduled
#               by CI's `proofs` job.
#   MODE:       advisory — a bead it cannot prove anything about stays exactly as it was
#   ON-FAILURE: closed — br/jq missing or a gate script absent exits 2 and touches nothing
#
# WHY IT EXISTS: flight-check.sh stamps `PREMISE-FAILED:` onto a title and every worker
# skips that title forever. The stamp is a cached verdict with no expiry. When the verdict
# was wrong — a parser truncated `bd-new-entry-…` to `bd-new` and refused five beads whose
# blockers were closed — fixing the parser did not un-stamp the beads, and a human comment
# saying "resolved" changed nothing workers read. Six beads sat dead for a day. This pass is
# the expiry: it re-asks flight-check the same question (--check-only, so nothing is
# written on the way) and acts only on what it can prove:
#
#   flyable   -> the stamp is stripped; the bead re-enters the worker pool
#   refused   -> ONE disposition-close attempt through close-gate.sh, which verifies the
#                claim itself: the work exists at HEAD (probes green), or the premise is
#                gone by cascade (every Consumes blocker closed with a disposition close).
#                A refused attempt leaves the bead stamped, unclaimed, untouched.
#
# It NEVER stamps, and it closes nothing by hand: the gate is the only writer of a close.
# A bead that still fails stays exactly as it was.
#
# Usage:
#   refly.sh [--root <repo root>] [--dry-run]
#
# Exit 0  every stamped bead re-checked (stripped, disposition-closed, or left, each reported)
# Exit 2  NOT-GATED — br/jq/gate scripts unavailable; nothing was touched
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
CLOSE_GATE="$HERE/close-gate.sh"
for G in "$GATE" "$CLOSE_GATE"; do
  [ -x "$G" ] || { echo "NOT-GATED: gate script missing or not executable at $G" >&2; exit 2; }
done
command -v br >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 \
  || { echo "NOT-GATED: br/jq are not on PATH — stamped beads cannot be re-checked" >&2; exit 2; }

# The ONE br_call invocation shape (ac-heyt.3); a refusal below is a NOT-GATED /
# keep-stamped routing, never empty data. Sourced before the cd: BASH_SOURCE may be
# relative, so the absolute helper path must resolve from the original cwd.
# shellcheck source=br-call.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../_tools" 2>/dev/null && pwd)/br-call.sh" 2>/dev/null \
  || { echo "NOT-GATED: br-call.sh helper missing — stamped beads cannot be re-checked" >&2; exit 2; }

if [ -z "$ROOT" ]; then
  ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || ROOT="$PWD"
fi
cd "$ROOT" || { echo "NOT-GATED: cannot enter repo root '$ROOT'" >&2; exit 2; }

STAMPED=$(br_call list --json --limit 0 </dev/null \
  | jq -r '(if type == "array" then . else (.issues // []) end)[]
           | select(.status == "open" and (.title | startswith("PREMISE-FAILED:"))) | .id') \
  || { echo "refly: NOT-GATED — br_call list refused; nothing re-checked (never a silent 'no PREMISE-FAILED beads')" >&2; exit 2; }

if [ -z "$STAMPED" ]; then
  echo "refly: no PREMISE-FAILED beads on the board"
  exit 0
fi

TREE=$(git rev-parse --short HEAD 2>/dev/null || echo no-git)
TRIAGE_ACTOR="refly-triage-$(date -u +%Y%m%d-%H%M%S)-$$"

# triage_disposition <id> <flight-check output> — ONE disposition-close attempt, through
# close-gate.sh. The gate verifies the claim itself (probes green at HEAD, or every Consumes
# blocker closed with a disposition close); a refusal leaves the bead stamped, unclaimed,
# untouched. The reason names a Delivers artifact when the board declares one — the evidence
# core (LEG 7) cross-references it; a bead with no checkable Delivers stays stamped.
triage_disposition() {
  local id="$1" flight_out="$2" body deliv cls reason f close_out close_rc
  if [ "$DRY" -eq 1 ]; then
    echo "refly (dry-run): $id — would attempt a disposition close through close-gate.sh"
    return 0
  fi
  if ! br update "$id" --claim --actor "$TRIAGE_ACTOR" </dev/null >/dev/null 2>&1; then
    echo "refly: $id — triage skipped: the claim was refused (owned elsewhere)"; return 1
  fi
  f=$(mktemp) && bf=$(mktemp) \
    || { echo "refly: $id — triage skipped: cannot create a scratch file" >&2; return 1; }
  body=$(br_call show "$id" --json </dev/null \
    | jq -r 'if type == "array" then .[0] else . end | .description // ""' 2>/dev/null) || body=""
  printf '%s\n' "$body" >"$bf"
  deliv=$(printf '%s\n' "$body" \
    | awk '/^## /{ inb = ($0 ~ "^## Delivers([[:space:]]|$)") ? 1 : 0; next }
            inb { print }' \
    | grep -oE '[A-Za-z0-9_.][A-Za-z0-9_./-]*\.[A-Za-z0-9]+' | grep -vE '^\.+$' | head -3 | tr '\n' ' ')
  cls=$(printf '%s\n' "$flight_out" | grep -m1 -oE 'PREMISE-FAILED: [A-Z-]+')
  reason="obsolete: TRIAGE — flight-check refuses ${cls:-the premises} at claim; the defect is resolved at HEAD by other work (${TREE}) or the bead is superseded by a disposition-closed blocker. Delivered: ${deliv:-see the ## Delivers section}"
  printf '%s\n' "$reason" >"$f"
  close_out=$(bash "$CLOSE_GATE" "$id" --reason "$reason" --actor "$TRIAGE_ACTOR" \
    --body-file "$bf" --root "$ROOT" 2>&1); close_rc=$?
  rm -f "$f" "$bf"
  if [ "$close_rc" -eq 0 ]; then
    echo "refly: $id — disposition-closed (obsolete)"
    return 0
  fi
  br update "$id" --status open --assignee "" </dev/null >/dev/null 2>&1 \
    || echo "warn: could not unclaim $id after the refused triage" >&2
  echo "refly: $id — triage refused ($(printf '%s' "$close_out" | grep -m1 -oE 'CLOSE-REFUSED: [A-Z-]+' || echo "exit $close_rc")); kept stamped"
  return 1
}

STRIPPED=0; KEPT=0; DISPO_CLOSED=0
while IFS= read -r id; do
  [ -n "$id" ] || continue
  out=$(bash "$GATE" "$id" --check-only --root "$ROOT" 2>&1)
  rc=$?
  if [ "$rc" -ne 0 ]; then
    if [ "$rc" -eq 1 ]; then
      # A real premise failure, not a gate failure: one disposition attempt, gate-decided.
      if triage_disposition "$id" "$out"; then
        DISPO_CLOSED=$(( DISPO_CLOSED + 1 ))
        continue
      fi
    fi
    KEPT=$(( KEPT + 1 ))
    why=$(printf '%s\n' "$out" | grep -m1 -E '^(PREMISE-FAILED|NOT-GATED)' || echo "exit $rc")
    echo "refly: $id — still stamped: $why"
    continue
  fi
  title=$(br_call show "$id" --json </dev/null \
    | jq -r 'if type == "array" then .[0] else . end | .title // ""') \
    || { KEPT=$(( KEPT + 1 )); echo "refly: $id — br_call show refused; left stamped" >&2; continue; }
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

echo "refly: $STRIPPED stripped, $DISPO_CLOSED disposition-closed, $KEPT still stamped"
exit 0
