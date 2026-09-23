#!/usr/bin/env bash
# ---
# id: 22-ledger-integrity
# prevents: a friction ledger and its controls drifting apart — entries citing controls the
#   constitution does not define, receipts nobody kept, a friction re-observed after its control
#   landed accruing silently instead of surfacing as a FAILED CONTROL, and an entry with no scorable
#   ordinal going unreported
# scope: LEDGER
# severity: fail
# fixture: lint/fixtures/22-ledger-integrity
# ---
#
# 22-ledger-integrity.sh — the lean family's friction sensor: one check, two surfaces.
#
# The lean family's controls and its friction ledger must still point at each other: every
# entry cites a `receipt:` and the `control:` that treats it (or is explicitly `untreated`),
# every control names the failure it prevents, and a friction re-observed AFTER its control
# landed surfaces as a FAILED CONTROL rather than accruing silently. This check is also the
# ONE friction sensor for the ledger-health class: an entry with no scorable ordinal
# (impact/frequency/recurrence) is a named finding — never a mutation (the ledger edit is
# human-gated; the frictions docket consumes the report rows). The ledger is parsed through
# the ONE shared parser (`skills/skill-builder/scripts/friction-rollup.py`) — this script adds
# assertions, never a second parse of the same files.
#
# THE CONTRACT, both directions:
#   ledger -> control   every entry cites a `receipt:` (the evidence) and names the
#                       `control:` that treats it, or is explicitly `control: untreated`.
#                       A cited control must RESOLVE against the constitution — `I<n>` for
#                       an Invariant, `C-<slug>` for a Calibration.
#   control -> failure  every Invariant names the failure it Prevents AND its L-tag; every
#                       Calibration names its L-tag and the measurement that *retires* it.
#   regression          a treated entry whose `last_seen` is AFTER its `control_landed`
#                       date is a FAILED CONTROL — the friction kept biting after the fix
#                       shipped. Treated entries must carry `control_landed:`, or that
#                       detector is unfalsifiable.
#   seed rule           a friction id minted in an older ledger is legal input: during
#                       construction, controls cite those ids and the family ledger
#                       inherits them. Foreign ids are never flagged.
#
# THE SCORABLE SWEEP (folded in from friction-rollup.py --strict; detection automated,
# mutation human-gated): every skills/*/FRICTIONS.md entry must carry scorable ordinals
# (impact/frequency/recurrence). Findings are REPORT ROWS, never mutations; the frictions
# docket consumes them. With no --ledger, the sweep covers ALL ledgers; an explicit
# --ledger scopes the sweep to that one ledger.
#
# ENTRY COUNTS: every entry count this check reports is derived from the parsed ledger at
# read time (`.ledger.entries | length`), never from a hand-kept frontmatter field.
#
# FINDINGS CONTRACT (machine-readable, one row per line, grep-able for the docket):
#   FAIL: NOT-SCORABLE: <id> (<path>): <ordinal>='<value>'; ...
# plus the contract rows (FAIL: ledger entry '...' / FAIL: constitution: ... /
# FAIL: FAILED CONTROL — ...).
#
# Usage:  22-ledger-integrity.sh [--ledger <path>] [--constitution <path>] [<repo root>]
# Exit 0   the ledger and the constitution satisfy the contract
# Exit 1   at least one violation (each reported as FAIL: ...), including an explicitly
#          named --ledger/--constitution or a parser that cannot be read
# Exit 2   the shared parser is missing — nothing was checked
# Exit 77 skip — this checkout ships no ledger at all (adopter-local, gitignored); an
#          explicitly named --ledger that is absent is still exit 1, never a skip
set -uo pipefail

LEDGER=""
CONSTITUTION=""
ROOT=""
LEDGER_SET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --ledger) LEDGER="${2:-}"; LEDGER_SET=1; shift 2 ;;
    --constitution) CONSTITUTION="${2:-}"; shift 2 ;;
    --*) echo "usage: $0 [--ledger <path>] [--constitution <path>] [<repo root>]" >&2; exit 2 ;;
    *) ROOT="$1"; shift ;;
  esac
done
ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
LEDGER="${LEDGER:-$ROOT/skills/ac-pipeline/FRICTIONS.md}"
CONSTITUTION="${CONSTITUTION:-$ROOT/skills/ac-pipeline/SKILL.md}"
ROLLUP="$ROOT/skills/skill-builder/scripts/friction-rollup.py"

RC=0
ali_fail() { echo "FAIL: $*"; RC=1; }

if [ ! -f "$ROLLUP" ]; then
  echo "FAIL: NOT-GATED — the shared ledger parser is missing at $ROLLUP; nothing was checked" >&2
  exit 2
fi

# --- Absent ledger: skip when unshipped, fail closed when explicitly named -------------
# Friction ledgers are adopter-local and gitignored (each deployment's own operational
# log, not shipped registry content), so a checkout carrying none is the normal case, not
# a broken sensor. An explicitly named --ledger that does not exist is still a hard
# failure: the caller asserted a sensor that is not there.
if [ ! -f "$LEDGER" ] && [ "$LEDGER_SET" = 0 ]; then
  echo "skipped: 22-ledger-integrity — no ledger in this checkout, nothing gated"
  exit 77
fi
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
    ali_fail "constitution: Invariant $num names no failure it prevents (no 'Prevents:')" ;;
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
# Tab is IFS WHITESPACE in bash: with IFS=$'\t' consecutive tabs collapse and an empty
# MIDDLE field shifts every later column (control reads last_seen, landed reads
# last_seen) — the failed-control detector then compares the wrong pair, silently.
# awk -F'\t' preserves empties; the fields are re-delimited with \x1f (US), which is
# NOT IFS whitespace, so the read below cannot collapse them.
while IFS=$'\x1f' read -r id receipt control landed last_seen untreated; do
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
  ] | @tsv' | awk -F'\t' -v OFS="$(printf '\037')" '{$1=$1; print}')
EOF

# --- THE SCORABLE SWEEP (the folded-in --strict classes) ----------------------------
# One parse of every skills/*/FRICTIONS.md, read from the shared rollup's default-all
# JSON: each entry's own `unscorable` reasons and the pointer-corrected declared-vs-
# parsed counts. Two legs, two verdict classes; each finding is a REPORT ROW for the
# frictions docket, never a mutation of the ledger.
SWEEP_JSON=$(python3 "$ROLLUP" --root "$ROOT" 2>/dev/null)
if [ -z "$SWEEP_JSON" ]; then
  echo "FAIL: NOT-GATED — the shared parser returned nothing for the ledger sweep; scorable integrity NOT-GATED"
  exit 1
fi
if ! printf '%s' "$SWEEP_JSON" | jq -e 'has("dream") and has("entry_count_mismatches")' >/dev/null 2>&1; then
  echo "FAIL: NOT-GATED — the ledger sweep parse produced no scorable document; scorable integrity NOT-GATED"
  exit 1
fi
LEDGER_REL=""
if [ "$LEDGER_SET" = 1 ]; then
  LEDGER_REL=$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$LEDGER" "$ROOT" 2>/dev/null || true)
fi
NOT_SCORABLE=$(printf '%s' "$SWEEP_JSON" | jq -r --arg ledger_rel "$LEDGER_REL" '
  .dream.entries[]
  | select(.unscorable | length > 0)
  | select($ledger_rel == "" or .path == $ledger_rel)
  | "FAIL: NOT-SCORABLE: \(.id) (\(.path)): \(.unscorable | join("; "))"')
if [ -n "$NOT_SCORABLE" ]; then printf '%s\n' "$NOT_SCORABLE"; RC=1; fi

if [ "$RC" -eq 0 ]; then
  if [ "$LEDGER_SET" = 1 ]; then
    echo "  ok: 22-ledger-integrity — $ENTRY_COUNT entr(y|ies) · $(printf '%s' "$CONTROL_IDS" | wc -w | tr -d ' ') controls — contract holds both directions"
  else
    LEDGER_COUNT=$(printf '%s' "$SWEEP_JSON" | jq -r '.ledgers')
    echo "  ok: 22-ledger-integrity — $ENTRY_COUNT entr(y|ies) · $(printf '%s' "$CONTROL_IDS" | wc -w | tr -d ' ') controls — contract holds both directions · all $LEDGER_COUNT ledgers scorable"
  fi
fi
exit "$RC"
