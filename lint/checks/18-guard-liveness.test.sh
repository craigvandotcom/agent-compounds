#!/usr/bin/env bash
# 18-guard-liveness.test.sh — the contract harness for lint/checks/18-guard-liveness.py.
#
#   PROBE: a non-executable hook is FAILED; the real guards fire/silence as
#           declared; a doctored tree with a chmod-x'd bead-capture-guard is
#           FAILED twice (executable check + provenance-gate leg); a tree with
#           no hooks/ is NOT-GATED (exit 2).
#
# ASSURANCE
#   PROBE:    bash lint/checks/18-guard-liveness.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/18-guard-liveness.py"
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

# --- 1 RED: a non-executable hook -> exit 1, hook named ----------------------
t="$work/red"; mkdir -p "$t/hooks"
printf '#!/usr/bin/env python3\nprint("dead")\n' > "$t/hooks/dead-guard.py"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "hooks/dead-guard.py is not executable" "$OUT"; then
  ok "RED: dead hook failed, named"
else
  bad "RED: expected exit 1 naming the dead hook, got $rc"; cat "$OUT"
fi

# --- 2 DOCTORED: real hooks with bead-capture-guard chmod-x'd -> exit 1 ------
t="$work/doctored"
mkdir -p "$t"
cp -R "$ROOT/hooks" "$t/hooks"
chmod -x "$t/hooks/bead-capture-guard.py"
rc=$(run_check "$t")
if [ "$rc" = 1 ] \
   && grep -q "hooks/bead-capture-guard.py is not executable" "$OUT" \
   && grep -q "bead-capture-guard.py or its .test.py is missing" "$OUT"; then
  ok "DOCTORED: chmod-x'd guard failed on both legs"
else
  bad "DOCTORED: expected exit 1 with both legs, got $rc"; cat "$OUT"
fi

# --- 3 NOT-GATED: no hooks/ -> exit 2 -----------------------------------------
t="$work/empty"
rc=$(run_check "$t")
if [ "$rc" = 2 ] && grep -qi "NOT-CHECKED" "$OUT"; then
  ok "EMPTY: no hooks/ -> NOT-GATED exit 2"
else
  bad "EMPTY: expected exit 2 NOT-CHECKED, got $rc"; cat "$OUT"
fi

# --- 4 LIVE: the real registry's guards are alive ------------------------------
rc=$(run_check "$ROOT")
if [ "$rc" = 0 ]; then
  ok "LIVE: guards fire and stay silent as declared"
else
  bad "LIVE: expected exit 0 on the real registry, got $rc"; cat "$OUT"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "All 18-guard-liveness contract cases passed."
  exit 0
fi
echo "$fails case(s) FAILED."
exit 1
