#!/usr/bin/env bash
# 08-deploy-dry-run-inert.test.sh — the contract harness for lint/checks/08-deploy-dry-run-inert.py.
#
#   PROBE: a dry run that exits nonzero FAILS; a dry run that writes into the
#           target dir FAILS with the leak named; an inert dry run PASSES; an
#           empty skills tree is a finding, never NOT-GATED.
#
# ASSURANCE
#   PROBE:    bash lint/checks/08-deploy-dry-run-inert.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/08-deploy-dry-run-inert.py"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

OUT="$(mktemp)"
run_check() { # <tmp-root> -> exit code; output in $OUT
  python3 "$CHECK" "$1" >"$OUT" 2>&1
  echo $?
}

work="$(mktemp -d)"
trap 'rm -rf "$work" "$OUT"' EXIT

build_tree() { # <root> <deploy-body>  -> root with skills/alpha + executable deploy.sh
  mkdir -p "$1/skills/alpha"
  printf '# alpha\n' > "$1/skills/alpha/SKILL.md"
  printf '%s\n' "$2" > "$1/deploy.sh"
  chmod +x "$1/deploy.sh"
}

# --- 1 RED-EXIT: dry run exits nonzero -> exit 1, exit code named ------------
t="$work/red-exit"
build_tree "$t" '#!/bin/sh
echo boom >&2
exit 3'
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "exited 3 (expected 0)" "$OUT"; then
  ok "RED-EXIT: nonzero dry run failed, exit code named"
else
  bad "RED-EXIT: expected exit 1 naming exit 3, got $rc"; cat "$OUT"
fi

# --- 2 RED-LEAK: dry run writes into the target -> exit 1, leak named --------
t="$work/red-leak"
build_tree "$t" '#!/bin/sh
touch "$1/stamped"
exit 0'
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "should be inert" "$OUT" && grep -q "stamped" "$OUT"; then
  ok "RED-LEAK: writing dry run failed, leak named"
else
  bad "RED-LEAK: expected exit 1 naming the leak, got $rc"; cat "$OUT"
fi

# --- 3 GREEN: inert dry run passes --------------------------------------------
t="$work/green"
build_tree "$t" '#!/bin/sh
exit 0'
rc=$(run_check "$t")
if [ "$rc" = 0 ]; then
  ok "GREEN: inert dry run passes"
else
  bad "GREEN: expected exit 0, got $rc"; cat "$OUT"
fi

# --- 4 RED-NOSKILL: no skill to test with is a finding, not NOT-GATED --------
t="$work/no-skill"
mkdir -p "$t/skills"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$t/deploy.sh"
chmod +x "$t/deploy.sh"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "could not find any skill to test with" "$OUT"; then
  ok "RED-NOSKILL: empty skills tree is a finding"
else
  bad "RED-NOSKILL: expected exit 1 naming the empty skills tree, got $rc"; cat "$OUT"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "All 08-deploy-dry-run-inert contract cases passed."
  exit 0
fi
echo "$fails case(s) FAILED."
exit 1
