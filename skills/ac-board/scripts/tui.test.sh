#!/usr/bin/env bash
# tui.test.sh — proves tui.py's single frame builder against hand-built model.build() JSON
# fixtures (the same shape board.sh --json prints). No repo, no br, no network, no terminal.
set -uo pipefail

TUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tui.py"
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
FAILURES=0
CASES=0

# once <fixture-file> [extra tui.py args...] — one rendered frame
once() { local f="$1"; shift; python3 "$TUI" --once --width 40 "$@" <"$f"; }

check() {  # check <name> <description> <grep -E pattern> [absent] -- against $got
  CASES=$((CASES + 1))
  if { [ "${4:-}" = absent ] && ! grep -qE -- "$3" <<<"$got"; } ||
     { [ "${4:-}" != absent ] && grep -qE -- "$3" <<<"$got"; }; then
    echo "ok   $1: $2"
  else
    echo "FAIL $1: $2 — expected ${4:+no }/$3/ in:"; sed 's/^/     | /' <<<"$got"
    FAILURES=$((FAILURES + 1))
  fi
}

lineno() { grep -nF -- "$1" <<<"$got" | head -1 | cut -d: -f1; }  # first line carrying a literal needle

order() {  # order <name> <description> <needle1> <needle2> -- needle1 must precede needle2 in $got
  CASES=$((CASES + 1))
  local l1 l2; l1=$(lineno "$3"); l2=$(lineno "$4")
  if [ -n "$l1" ] && [ -n "$l2" ] && [ "$l1" -lt "$l2" ]; then echo "ok   $1: $2"
  else echo "FAIL $1: $2 — '$3' at line ${l1:-?}, '$4' at line ${l2:-?}"; FAILURES=$((FAILURES + 1)); fi
}

# ── fixture A: a full frame — width, emoji, and the general shape ───────────────────────
cat >"$W/full.json" <<'EOF'
{
  "name": "agent-compounds", "now": "2026-09-25T22:00:00+00:00",
  "verdict": {"state": "STUCK", "line": "⛔ STUCK — waiting on you", "reasons": ["2 gates"]},
  "moves": [
    {"rung": "gate", "gate_id": "ac-g1", "title": "ACTION: retire deploy-targets.list",
     "created_at": "2026-09-09T12:00:00+00:00", "gate_kind": "action", "blocks": 1,
     "subject": "ac-g1", "detail": "action · unblocks 1 bead", "route": "/ac-human"},
    {"rung": "refine-bead", "n_unrefined": 9, "subject": "refine 9 beads",
     "detail": "nothing is ready without them", "route": "/ac-polish bead"},
    {"rung": "beadify", "stage": "bead-ready", "verb": "beadify",
     "names": ["2026-09-25-0012-ship-stage"], "subject": "beadify 1 plan", "detail": "", "route": "/ac-beadify"},
    {"rung": "approve-plan", "stage": "draft", "verb": "approve", "names": ["lint-system-upgrade"],
     "subject": "approve 1 plan", "detail": "", "route": "/ac-human"},
    {"rung": "idle-gate", "gate_id": "ac-g2", "title": "DECISION: run /dream on the dockets",
     "created_at": "2026-09-16T12:00:00+00:00", "gate_kind": "decision", "blocks": 0,
     "subject": "ac-g2", "detail": "decision", "route": "/ac-human"},
    {"rung": "pool", "pool": 1, "subject": "promote 1 pool idea", "detail": "", "route": "/ac-align"}
  ],
  "epics": {"ok": true, "items": [
    {"id": "ac-e1", "title": "compounds-dir: factory floor for git worktrees",
     "priority": 1, "created_at": "2026-09-01T00:00:00Z", "closed_at": null,
     "done": 0, "total": 8, "holding": [], "unclaimed_stale": false},
    {"id": "ac-e2", "title": "Run branch", "priority": 2, "created_at": "2026-09-02T00:00:00Z",
     "closed_at": null, "done": 6, "total": 14, "holding": ["ChartreuseWolf"], "unclaimed_stale": false}
  ]},
  "closed7": [10, 2, 30, 30, 2, 2, 5],
  "most_recent_closed_epic": {"id": "ac-e9", "title": "One silver bullet per plan",
                               "closed_at": "2026-09-22T12:00:00Z"},
  "plans": [{"name": "a", "stage": "draft", "mtime": 0}, {"name": "b", "stage": "approved", "mtime": 0}],
  "pool": 1,
  "beads": {"total": 22, "n_in_progress": 1, "n_ready": 0, "n_gates": 2, "n_unrefined": 9,
            "n_blocked": 10, "n_deferred": 0, "n_other": 0, "stale": 0, "unclaimed": 0,
            "held_up": 1, "no_memo": 2, "blocked_by": {"gate": 1, "unrefined": 7, "work": 2},
            "blocked_refined": 3, "orphans": 6, "in_progress": [], "gates": []},
  "agents": [], "mail": "up", "split": null, "waves": 0,
  "prs": [], "ci": "none scheduled", "truth": 0,
  "docket": {"reason_less": 0, "gate_incomplete": 0, "plan_gap": 0},
  "triage": {"ok": true, "value": null}, "tidy": {"status": "missing", "streak": null},
  "failed": []
}
EOF
got=$(once "$W/full.json" --no-color)
CASES=$((CASES + 1))
wide=$(python3 -c 'import sys; print(max(len(l.rstrip(chr(10))) for l in sys.stdin))' <<<"$got")
if [ "$wide" -le 40 ]; then echo "ok   full: widest line $wide"
else echo "FAIL full: widest line $wide > 40"; FAILURES=$((FAILURES + 1)); fi
CASES=$((CASES + 1))
if python3 -c 'import sys; s=sys.stdin.read(); sys.exit(1 if any(ord(c) >= 0x1F000 for c in s) else 0)' <<<"$got"
then echo "ok   full: no emoji codepoints"
else echo "FAIL full: an emoji codepoint leaked"; FAILURES=$((FAILURES + 1)); fi

# ── ON YOU: order, route on every item, gate slug strips ACTION: ────────────────────────
order onyou "a blocking gate precedes refine"          "retire deploy-targets.list" "refine 9 beads"
order onyou "refine precedes the draft-approve"        "refine 9 beads" "approve lint-system-upgrade"
order onyou "the draft-approve precedes the idle gate" "approve lint-system-upgrade" "run /dream on the dockets"
check onyou "the gate slug strips ACTION:"            'ACTION:' absent
check onyou "the gate slug strips DECISION:"          'DECISION:' absent
check onyou "the plan date prefix is stripped"        '2026-09-25-0012-ship-stage' absent
check onyou "the blocking gate's route line is present" '  → /ac-human'
check onyou "the refine row's route is present"       '→ /ac-polish bead'
check onyou "the beadify row's route is present"      '→ /ac-beadify'
check onyou "the pool row is relabelled a proposal"   'draft 1 proposal'
check onyou "pool routes to align"                    '→ /ac-align'

# ── EPICS: next (no progress, no agent) → open (ascending progress) → most recently closed ─
order epics "the untouched epic (next) precedes the started one" "compounds-dir" "Run branch"
order epics "the started epic precedes the closed one"           "Run branch" "One silver bullet"
check epics "a live agent on a child shows a dot"      '● '

# ── colour: escapes only when asked ──────────────────────────────────────────────────────
CASES=$((CASES + 1))
if once "$W/full.json" | grep -q $'\033' && ! once "$W/full.json" --no-color | grep -q $'\033'
then echo "ok   colour: escapes only without --no-color"
else echo "FAIL colour: expected escapes with colour, none without"; FAILURES=$((FAILURES + 1)); fi

# ── PIPELINE bars: cells in a section sum to the bar width (10) ─────────────────────────
CASES=$((CASES + 1))
plan_cells=$(sed -n '/^plans/,/^beads/p' <<<"$got" | grep -oE '█' | wc -l)
if [ "$plan_cells" -eq 10 ]; then echo "ok   pipeline: plans bar cells sum to 10"
else echo "FAIL pipeline: plans bar cells summed to $plan_cells, not 10"; FAILURES=$((FAILURES + 1)); fi
CASES=$((CASES + 1))
bead_cells=$(sed -n '/^beads/,/^[^ ]/p' <<<"$got" | grep -oE '[█▒]' | wc -l)
if [ "$bead_cells" -eq 10 ]; then echo "ok   pipeline: beads bar cells sum to 10"
else echo "FAIL pipeline: beads bar cells summed to $bead_cells, not 10"; FAILURES=$((FAILURES + 1)); fi

# ── the blocked part of a beads row renders ▒ (no colour needed to see it) ──────────────
check blocked "a refined-but-blocked bead dims to ▒" '▒'

# ── a moved count shows +1, in-process memory chained across two --once calls ───────────
cat >"$W/counts1.json" <<'EOF'
{"name":"x","now":"2026-09-25T22:00:00+00:00","verdict":{"state":"EMPTY","line":"⏸ EMPTY — nothing planned","reasons":[]},
 "moves":[{"rung":"none","subject":"nothing needs you","detail":"","route":""}],
 "epics":{"ok":true,"items":[]},"closed7":null,"most_recent_closed_epic":null,
 "plans":[],"pool":0,
 "beads":{"total":0,"n_in_progress":0,"n_ready":0,"n_gates":0,"n_unrefined":10,"n_blocked":0,
          "n_deferred":0,"n_other":0,"stale":0,"unclaimed":0,"held_up":0,"no_memo":0,
          "blocked_by":{"gate":0,"unrefined":0,"work":0},"blocked_refined":0,"orphans":0,
          "in_progress":[],"gates":[]},
 "agents":[],"mail":"up","split":null,"waves":0,"prs":[],"ci":"none scheduled","truth":0,
 "docket":{"reason_less":0,"gate_incomplete":0,"plan_gap":0},
 "triage":{"ok":true,"value":null},"tidy":{"status":"missing","streak":null},"failed":[]}
EOF
python3 -c "import json; d=json.load(open('$W/counts1.json')); d['beads']['n_unrefined']=11; json.dump(d, open('$W/counts2.json','w'))"
once "$W/counts1.json" --no-color --save-counts "$W/state.json" >/dev/null
got=$(once "$W/counts2.json" --no-color --prev "$W/state.json")
check delta "a count that moved shows +1"  '\+1'

echo "tui.test.sh: $((CASES - FAILURES))/$CASES passed"
[ "$FAILURES" -eq 0 ]
