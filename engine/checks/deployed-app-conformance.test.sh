#!/usr/bin/env bash
# deployed-app-conformance.test.sh — the contract harness for
# engine/checks/deployed-app-conformance.py (moved from
# lint/checks/12-deployed-app-conformance, W4 of the lint-system upgrade —
# this audits deploy targets, which sync.sh owns).
#
#   PROBE: a workflow-reminder.md carrying a dead pipeline command FAILS (C1);
#           a delegation-reminder.md carrying a dead tool name FAILS (C2); an
#           app-root AGENTS.md carrying a dead stage name FAILS (C3); clean or
#           missing every-prompt files PASS; no consumer dir at all (a
#           configured machine whose org root and targets carry no .claude)
#           SKIPs green, never a NOT-CHECKED/exit-2 claim; machine facts that
#           are absent (the reader's NOT-CONFIGURED, exit 4) SKIP green too;
#           machine facts the reader REFUSES (exit 2) are NOT-CHECKED — exit 2,
#           disclosed, never a green.
#
# ASSURANCE
#   PROBE:    bash engine/checks/deployed-app-conformance.test.sh
#   SCHEDULE: scripts/run-all-proofs.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/deployed-app-conformance.py"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

OUT="$(mktemp)"
run_check() { # <tmp-root> -> exit code; output in $OUT
  AC_MACHINE_FILE="$1/machine.json" python3 "$CHECK" >"$OUT" 2>&1
  echo $?
}

work="$(mktemp -d)"
trap 'rm -rf "$work" "$OUT"' EXIT

build_base() { # <root> — a configured machine: org root <root>, one existing app target
  mkdir -p "$1/app-target"
  printf '{"org_root": "%s", "targets": [{"path": "%s/app-target", "public": false}]}\n' \
    "$1" "$1" > "$1/machine.json"
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

# --- 3 RED-C3: dead stage name in app-root AGENTS.md ----------------------------
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

# --- 6 SKIP: no consumer dir exists at all -> exit 0 (never NOT-CHECKED/exit 2)
# A consumer-less checkout (an adopter's fresh clone, or a configured machine whose
# org root and targets carry no deployed layer) must get a green run: exit 2
# here would be unfixable and unconditional in every fresh clone. A skip is
# disclosed (SKIP token), never a silent/false pass.
t="$work/empty"
build_base "$t"
rc=$(run_check "$t")
if [ "$rc" = 0 ] && grep -qi "SKIP" "$OUT" && ! grep -qi "NOT-CHECKED" "$OUT"; then
  ok "EMPTY: no consumer dir -> SKIP exit 0, disclosed"
else
  bad "EMPTY: expected exit 0 SKIP (disclosed, no NOT-CHECKED), got $rc"; cat "$OUT"
fi

# --- 6b FAIL-CLOSED PRESERVED: a real consumer dir exists AND is broken --------
# Pins that "no consumer tree" (case 6, SKIP) and "a consumer tree that exists
# but is broken" (this case) are told apart: the same build_base() root, but
# with an actual workflow-reminder.md carrying a dead command, must still FAIL
# — the skip fix must never widen into "always green".
t="$work/empty-but-broken"
build_base "$t"
mkdir -p "$t/.claude/hooks"
printf 'Claim beads with /ac/bead-work.\n' > "$t/.claude/hooks/workflow-reminder.md"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "C1: .*workflow-reminder.md still contains dead pipeline command" "$OUT"; then
  ok "FAIL-CLOSED: a present-but-broken consumer tree still fails"
else
  bad "FAIL-CLOSED: expected exit 1 naming C1, got $rc"; cat "$OUT"
fi

# --- 7 SKIP: no machine facts at all (reader exit 4) -> exit 0 -------------------
# The absent-machine case: the reader has no file, so the union is UNKNOWN — a skip,
# never a fail, because a fresh clone legitimately has no local machine file.
rc=$(run_check "$work/no-such-root")
if [ "$rc" = 0 ] && grep -qi "SKIP" "$OUT" && ! grep -qi "NOT-CHECKED" "$OUT"; then
  ok "NOT-CONFIGURED: absent machine facts -> SKIP exit 0, disclosed"
else
  bad "NOT-CONFIGURED: expected exit 0 SKIP, got $rc"; cat "$OUT"
fi

# --- 8 NOT-CHECKED: machine facts the reader REFUSES -> exit 2 ------------------
# The two states must stay distinguishable: an absent file is a skip (case 7), a
# file the reader refuses is NOT-CHECKED — the check cannot see the consumer union
# and only a human can fix the file, so a green here would be a claim nobody made.
t="$work/wrong"
mkdir -p "$t"
printf 'this is not json\n' > "$t/machine.json"
rc=$(run_check "$t")
if [ "$rc" = 2 ] && grep -q 'machine.sh' "$OUT" && ! grep -qi "PASS" "$OUT"; then
  ok "WRONG: refused machine facts -> exit 2, disclosed, no pass claim"
else
  bad "WRONG: expected exit 2 naming the reader's refusal, got $rc"; cat "$OUT"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "All deployed-app-conformance contract cases passed."
  exit 0
fi
echo "$fails case(s) FAILED."
exit 1
