#!/usr/bin/env bash
# tui.test.sh — proves tui.py's single frame builder against hand-built model.build() JSON
# fixtures (the same shape board.sh --json prints). No repo, no br, no network, no terminal.
set -uo pipefail

TUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tui.py"
DIR="$(dirname "$TUI")"
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
FAILURES=0
CASES=0

# once <fixture-file> [extra tui.py args...] — one rendered frame at width 48 (narrow: stacked)
once() { local f="$1"; shift; python3 "$TUI" --once --width 48 "$@" <"$f"; }
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

vis() {  # vis <string> — the widest line's VISIBLE width (escapes stripped)
  python3 -c '
import re, sys
w = 0
for l in sys.stdin.read().splitlines():
    w = max(w, len(re.sub(r"\033\[[0-9;]*[a-zA-Z]", "", l)))
print(w)' <<<"$1"
}

fits() {  # fits <name> <width> — every line of $got is at most <width> visible columns
  CASES=$((CASES + 1))
  local m; m=$(vis "$got")
  if [ "$m" -le "$2" ]; then echo "ok   $1: widest line $m <= $2"
  else echo "FAIL $1: widest line $m > $2"; FAILURES=$((FAILURES + 1)); fi
}

noemoji() {  # noemoji <name> — no codepoint at or above U+1F000 anywhere in $got
  CASES=$((CASES + 1))
  if python3 -c 'import sys; s=sys.stdin.read(); sys.exit(1 if any(ord(c) >= 0x1F000 for c in s) else 0)' <<<"$got"
  then echo "ok   $1: no emoji codepoints"
  else echo "FAIL $1: an emoji codepoint leaked"; FAILURES=$((FAILURES + 1)); fi
}

esc() { printf '\033\\[%s' "$1"; }   # the grep -E prefix of an escape sequence

cells() {  # cells <line> <glyph> — how many times <glyph> occurs in <line>
  python3 -c 'import sys; print(sys.argv[1].count(sys.argv[2]))' "$1" "$2"
}

row() { grep -E -- "^│  $1 " <<<"$got" | head -1; }   # a PLANS/BEADS row by its stage label

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
  "agents": [{"name": "ChartreuseWolf", "program": "claude", "model": "claude-opus-4-6",
              "last_active": "2026-09-25T21:50:00Z", "live": true, "holds": "bd-9x"},
             {"name": "FoggyCreek", "program": "claude", "model": "claude-sonnet-4-6",
              "last_active": "2026-09-25T21:58:00Z", "live": true, "holds": null}],
  "mail": "up", "split": null, "waves": 3,
  "prs": [], "ci": "none scheduled", "truth": 0,
  "docket": {"reason_less": 0, "gate_incomplete": 0, "plan_gap": 0},
  "triage": {"ok": true, "value": null}, "tidy": {"status": "ok", "streak": 6}, "failed": []
}
EOF

# ── width, emoji, and the framed-card silhouette ────────────────────────────────────────
got=$(once "$W/full.json" --no-color)
fits "narrow" 48
noemoji "narrow"

got=$(once_w "$W/full.json" 96 --no-color)
fits "wide" 96
noemoji "wide"

got=$(once "$W/full.json" --no-color)
check card "the ON YOU card is double-framed with a tee-bracket header" '^╔═╡ ON YOU ╞═+╡ 8 ╞═+╗'
check card "its rows are ║-bounded"          '^║ .+ ║$'
check card "its bottom corners close"        '^╚═+╝$'
check card "EPICS is a single-framed card"   '┌─┤ EPICS ├─'
check card "PLANS is a single-framed card"   '^┌─┤ PLANS ├─'
check card "BEADS is a single-framed card"   '┌─┤ BEADS ├─'
check card "AGENTS & HEALTH is a card"       '^┌─┤ AGENTS & HEALTH ├─'
check card "a single card's rows are │-bounded" '^│ .+ │$'
check card "a single card's corners close"   '^└─+┘$'
check card "the old flat heading is gone"    '^PIPELINE$' absent

# ── the grid: narrow stacks, wide pairs ON YOU · EPICS and PLANS · BEADS ────────────────
CASES=$((CASES + 1))
if grep -E '^╔═╡ ON YOU ╞' <<<"$got" | grep -q 'EPICS' || grep -E '^┌─┤ PLANS ├' <<<"$got" | grep -q 'BEADS'
then echo "FAIL stack: a card at width 48 shares its row with another"; FAILURES=$((FAILURES + 1))
else echo "ok   stack: no 2-column grid at width 48"; fi
CASES=$((CASES + 1))
if [ "$(vis "$(grep -E '^┌─┤ PLANS ├' <<<"$got" | head -1)")" = 48 ]
then echo "ok   stack: a stacked card fills all 48 columns"
else echo "FAIL stack: the PLANS header is $(vis "$(grep -E '^┌─┤ PLANS ├' <<<"$got" | head -1)") wide, not 48"
     FAILURES=$((FAILURES + 1)); fi
order stack "ON YOU is above EPICS"    "ON YOU" "EPICS"
order stack "EPICS is above PLANS"     "EPICS"  "PLANS"
order stack "PLANS is above BEADS"     "PLANS"  "BEADS"
order stack "BEADS is above AGENTS & HEALTH" "BEADS" "AGENTS & HEALTH"

got=$(once_w "$W/full.json" 96 --no-color)
check grid "ON YOU and EPICS share row 1" '^╔═╡ ON YOU ╞.+┌─┤ EPICS ├'
check grid "PLANS and BEADS share row 2"  '^┌─┤ PLANS ├.+┌─┤ BEADS ├'
CASES=$((CASES + 1))
h=$(grep -F 'AGENTS & HEALTH' <<<"$got" | head -1)
if [ "$(vis "$h")" = 96 ]; then echo "ok   grid: AGENTS & HEALTH spans the full 96 columns"
else echo "FAIL grid: AGENTS & HEALTH header is $(vis "$h") wide, not 96"; FAILURES=$((FAILURES + 1)); fi
l1=$(grep -nF 'ON YOU' <<<"$got" | head -1 | cut -d: -f1); l2=$(grep -nF 'AGENTS & HEALTH' <<<"$got" | head -1 | cut -d: -f1)
CASES=$((CASES + 1))
if [ "$l1" -lt "$l2" ]; then echo "ok   grid: the 2x2 grid sits above AGENTS & HEALTH"
else echo "FAIL grid: AGENTS & HEALTH at $l2 is not below the grid at $l1"; FAILURES=$((FAILURES + 1)); fi
CASES=$((CASES + 1))
if [ "$(vis "$(sed -n "${l1}p" <<<"$got")")" = 96 ] && [ "$(vis "$(sed -n "$((l1 + 1))p" <<<"$got")")" = 96 ]
then echo "ok   grid: a joined grid row is exactly 96 columns"
else echo "FAIL grid: a grid row is $(vis "$(sed -n "${l1}p" <<<"$got")") wide, not 96"; FAILURES=$((FAILURES + 1)); fi

# ── the stage ribbon: the bottleneck stage wears the reverse-video pill ─────────────────
got=$(once "$W/full.json" --no-color)
check step "the ribbon names the five stages" 'plan 3 · bead-ready 1'
check step "building>0 makes building the bottleneck" '\[ ▶ building 1 \]'
check step "the bottleneck is the only bracketed stage" '\].*\[ ▶' absent
python3 -c "import json; d=json.load(open('$W/full.json')); d['beads']['n_in_progress']=0; d['beads']['n_ready']=2; json.dump(d, open('$W/step1.json','w'))"
got=$(once "$W/step1.json" --no-color)
check step "ready>0 outranks bead-ready" '\[ ▶ ready 2 \]'
python3 -c "import json; d=json.load(open('$W/step1.json')); d['beads']['n_ready']=0; json.dump(d, open('$W/step2.json','w'))"
got=$(once "$W/step2.json" --no-color)
check step "bead-ready>0 outranks the rest" '\[ ▶ bead-ready 1 \]'
python3 -c "import json; d=json.load(open('$W/step2.json')); d['plans']=[]; json.dump(d, open('$W/step3.json','w'))"
got=$(once "$W/step3.json" --no-color)
check step "with the flow empty, the pool takes the pill" '\[ ▶ pool 1 \]'

# ── ON YOU: one row per move — glyph, the command to type, what it acts on, the badge ──
got=$(once "$W/full.json" --no-color)
order onyou "a blocking gate precedes refine"          "retire deploy" "/ac-polish bead 9 beads"
order onyou "refine precedes the draft-approve"        "/ac-polish bead 9 beads" "memory-stewardship"
order onyou "the draft-approve precedes the idle gate" "memory-stewardship" "run /dream"
check onyou "the gate slug strips ACTION:"            'ACTION:' absent
check onyou "the gate slug strips DECISION:"          'DECISION:' absent
check onyou "the plan date prefix is stripped"        '2026-09-25-0012-ship-stage' absent
check onyou "command first on a gate, no route line"  '^║ ▲ /ac-human retire deploy.* +⊘1 +[0-9]+d +║$'
check onyou "no separate route lines remain"          '→' absent
check onyou "command first on refine"                 '^║ ~ /ac-polish bead 9 beads +║$'
check onyou "command first on beadify"                '^║ » /ac-beadify ship-stage +[0-9]+[mhd] +║$'
check onyou "the pool row counts proposals"           '^║ \+ /ac-align 1 proposal +║$'
check onyou "each plan in a grouped move gets its own row" '^║ » /ac-polish plan lint-system'
check onyou "the second plan too"                     '^║ » /ac-polish plan one-verdict'
check onyou "a decision gate wears ◆"                 '◆ /ac-human run /dream'
check onyou "the ≥8-move fixture is a double card"    '╔═╡ ON YOU ╞'

# a clear board is a calm single-line card, not a shouting double one
python3 -c "import json; d=json.load(open('$W/full.json')); d['moves']=[{'rung':'none','subject':'nothing needs you','detail':'','route':''}]; json.dump(d, open('$W/clear.json','w'))"
got=$(once "$W/clear.json" --no-color)
check onyou "a clear board says so"                   '✓ clear'
check onyou "…inside a single-line ON YOU card"       '^┌─┤ ON YOU ├'
check onyou "…and not the double focal card"          '╔═╡ ON YOU' absent

# ── a gate names the epic it serves; gates serving one epic merge into one row ─────────
sed 's|"subject": "ac-g1"|"epic": "Ship stage: one gate per release", "subject": "ac-g1"|; s|"subject": "ac-g2"|"epic": "Ship stage: one gate per release", "subject": "ac-g2"|' \
  "$W/full.json" >"$W/epic.json"
got=$(once "$W/epic.json" --no-color)
check epicgate "the gate shows its epic slug, merged ×2, blocks summed" '^║ ▲ /ac-human Ship stage ×2 +⊘1 +[0-9]+d +║$'
check epicgate "the merged gate's own title is gone"  'retire deploy-targets|run /dream' absent

# ── EPICS: next (○) → open (▶) → most recently closed (✓), columns aligned ─────────────
got=$(once "$W/full.json" --no-color)
order epics "the untouched epic (next) precedes the started one" "○ compounds-dir" "▶ Run branch"
order epics "the started epic precedes the closed one"           "▶ Run branch" "✓ One silver bullet"
check epics "the colon-split title is slugged"        '○ compounds-dir '
check epics "the em-dash-split title is slugged"      '▶ Run branch '
check epics "the full title text is gone (only the slug shows)" 'factory floor for git worktrees' absent
check epics "a live agent on a child shows a dot"     '^│ ▶ Run branch +● +'
check epics "a stale unclaimed child would show ⚠"    '⚠' absent
check epics "the closed row carries its age"          '✓ One silver bullet per plan +[0-9]+d'
check epics "the header badge carries done/total"     '^┌─┤ EPICS ├─+┤ 6/22 '
check epics "…and the 7-day sparkline"                '┤ 6/22 +[▁▂▃▄▅▆▇█]{7} [0-9]+/7d ├─┐$'
CASES=$((CASES + 1))
bar_cols=$(grep -E '^│ [○▶] ' <<<"$got" | python3 -c '
import sys
cols = set()
for l in sys.stdin:
    l = l.rstrip("\n")
    idx = next((i for i, ch in enumerate(l) if ch in "█─"), None)
    if idx is not None: cols.add(idx)
print(len(cols))')
if [ "$bar_cols" = 1 ]; then echo "ok   epics: the 6-cell bar starts at the same column on every row"
else echo "FAIL epics: bars start at $bar_cols different columns"; FAILURES=$((FAILURES + 1)); fi

# a narrow card has no room for the badge in its header — it becomes the first body row
got=$(once_w "$W/full.json" 36 --no-color)
check epics "at 36 columns the badge moves into the card body" '^│ 6/22 +[▁▂▃▄▅▆▇█]{7} [0-9]+/7d'
fits "epics" 36

# ── PLANS and BEADS: a tracked gauge — █ share · ▒ blocked · · unfilled track ──────────
got=$(once "$W/full.json" --no-color)
check gauge "no ░ anywhere (that is the inline board's glyph)" '░' absent
check gauge "no ▓ either"                                      '▓' absent
check gauge "the unfilled track is a dot leader"               '█████·········'
check gauge "proposals is a 1-in-5 share of 25 cells"          'proposals +1 █{5}·{20} '
check gauge "approved is a 2-in-5 share"                       'approved +2 █{10}·{15} '
check gauge "a refined-but-blocked bead dims to ▒"             '▒+'
check gauge "the refined row is blocked in full"               'refined +3 ▒{4}·{21} '
check gauge "building stays bright green, unblocked"           'building +1 █·{24} '
check gauge "the beads badge counts the section"               '^┌─┤ BEADS ├─+┤ 20 open ├─┐'
check gauge "the plans badge counts the section"               '^┌─┤ PLANS ├─+┤ 5 live ├─┐'
CASES=$((CASES + 1))
bad=0
for label in proposals draft approved bead-ready unrefined refined building; do
  l=$(row "$label")
  [ -n "$l" ] || { bad=$((bad + 1)); continue; }
  n=$(( $(cells "$l" '█') + $(cells "$l" '▒') + $(cells "$l" '·') ))
  [ "$n" = 25 ] || bad=$((bad + 1))
done
if [ "$bad" = 0 ]; then echo "ok   gauge: every row's █+▒+· fills the same 25 cells"
else echo "FAIL gauge: $bad row(s) do not fill 25 cells"; FAILURES=$((FAILURES + 1)); fi

# ── AGENTS & HEALTH: live agents, then the summary, then what is wrong ──────────────────
check health "a live agent shows as ● name holds model" '^│ ● ChartreuseWolf +bd-9x +claude-opus-4-6'
check health "a live agent holding nothing reads idle"  '^│ ● FoggyCreek +idle +claude-sonnet-4-6'
check health "the agent summary counts live and working" 'agents: 2 live · 1 working'
check health "the wave count rides along"                'waves: 3'
check health "the tidy streak reads n/7"                 'tidy: 6/7 agree'
check health "none-scheduled CI shows no warning"        '⚠ CI' absent
check health "none-scheduled CI shows plainly"           'CI —'
check health "the PR count is labelled"                  'PRs: 0 open'
check health "a clean checks column is a ✓"              'checks ✓'
check health "no split line when split is null"          'agents on another mailbox key' absent

python3 -c "import json; d=json.load(open('$W/full.json')); d['ci']='ci-gates: 1 failing ✗'; d['split']='7'; d['tidy']={'status':'ok','streak':7}; d['prs']=[{'number':12,'ci':'CI ✗ 1 failing: build'},{'number':9,'ci':'CI ✓'}]; d['truth']=1; json.dump(d, open('$W/ci_bad.json','w'))"
got=$(once "$W/ci_bad.json" --no-color)
check health "a failing CI read warns"                   '⚠ CI'
check health "a red PR is named"                         '⚠ PR #12 red'
check health "a real mailbox split still warns"          '⚠ 7 agents on another mailbox key'
check health "a non-zero docket check warns"             '⚠ board-truth 1'
check health "seven agreeing tidy runs are ready to apply" 'tidy: ready to apply'
check health "the PR count follows the red PR"           'PRs: 2 open'

# ── the footer: sibling repos as `name [state]` pills, never past the width ────────────
got=$(python3 -c "
import sys; sys.path.insert(0, '$DIR')
import tui
it = [('/x/north-ridge-app','IDLE'), ('/x/second-site-app','IDLE'), ('/x/gamma-app','EMPTY'),
      ('/x/four-lane-app','IDLE'), ('/x/epsilon-app','EMPTY')]
print(tui.footer_pills(it, 120, False))")
check footer "the long names are used while they fit" 'north-ridge \[idle\]  second-site \[idle\]'
check footer "a -app suffix is dropped, the state is lowercase" 'gamma \[empty\]'
CASES=$((CASES + 1))
if [ "$(vis "$got")" -le 120 ]; then echo "ok   footer: the pill line fits 120 ($(vis "$got"))"
else echo "FAIL footer: pills are $(vis "$got") wide"; FAILURES=$((FAILURES + 1)); fi
got=$(python3 -c "
import sys; sys.path.insert(0, '$DIR')
import tui
print(tui.footer_pills([('/x/stuck-app','STUCK'), ('/x/onset','RUNNING'), ('/x/notes','UNKNOWN')], 96, False))")
check footer "a stuck repo reads stuck"      'stuck \[stuck\]'
check footer "a running repo reads running"  'onset \[running\]'
check footer "an unreadable sibling reads unknown" 'notes \[unknown\]'
got=$(python3 -c "
import sys; sys.path.insert(0, '$DIR')
import tui
it = [('/x/north-ridge-app','IDLE'), ('/x/second-site-app','IDLE'), ('/x/gamma-app','EMPTY'),
      ('/x/four-lane-app','IDLE'), ('/x/epsilon-app','EMPTY')]
print(tui.footer_pills(it, 48, False))")
check footer "a narrow pane falls back to abbreviations" '^nr \[idle\]  ss \[idle\]'
CASES=$((CASES + 1))
if [ "$(vis "$got")" -le 48 ]; then echo "ok   footer: the abbr fallback fits 48 ($(vis "$got"))"
else echo "FAIL footer: abbr pills are $(vis "$got") wide"; FAILURES=$((FAILURES + 1)); fi
got=$(once "$W/full.json" --no-color --footer "ac bca usa")
check footer "a literal --footer line is printed" '^ac bca usa$'

# ── colour: escapes only when asked; and the reverse-video pill/banner ────────────────
CASES=$((CASES + 1))
if once "$W/full.json" | grep -q $'\033' && ! once "$W/full.json" --no-color | grep -q $'\033'
then echo "ok   colour: escapes only without --no-color"
else echo "FAIL colour: expected escapes with colour, none without"; FAILURES=$((FAILURES + 1)); fi
CASES=$((CASES + 1))
if once "$W/full.json" | grep -q $'\033\[1;7;38;5;'; then echo "ok   colour: the bottleneck stage is a reverse-video pill"
else echo "FAIL colour: no reverse-video pill in the ribbon"; FAILURES=$((FAILURES + 1)); fi
CASES=$((CASES + 1))
if once "$W/full.json" | grep -q $'\033\[38;5;240m'; then echo "ok   colour: the card borders are slate 240"
else echo "FAIL colour: card borders are not coloured"; FAILURES=$((FAILURES + 1)); fi

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
check delta "…beside its own gauge"        'unrefined +11 █[^┃]* \+1'
check delta "the gauge still sums after the move" '·'

# ── --height trims footer → health detail → ribbon → the ON YOU cap ────────────────────
python3 - "$W/tall.json" <<'EOF'
import json, sys
moves = [{"rung": "idle-gate", "gate_id": f"ac-g{i}", "title": f"DECISION: review item {i}",
          "created_at": "2026-09-01T00:00:00Z", "gate_kind": "decision", "blocks": 0,
          "subject": f"ac-g{i}", "detail": "decision", "route": "/ac-human"} for i in range(10)]
d = {"name": "tall-repo", "now": "2026-09-25T22:00:00+00:00",
     "verdict": {"state": "STUCK", "line": "⛔ STUCK — waiting on you", "reasons": []},
     "moves": moves, "epics": {"ok": True, "items": []}, "closed7": None,
     "most_recent_closed_epic": None, "plans": [], "pool": 0, "beads": None,
     "agents": None, "mail": "up", "split": None, "waves": 0, "prs": [], "ci": "none scheduled",
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
check height "…but keeps the HEALTH detail line"             '⚠ \? some read: boom'
check height "…and the ON YOU cap is untouched"               '\+ 2 more'

got=$(once "$W/tall.json" --no-color --footer "ac bca usa" --height $((base_n - 3)))
check height "a shorter pane drops the HEALTH detail"   '\? some read: boom' absent
check height "…the stage ribbon is still there"          'building 0'
check height "…the ON YOU cap is still untouched"        '\+ 2 more'

got=$(once "$W/tall.json" --no-color --footer "ac bca usa" --height $((base_n - 4)))
check height "shorter still drops the ribbon"  'building 0' absent
check height "…but keeps the ON YOU card"      '╔═╡ ON YOU ╞'

# the floor: footer + detail + ribbon gone, ON YOU capped to 0 — "-- 1" is below any pane
floor=$(once "$W/tall.json" --no-color --footer "ac bca usa" --height 1 | wc -l)
got=$(once "$W/tall.json" --no-color --footer "ac bca usa" --height $((floor + 2)))
CASES=$((CASES + 1))
n_more=$(grep -oE '\+ [0-9]+ more' <<<"$got" | grep -oE '[0-9]+')
if [ -n "$n_more" ] && [ "$n_more" -gt 2 ]; then echo "ok   height: a very short pane caps ON YOU further (+$n_more)"
else echo "FAIL height: expected ON YOU capped below 8 (+n more, n>2) in:"; sed 's/^/     | /' <<<"$got"; FAILURES=$((FAILURES + 1)); fi
CASES=$((CASES + 1))
if [ "$(wc -l <<<"$got")" -le $((floor + 2)) ]; then echo "ok   height: the trimmed frame fits --height $((floor + 2))"
else echo "FAIL height: frame is $(wc -l <<<"$got") lines, wider than $((floor + 2))"; FAILURES=$((FAILURES + 1)); fi

got=$(once "$W/tall.json" --no-color --footer "ac bca usa" --height 1)
check height "an impossible height caps ON YOU to 0 items" '\+ 10 more'
check height "…with the footer still gone"                 'ac bca usa' absent
check height "…and the detail still gone"                  '\? some read: boom' absent
CASES=$((CASES + 1))
if [ "$(wc -l <<<"$got")" = "$floor" ]; then echo "ok   height: --height 1 reaches the floor ($floor lines)"
else echo "FAIL height: --height 1 gave $(wc -l <<<"$got") lines, floor is $floor"; FAILURES=$((FAILURES + 1)); fi

# a fixture with no beads at all still renders the cards it can (never crashes)
got=$(once "$W/tall.json" --no-color)
check none "a missing beads read renders a BEADS card marked ?" '^│ \? the bead reads failed'
check none "…and an unreadable roster reads ?"                  'agents: \?'

# ── telemetry: the harness legend, sessions & tools, locks, and the activity tail ───────
# The model's `telemetry` block (model.py folds in telemetry.py's answer) drives four extra
# surfaces: the header's git badge, the harness legend bar, the SESSIONS & TOOLS card and the
# `tail -f activity.log` card. A model WITHOUT the block must render exactly as before — every
# check above this line runs on one.
cat >"$W/tel.json" <<'EOF'
{
  "git": {"branch": "main", "dirty": 0, "ahead": 0, "behind": 0},
  "reservations": [
    {"holder": "JadeLake", "program": "opencode", "path": "skills/ac-board/scripts/tui.py",
     "reason": "ac-board in-session telemetry", "exclusive": true,
     "created_at": "2026-10-14T23:02:34Z", "expires_at": "2026-10-15T00:02:34Z"},
    {"holder": "JadeLake", "program": "opencode", "path": "skills/ac-board/scripts/model.py",
     "reason": "ac-board in-session telemetry", "exclusive": true,
     "created_at": "2026-10-14T22:40:00Z", "expires_at": "2026-10-14T23:40:00Z"},
    {"holder": "OrangeAnchor", "program": "claude-code", "path": "skills/ac-board/scripts/board.sh",
     "reason": "lane work", "exclusive": true,
     "created_at": "2026-10-14T22:20:00Z", "expires_at": "2026-10-14T23:20:00Z"},
    {"holder": "OrangeAnchor", "program": "claude-code", "path": "skills/ac-board/scripts/render.py",
     "reason": "lane work", "exclusive": true,
     "created_at": "2026-10-14T22:19:00Z", "expires_at": "2026-10-14T23:19:00Z"}
  ],
  "bv": {"keystone": {"id": "ac-tv83.8", "unblocks": 12, "title": "Move distribution.template.md"},
         "bottleneck": {"id": "ac-an9w.9", "value": 95.3, "title": "A scheduled workflow runs autopilot"},
         "cycles": 0, "avg_close_days": 3.9, "closed_30d": 327},
  "harnesses": [
    {"harness": "opencode", "sessions_24h": 26, "active_now": 1, "tokens": 26837750,
     "cache_hit_pct": 93, "cost_usd": 1.8577, "models": ["gemini-4-argon-contributor"]},
    {"harness": "claude-code", "sessions_24h": 22, "active_now": 2, "tokens": 1571465,
     "cache_hit_pct": 69, "cost_usd": null, "models": ["claude-opus-5-5"]}
  ],
  "tools_24h": {"total": 184, "errors": 1,
    "top": [["bash", 98], ["read", 54], ["edit", 19], ["subagent", 8]]},
  "activity": [
    {"ts": "2026-10-14T23:02:34Z", "lane": "mail", "actor": "JadeLake", "text": "reserved 6 paths (skills/ac-board/scripts/*)"},
    {"ts": "2026-10-14T22:28:19Z", "lane": "git", "actor": "3ec02dce", "text": "feat(ac-board): tui cards, 2-column grid"},
    {"ts": "2026-10-14T22:15:00Z", "lane": "bead", "actor": "ac-tv83.14", "text": "closed · One shipping process"},
    {"ts": "2026-10-14T22:10:12Z", "lane": "opencode", "actor": "subagent", "text": "implementer · Implement upgraded ac-board TUI"}
  ]
}
EOF

# with <name> <fixture> — full.json plus that telemetry block (and a pinned "now" for the ages)
with() {
  python3 -c "
import json, sys
d = json.load(open('$W/full.json'))
d['telemetry'] = json.load(open(sys.argv[1]))
d['now'] = '2026-10-14T23:45:00+00:00'
json.dump(d, open(sys.argv[2], 'w'))" "$W/$1.json" "$W/$2.json"
}
with tel tel-model
TELFULL="$W/tel-model.json"

got=$(once_w "$TELFULL" 96 --no-color)
fits "telemetry" 96
noemoji "telemetry"
check tel "the header carries the branch and a clean tree" '^agent-compounds · main ✓ clean · [0-9]{2}:[0-9]{2}'
check tel "the legend gives each harness a ■ pill"        '■ opencode · gemini-4-argon… \(1 live\)'
check tel "…a second harness its own pill"                '■ claude-code · opus-5-5 \(2 live\)'
check tel "…and the file locks their own count"           '⊞ 4 locks'
order tel "the legend bar sits above the stage ribbon"    "■ opencode" "pool 1 · plan 3"
order tel "…and below the verdict banner"                 "STUCK · 2 gates" "■ opencode"
check tel "SESSIONS & TOOLS is a card"                    '^┌─┤ SESSIONS & TOOLS ├─'
check tel "a harness row gauges its tokens"               '^│ opencode +26 █{20} 26\.8M'
check tel "…the second row its own share"                 '^│ claude-code +22 █·{19} +1\.6M'
check tel "the cache row reads a percentage and a bar"    'cache hit 81% +█+'
check tel "the tool calls are broken down"                'tools 184 · bash 98 · read 54 · edit 19'
check tel "…subagent shortened, an error counted"         'sub 8 · ⚠ 1 error'
check tel "the SESSIONS badge counts the day's sessions"  '^┌─┤ SESSIONS & TOOLS ├─+┤ 48 sess ├─┐'
check tel "the keystone is named with what it unblocks"   '◆ keystone +ac-tv83\.8 → unblocks 12'
check tel "the bottleneck carries its centrality"         '▲ bottleneck ac-an9w\.9 \(centrality 95\)'
order tel "the graph facts sit below the gauges"          "unrefined  16" "◆ keystone"
check tel "the velocity summary is the EPICS footer"      'avg close 3\.9d · 327/30d · 0 cycles'
order tel "…below the epics it summarises"                "✓ One silver bullet" "avg close 3.9d"
check tel "a live lock shows holder, path and age"        '⊞ JadeLake +…d/scripts/tui\.py +42m'
check tel "…and the overflow is summarised"               '⊞ \+1 more lock'
check tel "the activity tail is a card"                   '^┌─┤ tail -f activity\.log ├─'
order tel "the activity tail is the last card"            "AGENTS & HEALTH" "tail -f activity.log"
order tel "its lines run oldest first, newest last"       "closed · One shipping process" "reserved 6 paths"
check tel "…each line lane · actor · event"               '^│ 01:02 +mail +JadeLake +reserved 6 paths'
check tel "in wide mode SESSIONS & TOOLS pairs with HEALTH" '^┌─┤ SESSIONS & TOOLS ├.+┌─┤ AGENTS & HEALTH ├'
check tel "the agent row drops a redundant program"       '│ ● ChartreuseWolf +bd-9x +claude-opus-4-6 +│'

got=$(once "$TELFULL" --no-color)
fits "telemetry narrow" 48
noemoji "telemetry narrow"
order tel "stacked, SESSIONS & TOOLS precedes AGENTS & HEALTH" "SESSIONS & TOOLS" "AGENTS & HEALTH"
order tel "…and follows BEADS"                                "BEADS" "SESSIONS & TOOLS"

# lanes are coloured by source: git green, mail amber, bead cyan, a harness lane blue
got=$(once_w "$TELFULL" 96)
check tel "the git lane is green"      "$(esc '38;5;114m')git"
check tel "the mail lane is amber"     "$(esc '38;5;215m')mail"
check tel "the bead lane is cyan"      "$(esc '38;5;117m')bead"
check tel "a harness lane is blue"     "$(esc '38;5;75m')opencode"

# a dirty tree is a warning, not a ✓; the lead rides along
python3 -c "
import json
d = json.load(open('$TELFULL'))
d['telemetry']['git'] = {'branch': 'main', 'dirty': 3, 'ahead': 2, 'behind': 0}
json.dump(d, open('$W/teldirty.json', 'w'))"
got=$(once_w "$W/teldirty.json" 96 --no-color)
check tel "a dirty tree warns with its count"  '^agent-compounds · main ⚠ 3 dirty ↑2 · '

# an empty telemetry block is silent: the git badge and nothing else
python3 -c "
import json
d = json.load(open('$TELFULL'))
d['telemetry'] = {'git': {'branch': 'main', 'dirty': 0, 'ahead': 0, 'behind': 0},
                  'reservations': [], 'bv': None, 'harnesses': [],
                  'tools_24h': {'total': 0, 'errors': 0, 'top': []}, 'activity': []}
json.dump(d, open('$W/telempty.json', 'w'))"
got=$(once_w "$W/telempty.json" 96 --no-color)
fits "telemetry empty" 96
noemoji "telemetry empty"
check tel "an empty telemetry block adds no SESSIONS card" 'SESSIONS & TOOLS' absent
check tel "…no activity tail"                              'tail -f activity.log' absent
check tel "…no lock rows"                                  '⊞' absent
check tel "…no ■ legend pill"                              '■' absent
check tel "…no keystone or bottleneck"                     'keystone|bottleneck' absent
check tel "…but the header still carries the branch"       '^agent-compounds · main ✓ clean'

# the trim ladder still holds with telemetry: footer → detail (tail + SESSIONS) → deco
base=$(once_w "$TELFULL" 96 --no-color --footer "ac bca usa")
base_n=$(wc -l <<<"$base")
got=$(once_w "$TELFULL" 96 --no-color --footer "ac bca usa" --height $((base_n - 1)))
check tel-height "a short pane drops the footer first"       'ac bca usa' absent
check tel-height "…keeping the activity tail"                'tail -f activity.log'
got=$(once_w "$TELFULL" 96 --no-color --footer "ac bca usa" --height $((base_n - 4)))
check tel-height "shorter drops the tail and the SESSIONS card" 'tail -f activity.log' absent
check tel-height "…and SESSIONS & TOOLS with it"                'SESSIONS & TOOLS' absent
check tel-height "…but the legend bar stays"                    '■ opencode'

# ── telemetry.py: the collector behind that block ───────────────────────────────────────
TEL="$DIR/telemetry.py"
ROOT="$(cd "$DIR/../../.." && pwd)"
t0=$(date +%s%N); out=$(timeout 10 python3 "$TEL" "$ROOT" 2>/dev/null); tel_rc=$?
tel_ms=$(( ($(date +%s%N) - t0) / 1000000 ))
CASES=$((CASES + 1))
if [ "$tel_rc" = 0 ] && python3 -c '
import json, sys
d = json.loads(sys.stdin.read())
assert isinstance(d["git"], dict), "git"
assert isinstance(d["reservations"], list), "reservations"
assert d["bv"] is None or isinstance(d["bv"], dict), "bv"
assert isinstance(d["harnesses"], list), "harnesses"
assert isinstance(d["tools_24h"], dict) and isinstance(d["tools_24h"]["top"], list), "tools_24h"
assert isinstance(d["activity"], list), "activity"' <<<"$out"
then echo "ok   telemetry.py: prints the six sections as one JSON object"
else echo "FAIL telemetry.py: rc=$tel_rc out=${out:0:200}"; FAILURES=$((FAILURES + 1)); fi
CASES=$((CASES + 1))
if [ "$tel_ms" -lt 2000 ]; then echo "ok   telemetry.py: answered the live repo in ${tel_ms}ms"
else echo "FAIL telemetry.py: took ${tel_ms}ms"; FAILURES=$((FAILURES + 1)); fi
CASES=$((CASES + 1))
out=$(timeout 10 python3 "$TEL" /nonexistent-repo 2>/dev/null); tel_rc=$?
if [ "$tel_rc" = 0 ] && python3 -c '
import json, sys
d = json.load(sys.stdin)
assert d["harnesses"] == [] and d["reservations"] == [] and d["activity"] == []' <<<"$out"
then echo "ok   telemetry.py: a repo that is not there is empty, never a crash"
else echo "FAIL telemetry.py: rc=$tel_rc on a missing repo"; FAILURES=$((FAILURES + 1)); fi
CASES=$((CASES + 1))
tel_branch=$(python3 "$TEL" "$ROOT" 2>/dev/null |
             python3 -c 'import json,sys; print(json.load(sys.stdin)["git"].get("branch") or "")')
if [ -n "$tel_branch" ]; then echo "ok   telemetry.py: the live repo reports its branch ($tel_branch)"
else echo "FAIL telemetry.py: no branch from the live repo"; FAILURES=$((FAILURES + 1)); fi

# ── the watcher re-execs itself the moment its own source changes ───────────────────────
# (a long-running watcher that re-shells the producer but keeps its own parser renders
#  impossible numbers after a field rename — so an edited tui.py must reload in place)
mkdir -p "$W/live"
cp "$TUI" "$W/live/tui.py"
cat >"$W/live/board.sh" <<EOF
#!/usr/bin/env bash
case " \$* " in *" --json "*) cat "$W/full.json" ;; *) exit 0 ;; esac
EOF
chmod +x "$W/live/board.sh"
( cd "$W/live" && exec python3 tui.py 30 >"$W/live/out.txt" 2>&1 ) &
live_pid=$!
sleep 2
before=$(ps -o args= -p "$live_pid" 2>/dev/null)
touch "$W/live/tui.py"
sleep 2
after=$(ps -o args= -p "$live_pid" 2>/dev/null)
alive=$(kill -0 "$live_pid" 2>/dev/null && echo yes || echo no)
kill "$live_pid" 2>/dev/null
CASES=$((CASES + 1))
if [ "$alive" = yes ] && [[ "$before" == *"tui.py 30"* ]] && [[ "$after" == *"tui.py"* && "$after" != *" 30"* ]]
then echo "ok   reload: an edited tui.py re-execs the watcher in place"
else echo "FAIL reload: before=[$before] after=[$after] alive=$alive"; FAILURES=$((FAILURES + 1)); fi
CASES=$((CASES + 1))
if ! grep -q Traceback "$W/live/out.txt"; then echo "ok   reload: the watcher never crashed"
else echo "FAIL reload: the watcher raised:"; sed 's/^/     | /' "$W/live/out.txt"; FAILURES=$((FAILURES + 1)); fi

echo "tui.test.sh: $((CASES - FAILURES))/$CASES passed"
[ "$FAILURES" -eq 0 ]
