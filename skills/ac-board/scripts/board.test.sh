#!/usr/bin/env bash
# board.test.sh — proves render.py derives each verdict from the reads, and says `?` when one fails.
#
# Each case writes the read files board.sh would leave (<name>.out/.err/.rc) plus a beads jsonl,
# pins the clock with AC_BOARD_NOW, and asserts on the render. No repo, no br, no network.
set -uo pipefail

RENDER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/render.py"
NOW=2026-09-22T12:00:00+00:00
FAILURES=0
CASES=0
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT

# put <dir> <read> <rc> <stdout> — one read's result files
put() { printf '%s' "$4" >"$1/$2.out"; : >"$1/$2.err"; echo "$3" >"$1/$2.rc"; }

# fixture <name> <br-list-json> <br-ready-json> <jsonl> <roster> — a reads dir + project root
fixture() {
  local d="$W/$1"; mkdir -p "$d/reads" "$d/repo/.beads"
  put "$d/reads" beads 0 "$2"; put "$d/reads" ready 0 "$3"
  printf '%s\n' "$4" >"$d/repo/.beads/issues.jsonl"
  put "$d/reads" roster 0 "$(printf '#mail\tup\n%s' "$5")"
  put "$d/reads" docket 0 "docket-health: 1 open human-gate · 0 reason-less · plan-gap: 0 · gate-incomplete: 0"
  put "$d/reads" ci 0 "ci-gates: 0 scheduled · none · ci_health: none"
  put "$d/reads" truth 0 "board-truth: 0 cited-but-open"
  put "$d/reads" waves 0 ""
  put "$d/reads" prs 0 "[]"
}

render() { TZ=UTC AC_BOARD_NOW=$NOW python3 "$RENDER" "$W/$1/reads" "$W/$1/repo" "${2:-0}"; }

check() {  # check <case> <description> <grep -E pattern> [absent]
  CASES=$((CASES + 1))
  local got; got=$(render "$1")
  if { [ "${4:-}" = absent ] && ! grep -qE -- "$3" <<<"$got"; } ||
     { [ "${4:-}" != absent ] && grep -qE -- "$3" <<<"$got"; }; then
    echo "ok   $1: $2"
  else
    echo "FAIL $1: $2 — expected ${4:+no }/$3/ in:"; sed 's/^/     | /' <<<"$got"
    FAILURES=$((FAILURES + 1))
  fi
}

B='"status":"open","created_at":"2026-09-20T12:00:00Z"'
GATE='{"id":"ac-g1","title":"ACTION: rotate the key","issue_type":"task","labels":["human-gate"],'$B'}'
UNREF='{"id":"ac-u1","title":"an unrefined idea","issue_type":"task",'$B'}'
READY='{"id":"ac-r1","title":"a refined bead","issue_type":"task","labels":["refined"],'$B'}'
BLOCKED='{"id":"ac-b1","title":"waits on the gate","issue_type":"task",'$B',"dependencies":[{"issue_id":"ac-b1","depends_on_id":"ac-g1","type":"blocks"}]}'
HELD='{"id":"ac-p1","title":"work underway","issue_type":"task","status":"in_progress","assignee":"BlueFox","created_at":"2026-09-22T11:00:00Z","updated_at":"2026-09-22T11:50:00Z"}'
LIVE=$'BlueFox\tclaude-code\tclaude-opus-5-5\t2026-09-22T11:55:00+00:00'

# STALLED on you: a gate, the bead it blocks, an unrefined bead — nothing ready.
fixture stalled "[$GATE,$UNREF,$BLOCKED]" "[$GATE,$UNREF]" "$GATE
$UNREF
$BLOCKED" "$LIVE"
check stalled "verdict word on its own line"   '^⛔ STALLED on you$'
check stalled "its reasons stacked beneath"    '^   0 ready · 1 gate$'
check stalled "YOU counts what gates block"    '^   blocking 1 · oldest 2d$'
check stalled "blocked row counts yours"       '^   blocked +1  1 on you$'
check stalled "no bead is itemized"            'ac-b1|waits on the gate' absent
check stalled "the jam is marked"              '▲ nothing refined'
check stalled "NEXT leads with the gate"       '^1\. ac-g1$'
check stalled "its detail and route stack"     '^   action · unblocks 1 bead$'
check stalled "then the refinement jam"        '^2\. refine 1 bead$'
check stalled "a live agent with no bead"      '^   0 working · 0 idle >1h · mail up$'

# FLOWING: a ready bead and one held by a live agent.
fixture flowing "[$READY,$HELD]" "[$READY]" "$READY
$HELD" "$LIVE"
check flowing "verdict says it flows"          '^✅ FLOWING$'
check flowing "agents count the held bead"     '^   1 working'
check flowing "no ready title leaks"           'a refined bead' absent
check flowing "checks all clear on zeros"      '^   checks +✓ all clear$'
put "$W/flowing/reads" truth 0 "board-truth: 3 cited-but-open"
check flowing "only a non-zero check shows"    '^   checks +⚠ board-truth 3$'
check flowing "no jam when work is ready"      '▲' absent
check flowing "NEXT has nothing for you"       '^1\. nothing needs you$'
put "$W/flowing/reads" prs 0 '[{"number":42,"statusCheckRollup":[{"conclusion":"FAILURE","name":"build"}]}]'
check flowing "a failing PR check is counted"  '^   PRs +1 open · 1 red$'
check flowing "and surfaces in NEXT"           '^1\. PR #42 is red$'

# STARVED: ready work, nobody live to take it.
fixture starved "[$READY]" "[$READY]" "$READY" ""
check starved "verdict says starved, not empty" '^🥵 STARVED$'
check starved "NEXT names the ready work"       '^1\. 1 ready bead$'
check starved "and routes to implement"         '^   → /ac-implement$'

# EMPTY: nothing open at all.
fixture empty '[]' '[]' '' ""
check empty "verdict says empty"               '^⏸ EMPTY$'
check empty "NEXT routes to planning"          '^   → /ac-align$'

# A failed read renders `?` and is named — never a guessed count.
fixture failed "[$READY]" "[$READY]" "$READY" "$LIVE"
put "$W/failed/reads" beads 1 ""; echo "br: database locked" >"$W/failed/reads/beads.err"
check failed "verdict is unknown"              '^\? verdict unknown'
check failed "the failing read is named"       '\? br_call list: br: database locked'
check failed "no verdict state is claimed"     'STALLED|FLOWING|STARVED|EMPTY' absent

# Compact is one verdict line per repo.
CASES=$((CASES + 1))
if [ "$(render stalled 1 | wc -l)" -eq 1 ]; then echo "ok   compact: one line"
else echo "FAIL compact: expected one line"; FAILURES=$((FAILURES + 1)); fi

# Every line fits a phone: 40 columns, never wrapped.
CASES=$((CASES + 1))
wide=$(for c in stalled flowing starved empty failed; do render "$c"; done |
       python3 -c 'import sys; print(max(len(l.rstrip("\n")) for l in sys.stdin))')
if [ "$wide" -le 40 ]; then echo "ok   width: widest line $wide"
else echo "FAIL width: widest line $wide > 40"; FAILURES=$((FAILURES + 1)); fi

echo "board.test.sh: $((CASES - FAILURES))/$CASES passed"
[ "$FAILURES" -eq 0 ]
