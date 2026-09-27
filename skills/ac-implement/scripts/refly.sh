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
#   ON-FAILURE: closed — br/jq/python3 missing, a gate script absent, or bead.py missing exits
#               2 and touches nothing; a bead.py that loads but crashes mid-read skips only
#               that one bead's disposition attempt (kept stamped), never the whole run
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
# Exit 2  NOT-GATED — br/jq/python3/gate scripts/bead.py unavailable; nothing was touched
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
TOOLS_DIR="$(cd "$HERE/../../_tools" 2>/dev/null && pwd)"
# bead.py is the one bead reader (ac-m9y4.1): the Delivers artifact named in a disposition
# close reason reads through its own `delivers()` extractor, never a second hand-rolled
# regex. Same closed-failure loop as the gate scripts above (extended, per this bead): a
# missing reader stops the refly at load, before any bead is touched.
_BEAD_PY_HOME="${TOOLS_DIR:+$TOOLS_DIR/bead.py}"
[ -n "$TOOLS_DIR" ] && [ -f "$_BEAD_PY_HOME" ] \
  || { echo "NOT-GATED: bead.py missing at ${_BEAD_PY_HOME:-<unresolved _tools dir>} — Delivers paths cannot be read" >&2; exit 2; }
command -v br >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1 \
  || { echo "NOT-GATED: br/jq/python3 are not on PATH — stamped beads cannot be re-checked" >&2; exit 2; }

# The ONE br_call invocation shape (ac-heyt.3); a refusal below is a NOT-GATED /
# keep-stamped routing, never empty data. Sourced before the cd: BASH_SOURCE may be
# relative, so the absolute helper path must resolve from the original cwd.
# shellcheck source=br-call.sh
. "$TOOLS_DIR/br-call.sh" 2>/dev/null \
  || { echo "NOT-GATED: br-call.sh helper missing — stamped beads cannot be re-checked" >&2; exit 2; }

# The program lives in its own file, never a heredoc attached to `python3 -`: a heredoc IS
# the command's stdin, so a text argument piped in on the same command would starve
# `sys.stdin.read()` of everything but EOF (needs-device-gate.sh's own write_device_paths_py
# already paid for this lesson). `BEAD_MODULE_PATH` is the same test-only override
# bead-capture-guard.py's own `_load_bead_module()` uses: a nonexistent path drives the
# broken-reader fixture without ever touching the real bead.py in a shared checkout.
_write_delivers_py() {
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
        desc = f.read()
    paths = []
    for d in bead.delivers(desc):
        paths.extend(p for p in d["paths"] if p)
    print(" ".join(paths[:3]))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        print(f"NOT-GATED: bead.py unavailable or crashed: {e}", file=sys.stderr)
        sys.exit(2)
PY
}

# <body-file> -> the first 3 ## Delivers paths, space-joined, via bead.py's own extractor —
# stdout on rc 0 (empty is a legitimate "Delivers names no path"). A non-zero rc is a broken
# reader, never a silent empty extraction; the caller skips that bead's disposition rather
# than pass a reason it could not verify.
_delivers_via_bead() {
  local bf="$1" py out rc
  py=$(mktemp) || return 2
  _write_delivers_py "$py"
  out=$(BEAD_PY_PATH="$_BEAD_PY_HOME" python3 "$py" "$bf" 2>&1); rc=$?
  rm -f "$py"
  [ "$rc" -eq 0 ] && printf '%s' "$out"
  return $rc
}

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
  local id="$1" flight_out="$2" body deliv deliv_rc cls reason f close_out close_rc
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
  deliv=$(_delivers_via_bead "$bf"); deliv_rc=$?
  if [ "$deliv_rc" -ne 0 ]; then
    echo "refly: $id — triage skipped: bead.py could not be read (Delivers paths unavailable): $deliv" >&2
    br update "$id" --status open --assignee "" </dev/null >/dev/null 2>&1 \
      || echo "warn: could not unclaim $id after the broken-reader skip" >&2
    rm -f "$f" "$bf"
    return 1
  fi
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
