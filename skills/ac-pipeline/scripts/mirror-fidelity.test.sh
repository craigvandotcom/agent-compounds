#!/usr/bin/env bash
# mirror-fidelity.test.sh — RED/GREEN harness for lint.sh Check 16 (bead ac-kdtg.3).
#
# Check 16 byte-compares every VERBATIM-class mirror carrier against the canon block in
# ac-pipeline/references/delegation-contract.md § Child-spawn preamble. That proof was
# RED-probed by hand once (7c3dc63); a hand probe is not repeatable in CI. This harness
# makes it repeatable: it copies the Check 16 block OUT of lint.sh by its text anchors
# (never line numbers), runs it against a scratch AC root, and asserts three cases:
#
#   1. canon-extraction failure — the canon file lacks the § blockquote. Must fail on
#      BOTH legs: the extraction failure AND the zero-marker accounting assertion
#      (the vacuous-accounting path 7c3dc63 fixed).
#   2. a drifted carrier — one altered line in a verbatim-class carrier fails.
#   3. the clean tree — canon + one faithful carrier passes with zero FAILs.
#
# Exit 0 all three cases hold; exit 1 any leg fails.

set -u
ROOT="$(git rev-parse --show-toplevel)" || exit 2
cd "$ROOT" || exit 2

rc=0

# ---------------------------------------------------------------------------
# Extract the Check 16 block from lint.sh by text anchor: from the Check 16
# banner echo up to (not including) the `Check 17` header and its separator.
# ---------------------------------------------------------------------------
CHECK16_BLOCK=$(sed -n '/^echo "--- Check 16: mirror fidelity/,/^# Check 17 /p' lint.sh \
  | awk '{a[NR]=$0} END {for (i=1; i <= NR - 2; i++) print a[i]}')
case "$CHECK16_BLOCK" in
  *"Check 16: mirror fidelity"*) ;;
  *) echo "HARNESS-BROKEN: Check 16 block not extractable from lint.sh (anchor moved?)"; exit 1 ;;
esac
case "$CHECK16_BLOCK" in
  *"zero mirror markers scanned"*) ;;
  *) echo "HARNESS-BROKEN: extracted block lacks the zero-marker assertion — wrong range"; exit 1 ;;
esac

WORKDIR="$(mktemp -d)" || exit 2
trap 'rm -rf "$WORKDIR"' EXIT

# Runner template: stubs the lint check/fail helpers, points AC_ROOT at a case
# tree, then evaluates the extracted block. Exit 0 iff zero FAILs fired.
cat > "$WORKDIR/runner.tpl" <<'RUNNER'
check() { :; }
fail() { FAILS=$((FAILS+1)); printf 'FAIL: %s\n' "$*"; }
AC_ROOT="$1"
FAILS=0
__CHECK16_BLOCK__
[ "$FAILS" -eq 0 ]
RUNNER

make_runner() {
  CHECK16_BLOCK="$CHECK16_BLOCK" awk '
    index($0, "__CHECK16_BLOCK__") { printf "%s\n", ENVIRON["CHECK16_BLOCK"]; next }
    { print }' "$WORKDIR/runner.tpl" > "$WORKDIR/runner.sh"
}

# One canon-preamble source; canon gets `> `-prefixed (blockquoted) lines, the
# carriers get the stripped form — exactly the relationship Check 16 compares.
PREAMBLE="ENVIRONMENT CONTRACT (non-negotiable):
- WAIT for your own long-running commands in-shell; never arm a Monitor.
- Agent Mail: CHECK whether you hold the mail tools; assume neither way.
- Touching beads? The canon is beads-standards; read before inventing usage.
- After every push: verify origin SHA == local HEAD before proceeding.
- A guard block (dcg / pre-commit) means CHANGE APPROACH, never bypass.
- Shared checkout: commit scoped the instant the ACs verify; never git add -A.
- Autonomous run: never AskUserQuestion — Exhaust Rule.
- Return a structured friction block (stage/cost/lesson/class; [] if clean).
- Keep the preamble SHORT: every added line is paid on every delegation."

make_tree() {  # $1 = case root
  mkdir -p "$1/skills/ac-pipeline/references" "$1/skills/carry-skill/references"
}

write_canon() {  # $1 = case root, $2 = blockquoted(yes|no)
  local canon="$1/skills/ac-pipeline/references/delegation-contract.md"
  if [ "$2" = yes ]; then
    { printf '## Child-spawn preamble (the child-side environment contract)\n\n'
      printf '%s\n' "$PREAMBLE" | sed 's/^/> /'
    } > "$canon"
  else
    printf '## Child-spawn preamble (the child-side environment contract)\n\nThe block was deleted from this file.\n' > "$canon"
  fi
}

write_carrier() {  # $1 = case root, $2 = drift(yes|no)
  local carrier="$1/skills/carry-skill/references/prompt.md"
  { printf '<!-- mirror: ac-pipeline/references/delegation-contract.md § Child-spawn preamble -- edit there first -->\n\n'
    if [ "$2" = yes ]; then
      printf '%s\n' "$PREAMBLE" \
        | sed 's/^- After every push: verify origin SHA == local HEAD before proceeding\.$/- After every push: trust the push./'
    else
      printf '%s\n' "$PREAMBLE"
    fi
  } > "$carrier"
}

run_case() {  # $1 = case root; echoes runner output
  make_runner
  bash "$WORKDIR/runner.sh" "$1" 2>&1
}

# --- Case 1: canon-extraction failure must fire BOTH legs -------------------
C1="$WORKDIR/case-extraction-fail"
make_tree "$C1"
write_canon "$C1" no
write_carrier "$C1" no
OUT1=$(run_case "$C1")
if printf '%s' "$OUT1" | grep -q "could not extract" \
  && printf '%s' "$OUT1" | grep -q "zero mirror markers scanned"; then
  echo "PASS  case-extraction-fail: extraction AND zero-marker legs both fired"
else
  echo "FAIL  case-extraction-fail: expected BOTH 'could not extract' and 'zero mirror markers scanned'; got:"
  printf '%s\n' "$OUT1"
  rc=1
fi

# --- Case 2: a drifted carrier fails ---------------------------------------
C2="$WORKDIR/case-drifted-carrier"
make_tree "$C2"
write_canon "$C2" yes
write_carrier "$C2" yes
OUT2=$(run_case "$C2")
if printf '%s' "$OUT2" | grep -q "has DRIFTED"; then
  echo "PASS  case-drifted-carrier: the altered line was caught"
else
  echo "FAIL  case-drifted-carrier: expected a DRIFTED failure; got:"
  printf '%s\n' "$OUT2"
  rc=1
fi

# --- Case 3: canon + faithful carrier passes --------------------------------
C3="$WORKDIR/case-clean"
make_tree "$C3"
write_canon "$C3" yes
write_carrier "$C3" no
OUT3=$(run_case "$C3")
if printf '%s' "$OUT3" | grep -q "^FAIL:" || ! printf '%s' "$OUT3" | grep -q "1 verbatim-class checked"; then
  echo "FAIL  case-clean: expected zero FAILs and 1 verbatim-class carrier checked; got:"
  printf '%s\n' "$OUT3"
  rc=1
else
  echo "PASS  case-clean: faithful carrier passes, accounting is non-vacuous"
fi

exit $rc
