#!/usr/bin/env bash
# 19-bead-template-conformance.test.sh — the contract harness for
# lint/checks/19-bead-template-conformance.py.
#
#   PROBE: a registry tree whose templates are conformant PASSES; a tree
#           without scripts/bead-template-lint.py is FAILED (missing judge,
#           never a silent gate); a tree carrying a template without the
#           origin:<skill> label is FAILED.
#
# ASSURANCE
#   PROBE:    bash lint/checks/19-bead-template-conformance.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/19-bead-template-conformance.py"
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

# --- 1 RED: the lint script itself is missing -> exit 1 -----------------------
t="$work/missing"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "scripts/bead-template-lint.py missing — template conformance unverified" "$OUT"; then
  ok "RED: missing judge failed loudly"
else
  bad "RED: expected exit 1 naming the missing script, got $rc"; cat "$OUT"
fi

# --- 2 RED: a template without origin: -> exit 1 ------------------------------
t="$work/bad"
mkdir -p "$t/scripts" "$t/hooks" "$t/skills/bad"
cp "$ROOT/scripts/bead-template-lint.py" "$t/scripts/"
cp "$ROOT/hooks/bead-capture-guard.py" "$t/hooks/"
printf '%s\n' '`br create -t bug --title "no provenance label"`' > "$t/skills/bad/SKILL.md"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "non-conforming bead template(s)" "$OUT"; then
  ok "RED: non-conforming template failed"
else
  bad "RED: expected exit 1 naming the template, got $rc"; cat "$OUT"
fi

# --- 3 RED: a finding template without a catch-stage label -> exit 1 -------------
# The VACUOUS guard (>= 20 scanned templates) needs a populated fixture tree, so
# generate 20 conformant templates plus one finding template missing its catch-stage.
t="$work/nocatch"
mkdir -p "$t/scripts" "$t/hooks" "$t/skills/bad"
cp "$ROOT/scripts/bead-template-lint.py" "$t/scripts/"
cp "$ROOT/hooks/bead-capture-guard.py" "$t/hooks/"
{
  for n in $(seq 1 20); do
    printf '%s\n' '`br create -t task --labels "origin:ac-hygiene,hygiene-finding,unrefined" --title "conformant template '"$n"'"`'
  done
  printf '%s\n' '`br create -t bug --labels "origin:ac-triage,triage,<source>,unrefined" --title "finding template with no catch-stage"`'
} > "$t/skills/bad/SKILL.md"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "no catch-stage label" "$OUT"; then
  ok "RED: finding template without catch-stage failed"
else
  bad "RED: expected exit 1 naming the missing catch-stage, got $rc"; cat "$OUT"
fi

# --- 4 LIVE: the real registry's shipped templates conform --------------------
rc=$(run_check "$ROOT")
if [ "$rc" = 0 ]; then
  ok "LIVE: shipped templates conform"
else
  bad "LIVE: expected exit 0 on the real registry, got $rc"; cat "$OUT"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "All 19-bead-template-conformance contract cases passed."
  exit 0
fi
echo "$fails case(s) FAILED."
exit 1
