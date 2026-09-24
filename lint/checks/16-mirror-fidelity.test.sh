#!/usr/bin/env bash
# 16-mirror-fidelity.test.sh — the contract harness for lint/checks/16-mirror-fidelity.py.
#
#   PROBE:
#     1. canon-extraction failure — the canon file lacks the § blockquote.
#        Must fail on BOTH legs: the extraction failure AND the zero-marker
#        accounting assertion (the vacuous-accounting path).
#     2. a drifted carrier — one altered line in a verbatim-class carrier fails.
#     3. the clean tree — canon + one faithful carrier passes with zero FAILs,
#        including a clean pass of the absorbed anchor-audit leg.
#     4. anchor leg RED: a header naming an anchor absent from the body.
#     5. anchor leg RED: a header naming no anchor at all.
#   Plus a NOT-GATED leg (no skills/) and the LIVE registry (which also
#   proves the anchor leg against the real 6 governed carriers).
#
# ASSURANCE
#   PROBE:    bash lint/checks/16-mirror-fidelity.test.sh
#   SCHEDULE: scripts/run-all-proofs.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/16-mirror-fidelity.py"
ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

OUT="$(mktemp)"
run_check() {
  python3 "$CHECK" "$1" >"$OUT" 2>&1
  echo $?
}

work="$(mktemp -d)"
trap 'rm -rf "$work" "$OUT"' EXIT

CANON_QUOTED='> ENVIRONMENT CONTRACT (non-negotiable):
> line one of the contract
> line two of the contract
> line three of the contract
> line four of the contract
> line five of the contract
> line six of the contract
> line seven of the contract
> line eight of the contract
> line nine of the contract
> line ten of the contract'

CANON_PASTED='ENVIRONMENT CONTRACT (non-negotiable):
line one of the contract
line two of the contract
line three of the contract
line four of the contract
line five of the contract
line six of the contract
line seven of the contract
line eight of the contract
line nine of the contract
line ten of the contract'

MARKER='<!-- mirror: ac-pipeline/references/delegation-contract.md § Child-spawn preamble -- edit there first -->'
ANCHOR_PARA='Conductor: paste the block below VERBATIM at the head of the child prompt, above its `First: read AGENTS.md` line, substituting the AGENT_NAME.'
ANCHOR_PARA_NO_ANCHOR='Conductor: paste the block below VERBATIM at the head of the child prompt.'

build_tree() { # <root> <drift:0|1> <canon:0|1> <anchor:ok|broken|missing (default ok)>
  mkdir -p "$1/skills/ac-pipeline/references" "$1/skills/carrier"
  if [ "$3" = 1 ]; then
    printf '%s\n' "$CANON_QUOTED" > "$1/skills/ac-pipeline/references/delegation-contract.md"
  else
    printf '%s\n' 'no blockquote here' > "$1/skills/ac-pipeline/references/delegation-contract.md"
  fi
  local preamble
  if [ "$2" = 1 ]; then
    preamble="$(printf '%s' "$CANON_PASTED" | sed '2s/line one/LINE ONE/')"
  else
    preamble="$CANON_PASTED"
  fi
  local anchor_para body
  case "${4:-ok}" in
    broken)  anchor_para="$ANCHOR_PARA"; body='No such anchor line in this body.' ;;
    missing) anchor_para="$ANCHOR_PARA_NO_ANCHOR"; body='First: read AGENTS.md and go.' ;;
    *)       anchor_para="$ANCHOR_PARA"; body='First: read AGENTS.md and go.' ;;
  esac
  printf '%s\n\n%s\n\n%s\n\n%s\n' "$MARKER" "$anchor_para" "$preamble" "$body" \
    > "$1/skills/carrier/SKILL.md"
}

# --- 1 DRIFT: one altered line in a verbatim carrier -> exit 1 ---------------
t="$work/drift"; build_tree "$t" 1 1
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "has DRIFTED from ac-pipeline/references/delegation-contract.md" "$OUT"; then
  ok "DRIFT: altered carrier failed, drift named"
else
  bad "DRIFT: expected exit 1 naming the drift, got $rc"; cat "$OUT"
fi

# --- 2 CANON-MISSING: extraction fails on BOTH legs -> exit 1 -----------------
t="$work/nocanon"; build_tree "$t" 0 0
rc=$(run_check "$t")
if [ "$rc" = 1 ] \
   && grep -q "could not extract the § Child-spawn preamble block" "$OUT" \
   && grep -q "zero mirror markers scanned — accounting is vacuous" "$OUT"; then
  ok "CANON-MISSING: extraction failure AND vacuous accounting both fired"
else
  bad "CANON-MISSING: expected exit 1 with both legs, got $rc"; cat "$OUT"
fi

# --- 3 GREEN: canon + faithful carrier -> exit 0 ------------------------------
t="$work/green"; build_tree "$t" 0 1
rc=$(run_check "$t")
if [ "$rc" = 0 ] && grep -q "1 verbatim-class checked" "$OUT" \
   && grep -q "anchor audit: 1 governed carrier(s) checked, 0 broken" "$OUT"; then
  ok "GREEN: faithful carrier passes, accounting clean, anchor leg clean"
else
  bad "GREEN: expected exit 0 with clean accounting, got $rc"; cat "$OUT"
fi

# --- 4 ANCHOR-BROKEN: header names an anchor absent from the body -> exit 1 ---
t="$work/anchor-broken"; build_tree "$t" 0 1 broken
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "does not occur in the prompt body" "$OUT"; then
  ok "ANCHOR-BROKEN: named anchor absent from body -> exit 1"
else
  bad "ANCHOR-BROKEN: expected exit 1 naming the inert anchor, got $rc"; cat "$OUT"
fi

# --- 5 ANCHOR-MISSING: header names no anchor at all -> exit 1 ----------------
t="$work/anchor-missing"; build_tree "$t" 0 1 missing
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "preamble header names no anchor" "$OUT"; then
  ok "ANCHOR-MISSING: no anchor named -> exit 1"
else
  bad "ANCHOR-MISSING: expected exit 1 naming the missing anchor, got $rc"; cat "$OUT"
fi

# --- 6 NOT-GATED: no skills/ -> exit 2 ----------------------------------------
t="$work/empty"
rc=$(run_check "$t")
if [ "$rc" = 2 ] && grep -qi "NOT-CHECKED" "$OUT"; then
  ok "EMPTY: no skills/ -> NOT-GATED exit 2"
else
  bad "EMPTY: expected exit 2 NOT-CHECKED, got $rc"; cat "$OUT"
fi

# --- 7 LIVE: the real registry is green, including the anchor leg -------------
rc=$(run_check "$ROOT")
if [ "$rc" = 0 ] && grep -q "anchor audit: 6 governed carrier(s) checked, 0 broken" "$OUT"; then
  ok "LIVE: registry tree passes, all 6 governed carriers' anchors resolve"
else
  bad "LIVE: expected exit 0 with 6 carriers clean, got $rc"; cat "$OUT"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "All 16-mirror-fidelity contract cases passed."
  exit 0
fi
echo "$fails case(s) FAILED."
exit 1
