#!/usr/bin/env bash
# plan-approve.test.sh — RED/GREEN proof harness for plan-approve.sh.
#
# ASSURANCE-ROLE: test-harness
# CALLER: scripts/run-all-harnesses.sh (discovered by its *.test.sh glob) and any local run.
#
# EVERY CHECK IS TESTED IN BOTH DIRECTIONS. The 2026-09-11 defect (ac-1p7j) is the reason the
# rule is written down here: the previous harness proved only that SOME string refused, using
# a fixture shape (`- DECISION … state: needs-human`) that NO document prescribes and no plan
# ever emitted. The matcher scored 0 against every real plan while this harness stayed green.
# So each case below pins its fixture to a shape with a named source — `ac-plan/references/
# decisions.md`, or a line lifted verbatim from a plan that shipped — and every REFUSES case
# is paired with an APPROVES twin that differs only in the state token.
#
# Exit 0 = all cases pass.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
SCRIPT="$HERE/plan-approve.sh"
[ -f "$SCRIPT" ] || { echo "HARNESS FAIL: $SCRIPT missing"; exit 1; }
FAILURES=0
CASES=0

expect() {
  CASES=$((CASES + 1))
  if [ "$1" = "$2" ]; then
    printf '  ok    %s\n' "$3"
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
TAIL='## Risk and sequence

Ship it in one wave.'

W=$(mktemp -d "${TMPDIR:-/tmp}/plan-approve-test-XXXXXX")
trap 'rm -rf "$W"' EXIT

# mkplan <file> <frontmatter> <decisions-body>
mkplan() { printf '%s\n\n%s\n\n%s\n' "$2" "$3" "$TAIL" > "$1"; }

# ---- the two card shapes, each in both states --------------------------------
# SHAPE A — the bullet card decisions.md prescribes (§ The card).
A_SETTLED=$(cat <<'EOF'
## Decisions

- **question** — which storage engine.
- **options** — sqlite (simple) · postgres (concurrent).
- **recommendation** — sqlite.
- **what settles it** — the concurrent-writer probe.
- **state** — `settled: sqlite — one writer, measured in the probe`
EOF
)
A_OPEN=$(cat <<'EOF'
## Decisions

- **question** — which storage engine.
- **options** — sqlite (simple) · postgres (concurrent).
- **recommendation** — sqlite.
- **what settles it** — the concurrent-writer probe.
- **state** — `needs-human`
EOF
)

# SHAPE B — the heading-per-card shape real plans emit. Both lines are VERBATIM from
# easy-mode `_plans/2026-09-11-0851-model-gateway.md`, the plan the old matcher passed.
B_SETTLED=$(cat <<'EOF'
## Decisions

### Where the gateway lives
`settled: apps/model-gateway/ — its own deployable and image.` Forced from three sides:
ADR 0007 requires it not sit under either path sub-check 4 covers.
EOF
)
B_OPEN=$(cat <<'EOF'
## Decisions

### ADR 0007's rule-3 exemption
`needs-human — already owned by bd-2mik, not re-decided here.` bd-2mik holds the FIX verdict
and states OUT: reversing the exemption. This plan does not answer it.
EOF
)

echo "shell: ${ZSH_VERSION:+zsh $ZSH_VERSION}${BASH_VERSION:+bash $BASH_VERSION}"
echo "-- shape A: the bullet card decisions.md prescribes --"

# 1 — A settled -> APPROVED, three keys written
mkplan "$W/a1.md" "$FM_POLISHED" "$A_SETTLED"
OUT=$("$SCRIPT" "$W/a1.md" "Craig" 2>&1)
expect "$(grep -c '^APPROVED:' <<<"$OUT")" 1 "A/settled -> APPROVED"
expect "$(grep -c '^status: loop-ready$' "$W/a1.md")" 1 "approval writes status: loop-ready"
expect "$(grep -c '^loop_ready_at:' "$W/a1.md")" 1 "approval writes loop_ready_at"
expect "$(grep -c '^approved_by: Craig$' "$W/a1.md")" 1 "approval writes approved_by"

# 2 — A open -> REFUSED, and the plan is NOT re-stamped
mkplan "$W/a2.md" "$FM_POLISHED" "$A_OPEN"
OUT=$("$SCRIPT" "$W/a2.md" "Craig" 2>&1)
expect "$(grep -c 'REFUSED needs-human 1' <<<"$OUT")" 1 "A/open -> REFUSED needs-human 1"
expect "$(grep -c '^status: draft$' "$W/a2.md")" 1 "refused plan is not re-stamped"

echo "-- shape B: the heading-per-card shape real plans emit --"

# 3 — B settled -> APPROVED
mkplan "$W/b1.md" "$FM_POLISHED" "$B_SETTLED"
OUT=$("$SCRIPT" "$W/b1.md" "Craig" 2>&1)
expect "$(grep -c '^APPROVED:' <<<"$OUT")" 1 "B/settled -> APPROVED"

# 4 — REGRESSION (ac-1p7j): the exact card the old matcher scored 0 against.
mkplan "$W/b2.md" "$FM_POLISHED" "$B_OPEN"
OUT=$("$SCRIPT" "$W/b2.md" "Craig" 2>&1)
expect "$(grep -c 'REFUSED needs-human 1' <<<"$OUT")" 1 "B/open -> REFUSED (regression: real plan shape)"
expect "$(grep -c '^status: draft$' "$W/b2.md")" 1 "B/open refused plan is not re-stamped"

echo "-- the word vs the state token: prose must not refuse a healthy plan --"

# 5 — prose OUTSIDE the Decisions section naming the state
mkplan "$W/p1.md" "$FM_POLISHED" "$A_SETTLED
"
printf 'Any unsettled fork stays needs-human until the docket clears it.\n' >> "$W/p1.md"
OUT=$("$SCRIPT" "$W/p1.md" "Craig" 2>&1)
expect "$(grep -c '^APPROVED:' <<<"$OUT")" 1 "prose outside Decisions naming needs-human -> APPROVED"

# 6 — prose INSIDE the Decisions section, token not line-initial
mkplan "$W/p2.md" "$FM_POLISHED" "$A_SETTLED
An unattended run leaves a card \`needs-human\` for the docket — never invent an answer."
OUT=$("$SCRIPT" "$W/p2.md" "Craig" 2>&1)
expect "$(grep -c '^APPROVED:' <<<"$OUT")" 1 "prose inside Decisions, token mid-line -> APPROVED"

# 7 — a SETTLED card whose why-text names the state it rejected
mkplan "$W/p3.md" "$FM_POLISHED" '## Decisions

- **state** — `settled: defer to bd-2mik — the needs-human escalation was rejected`'
OUT=$("$SCRIPT" "$W/p3.md" "Craig" 2>&1)
expect "$(grep -c '^APPROVED:' <<<"$OUT")" 1 "settled card naming needs-human in its why -> APPROVED"

echo "-- counting, and the remaining verdicts --"

# 8 — two open cards report N=2, not 1
mkplan "$W/n2.md" "$FM_POLISHED" "$A_OPEN

### A second fork
\`needs-human — nobody has ruled on the credential owner.\`"
OUT=$("$SCRIPT" "$W/n2.md" "Craig" 2>&1)
expect "$(grep -c 'REFUSED needs-human 2' <<<"$OUT")" 1 "two open cards -> REFUSED needs-human 2"

# 9 — the Decisions section runs to EOF (no following `## ` to close the slice)
printf '%s\n\n%s\n' "$FM_POLISHED" "$B_OPEN" > "$W/eof1.md"
OUT=$("$SCRIPT" "$W/eof1.md" "Craig" 2>&1)
expect "$(grep -c 'REFUSED needs-human 1' <<<"$OUT")" 1 "Decisions section at EOF, open -> REFUSED"
printf '%s\n\n%s\n' "$FM_POLISHED" "$B_SETTLED" > "$W/eof2.md"
OUT=$("$SCRIPT" "$W/eof2.md" "Craig" 2>&1)
expect "$(grep -c '^APPROVED:' <<<"$OUT")" 1 "Decisions section at EOF, settled -> APPROVED"

# 10 — no polish stamp -> REFUSED not-polished
mkplan "$W/u1.md" "$FM_UNPOLISHED" "$A_SETTLED"
OUT=$("$SCRIPT" "$W/u1.md" "Craig" 2>&1)
expect "$(grep -c 'REFUSED not-polished' <<<"$OUT")" 1 "no polish stamp -> REFUSED not-polished"

# 11 — no ## Decisions section -> REFUSED no-decisions
printf '%s\n\n%s\n' "$FM_POLISHED" "$TAIL" > "$W/d0.md"
OUT=$("$SCRIPT" "$W/d0.md" "Craig" 2>&1)
expect "$(grep -c 'REFUSED no-decisions' <<<"$OUT")" 1 "no Decisions section -> REFUSED no-decisions"

# 12 — missing plan file -> NOT-GATED
OUT=$("$SCRIPT" "$W/absent.md" "Craig" 2>&1)
expect "$(grep -c 'NOT-GATED' <<<"$OUT")" 1 "missing plan -> NOT-GATED"

printf 'plan-approve.test: %s cases, %s failures\n' "$CASES" "$FAILURES"
[ "$FAILURES" -eq 0 ]
