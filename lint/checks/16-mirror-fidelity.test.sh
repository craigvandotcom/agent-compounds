#!/usr/bin/env bash
# 16-mirror-fidelity.test.sh — the contract harness for lint/checks/16-mirror-fidelity.py.
#
#   PROBE (inherits the three cases of the retired legacy-judge harness
#   skills/ac-pipeline/scripts/mirror-fidelity.test.sh, bead ac-kdtg.3):
#     1. canon-extraction failure — the canon file lacks the § blockquote.
#        Must fail on BOTH legs: the extraction failure AND the zero-marker
#        accounting assertion (the vacuous-accounting path).
#     2. a drifted carrier — one altered line in a verbatim-class carrier fails.
#     3. the clean tree — canon + one faithful carrier passes with zero FAILs.
#   Plus a NOT-GATED leg (no skills/) and the LIVE registry.
#
# ASSURANCE
#   PROBE:    bash lint/checks/16-mirror-fidelity.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
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

build_tree() { # <root> <drift:0|1> <canon:0|1>
  mkdir -p "$1/skills/ac-pipeline/references" "$1/skills/carrier"
  if [ "$3" = 1 ]; then
    printf '%s\n' "$CANON_QUOTED" > "$1/skills/ac-pipeline/references/delegation-contract.md"
  else
    printf '%s\n' 'no blockquote here' > "$1/skills/ac-pipeline/references/delegation-contract.md"
  fi
  if [ "$2" = 1 ]; then
    printf '%s\n\n%s\n' "$MARKER" "$(printf '%s' "$CANON_PASTED" | sed '2s/line one/LINE ONE/')" \
      > "$1/skills/carrier/SKILL.md"
  else
    printf '%s\n\n%s\n' "$MARKER" "$CANON_PASTED" > "$1/skills/carrier/SKILL.md"
  fi
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
if [ "$rc" = 0 ] && grep -q "1 verbatim-class checked" "$OUT"; then
  ok "GREEN: faithful carrier passes, accounting clean"
else
  bad "GREEN: expected exit 0 with clean accounting, got $rc"; cat "$OUT"
fi

# --- 4 NOT-GATED: no skills/ -> exit 2 ----------------------------------------
t="$work/empty"
rc=$(run_check "$t")
if [ "$rc" = 2 ] && grep -qi "NOT-CHECKED" "$OUT"; then
  ok "EMPTY: no skills/ -> NOT-GATED exit 2"
else
  bad "EMPTY: expected exit 2 NOT-CHECKED, got $rc"; cat "$OUT"
fi

# --- 5 LIVE: the real registry is green ---------------------------------------
rc=$(run_check "$ROOT")
if [ "$rc" = 0 ]; then
  ok "LIVE: registry tree passes"
else
  bad "LIVE: expected exit 0 on the real registry, got $rc"; cat "$OUT"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "All 16-mirror-fidelity contract cases passed."
  exit 0
fi
echo "$fails case(s) FAILED."
exit 1
