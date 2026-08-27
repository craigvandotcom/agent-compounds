#!/usr/bin/env bash
# polish-fixpoint.test.sh — RED/GREEN proof harness for polish-fixpoint.sh.
#
# ASSURANCE-ROLE: test-harness
# CALLER: scripts/run-all-harnesses.sh (discovered by its *.test.sh glob) and any local run.
#
# Every case asserts the VERDICT TOKEN, not just the exit status: the refusals differ from
# each other in kind (continue vs round-1-clean vs bound-exhausted vs out-of-band) and all
# four exit 1, so an exit-code-only harness would pass while the script confused them.
# It also asserts what the script must NOT do: spawn anything, or stamp without a receipt.
#
# Exit 0 = all cases pass.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/polish-fixpoint.sh"
[ -x "$SCRIPT" ] || { echo "HARNESS FAIL: $SCRIPT missing or not executable"; exit 1; }

W=$(mktemp -d "${TMPDIR:-/tmp}/polish-fixpoint-XXXXXX")
trap 'rm -rf "$W"' EXIT
PASS=0; FAIL=0

sha() { shasum -a 256 "$1" | awk '{print $1}'; }

# expect <name> <want-exit> <want-token> -- <args...>
expect() {
  local name="$1" want_rc="$2" want_tok="$3"; shift 4
  local out rc
  out=$("$SCRIPT" "$@" 2>&1); rc=$?
  if [ "$rc" = "$want_rc" ] && printf '%s' "$out" | grep -q -- "$want_tok"; then
    PASS=$((PASS+1)); printf 'ok   %-46s rc=%s\n' "$name" "$rc"
  else
    FAIL=$((FAIL+1)); printf 'FAIL %-46s rc=%s want=%s\n     token %s not found in: %s\n' \
      "$name" "$rc" "$want_rc" "$want_tok" "$out"
  fi
}

echo "shell: ${ZSH_VERSION:+zsh $ZSH_VERSION}${BASH_VERSION:+bash $BASH_VERSION}"

# --- setup: a plan fixture with frontmatter -----------------------------------
mk_plan() { printf -- '---\ntitle: fixture\n---\n\nbody %s\n' "$1" > "$2"; }

# --- 1. usage / NOT-GATED: nothing measured means nothing claimed --------------
expect "missing --artifact -> NOT-GATED"        2 "NOT-GATED" -- --state "$W/s0" --round 1 --pre x
expect "nonexistent artifact -> NOT-GATED"      2 "NOT-GATED" -- --state "$W/s0" --artifact "$W/nope.md" --round 1 --pre x
mk_plan a "$W/p0.md"
expect "bad --round -> NOT-GATED"               2 "NOT-GATED" -- --state "$W/s0" --artifact "$W/p0.md" --round zero --pre "$(sha "$W/p0.md")"
expect "bead mode without --target -> NOT-GATED" 2 "NOT-GATED" -- --mode bead --state "$W/s0" --artifact "$W/p0.md" --round 1 --pre "$(sha "$W/p0.md")"

# --- 2. round 1 never stamps ---------------------------------------------------
S1="$W/s1"; mk_plan a "$W/p1.md"; PRE=$(sha "$W/p1.md")
mk_plan b "$W/p1.md"   # the round-1 reader changed it
expect "round 1 with changes -> CONTINUE"       1 "CONTINUE round=1" -- --state "$S1" --artifact "$W/p1.md" --round 1 --pre "$PRE"

S2="$W/s2"; mk_plan a "$W/p2.md"; PRE=$(sha "$W/p2.md")
expect "clean round 1 -> REFUSED round-1-clean" 1 "REFUSED round-1-clean" -- --state "$S2" --artifact "$W/p2.md" --round 1 --pre "$PRE"

# --- 3. the stamp: clean round 2 over a recorded round 1 -----------------------
S3="$W/s3"; mk_plan a "$W/p3.md"; PRE=$(sha "$W/p3.md")
mk_plan b "$W/p3.md"
"$SCRIPT" --state "$S3" --artifact "$W/p3.md" --round 1 --pre "$PRE" >/dev/null 2>&1 || true
PRE2=$(sha "$W/p3.md")   # round-2 reader changed nothing
expect "clean round 2 -> STAMPED"               0 "STAMPED mode=plan round=2" -- --state "$S3" --artifact "$W/p3.md" --round 2 --pre "$PRE2"
if grep -q '^polish_fixpoint_sha256: ' "$W/p3.md" && grep -q '^polish_rounds: 2' "$W/p3.md"; then
  PASS=$((PASS+1)); echo "ok   plan frontmatter stamped in place"
else
  FAIL=$((FAIL+1)); echo "FAIL plan frontmatter not stamped"; fi
if [ -f "$S3/receipt.txt" ] && grep -q '^POLISH-FIXPOINT: mode=plan rounds=2 sha256=' "$S3/receipt.txt"; then
  PASS=$((PASS+1)); echo "ok   fixpoint receipt written"
else
  FAIL=$((FAIL+1)); echo "FAIL receipt missing or malformed"; fi

# --- 4. a non-empty final diff is NOT stamped (the core refusal) ---------------
S4="$W/s4"; mk_plan a "$W/p4.md"; PRE=$(sha "$W/p4.md")
mk_plan b "$W/p4.md"
"$SCRIPT" --state "$S4" --artifact "$W/p4.md" --round 1 --pre "$PRE" >/dev/null 2>&1 || true
PRE2=$(sha "$W/p4.md"); mk_plan c "$W/p4.md"   # round 2 changed it again
expect "round 2 with a non-empty diff -> CONTINUE" 1 "CONTINUE round=2" -- --state "$S4" --artifact "$W/p4.md" --round 2 --pre "$PRE2"
if grep -q '^polish_fixpoint_sha256:' "$W/p4.md"; then
  FAIL=$((FAIL+1)); echo "FAIL stamped an artifact with a non-empty final diff"
else
  PASS=$((PASS+1)); echo "ok   no stamp written when the diff is non-empty"; fi

# --- 5. the bound: exhaustion sends findings to the human, never a stamp -------
S5="$W/s5"; mk_plan a "$W/p5.md"; PRE=$(sha "$W/p5.md")
for r in 1 2; do
  mk_plan "r$r" "$W/p5.md"
  "$SCRIPT" --state "$S5" --artifact "$W/p5.md" --round "$r" --pre "$PRE" --max-rounds 3 >/dev/null 2>&1 || true
  PRE=$(sha "$W/p5.md")
done
mk_plan final "$W/p5.md"
expect "bound reached, still dirty -> bound-exhausted" 1 "REFUSED bound-exhausted" -- --state "$S5" --artifact "$W/p5.md" --round 3 --pre "$PRE" --max-rounds 3

# --- 6. FROZEN INPUT: an out-of-band amendment ends the loop -------------------
S6="$W/s6"; mk_plan a "$W/p6.md"; PRE=$(sha "$W/p6.md")
mk_plan b "$W/p6.md"
"$SCRIPT" --state "$S6" --artifact "$W/p6.md" --round 1 --pre "$PRE" >/dev/null 2>&1 || true
mk_plan "edited-by-a-human" "$W/p6.md"          # moved from OUTSIDE the loop
expect "input moved between rounds -> ENDED"    1 "ENDED out-of-band-amendment" -- --state "$S6" --artifact "$W/p6.md" --round 2 --pre "$(sha "$W/p6.md")"

# --- 7. bead mode produces the receipt without touching any bead ---------------
S7="$W/s7"; mk_plan a "$W/p7.md"; PRE=$(sha "$W/p7.md")
mk_plan b "$W/p7.md"
"$SCRIPT" --mode bead --target ac-fixture --state "$S7" --artifact "$W/p7.md" --round 1 --pre "$PRE" --dry-run >/dev/null 2>&1 || true
expect "bead mode, clean round 2 -> STAMPED"    0 "STAMPED mode=bead round=2" -- --mode bead --target ac-fixture --state "$S7" --artifact "$W/p7.md" --round 2 --pre "$(sha "$W/p7.md")" --dry-run
if grep -q '^POLISH-FIXPOINT: mode=bead rounds=2 ' "$S7/receipt.txt"; then
  PASS=$((PASS+1)); echo "ok   bead receipt format is the one stamp-refined.sh will gate on"
else
  FAIL=$((FAIL+1)); echo "FAIL bead receipt malformed"; fi

# --- 8. the engine SPAWNS NOTHING ---------------------------------------------
if grep -nE '(^|[^[:alnum:]_-])(claude|codex|droid|amp|cursor-agent)[[:space:]]|subagent|[Tt]ask\(|--dangerously' "$SCRIPT" >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); echo "FAIL the engine invokes an agent — it must measure and gate, nothing else"
  grep -nE '(^|[^[:alnum:]_-])(claude|codex|droid|amp|cursor-agent)[[:space:]]|subagent|[Tt]ask\(' "$SCRIPT" | sed 's/^/     /'
else
  PASS=$((PASS+1)); echo "ok   engine spawns nothing (no agent invocation in the script)"; fi

# --- 9. the assurance declaration is present at birth -------------------------
miss=""
for f in PROBE: SCHEDULE: MODE: ON-FAILURE:; do
  grep -q "$f" "$SCRIPT" || miss="$miss $f"
done
if [ -z "$miss" ]; then PASS=$((PASS+1)); echo "ok   4-field assurance declaration present"
else FAIL=$((FAIL+1)); echo "FAIL assurance declaration missing:$miss"; fi

echo "---"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
