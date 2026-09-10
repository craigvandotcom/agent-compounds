#!/usr/bin/env bash
# 12-deployed-app-conformance.test.sh — the contract harness for
# lint/checks/12-deployed-app-conformance.py.
#
#   PROBE: a workflow-reminder.md carrying a dead pipeline command FAILS (C1);
#           a delegation-reminder.md carrying a dead tool name FAILS (C2); an
#           app-root AGENTS.md carrying a dead stage name FAILS (C3); clean or
#           missing every-prompt files PASS; no consumer dir is NOT-GATED; an
#           absent consumer ROOT (a bare checkout) SKIPs green.
#
# ASSURANCE
#   PROBE:    bash lint/checks/12-deployed-app-conformance.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/12-deployed-app-conformance.py"

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

# --- 1 RED-C1: dead pipeline command in workflow-reminder.md -> exit 1 --------
t="$work/red-c1"
build_base "$t"
mkdir -p "$t/.claude/hooks"
printf 'Claim beads with /ac/bead-work.\n' > "$t/.claude/hooks/workflow-reminder.md"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "C1: .*workflow-reminder.md still contains dead pipeline command" "$OUT"; then
  ok "RED-C1: dead pipeline command failed, named"
else
  bad "RED-C1: expected exit 1 naming C1, got $rc"; cat "$OUT"
fi

# --- 2 RED-C2: dead delegation tool in delegation-reminder.md -> exit 1 -------
t="$work/red-c2"
build_base "$t"
mkdir -p "$t/.claude/hooks"
printf 'Delegate with cass search when useful.\n' > "$t/.claude/hooks/delegation-reminder.md"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "C2: .*delegation-reminder.md still contains dead delegation tool" "$OUT"; then
  ok "RED-C2: dead delegation tool failed, named"
else
  bad "RED-C2: expected exit 1 naming C2, got $rc"; cat "$OUT"
fi

# --- 3 RED-C3: dead stage name in app-root AGENTS.md -> exit 1 ----------------
t="$work/red-c3"
build_base "$t"
mkdir -p "$t/.claude"
printf 'Stages: bead-work then wave-merge.\n' > "$t/AGENTS.md"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "C3: .*AGENTS.md still contains dead pipeline stage" "$OUT"; then
  ok "RED-C3: dead stage name failed, named"
else
  bad "RED-C3: expected exit 1 naming C3, got $rc"; cat "$OUT"
fi

# --- 4 GREEN: clean every-prompt files pass ------------------------------------
t="$work/green"
build_base "$t"
mkdir -p "$t/.claude/hooks"
printf 'Read AGENTS.md first.\n' > "$t/.claude/hooks/workflow-reminder.md"
printf 'Delegate, do not inline.\n' > "$t/.claude/hooks/delegation-reminder.md"
printf 'The pipeline runs as a swarm.\n' > "$t/AGENTS.md"
rc=$(run_check "$t")
if [ "$rc" = 0 ]; then
  ok "GREEN: clean surfaces pass"
else
  bad "GREEN: expected exit 0, got $rc"; cat "$OUT"
fi

# --- 5 GREEN: missing files are skipped silently --------------------------------
t="$work/missing"
build_base "$t"
mkdir -p "$t/.claude"
rc=$(run_check "$t")
if [ "$rc" = 0 ]; then
  ok "GREEN-MISSING: consumer dir with no every-prompt files passes"
else
  bad "GREEN-MISSING: expected exit 0, got $rc"; cat "$OUT"
fi

# --- 6 NOT-GATED: no consumer dir exists at all -> exit 2 -----------------------
t="$work/empty"
build_base "$t"
rc=$(run_check "$t")
if [ "$rc" = 2 ] && grep -qi "NOT-CHECKED" "$OUT"; then
  ok "EMPTY: no consumer dir -> NOT-GATED exit 2"
else
  bad "EMPTY: expected exit 2 NOT-CHECKED, got $rc"; cat "$OUT"
fi

# --- 7 SKIP: absent consumer root (a consumer-less checkout) -> exit 0 -----------
rc=$(run_check "$work/no-such-root")
if [ "$rc" = 0 ] && grep -qi "SKIP" "$OUT"; then
  ok "NO-ROOT: absent consumer root -> SKIP exit 0"
else
  bad "NO-ROOT: expected exit 0 SKIP, got $rc"; cat "$OUT"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "All 12-deployed-app-conformance contract cases passed."
  exit 0
fi
echo "$fails case(s) FAILED."
exit 1
