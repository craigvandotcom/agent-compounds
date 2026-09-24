#!/usr/bin/env bash
# 18-guard-liveness.test.sh — the contract harness for lint/checks/18-guard-liveness.py.
#
#   PROBE: a non-executable hook is FAILED; the real guards fire/silence as
#           declared; a doctored tree with a chmod-x'd bead-capture-guard is
#           FAILED on the executable check; a tree with no hooks/ is
#           NOT-GATED (exit 2).
#
# ASSURANCE
#   PROBE:    bash lint/checks/18-guard-liveness.test.sh
#   SCHEDULE: scripts/run-all-proofs.sh + CI harness job
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
# $1 = root, $2 = machine.json path (fixture override for the wiring leg —
# the same AC_MACHINE_FILE knob engine/machine.sh already honours).
run_check_with_machine() {
  AC_MACHINE_FILE="$2" python3 "$CHECK" "$1" >"$OUT" 2>&1
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
if [ "$rc" = 1 ] && grep -q "hooks/bead-capture-guard.py is not executable" "$OUT"; then
  ok "DOCTORED: chmod-x'd guard failed on the executable check"
else
  bad "DOCTORED: expected exit 1 naming the dead guard, got $rc"; cat "$OUT"
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

# --- 5 RED: a non-executable .sh hook -> exit 1, hook named ------------------
t="$work/shguard"; mkdir -p "$t/hooks"
printf '#!/usr/bin/env bash\necho dead\n' > "$t/hooks/dead-guard.sh"
chmod -x "$t/hooks/dead-guard.sh"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "hooks/dead-guard.sh is not executable" "$OUT"; then
  ok "RED: non-executable .sh hook failed, named"
else
  bad "RED: expected exit 1 naming the dead .sh hook, got $rc"; cat "$OUT"
fi

# --- 6 GREEN: a non-executable .md doc is never flagged ----------------------
t="$work/mdguard"; mkdir -p "$t/hooks"
printf '#!/usr/bin/env python3\nprint("ok")\n' > "$t/hooks/dummy.py"
chmod +x "$t/hooks/dummy.py"
printf '# just a doc\n' > "$t/hooks/notes.md"
chmod -x "$t/hooks/notes.md"
run_check "$t" >/dev/null
if ! grep -q "hooks/notes.md is not executable" "$OUT"; then
  ok "MD-DOC: non-executable .md is never named as a violation"
else
  bad "MD-DOC: expected notes.md to be ignored by the +x scan"; cat "$OUT"
fi

# --- 7 RED: guard present, live settings present-but-unwired -> FAIL --------
t="$work/unwired"; mkdir -p "$t"
cp -R "$ROOT/hooks" "$t/hooks"
orgroot="$work/orgroot"; mkdir -p "$orgroot/.claude"
printf '{"hooks": {}}\n' > "$orgroot/.claude/settings.json"
machinejson="$work/machine-unwired.json"
printf '{"org_root": "%s", "targets": []}\n' "$orgroot" > "$machinejson"
rc=$(run_check_with_machine "$t" "$machinejson")
if [ "$rc" = 1 ] && grep -q "skill-edit-guard is NOT wired" "$OUT"; then
  ok "RED: unwired guard failed when live settings are present"
else
  bad "RED: expected exit 1 naming the unwired guard, got $rc"; cat "$OUT"
fi

# --- 8 GREEN: guard present, live settings present-and-wired -> pass --------
t="$work/wired"; mkdir -p "$t"
cp -R "$ROOT/hooks" "$t/hooks"
orgroot2="$work/orgroot2"; mkdir -p "$orgroot2/.claude"
cat > "$orgroot2/.claude/settings.json" <<'JSON'
{"hooks": {"PreToolUse": [{"matcher": "Bash|Edit|Write", "hooks": [{"type": "command", "command": "hooks/skill-edit-guard.py"}]}]}}
JSON
machinejson2="$work/machine-wired.json"
printf '{"org_root": "%s", "targets": []}\n' "$orgroot2" > "$machinejson2"
rc=$(run_check_with_machine "$t" "$machinejson2")
if [ "$rc" = 0 ]; then
  ok "GREEN: guard present + live settings wired -> pass"
else
  bad "GREEN: expected exit 0 with live settings wired, got $rc"; cat "$OUT"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "All 18-guard-liveness contract cases passed."
  exit 0
fi
echo "$fails case(s) FAILED."
exit 1
