#!/usr/bin/env bash
# rule-0-provenance.test.sh — Rule-0 IMPLEMENT / REFINE-half provenance (bd-nwri9).
#
# Drift-guard sibling of bead-refine-concurrent-dir.test.sh Case 6: extracts the
# live ENTER / IMPLEMENT / REFINE-half jq from skills/ac-loop/SKILL.md and runs
# them against a fixture. The test does not hardcode the jq.
#
# Usage: bash skills/ac-pipeline/scripts/rule-0-provenance.test.sh
# Exit 0 — all assertions passed. Exit 1 — leak, miss, or doc drift.
set -uo pipefail

FAILURES=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
AC_LOOP="$SKILLS_DIR/ac-loop/SKILL.md"

[ -f "$AC_LOOP" ] || { echo "FAIL: missing $AC_LOOP"; exit 1; }

# Unique markers the skill must publish (drift-guard).
extract_marked() {
  local mark="$1"
  # After the marker, take the first line that is the jq predicate itself
  # (contains issue_type) — skip comments, blanks, and the wrapping `br ready`.
  awk -v m="$mark" '
    $0 ~ m { grab=1; next }
    grab && $0 ~ /^[[:space:]]*$/ { next }
    grab && $0 ~ /^[[:space:]]*#/ { next }
    grab && $0 !~ /issue_type/ { next }
    grab {
      line=$0
      sub(/^[[:space:]]*/, "", line)
      sub(/[[:space:]]*$/, "", line)
      print line
      exit
    }
  ' "$AC_LOOP"
}

ENTER_JQ=$(extract_marked 'RULE-0 ENTER')
IMPLEMENT_JQ=$(extract_marked 'RULE-0 IMPLEMENT')
REFINE_JQ=$(extract_marked 'RULE-0 REFINE-half')

echo "ENTER:     ${ENTER_JQ:-<missing>}"
echo "IMPLEMENT: ${IMPLEMENT_JQ:-<missing>}"
echo "REFINE:    ${REFINE_JQ:-<missing>}"

if [ -z "$ENTER_JQ" ]; then fail "could not extract RULE-0 ENTER from ac-loop/SKILL.md"; fi
if [ -z "$IMPLEMENT_JQ" ]; then fail "could not extract RULE-0 IMPLEMENT from ac-loop/SKILL.md"; fi
if [ -z "$REFINE_JQ" ]; then fail "could not extract RULE-0 REFINE-half from ac-loop/SKILL.md"; fi

# ENTER must stay the unique lane-admission filter (byte-identical intent).
if [ -n "$ENTER_JQ" ]; then
  case "$ENTER_JQ" in
    *'(.issue_type == "bug") and (.labels | index("human-gate") | not)'*)
      pass "ENTER is the unique Rule-0 lane-admission filter"
      ;;
    *)
      fail "ENTER drifted off (.issue_type == \"bug\") and (.labels | index(\"human-gate\") | not) — got: $ENTER_JQ"
      ;;
  esac
fi

# IMPLEMENT must be DISTINCT from ENTER (the uk7la class lives in that gap).
if [ -n "$ENTER_JQ" ] && [ -n "$IMPLEMENT_JQ" ] && [ "$ENTER_JQ" = "$IMPLEMENT_JQ" ]; then
  fail "IMPLEMENT is identical to ENTER — bare-refined bugs leak (uk7la class)"
fi

FIXTURE='[
  {"id":"bare","issue_type":"bug","labels":["refined","curator"]},
  {"id":"full","issue_type":"bug","labels":["refined","refine-full"]},
  {"id":"light","issue_type":"bug","labels":["refined","refine-light"]},
  {"id":"ratif","issue_type":"bug","labels":["human-ratified"]},
  {"id":"unref","issue_type":"bug","labels":["unrefined"]},
  {"id":"hg","issue_type":"bug","labels":["refined","refine-full","human-gate"]},
  {"id":"task","issue_type":"task","labels":["refined"]}
]'

run_ids() {
  local jq_expr="$1"
  printf '%s' "$FIXTURE" | jq -c "[.[] | select($jq_expr)] | [.[].id]"
}

if [ -n "$IMPLEMENT_JQ" ]; then
  IMPL_IDS=$(run_ids "$IMPLEMENT_JQ") || IMPL_IDS='[]'
  echo "implement-eligible: $IMPL_IDS"

  case "$IMPL_IDS" in
    *'"bare"'*) fail "bare-refined-bug-excluded: implement admitted bare" ;;
    *) pass "bare-refined-bug-excluded" ;;
  esac
  case "$IMPL_IDS" in
    *'"full"'*) pass "full-admitted" ;;
    *) fail "full-admitted: implement dropped refine-full" ;;
  esac
  case "$IMPL_IDS" in
    *'"light"'*) pass "light-admitted" ;;
    *) fail "light-admitted: implement dropped refine-light" ;;
  esac
  case "$IMPL_IDS" in
    *'"ratif"'*) pass "ratif-admitted (human-ratified does not require refined)" ;;
    *) fail "ratif-admitted: implement dropped human-ratified (exclusive-stamper bite)" ;;
  esac
  case "$IMPL_IDS" in
    *'"hg"'*) fail "hg-rejected-implement: human-gate leaked" ;;
    *) pass "hg-rejected-implement" ;;
  esac
  case "$IMPL_IDS" in
    *'"task"'*) fail "task-rejected-implement: non-bug leaked" ;;
    *) pass "task-rejected-implement" ;;
  esac
  case "$IMPL_IDS" in
    *'"unref"'*) fail "unrefined-stays-in-refine-half: unrefined leaked into IMPLEMENT" ;;
    *) pass "unrefined-stays-in-refine-half" ;;
  esac

  EXPECTED='["full","light","ratif"]'
  if [ "$IMPL_IDS" = "$EXPECTED" ]; then
    pass "implement-eligible ids are exactly $EXPECTED"
  else
    fail "implement-eligible ids expected $EXPECTED got $IMPL_IDS"
  fi
fi

if [ -n "$REFINE_JQ" ]; then
  REF_IDS=$(run_ids "$REFINE_JQ") || REF_IDS='[]'
  echo "refine-half: $REF_IDS"
  case "$REF_IDS" in
    *'"bare"'*) pass "bare-routed-to-refine-half" ;;
    *) fail "bare-routed-to-refine-half: bare missing from REFINE-half" ;;
  esac
  case "$REF_IDS" in
    *'"unref"'*) pass "unrefined-in-refine-half" ;;
    *) fail "unrefined-in-refine-half: unref missing from REFINE-half" ;;
  esac
  case "$REF_IDS" in
    *'"full"'*|*'"light"'*|*'"ratif"'*) fail "provenance leaked into REFINE-half: $REF_IDS" ;;
    *) pass "provenance-not-in-refine-half" ;;
  esac
  case "$REF_IDS" in
    *'"hg"'*) fail "hg-rejected-refine: human-gate leaked into REFINE-half" ;;
    *) pass "hg-rejected-refine" ;;
  esac
  case "$REF_IDS" in
    *'"task"'*) fail "task-rejected-refine: non-bug leaked into REFINE-half" ;;
    *) pass "task-rejected-refine" ;;
  esac

  # Lane is not dry while REFINE-half is non-empty.
  if [ "$REF_IDS" != "[]" ]; then
    pass "lane-not-dry-while-refine-half-nonempty"
  else
    fail "lane-not-dry-while-refine-half-nonempty: REFINE-half empty"
  fi
fi

# Destamp instruction must exist so the orphan filter cannot pick a bare-refined bug.
if rg -n 'destamp' "$AC_LOOP" >/dev/null; then
  pass "destamp instruction present in ac-loop"
else
  fail "destamp instruction missing from ac-loop (orphan-leak backstop)"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "rule-0-provenance.test.sh: ALL PASS"
  exit 0
fi
echo "rule-0-provenance.test.sh: $FAILURES FAIL"
exit 1
