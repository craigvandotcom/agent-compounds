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

# STUCK on you: a gate, the bead it blocks, an unrefined bead — nothing ready.
fixture stalled "[$GATE,$UNREF,$BLOCKED]" "[$GATE,$UNREF]" "$GATE
$UNREF
$BLOCKED" "$LIVE"
check stalled "verdict line under the header"  '^⛔ STUCK — waiting on you$'
check stalled "human-gate row counts what it blocks" '^   human-gate +1 ▓+░* block 1$'
check stalled "gate kinds and age beneath"     '^     0 decisions · 1 action · oldest 2d$'
check stalled "a bar is its share of the section" '^   unrefined +1 ▓▓▓░{7}$'
check stalled "blocked splits by its blocker"  '^     by gate 1$'
check stalled "no bead is itemized"            'ac-b1|waits on the gate' absent
check stalled "the jam is marked"              '▲ nothing refined'
check stalled "NEXT leads with the gate"       '^1\. ac-g1$'
check stalled "its detail and route stack"     '^   action · unblocks 1 bead$'
check stalled "then the refinement jam"        '^2\. refine 1 bead$'
check stalled "a live agent with no bead"      '^   agents +1 live · 0 working$'
check stalled "no change marks outside watch"  '[+-][0-9]+$' absent

# RUNNING: a ready bead and one held by a live agent.
fixture flowing "[$READY,$HELD]" "[$READY]" "$READY
$HELD" "$LIVE"
check flowing "verdict says it runs"           '^✅ RUNNING — agents are building$'
check flowing "agents count the held bead"     '^   agents +1 live · 1 working$'
check flowing "no ready title leaks"           'a refined bead' absent
check flowing "only non-zero checks show"      '^   checks +⚠ no epic 2$'
put "$W/flowing/reads" truth 0 "board-truth: 3 cited-but-open"
check flowing "each non-zero check is named"   '^   checks +⚠ board-truth 3$'
check flowing "no jam when work is ready"      '▲' absent
check flowing "NEXT has nothing for you"       '^1\. nothing needs you$'
put "$W/flowing/reads" prs 0 '[{"number":42,"statusCheckRollup":[{"conclusion":"FAILURE","name":"build"}]}]'
check flowing "a failing PR check is counted"  '^   PRs +1 open · 1 red$'
check flowing "and surfaces in NEXT"           '^1\. PR #42 is red$'

# IDLE: ready work, nobody holding it — whether or not an agent is live.
fixture starved "[$READY]" "[$READY]" "$READY" ""
check starved "verdict says idle, not empty"   '^🥵 IDLE — work waiting, no agent on it$'
check starved "NEXT names the ready work"      '^1\. 1 ready bead$'
check starved "and routes to implement"        '^   → /ac-implement$'
fixture idlelive "[$READY]" "[$READY]" "$READY" "$LIVE"
check idlelive "a live agent holding nothing is idle" '^🥵 IDLE'

# EMPTY: nothing open at all.
fixture empty '[]' '[]' '' ""
check empty "verdict says empty"               '^⏸ EMPTY — nothing planned$'
check empty "NEXT routes to planning"          '^   → /ac-align$'
check empty "checks all clear on zeros"        '^   checks +✓ all clear$'
check empty "no plans renders none"            '^📋 PLANS · none$'

# PLANS: each stage a row, the backlog pool counted, an unknown status named.
fixture plans '[]' '[]' '' ""
mkdir -p "$W/plans/repo/_plans" "$W/plans/repo/_backlog/pool"
printf -- '---\nstatus: approved\n---\n' >"$W/plans/repo/_plans/a.md"
printf -- '---\nstatus: findings\n---\n' >"$W/plans/repo/_plans/b.md"
: >"$W/plans/repo/_backlog/pool/001-idea.md"
check plans "live counts plans and pool"       '^📋 PLANS · 3 live$'
check plans "bead-ready shows at zero"         '^   bead-ready +0 ░{10}$'
check plans "approved is a row"                '^   approved +1 ▓▓▓░{7}$'
check plans "the pool is a row"                '^   pool +1 ▓'
check plans "an unknown status is named"       '^   other +1 ▓+░* findings$'

# The pull order: NEXT ranks by distance from implement (pull_order.LADDER).
fixture ladder "[$READY,$HELD,$GATE,$BLOCKED]" "[$READY,$GATE]" "$READY
$HELD
$GATE
$BLOCKED" ""
check ladder "an unheld bead is reclaimed first" '^1\. reclaim 1 unclaimed bead$'
check ladder "then the ready work"             '^2\. 1 ready bead$'
check ladder "then the gate that frees beads"  '^3\. ac-g1$'
fixture planorder '[]' '[]' '' ""
mkdir -p "$W/planorder/repo/_plans"
printf -- '---\nstatus: draft\n---\n' >"$W/planorder/repo/_plans/d.md"
printf -- '---\nstatus: approved\n---\n' >"$W/planorder/repo/_plans/a.md"
printf -- '---\nstatus: approved\npolish_rounds: 2\npolish_fixpoint_sha256: x\n---\n' >"$W/planorder/repo/_plans/p.md"
printf -- '---\nstatus: refined\n---\n' >"$W/planorder/repo/_plans/r.md"
check planorder "a refused plan needs a ruling"  '^1\. rule on 1 plan$'
check planorder "a polished plan is marked ready" '^2\. mark ready 1 plan$'
check planorder "an unpolished plan is polished" '^3\. polish 1 plan$'
check planorder "the refusal is flagged in PLANS" '^   refined +1 ▓+░* needs you$'
rm "$W/planorder/repo/_plans/r.md" "$W/planorder/repo/_plans/p.md"
check planorder "a draft waits on approval"    '^2\. approve 1 plan$'

# A failed read renders `?` and is named — never a guessed count.
fixture failed "[$READY]" "[$READY]" "$READY" "$LIVE"
put "$W/failed/reads" beads 1 ""; echo "br: database locked" >"$W/failed/reads/beads.err"
check failed "verdict is unknown"              '^\? unknown — the bead reads failed$'
check failed "the failing read is named"       '\? br_call list: br: database locked'
check failed "no verdict state is claimed"     'RUNNING|IDLE|STUCK|EMPTY' absent

# Watch-only features (a moved count's delta, ANSI colour) moved to tui.py — see tui.test.sh.
# render.py stays plain text always: no escapes leak in.
CASES=$((CASES + 1))
if ! render stalled | grep -q $'\033'; then echo "ok   render.py never emits ANSI escapes"
else echo "FAIL render.py: unexpected escape in plain output"; FAILURES=$((FAILURES + 1)); fi

# Compact is one verdict line per repo.
CASES=$((CASES + 1))
if [ "$(render stalled 1 | wc -l)" -eq 1 ]; then echo "ok   compact: one line"
else echo "FAIL compact: expected one line"; FAILURES=$((FAILURES + 1)); fi

# Every line fits a phone: 40 columns, never wrapped.
CASES=$((CASES + 1))
wide=$(for c in stalled flowing starved empty plans ladder planorder failed; do render "$c"; render "$c" 1; done |
       python3 -c 'import sys; print(max(len(l.rstrip("\n")) for l in sys.stdin))')
if [ "$wide" -le 40 ]; then echo "ok   width: widest line $wide"
else echo "FAIL width: widest line $wide > 40"; FAILURES=$((FAILURES + 1)); fi

echo "board.test.sh: $((CASES - FAILURES))/$CASES passed"
[ "$FAILURES" -eq 0 ]
