#!/usr/bin/env bash
# tui.test.sh — proves tui.py's single frame builder against hand-built model.build() JSON
# fixtures (the same shape board.sh --json prints). No repo, no br, no network, no terminal.
set -uo pipefail

TUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tui.py"
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
FAILURES=0
CASES=0

# once <fixture-file> [extra tui.py args...] — one rendered frame at width 40
once() { local f="$1"; shift; python3 "$TUI" --once --width 40 "$@" <"$f"; }
# once_w <fixture-file> <width> [extra tui.py args...] — one rendered frame at a given width
once_w() { local f="$1" w="$2"; shift 2; python3 "$TUI" --once --width "$w" "$@" <"$f"; }

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
    {"rung": "polish-plan", "stage": "approved", "verb": "polish",
     "names": ["lint-system-upgrade", "one-verdict-contract"], "subject": "polish 2 plans",
     "detail": "", "route": "/ac-polish plan"},
    {"rung": "approve-plan", "stage": "draft", "verb": "approve", "names": ["memory-stewardship-research"],
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
  "plans": [
    {"name": "2026-09-25-0012-ship-stage", "stage": "bead-ready", "mtime": 1788991200},
    {"name": "lint-system-upgrade", "stage": "approved", "mtime": 1789596000},
    {"name": "one-verdict-contract", "stage": "approved", "mtime": 1790200800},
    {"name": "memory-stewardship-research", "stage": "draft", "mtime": 1789941600}
  ],
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

# ── ON YOU: one line per move — glyph, the command to type, what it acts on, the badge ──
order onyou "a blocking gate precedes refine"          "retire deploy" "/ac-polish bead 9 beads"
order onyou "refine precedes the draft-approve"        "/ac-polish bead 9 beads" "memory-stewardship"
order onyou "the draft-approve precedes the idle gate" "memory-stewardship" "run /dream"
check onyou "the gate slug strips ACTION:"            'ACTION:' absent
check onyou "the gate slug strips DECISION:"          'DECISION:' absent
check onyou "the plan date prefix is stripped"        '2026-09-25-0012-ship-stage' absent
check onyou "command first on a gate, no route line"  '^▲ /ac-human retire deploy.* +⊘1 +[0-9]+d$'
check onyou "no separate route lines remain"          '→' absent
check onyou "command first on refine"                 '^~ /ac-polish bead 9 beads$'
check onyou "command first on beadify"                '^» /ac-beadify ship-stage +[0-9]+[mhd]$'
check onyou "the pool row counts proposals"           '^\+ /ac-align 1 proposal$'
check onyou "each plan in a grouped move gets its own row" '^» /ac-polish plan lint-system'
check onyou "the second plan too"                     '^» /ac-polish plan one-verdict'

# ── a gate names the epic it serves; gates serving one epic merge into one row ─────────
sed 's|"subject": "ac-g1"|"epic": "Ship stage: one gate per release", "subject": "ac-g1"|; s|"subject": "ac-g2"|"epic": "Ship stage: one gate per release", "subject": "ac-g2"|' \
  "$W/full.json" >"$W/epic.json"
got=$(once "$W/epic.json" --no-color)
check epicgate "the gate shows its epic slug, merged ×2, blocks summed" '^▲ /ac-human Ship stage ×2 +⊘1 +[0-9]+d$'
check epicgate "the merged gate's own title is gone"  'retire deploy-targets|run /dream' absent
got=$(once "$W/full.json" --no-color)

# ── EPICS: next (no progress, no agent) → open (ascending progress) → most recently closed ─
order epics "the untouched epic (next) precedes the started one" "compounds-dir" "Run branch"
order epics "the started epic precedes the closed one"           "Run branch" "One silver bullet"
check epics "a live agent on a child shows a dot"      '● '

# ── colour: escapes only when asked ──────────────────────────────────────────────────────
CASES=$((CASES + 1))
if once "$W/full.json" | grep -q $'\033' && ! once "$W/full.json" --no-color | grep -q $'\033'
then echo "ok   colour: escapes only without --no-color"
else echo "FAIL colour: expected escapes with colour, none without"; FAILURES=$((FAILURES + 1)); fi

# ── fix 1: PIPELINE rows are `label  count bar` — no ░ track, a solid touching silhouette.
# The bar's width is W minus the label/count/delta-room, not a fixed 10 — cells in a section
# still sum exactly to it. Every count here is 1 or 2 digits, so count_w floors at 2, and the
# same formula (w - 1 label(11) - count(2) - 1 - 4 delta-room = w - 19) holds at both widths.
check pipeline "no ░ track glyph anywhere in the bars"  '░' absent
for W40 in 40 56; do
  barw=$((W40 - 19))
  g=$(once_w "$W/full.json" "$W40" --no-color)
  plan_cells=$(sed -n '/^plans/,/^beads/p' <<<"$g" | grep -oE '█' | wc -l)
  CASES=$((CASES + 1))
  if [ "$plan_cells" -eq "$barw" ]; then echo "ok   pipeline@$W40: plans bar cells sum to $barw"
  else echo "FAIL pipeline@$W40: plans bar cells summed to $plan_cells, not $barw"; FAILURES=$((FAILURES + 1)); fi
  bead_cells=$(sed -n '/^beads/,/^$/p' <<<"$g" | grep -oE '[█▒]' | wc -l)
  CASES=$((CASES + 1))
  if [ "$bead_cells" -eq "$barw" ]; then echo "ok   pipeline@$W40: beads bar cells sum to $barw"
  else echo "FAIL pipeline@$W40: beads bar cells summed to $bead_cells, not $barw"; FAILURES=$((FAILURES + 1)); fi
  CASES=$((CASES + 1))
  if grep -qE '^ proposals *[0-9]+ █' <<<"$g"; then echo "ok   pipeline@$W40: label, right-aligned count, then bar"
  else echo "FAIL pipeline@$W40: expected 'label  count bar' shape"; FAILURES=$((FAILURES + 1)); fi
done

# ── the blocked part of a beads row renders ▒ (no colour needed to see it) ──────────────
check blocked "a refined-but-blocked bead dims to ▒" '▒'

# ── fix 2: EPICS titles are slugged at the first `:`/` — `, columns aligned ─────────────
check epics "the colon-split title is slugged"        'compounds-dir  '
check epics "the em-dash-split title is slugged"       'Run branch  '
check epics "the full title text is gone (only the slug shows)" 'factory floor for git worktrees' absent
CASES=$((CASES + 1))
bar_cols=$(grep -E '^[○▶] ' <<<"$got" | python3 -c '
import sys
cols = set()
for l in sys.stdin:
    l = l.rstrip("\n")
    idx = next((i for i, ch in enumerate(l) if ch in "█─"), None)
    if idx is not None: cols.add(idx)
print(len(cols))')
if [ "$bar_cols" = 1 ]; then echo "ok   epics: the bar starts at the same column on every row"
else echo "FAIL epics: bars start at $bar_cols different columns"; FAILURES=$((FAILURES + 1)); fi

# ── fix 3: CI "none scheduled" is not a warning; only a failing/unknown CI read is ───────
check health "none-scheduled CI shows no warning"      '⚠ CI' absent
check health "none-scheduled CI shows plainly"         'CI —'
check health "no split line when split is null"        'agents on another mailbox key' absent
python3 -c "import json; d=json.load(open('$W/full.json')); d['ci']='ci-gates: 1 failing ✗'; d['split']='7'; json.dump(d, open('$W/ci_bad.json','w'))"
got=$(once "$W/ci_bad.json" --no-color)
check health "a failing CI read warns"                 '⚠ CI'
check health "a real mailbox split still warns"         '7 agents on another mailbox key'

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

# ── fix 6: --height trims footer, then HEALTH detail, then caps ON YOU further ──────────
python3 - "$W/tall.json" <<'EOF'
import json, sys
moves = [{"rung": "idle-gate", "gate_id": f"ac-g{i}", "title": f"DECISION: review item {i}",
          "created_at": "2026-09-01T00:00:00Z", "gate_kind": "decision", "blocks": 0,
          "subject": f"ac-g{i}", "detail": "decision", "route": "/ac-human"} for i in range(10)]
d = {"name": "tall-repo", "now": "2026-09-25T22:00:00+00:00",
     "verdict": {"state": "STUCK", "line": "⛔ STUCK — waiting on you", "reasons": []},
     "moves": moves, "epics": {"ok": True, "items": []}, "closed7": None,
     "most_recent_closed_epic": None, "plans": [], "pool": 0, "beads": None,
     "agents": [], "mail": "up", "split": None, "waves": 0, "prs": [], "ci": "none scheduled",
     "truth": 0, "docket": {"reason_less": 0, "gate_incomplete": 0, "plan_gap": 0},
     "triage": {"ok": True, "value": None}, "tidy": {"status": "missing", "streak": None},
     "failed": ["some read: boom"]}
json.dump(d, open(sys.argv[1], "w"))
EOF
base=$(once "$W/tall.json" --no-color --footer "ac bca usa")
base_n=$(wc -l <<<"$base")
CASES=$((CASES + 1))
if grep -qF '+ 2 more' <<<"$base"; then echo "ok   height: the default 8-cap shows +2 more (untrimmed)"
else echo "FAIL height: expected '+ 2 more' untrimmed in:"; sed 's/^/     | /' <<<"$base"; FAILURES=$((FAILURES + 1)); fi

got=$(once "$W/tall.json" --no-color --footer "ac bca usa" --height $((base_n - 1)))
check height "a slightly short pane drops the footer first" 'ac bca usa' absent
check height "…but keeps the HEALTH detail line"             '\? some read: boom'
check height "…and the ON YOU cap is untouched"               '\+ 2 more'

foot_lines=2  # a blank separator + the footer text itself
got=$(once "$W/tall.json" --no-color --footer "ac bca usa" --height $((base_n - foot_lines - 1)))
check height "a shorter pane also drops the HEALTH detail"    '\? some read: boom' absent
check height "…footer stays dropped too"                      'ac bca usa' absent
check height "…the ON YOU cap is still untouched"              '\+ 2 more'

# 17 is this fixture's true floor once footer + HEALTH detail are gone and ON YOU is capped to
# 0 (EPICS/PIPELINE/the HEALTH head line are never trimmed) — proven separately below with
# --height 1; ask for exactly that floor to prove the cap gets pushed all the way down.
got=$(once "$W/tall.json" --no-color --footer "ac bca usa" --height 17)
CASES=$((CASES + 1))
n_more=$(grep -oE '\+ [0-9]+ more' <<<"$got" | grep -oE '[0-9]+')
if [ -n "$n_more" ] && [ "$n_more" -gt 2 ]; then echo "ok   height: a very short pane caps ON YOU further (+$n_more)"
else echo "FAIL height: expected ON YOU capped below 8 (+n more, n>2) in:"; sed 's/^/     | /' <<<"$got"; FAILURES=$((FAILURES + 1)); fi
check height "footer stays dropped at the smallest height"    'ac bca usa' absent
check height "HEALTH detail stays dropped at the smallest height" '\? some read: boom' absent
CASES=$((CASES + 1))
got_n=$(wc -l <<<"$got")
if [ "$got_n" -le 17 ]; then echo "ok   height: the frame fits inside --height 17 ($got_n lines)"
else echo "FAIL height: frame is $got_n lines, wider than --height 17"; FAILURES=$((FAILURES + 1)); fi

# --height 1 (impossible) proves the floor: ON YOU caps all the way to 0, "+ 10 more".
CASES=$((CASES + 1))
got=$(once "$W/tall.json" --no-color --footer "ac bca usa" --height 1)
if grep -qE '\+ 10 more' <<<"$got"; then echo "ok   height: an impossible height caps ON YOU to 0 items"
else echo "FAIL height: expected '+ 10 more' (cap 0) in:"; sed 's/^/     | /' <<<"$got"; FAILURES=$((FAILURES + 1)); fi

echo "tui.test.sh: $((CASES - FAILURES))/$CASES passed"
[ "$FAILURES" -eq 0 ]
