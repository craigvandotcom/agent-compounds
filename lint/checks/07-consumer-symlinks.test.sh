#!/usr/bin/env bash
# 07-consumer-symlinks.test.sh — the contract harness for
# lint/checks/07-consumer-symlinks.py.
#
#   PROBE: a dangling symlink in a consumer dir FAILS with the link named; a
#           dangling link nested deeper in the layer FAILS; a layer whose
#           symlinks all resolve PASSES; no consumer dir is NOT-GATED.
#
# ASSURANCE
#   PROBE:    bash lint/checks/07-consumer-symlinks.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/07-consumer-symlinks.py"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

OUT="$(mktemp)"
run_check() { # <tmp-base> -> exit code; output in $OUT
  LINT_CONSUMER_BASE="$1" python3 "$CHECK" >"$OUT" 2>&1
  echo $?
}

work="$(mktemp -d)"
trap 'rm -rf "$work" "$OUT"' EXIT

build_base() { # <root> — an empty consumer base with a (nonexistent) app target
  mkdir -p "$1/infrastructure"
  : > "$1/infrastructure/ac-deploy-targets.list"
}

# --- 1 RED: dangling symlink in a consumer dir -> exit 1, named ---------------
t="$work/red"
build_base "$t"
mkdir -p "$t/.claude/skills"
ln -s "$t/.claude/skills/gone-skill" "$t/.claude/skills/dangling-link"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "broken symlink: .*dangling-link" "$OUT"; then
  ok "RED: dangling symlink failed, named"
else
  bad "RED: expected exit 1 naming dangling-link, got $rc"; cat "$OUT"
fi

# --- 2 RED-NESTED: dangling link deeper in the layer -> exit 1 ----------------
t="$work/red-nested"
build_base "$t"
mkdir -p "$t/.claude/agents"
ln -s ../skills/never-existed "$t/.claude/agents/deep-link"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "broken symlink: .*deep-link" "$OUT"; then
  ok "RED-NESTED: nested dangling link failed, named"
else
  bad "RED-NESTED: expected exit 1 naming deep-link, got $rc"; cat "$OUT"
fi

# --- 3 GREEN: every symlink resolves ------------------------------------------
t="$work/green"
build_base "$t"
mkdir -p "$t/.claude/skills/real-skill"
printf '# real-skill\n' > "$t/.claude/skills/real-skill/SKILL.md"
ln -s real-skill "$t/.claude/skills/linked"
rc=$(run_check "$t")
if [ "$rc" = 0 ]; then
  ok "GREEN: resolving symlinks pass"
else
  bad "GREEN: expected exit 0, got $rc"; cat "$OUT"
fi

# --- 4 NOT-GATED: no consumer dir exists -> exit 2 ----------------------------
t="$work/empty"
build_base "$t"
rc=$(run_check "$t")
if [ "$rc" = 2 ] && grep -qi "NOT-CHECKED" "$OUT"; then
  ok "EMPTY: no consumer dir -> NOT-GATED exit 2"
else
  bad "EMPTY: expected exit 2 NOT-CHECKED, got $rc"; cat "$OUT"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "All 07-consumer-symlinks contract cases passed."
  exit 0
fi
echo "$fails case(s) FAILED."
exit 1
