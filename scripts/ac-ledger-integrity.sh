#!/usr/bin/env bash
#
# ac-ledger-integrity.sh — the ac2 family ledger's referential-integrity gate (lint Check 22).
#
# ASSURANCE — MODE: blocking · ON-FAILURE: closed. A missing or empty ledger is NOT a pass:
# it exits non-zero carrying the literal token NOT-GATED. A check that green-passes over an
# empty set is the exact failure this pipeline exists to stop believing (ac-pipeline
# Invariant 3: silence is never success).
#
# THE CONTRACT, both directions:
#   ledger -> control   every entry cites a `receipt:` (the evidence) and names the
#                       `control:` that treats it, or is explicitly `control: untreated`.
#                       A cited control must RESOLVE against the constitution — `I<n>` for
#                       an Invariant, `C-<slug>` for a Calibration.
#   control -> failure  every Invariant names the failure it Prevents AND its L-tag; every
#                       Calibration names its L-tag and the measurement that *retires* it.
#                       (ac-pipeline Invariant 8, made mechanical.)
#   regression          a treated entry whose `last_seen` is AFTER its `control_landed`
#                       date is a FAILED CONTROL — the friction kept biting after the fix
#                       shipped. Treated entries must carry `control_landed:`, or that
#                       detector is unfalsifiable.
#   seed rule           a friction id minted in an OLD ac-* ledger is legal input: during
#                       construction ac2 controls cite those ids and the family ledger
#                       inherits them. Foreign ids are never flagged.
#
# ONE PARSER: the ledger is parsed by `skills/skill-builder/scripts/friction-rollup.py`
# --ledger (the shared computation delivered by ac-on0y.3). This script adds assertions,
# never a second parse of the same files.
#
# Usage:  ac-ledger-integrity.sh [--ledger <path>] [--constitution <path>] [<repo root>]
# Exit 0  the ledger and the constitution satisfy the contract
# Exit 1  at least one violation (each reported as FAIL: ...)
# Exit 2  usage error, or the shared parser is missing
set -uo pipefail

LEDGER=""
CONSTITUTION=""
ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ledger) LEDGER="${2:-}"; shift 2 ;;
    --constitution) CONSTITUTION="${2:-}"; shift 2 ;;
    --*) echo "usage: $0 [--ledger <path>] [--constitution <path>] [<repo root>]" >&2; exit 2 ;;
    *) ROOT="$1"; shift ;;
  esac
done
ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LEDGER="${LEDGER:-$ROOT/skills/ac-pipeline/FRICTIONS.md}"
CONSTITUTION="${CONSTITUTION:-$ROOT/skills/ac-pipeline/SKILL.md}"
ROLLUP="$ROOT/skills/skill-builder/scripts/friction-rollup.py"

RC=0
ali_fail() { echo "FAIL: $*"; RC=1; }

if [ ! -f "$ROLLUP" ]; then
  echo "FAIL: NOT-GATED — the shared ledger parser is missing at $ROLLUP; nothing was checked" >&2
  exit 2
fi

# --- Fail closed on an absent or empty ledger -----------------------------------------
if [ ! -f "$LEDGER" ]; then
  echo "FAIL: NOT-GATED — no ac2 ledger at $LEDGER. An absent sensor is not a clean one."
  exit 1
fi
LEDGER_JSON=$(python3 "$ROLLUP" --root "$ROOT" --ledger "$LEDGER" 2>/dev/null)
if [ -z "$LEDGER_JSON" ]; then
  echo "FAIL: NOT-GATED — the shared parser returned nothing for $LEDGER"
  exit 1
fi
ENTRY_COUNT=$(printf '%s' "$LEDGER_JSON" | jq '.ledger.entries | length' 2>/dev/null || echo 0)
if [ "${ENTRY_COUNT:-0}" -eq 0 ]; then
  echo "FAIL: NOT-GATED — $LEDGER carries zero entries; an empty ledger proves nothing"
  exit 1
fi

# --- Control inventory, and the control -> failure direction ---------------------------
if [ ! -f "$CONSTITUTION" ]; then
  echo "FAIL: NOT-GATED — no constitution at $CONSTITUTION; controls cannot be resolved"
  exit 1
fi

# Each control is a BLOCK (its text wraps), so flatten block-by-block before asserting.
INVARIANTS=$(awk '
  /^## Calibrations/ { if (cur != "") { print cur; cur = "" } inv = 0 }
  /^## Invariants/   { inv = 1; next }
  inv && /^[0-9]+\./ { if (cur != "") print cur; cur = $0; next }
  inv && cur != ""   { cur = cur " " $0; next }
  END { if (cur != "") print cur }
' "$CONSTITUTION")

CALIBRATIONS=$(awk '
  /^## Calibrations/ { cal = 1; next }
  cal && /^- \*\*/   { if (cur != "") print cur; cur = $0; next }
  cal && cur != ""   { cur = cur " " $0; next }
  END { if (cur != "") print cur }
' "$CONSTITUTION")

CONTROL_IDS=""
while IFS= read -r line; do
  [ -n "$line" ] || continue
  num=${line%%.*}
  CONTROL_IDS="$CONTROL_IDS I$num"
  case "$line" in *"(L1)"*|*"(L2)"*|*"(L3)"*) ;; *)
    ali_fail "constitution: Invariant $num carries no L-tag — a control naming neither its failure nor its layer is deleted, not demoted" ;;
  esac
  case "$line" in *"Prevents:"*) ;; *)
    ali_fail "constitution: Invariant $num names no failure it prevents (no 'Prevents:') — ac-pipeline Invariant 8" ;;
  esac
done <<EOF
$INVARIANTS
EOF

while IFS= read -r line; do
  [ -n "$line" ] || continue
  name=$(printf '%s' "$line" | sed -E 's/^- \*\*([^*]+)\*\*.*/\1/')
  slug=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')
  [ -n "$slug" ] || continue
  CONTROL_IDS="$CONTROL_IDS C-$slug"
  case "$line" in *"(L1)"*|*"(L2)"*|*"(L3)"*) ;; *)
    ali_fail "constitution: Calibration '$name' carries no L-tag" ;;
  esac
  case "$line" in *"retires when:"*) ;; *)
    ali_fail "constitution: Calibration '$name' names no measurement that retires it — a Calibration that cannot be retired is an Invariant in disguise or a superstition" ;;
  esac
done <<EOF
$CALIBRATIONS
EOF

# --- The ledger -> control direction ---------------------------------------------------
while IFS=$'\t' read -r id receipt control landed last_seen untreated; do
  [ -n "$id" ] || continue
  if [ -z "$receipt" ]; then
    ali_fail "ledger entry '$id' cites no 'receipt:' — an entry without evidence is an opinion"
  fi
  low=$(printf '%s' "$control" | tr '[:upper:]' '[:lower:]')
  if [ -z "$control" ] && [ -z "$untreated" ]; then
    ali_fail "ledger entry '$id' names no 'control:' and is not tagged untreated — every friction is treated or declared untreated"
    continue
  fi
  case "$low" in
    ""|untreated|"untreated"*) continue ;;   # the sanctioned, explicit escape
  esac
  case " $CONTROL_IDS " in
    *" $control "*) ;;
    *) ali_fail "ledger entry '$id' cites control '$control', which the constitution does not define — a pointer to a control nobody kept"
       continue ;;
  esac
  if [ -z "$landed" ]; then
    ali_fail "ledger entry '$id' names control '$control' but no 'control_landed:' date — without it the failed-control detector cannot fire"
    continue
  fi
  if [ -n "$last_seen" ] && [ "$last_seen" \> "$landed" ]; then
    ali_fail "FAILED CONTROL — '$id' was re-observed on $last_seen, AFTER its control '$control' landed on $landed"
  fi
done <<EOF
$(printf '%s' "$LEDGER_JSON" | jq -r '
  .ledger.entries[] | [
    .id,
    (.fields.receipt // ""),
    (.fields.control // ""),
    (.fields.control_landed // ""),
    (.fields.last_seen // ""),
    (.fields.untreated // "")
  ] | @tsv')
EOF

if [ "$RC" -eq 0 ]; then
  echo "ac-ledger-integrity: $ENTRY_COUNT entr(y|ies) · $(printf '%s' "$CONTROL_IDS" | wc -w | tr -d ' ') controls — contract holds both directions"
fi
exit "$RC"
