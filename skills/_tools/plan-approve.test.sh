#!/usr/bin/env bash
# plan-approve.test.sh — RED/GREEN over every plan-approve.sh verdict (ac-wp8i.10).
# Fixtures: polished plan + closed Decisions (APPROVED); open Decision card
# (REFUSED needs-human); no polish stamp (REFUSED not-polished). A missing plan
# file is the NOT-GATED case; a plan without ## Decisions is REFUSED no-decisions.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/plan-approve.sh"
FAILURES=0
CASES=0

expect() {
  CASES=$((CASES + 1))
  if [ "$1" = "$2" ]; then
    printf '  PASS  %s\n' "$3"
  else
    printf '  FAIL  %s (want %s got %s)\n' "$3" "$2" "$1"
    FAILURES=$((FAILURES + 1))
  fi
}

FM_POLISHED='---
status: draft
created: 2026-09-05
polish_rounds: 4
polish_fixpoint_sha256: b3275a306b626c0eb07bbb626f04a8ede39d1f5c1ec2b9f56a59503de8c58c00
---
# Plan'
FM_UNPOLISHED='---
status: draft
created: 2026-09-05
---
# Plan'
DEC_CLOSED='## Decisions

- DECISION keep the one-engine shape — state: settled (Craig 2026-09-05)'
DEC_OPEN='## Decisions

- DECISION pick the storage engine — state: needs-human'
BODY='# Plan body'

W=$(mktemp -d /tmp/plan-approve-test-XXXXXX)

# 1 — polished + closed Decisions -> APPROVED, three keys written
printf '%s\n%s\n%s\n' "$FM_POLISHED" "$DEC_CLOSED" "$BODY" > "$W/p1.md"
OUT=$("$SCRIPT" "$W/p1.md" "Craig")
expect "$(grep -c '^APPROVED:' <<<"$OUT")" 1 "polished + closed decisions -> APPROVED"
expect "$(grep -c '^status: loop-ready$' "$W/p1.md")" 1 "approval writes status: loop-ready"
expect "$(grep -c '^loop_ready_at:' "$W/p1.md")" 1 "approval writes loop_ready_at"
expect "$(grep -c '^approved_by: Craig$' "$W/p1.md")" 1 "approval writes approved_by"

# 2 — polished + an open Decision card -> REFUSED needs-human N, plan untouched
printf '%s\n%s\n%s\n' "$FM_POLISHED" "$DEC_OPEN" "$BODY" > "$W/p2.md"
OUT=$("$SCRIPT" "$W/p2.md" "Craig" 2>&1)
expect "$(grep -c 'REFUSED needs-human 1' <<<"$OUT")" 1 "open Decision card -> REFUSED needs-human 1"
expect "$(grep -c '^status: draft$' "$W/p2.md")" 1 "refused plan is not re-stamped"

# 3 — no polish stamp -> REFUSED not-polished
printf '%s\n%s\n%s\n' "$FM_UNPOLISHED" "$DEC_CLOSED" "$BODY" > "$W/p3.md"
OUT=$("$SCRIPT" "$W/p3.md" "Craig" 2>&1)
expect "$(grep -c 'REFUSED not-polished' <<<"$OUT")" 1 "no polish stamp -> REFUSED not-polished"

# 4 — no ## Decisions section -> REFUSED no-decisions
printf '%s\n%s\n' "$FM_POLISHED" "$BODY" > "$W/p4.md"
OUT=$("$SCRIPT" "$W/p4.md" "Craig" 2>&1)
expect "$(grep -c 'REFUSED no-decisions' <<<"$OUT")" 1 "no Decisions section -> REFUSED no-decisions"

# 5 — missing plan file -> NOT-GATED
OUT=$("$SCRIPT" "$W/absent.md" "Craig" 2>&1)
expect "$(grep -c 'NOT-GATED' <<<"$OUT")" 1 "missing plan -> NOT-GATED"

# 6 — the word needs-human in ordinary prose (not a Decision bullet) must NOT refuse
printf '%s\n%s\n%s\n' "$FM_POLISHED" "$DEC_CLOSED" "Prose may name the needs-human state without being a card." > "$W/p6.md"
OUT=$("$SCRIPT" "$W/p6.md" "Craig" 2>&1)
expect "$(grep -c '^APPROVED:' <<<"$OUT")" 1 "prose mentioning needs-human does not refuse"

rm -rf "$W"
printf 'plan-approve.test: %s cases, %s failures\n' "$CASES" "$FAILURES"
[ "$FAILURES" -eq 0 ]
