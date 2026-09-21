#!/usr/bin/env bash
# 07-consumer-symlinks.test.sh — the contract harness for
# lint/checks/07-consumer-symlinks.py.
#
#   PROBE: a dangling symlink in a consumer dir FAILS with the link named; a
#           dangling link nested deeper in the layer FAILS; a layer whose
#           symlinks all resolve PASSES; no consumer dir at all (a configured
#           machine whose org root and targets carry no .claude) SKIPs green,
#           never a NOT-CHECKED/exit-2 claim; machine facts that are absent
#           (the reader's NOT-CONFIGURED, exit 4) SKIP green too; machine facts
#           the reader REFUSES (exit 2) are NOT-CHECKED — exit 2, disclosed,
#           never a green.
#
# ASSURANCE
#   PROBE:    bash lint/checks/07-consumer-symlinks.test.sh
#   SCHEDULE: scripts/run-all-proofs.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/07-consumer-symlinks.py"

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

# --- 4 SKIP: no consumer dir exists -> exit 0 (never NOT-CHECKED/exit 2) -----
# A consumer-less checkout (an adopter's fresh clone, or a configured machine whose
# org root and targets carry no deployed layer) must get a green suite: exit 2
# here used to be unfixable and unconditional in every fresh clone (ac-agnostic
# batch B). A skip is disclosed (SKIP token), never a silent/false pass.
t="$work/empty"
build_base "$t"
rc=$(run_check "$t")
if [ "$rc" = 0 ] && grep -qi "SKIP" "$OUT" && ! grep -qi "NOT-CHECKED" "$OUT"; then
  ok "EMPTY: no consumer dir -> SKIP exit 0, disclosed"
else
  bad "EMPTY: expected exit 0 SKIP (disclosed, no NOT-CHECKED), got $rc"; cat "$OUT"
fi

# --- 4b FAIL-CLOSED PRESERVED: a real consumer dir exists AND is broken -------
# Pins that "no consumer tree" (case 4, SKIP) and "a consumer tree that exists
# but is broken" (this case) are told apart: the same build_base() root, but
# with an actual .claude/skills tree carrying a dangling link, must still FAIL
# — the skip fix must never widen into "always green".
t="$work/empty-but-broken"
build_base "$t"
mkdir -p "$t/.claude/skills"
ln -s "$t/.claude/skills/gone-skill" "$t/.claude/skills/dangling-link"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "broken symlink: .*dangling-link" "$OUT"; then
  ok "FAIL-CLOSED: a present-but-broken consumer tree still fails"
else
  bad "FAIL-CLOSED: expected exit 1 naming dangling-link, got $rc"; cat "$OUT"
fi

# --- 5 SKIP: no machine facts at all (reader exit 4) -> exit 0 ------------------
# The absent-machine case: the reader has no file, so the union is UNKNOWN — a skip,
# never a fail, because a fresh clone legitimately has no local machine file.
rc=$(run_check "$work/no-such-root")
if [ "$rc" = 0 ] && grep -qi "SKIP" "$OUT" && ! grep -qi "NOT-CHECKED" "$OUT"; then
  ok "NOT-CONFIGURED: absent machine facts -> SKIP exit 0, disclosed"
else
  bad "NOT-CONFIGURED: expected exit 0 SKIP, got $rc"; cat "$OUT"
fi

# --- 6 NOT-CHECKED: machine facts the reader REFUSES -> exit 2 -----------------
# The two states must stay distinguishable: an absent file is a skip (case 5), a
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
  echo "All 07-consumer-symlinks contract cases passed."
  exit 0
fi
echo "$fails case(s) FAILED."
exit 1
